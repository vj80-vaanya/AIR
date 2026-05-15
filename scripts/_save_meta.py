import json, os, time
from pathlib import Path

DATA_DIR  = Path(r'C:\X3D\assets\data')
MODEL_DIR = Path(r'C:\X3D\assets\models')

meta = {
    'model_id':      'mrm8488/bert-tiny-finetuned-sms-spam-detection',
    'version':       1,
    'seq_len':       64,
    'labels':        {'0': 'LABEL_0', '1': 'LABEL_1'},
    'spam_label_id': 1,
    'ham_label_id':  0,
    'note':          'LABEL_0=ham LABEL_1=spam (trained on UCI SMS Spam Collection)',
    'files': {
        'onnx':             'text_classifier.onnx',
        'vocab':            'vocab.txt',
        'tokenizer_config': 'tokenizer_config.json',
    },
    'size_bytes': {
        'onnx': os.path.getsize(MODEL_DIR / 'text_classifier.onnx'),
    },
    'converted_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
}

with open(DATA_DIR / 'model_meta.json', 'w') as f:
    json.dump(meta, f, indent=2)

sz = meta['size_bytes']['onnx']
print('Saved model_meta.json')
print('  onnx size:', round(sz / 1024 / 1024, 1), 'MB')
