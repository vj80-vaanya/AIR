import onnxruntime as ort
import numpy as np
from transformers import AutoTokenizer

MODEL_PATH = r'C:\X3D\assets\models\text_classifier.onnx'
MODEL_ID   = 'mrm8488/bert-tiny-finetuned-sms-spam-detection'
SEQ_LEN    = 64

print('Loading tokenizer ...')
tok  = AutoTokenizer.from_pretrained(MODEL_ID)

print('Loading ONNX session from:', MODEL_PATH)
sess = ort.InferenceSession(MODEL_PATH)
print('Inputs :', [i.name for i in sess.get_inputs()])
print('Outputs:', [o.name for o in sess.get_outputs()])

labels = {0: 'HAM', 1: 'SPAM'}
cases = [
    ('WINNER!! You have been selected to receive a 900 prize reward! To claim call 09061701461.', 'SPAM'),
    ('Had your mobile 11 months or more? U R entitled to Update to the latest colour mobiles for Free!', 'SPAM'),
    ('Hi, how are you doing? Are you free tonight?',                   'HAM'),
    ('Ok lar... Joking wif u oni...',                                   'HAM'),
    ('Nah I do not think he goes to usf, he lives around here though',  'HAM'),
]

print()
all_ok = True
for text, expected in cases:
    enc = tok(text, max_length=SEQ_LEN, padding='max_length',
               truncation=True, return_tensors='np')
    feeds = {
        'input_ids':      enc['input_ids'].astype(np.int64),
        'attention_mask': enc['attention_mask'].astype(np.int64),
        'token_type_ids': enc.get('token_type_ids',
                          np.zeros_like(enc['input_ids'])).astype(np.int64),
    }
    logits = sess.run(None, feeds)[0][0]
    probs  = np.exp(logits - logits.max())
    probs /= probs.sum()
    pred   = labels[int(np.argmax(probs))]
    conf   = float(probs[int(np.argmax(probs))])
    ok     = pred == expected
    if not ok:
        all_ok = False
    status = 'PASS' if ok else 'FAIL'
    print(f'  [{status}] {pred:4s} ({conf:.0%}) | {text[:55]}')

print()
print('Result:', 'ALL PASSED' if all_ok else 'SOME FAILED')
