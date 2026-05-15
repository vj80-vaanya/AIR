"""
Model conversion pipeline
HuggingFace bert-tiny SMS spam (PyTorch) -> ONNX (single-file, FP32)

Usage:
    # From project root, using the venv at C:\ml\venv:
    C:\ml\venv\Scripts\python scripts\convert_model.py

Outputs:
    assets/models/text_classifier.onnx   (~17 MB, FP32, all weights inlined)
    assets/data/vocab.txt                (WordPiece vocabulary, 30522 tokens)
    assets/data/tokenizer_config.json    (special token IDs)
    assets/data/model_meta.json          (labels, version, file sizes)

Label semantics (UCI SMS Spam Collection):
    LABEL_0 = ham  (legitimate)
    LABEL_1 = spam

Next step:
    C:\ml\venv\Scripts\python scripts\build_c_vocab.py
"""

import io
import json
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

import numpy as np

# ── Config ────────────────────────────────────────────────────────────────────

MODEL_ID   = "mrm8488/bert-tiny-finetuned-sms-spam-detection"
SEQ_LEN    = 64
ASSETS_DIR = Path(__file__).parent.parent / "assets"
MODEL_DIR  = ASSETS_DIR / "models"
DATA_DIR   = ASSETS_DIR / "data"
TMP_DIR    = Path("C:/ml/tmp_convert")

MODEL_DIR.mkdir(parents=True, exist_ok=True)
DATA_DIR.mkdir(parents=True, exist_ok=True)
TMP_DIR.mkdir(parents=True, exist_ok=True)

# Validation cases (classic English SMS spam — matches training distribution)
VALIDATION_CASES = [
    ("WINNER!! You have been selected to receive a 900 prize reward! To claim call 09061701461.", "LABEL_1"),
    ("Had your mobile 11 months or more? U R entitled to Update to the latest colour mobiles for Free!", "LABEL_1"),
    ("Hi, how are you doing? Are you free tonight?",                   "LABEL_0"),
    ("Ok lar... Joking wif u oni...",                                   "LABEL_0"),
    ("Nah I do not think he goes to usf, he lives around here though",  "LABEL_0"),
]


# ── Step 1 — Download ─────────────────────────────────────────────────────────

def download_model():
    print("\n[1/4] Downloading model from HuggingFace ...")
    from transformers import AutoTokenizer, AutoModelForSequenceClassification
    import torch

    tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
    model = AutoModelForSequenceClassification.from_pretrained(MODEL_ID)
    model.eval()

    labels = {int(k): v for k, v in model.config.id2label.items()}
    print("      Labels     :", labels)
    print("      Parameters :", f"{sum(p.numel() for p in model.parameters()):,}")
    return tokenizer, model, labels


# ── Step 2 — Export vocabulary ────────────────────────────────────────────────

def export_vocab(tokenizer):
    print("\n[2/4] Exporting vocabulary ...")
    vocab = tokenizer.get_vocab()
    sorted_vocab = sorted(vocab.items(), key=lambda x: x[1])

    vocab_path = DATA_DIR / "vocab.txt"
    with open(vocab_path, "w", encoding="utf-8") as f:
        for token, _ in sorted_vocab:
            f.write(token + "\n")

    special = {
        "unk_token":     tokenizer.unk_token,
        "sep_token":     tokenizer.sep_token,
        "pad_token":     tokenizer.pad_token,
        "cls_token":     tokenizer.cls_token,
        "mask_token":    tokenizer.mask_token,
        "unk_token_id":  tokenizer.unk_token_id,
        "sep_token_id":  tokenizer.sep_token_id,
        "pad_token_id":  tokenizer.pad_token_id,
        "cls_token_id":  tokenizer.cls_token_id,
        "mask_token_id": tokenizer.mask_token_id,
        "vocab_size":    tokenizer.vocab_size,
        "do_lower_case": getattr(tokenizer, "do_lower_case", True),
        "seq_len":       SEQ_LEN,
    }
    with open(DATA_DIR / "tokenizer_config.json", "w") as f:
        json.dump(special, f, indent=2)

    print("      Vocab size :", len(sorted_vocab), "->", str(vocab_path))
    return vocab_path


# ── Step 3 — Export ONNX (single inlined file) ───────────────────────────────

def export_onnx(model, tokenizer):
    print("\n[3/4] Exporting to ONNX ...")
    import torch
    import onnx
    from onnx.external_data_helper import load_external_data_for_model

    tmp_onnx = TMP_DIR / "model.onnx"

    dummy = tokenizer(
        "test message",
        max_length=SEQ_LEN,
        padding="max_length",
        truncation=True,
        return_tensors="pt",
    )
    input_ids      = dummy["input_ids"]
    attention_mask = dummy["attention_mask"]
    token_type_ids = dummy.get("token_type_ids", torch.zeros_like(input_ids))

    with torch.no_grad():
        torch.onnx.export(
            model,
            (input_ids, attention_mask, token_type_ids),
            str(tmp_onnx),
            opset_version=14,
            input_names=["input_ids", "attention_mask", "token_type_ids"],
            output_names=["logits"],
            dynamic_axes={
                "input_ids":      {0: "batch"},
                "attention_mask": {0: "batch"},
                "token_type_ids": {0: "batch"},
                "logits":         {0: "batch"},
            },
        )

    # Load with external data, then inline everything into one file
    onnx_model = onnx.load(str(tmp_onnx), load_external_data=False)
    load_external_data_for_model(onnx_model, str(TMP_DIR))

    out_path = MODEL_DIR / "text_classifier.onnx"
    onnx.save(onnx_model, str(out_path), save_as_external_data=False)

    size_mb = out_path.stat().st_size / 1024 / 1024
    print("      ONNX file :", str(out_path), f"({size_mb:.1f} MB, inlined)")
    return out_path


# ── Step 4 — Validate with ONNX Runtime ──────────────────────────────────────

def validate(onnx_path, tokenizer):
    import onnxruntime as ort

    print("\n[4/4] Validating with ONNX Runtime ...")
    sess    = ort.InferenceSession(str(onnx_path))
    labels  = {0: "LABEL_0", 1: "LABEL_1"}
    all_ok  = True

    for text, expected in VALIDATION_CASES:
        enc = tokenizer(text, max_length=SEQ_LEN, padding="max_length",
                        truncation=True, return_tensors="np")
        feeds = {
            "input_ids":      enc["input_ids"].astype(np.int64),
            "attention_mask": enc["attention_mask"].astype(np.int64),
            "token_type_ids": enc.get(
                "token_type_ids", np.zeros_like(enc["input_ids"])
            ).astype(np.int64),
        }
        logits = sess.run(None, feeds)[0][0]
        probs  = np.exp(logits - logits.max())
        probs /= probs.sum()
        pred   = int(np.argmax(probs))
        pred_lbl = labels[pred].upper()
        conf   = float(probs[pred])
        ok     = pred_lbl == expected
        if not ok:
            all_ok = False
        status = "PASS" if ok else "FAIL"
        print("     ", "[" + status + "]", pred_lbl, f"({conf:.0%}) |", text[:55])

    return all_ok


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("=" * 62)
    print(" AI Phone Security -- ONNX Model Conversion Pipeline")
    print("=" * 62)
    print(" Source :", MODEL_ID)
    print(" Seq len:", SEQ_LEN, "tokens")
    print(" Output :", str(MODEL_DIR))

    tokenizer, model, labels = download_model()
    export_vocab(tokenizer)
    onnx_path = export_onnx(model, tokenizer)
    ok = validate(onnx_path, tokenizer)

    meta = {
        "model_id":      MODEL_ID,
        "version":       1,
        "seq_len":       SEQ_LEN,
        "labels":        {str(k): v for k, v in labels.items()},
        "spam_label_id": next((k for k, v in labels.items() if v.upper() in ("LABEL_1", "SPAM")), 1),
        "ham_label_id":  next((k for k, v in labels.items() if v.upper() in ("LABEL_0", "HAM")),  0),
        "note":          "LABEL_0=ham LABEL_1=spam (trained on UCI SMS Spam Collection)",
        "files": {
            "onnx":             onnx_path.name,
            "vocab":            "vocab.txt",
            "tokenizer_config": "tokenizer_config.json",
        },
        "size_bytes": {
            "onnx": onnx_path.stat().st_size,
        },
        "converted_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    with open(DATA_DIR / "model_meta.json", "w") as f:
        json.dump(meta, f, indent=2)

    shutil.rmtree(TMP_DIR, ignore_errors=True)

    print("\n" + "=" * 62)
    result = "ALL PASSED" if ok else "SOME FAILED -- review output"
    print(" Validation :", result)
    sz_mb = meta["size_bytes"]["onnx"] / 1024 / 1024
    print(" ONNX size  :", round(sz_mb, 1), "MB")
    print()
    print(" Next step:")
    print("   C:\\ml\\venv\\Scripts\\python scripts\\build_c_vocab.py")
    print("=" * 62)


if __name__ == "__main__":
    main()
