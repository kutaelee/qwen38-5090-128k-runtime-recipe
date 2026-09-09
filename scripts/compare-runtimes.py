"""Identical-content, sequential Chat Completions comparison; standard library only.

Run only against a server owned by your GPU reservation. No server lifecycle changes.
Outputs include complete responses for these public synthetic prompts only.
"""
import argparse
import ast
import hashlib
import json
import time
import urllib.request
from pathlib import Path

FACTS = {10: 'KITE-1031', 25: 'MAPLE-2547', 50: 'ORBIT-5099', 75: 'RIVER-7523', 90: 'SOLAR-9071'}


def context(units):
    if not units:
        return 'Repository: TypeScript utilities. All existing tests pass.'
    chunks = []
    for percent in range(1, 101):
        lines = [f'## Repository evidence chunk {percent:03d}']
        for unit in range(units):
            ident = percent * 10000 + unit
            lines.append(f'FILE src/module_{ident}.ts\nexport function normalize_{ident}(value: string): string {{ return value.trim().toLowerCase(); }}\nTEST module_{ident}: PASS; BUILD sha={ident:08x}; CONFIG retries=3 timeout_ms=5000; LOG clean=true')
        if percent in FACTS:
            lines.append(f'RETAIN_THIS_FACT position_{percent}={FACTS[percent]}')
        chunks.append('\n'.join(lines))
    return '\n\n'.join(chunks)


def request(args, prompt, **extra):
    body = dict(model=args.model, messages=[dict(role='user', content=prompt)],
                temperature=0, top_p=1, max_tokens=300, stream=True,
                stream_options={'include_usage': True},
                chat_template_kwargs={'enable_thinking': False})
    body.update(extra)
    start = time.perf_counter()
    req = urllib.request.Request(args.endpoint.rstrip('/') + '/chat/completions',
                                 json.dumps(body).encode(), {'Content-Type': 'application/json'})
    chunks, first, last, usage, timings = [], None, None, {}, {}
    content, thoughts, calls = '', '', {}
    with urllib.request.urlopen(req, timeout=900) as response:
        for line in response:
            if not line.startswith(b'data: '):
                continue
            data = line[6:].strip()
            if data == b'[DONE]':
                break
            chunk = json.loads(data)
            if 'error' in chunk:
                raise RuntimeError(str(chunk['error']))
            chunks.append(chunk)
            usage = chunk.get('usage') or usage
            timings = chunk.get('timings') or timings
            for choice in chunk.get('choices', []):
                delta = choice.get('delta', {})
                text = delta.get('content') or ''
                reasoning = delta.get('reasoning_content') or ''
                tc = delta.get('tool_calls') or []
                if text or reasoning or tc:
                    now = time.perf_counter()
                    first = now if first is None else first
                    last = now
                content += text
                thoughts += reasoning
                for call in tc:
                    idx = call.get('index', 0)
                    dst = calls.setdefault(idx, {'name': '', 'arguments': ''})
                    fn = call.get('function', {})
                    dst['name'] += fn.get('name') or ''
                    dst['arguments'] += fn.get('arguments') or ''
    wall = time.perf_counter() - start
    return dict(prompt_sha256=hashlib.sha256(prompt.encode()).hexdigest(),
                input_tokens=usage.get('prompt_tokens'), output_tokens=usage.get('completion_tokens'),
                usage=usage, ttft_seconds=first-start if first else None, wall_seconds=wall,
                stream_seconds=last-first if first and last else None,
                content=content, thoughts=thoughts, calls=list(calls.values()),
                timings=timings, finish_reason=next((c['choices'][0].get('finish_reason') for c in reversed(chunks) if c.get('choices')), None))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--endpoint', required=True)
    parser.add_argument('--model', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = {'model': args.model, 'rows': []}
    args.output.parent.mkdir(parents=True, exist_ok=True)

    def save():
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')

    def run(kind, prompt, expected=None, **extra):
        try:
            row = request(args, prompt, **extra)
        except Exception as exc:
            detail = exc.read().decode(errors='replace') if hasattr(exc, 'read') else str(exc)
            report['error'] = {'kind': kind, 'detail': detail}
            save()
            raise
        row['kind'] = kind
        row['pass'] = not row['thoughts'] and '\ufffd' not in row['content']
        if expected is not None:
            try:
                row['pass'] &= bool(expected(row))
            except Exception as exc:
                row['pass'] = False
                row['validation_error'] = str(exc)
        report['rows'].append(row)
        save()
        print(json.dumps({k: row.get(k) for k in ('kind', 'pass', 'input_tokens', 'output_tokens', 'wall_seconds', 'ttft_seconds')}), flush=True)
        return row

    basic = [('Reply exactly OK.', 'OK'), ('What is 2+2? Reply only the number.', '4'),
             ('한국어 단어 안녕만 출력하세요.', '안녕')]
    for p, e in basic:
        run('basic', p, lambda r, e=e: r['content'].strip() == e, max_tokens=64)
    schema = {'type': 'object', 'properties': {'value': {'type': 'integer'}, 'label': {'type': 'string'}}, 'required': ['value', 'label'], 'additionalProperties': False}
    report['constrained_json_schema'] = 'UNSUPPORTED: response_format_not_supported observed in prior attempt'
    for i in range(20):
        run('json', f'Return JSON with value {i} and label 한국어.',
            lambda r, i=i: json.loads(r['content']) == {'value': i, 'label': '한국어'},
            max_tokens=128)
    tools = [{'type': 'function', 'function': {'name': 'read_file', 'description': 'Read a UTF-8 source file', 'parameters': {'type': 'object', 'properties': {'path': {'type': 'string'}}, 'required': ['path'], 'additionalProperties': False}}}]
    for i in range(40):
        path = f'src/module_{i}.tsx'
        run('tool', f'Call read_file for {path}.', lambda r, path=path: len(r['calls']) == 1 and r['calls'][0]['name'] == 'read_file' and json.loads(r['calls'][0]['arguments']) == {'path': path}, tools=tools, max_tokens=128)
    tasks = [
        ('sum_even', 'Return the sum of even integers in xs.', [([], 0), ([1,2,3,4], 6), ([-2,2,7], 0)]),
        ('unique', 'Return a list of distinct integers in xs, preserving first occurrence order.', [([], []), ([3,1,3,2,1], [3,1,2])]),
        ('max_run', 'Return the longest consecutive run length of equal integers in xs; empty input returns zero.', [([], 0), ([1,1,2,2,2,1], 3), ([7], 1)])
    ]
    def check_code(row, name, cases):
        source = row['content'].strip()
        if source.startswith('```'):
            source = '\n'.join(source.splitlines()[1:-1])
        tree = ast.parse(source)
        allowed_calls = {'sum', 'len', 'range', 'max', 'min', 'list', 'set', 'enumerate'}
        for node in ast.walk(tree):
            if isinstance(node, (ast.Import, ast.ImportFrom, ast.Attribute, ast.ClassDef, ast.Global, ast.Nonlocal, ast.While)):
                return False
            if isinstance(node, ast.Name) and node.id.startswith('__'):
                return False
            if isinstance(node, ast.Call) and (not isinstance(node.func, ast.Name) or node.func.id not in allowed_calls):
                return False
        import builtins
        scope = {'__builtins__': {n: getattr(builtins, n) for n in allowed_calls}}
        exec(compile(tree, '<generated-fixture>', 'exec'), scope)
        return all(scope[name](xs) == expected for xs, expected in cases)
    for name, specification, cases in tasks:
        for repetition in range(4):
            run(('coding-warmup-' if repetition == 0 else 'coding-')+name,
                f'Write only a Python function {name}(xs). {specification} Use no imports, attributes, while loops or type annotations. Only pure builtins and for loops/comprehensions are allowed. Do not include tests or explanations.',
                lambda r, name=name, cases=cases: check_code(r, name, cases), max_tokens=512)
    for depth, units in [('short', 0), ('38K', 5), ('84K', 11), ('114K', 15)]:
        ctx = context(units)
        if units:
            expected = {f'p{k}': v for k, v in FACTS.items()}
            run('recall-'+depth, ctx+'\nReturn a JSON object with keys p10,p25,p50,p75,p90 containing the retained facts at those positions. No markdown.', lambda r: json.loads(r['content']) == expected, max_tokens=256)
        prompt = ctx+'\n\nImplement a robust TypeScript RepositoryIndex class with parsing, validation, deduplication, typed errors, and tests. Output code only and include all implementation details.'
        run('warmup-'+depth, prompt)
        for _ in range(3):
            run('decode-'+depth, prompt)
    report['completed'] = True
    save()


if __name__ == '__main__':
    main()
