"""Explicit JSON-only diagnostic, separate from the original prompt results."""
import argparse
import json
from pathlib import Path
from importlib.util import spec_from_file_location, module_from_spec

spec = spec_from_file_location('comparison', Path(__file__).with_name('compare-runtimes.py'))
mod = module_from_spec(spec)
spec.loader.exec_module(mod)
args = argparse.Namespace(endpoint='http://127.0.0.1:8083/v1', model='qwen3.8-27b')
rows = []
for i in range(20):
    row = mod.request(args, f'Return ONLY a raw JSON object with value {i} and label 한국어. No Markdown fences, no prose. The first character must be {{ and the last must be }}.', max_tokens=128)
    try:
        row['pass'] = json.loads(row['content']) == {'value': i, 'label': '한국어'} and not row['thoughts']
    except ValueError:
        row['pass'] = False
    rows.append(row)
Path('results/ninfer-explicit-json.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'pass': sum(r['pass'] for r in rows), 'total': len(rows)}))
