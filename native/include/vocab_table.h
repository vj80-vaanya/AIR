#ifndef VOCAB_TABLE_H
#define VOCAB_TABLE_H

/* AUTO-GENERATED — run scripts/build_c_vocab.py to regenerate */

#include <stdint.h>

#define VOCAB_SIZE       30522
#define VOCAB_SEQ_LEN    64

#define TOKEN_UNK        100
#define TOKEN_SEP        102
#define TOKEN_PAD        0
#define TOKEN_CLS        101
#define TOKEN_MASK       103

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
