"""
Converts assets/data/vocab.txt → native/src/vocab_table.c

The generated file embeds the full WordPiece vocabulary as a C array,
eliminating runtime file I/O and keeping the tokenizer self-contained.

Usage:
    python scripts/build_c_vocab.py
"""

import json
import sys
from pathlib import Path

ROOT      = Path(__file__).parent.parent
VOCAB_IN  = ROOT / "assets" / "data" / "vocab.txt"
META_IN   = ROOT / "assets" / "data" / "tokenizer_config.json"
OUT_C     = ROOT / "native" / "src" / "vocab_table.c"
OUT_H     = ROOT / "native" / "include" / "vocab_table.h"


def load_vocab(path: Path) -> list[str]:
    with open(path, encoding="utf-8") as f:
        return [line.rstrip("\n") for line in f]


def load_meta(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def escape_c_string(s: str) -> str:
    out = []
    for ch in s:
        if ch == '"':   out.append('\\"')
        elif ch == '\\': out.append('\\\\')
        elif ch == '\n': out.append('\\n')
        elif ch == '\r': out.append('\\r')
        elif ch == '\t': out.append('\\t')
        elif ord(ch) < 32 or ord(ch) > 126:
            out.append(f"\\x{ord(ch):02x}")
        else:
            out.append(ch)
    return "".join(out)


def write_header(vocab: list[str], meta: dict):
    vocab_size = len(vocab)
    content = f"""\
#ifndef VOCAB_TABLE_H
#define VOCAB_TABLE_H

/* AUTO-GENERATED — run scripts/build_c_vocab.py to regenerate */

#include <stdint.h>

#define VOCAB_SIZE       {vocab_size}
#define VOCAB_SEQ_LEN    {meta.get("seq_len", 64)}

#define TOKEN_UNK        {meta.get("unk_token_id",  100)}
#define TOKEN_SEP        {meta.get("sep_token_id",  102)}
#define TOKEN_PAD        {meta.get("pad_token_id",  0)}
#define TOKEN_CLS        {meta.get("cls_token_id",  101)}
#define TOKEN_MASK       {meta.get("mask_token_id", 103)}

extern const char * const VOCAB_TABLE[VOCAB_SIZE];

/* Returns token id for a given WordPiece token, TOKEN_UNK if not found. */
int vocab_lookup(const char *token);

/* Tokenize null-terminated UTF-8 text into token IDs.
   out_ids must be pre-allocated with at least max_len int32_t slots.
   Returns the number of tokens written (always <= max_len). */
int wordpiece_tokenize(const char *text,
                       int32_t    *out_ids,
                       int         max_len,
                       int         do_lower_case);

#endif /* VOCAB_TABLE_H */
"""
    OUT_H.write_text(content, encoding="utf-8")
    print(f"  Header  → {OUT_H}")


def write_source(vocab: list[str], meta: dict):
    vocab_size = len(vocab)
    lines = []

    lines.append("/* AUTO-GENERATED — run scripts/build_c_vocab.py to regenerate */")
    lines.append('#include "vocab_table.h"')
    lines.append('#include <string.h>')
    lines.append('#include <stdint.h>')
    lines.append('#include <ctype.h>')
    lines.append('#include <stdio.h>')
    lines.append("")

    # Vocabulary string table
    lines.append(f"const char * const VOCAB_TABLE[VOCAB_SIZE] = {{")
    chunk = []
    for i, token in enumerate(vocab):
        escaped = escape_c_string(token)
        chunk.append(f'    /* {i:5d} */ "{escaped}"')
    lines.append(",\n".join(chunk))
    lines.append("};")
    lines.append("")

    # Simple linear search — fast enough for vocab_size ~30k with short tokens.
    # For production, replace with a hash map (e.g. uthash).
    lines.append("""\
int vocab_lookup(const char *token) {
    if (!token) return TOKEN_UNK;
    for (int i = 0; i < VOCAB_SIZE; i++) {
        if (strcmp(VOCAB_TABLE[i], token) == 0) return i;
    }
    return TOKEN_UNK;
}
""")

    # WordPiece tokenizer
    # The full algorithm:
    #   1. Lowercase (if do_lower_case)
    #   2. Split on whitespace and punctuation
    #   3. For each word: try longest prefix match; remainder gets "##" prefix
    lines.append("""\
/* Maximum single-word length we will attempt to tokenize */
#define MAX_WORD_LEN 128

static int is_punct(unsigned char c) {
    return ispunct(c) && c != '\''; /* keep apostrophes */
}

static int tokenize_word(const char *word, int word_len,
                         int32_t *ids, int max_ids) {
    if (word_len == 0 || max_ids == 0) return 0;

    char sub[MAX_WORD_LEN + 3]; /* +3 for "##" prefix + NUL */
    int  n_ids = 0;
    int  start = 0;

    while (start < word_len && n_ids < max_ids) {
        int found   = -1;
        int end     = word_len;

        /* Longest-match greedy search */
        while (end > start) {
            int is_suffix = (start > 0);
            int prefix_len = is_suffix ? 2 : 0;
            int sub_len    = end - start + prefix_len;

            if (sub_len >= MAX_WORD_LEN + 3) { end--; continue; }

            if (is_suffix) {
                sub[0] = '#'; sub[1] = '#';
                memcpy(sub + 2, word + start, (size_t)(end - start));
                sub[sub_len] = '\\0';
            } else {
                memcpy(sub, word + start, (size_t)(end - start));
                sub[end - start] = '\\0';
            }

            int id = vocab_lookup(sub);
            if (id != TOKEN_UNK) {
                found = id;
                break;
            }
            end--;
        }

        if (found == -1 || end == start) {
            /* Cannot tokenize — emit UNK for whole remaining word */
            ids[n_ids++] = TOKEN_UNK;
            break;
        }

        ids[n_ids++] = found;
        start = end;
    }

    return n_ids;
}

int wordpiece_tokenize(const char *text,
                       int32_t    *out_ids,
                       int         max_len,
                       int         do_lower_case) {
    if (!text || !out_ids || max_len < 4) return 0;

    int n = 0;

    /* [CLS] token at position 0 */
    out_ids[n++] = TOKEN_CLS;

    char word[MAX_WORD_LEN];
    int  word_len = 0;

    for (const char *p = text; ; p++) {
        unsigned char c = (unsigned char)*p;
        int end_of_input = (c == '\\0');

        if (end_of_input || isspace(c) || is_punct(c)) {
            /* Flush current word */
            if (word_len > 0 && n < max_len - 1) {
                word[word_len] = '\\0';
                int32_t sub_ids[MAX_WORD_LEN];
                int sub_n = tokenize_word(word, word_len,
                                          sub_ids,
                                          max_len - n - 1 /* reserve [SEP] */);
                for (int i = 0; i < sub_n && n < max_len - 1; i++) {
                    out_ids[n++] = sub_ids[i];
                }
                word_len = 0;
            }
            /* Punctuation as its own token */
            if (!end_of_input && is_punct(c) && n < max_len - 1) {
                char pstr[2] = { (char)c, '\\0' };
                out_ids[n++] = vocab_lookup(pstr);
            }
            if (end_of_input) break;
        } else {
            if (word_len < MAX_WORD_LEN - 1) {
                word[word_len++] = do_lower_case ? (char)tolower(c) : (char)c;
            }
        }
    }

    /* [SEP] token at the end */
    if (n < max_len) out_ids[n++] = TOKEN_SEP;

    /* Pad to max_len */
    while (n < max_len) out_ids[n++] = TOKEN_PAD;

    return n;
}
""")

    OUT_C.write_text("\n".join(lines), encoding="utf-8")
    print(f"  Source  → {OUT_C}")


def main():
    print("=" * 60)
    print(" build_c_vocab — WordPiece vocabulary → C source")
    print("=" * 60)

    if not VOCAB_IN.exists():
        print(f"ERROR: {VOCAB_IN} not found.")
        print("  Run 'python scripts/convert_model.py' first.")
        sys.exit(1)

    vocab = load_vocab(VOCAB_IN)
    meta  = load_meta(META_IN) if META_IN.exists() else {}

    print(f"  Vocab size : {len(vocab):,} tokens")
    print(f"  Seq length : {meta.get('seq_len', 64)}")
    print(f"  Lower case : {meta.get('do_lower_case', True)}")
    print()

    write_header(vocab, meta)
    write_source(vocab, meta)

    size_c = OUT_C.stat().st_size
    size_h = OUT_H.stat().st_size
    print(f"\n  vocab_table.c : {size_c/1024:.1f} KB")
    print(f"  vocab_table.h : {size_h/1024:.1f} KB")
    print()
    print("  Next step:")
    print("    Add vocab_table.c to native/CMakeLists.txt ENGINE_SOURCES")
    print("    Add #include \"vocab_table.h\" to native/src/ml_inference.c")
    print("=" * 60)


if __name__ == "__main__":
    main()
