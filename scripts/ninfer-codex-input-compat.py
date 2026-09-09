"""Minimal NInfer-only input adapter for the observed Codex metadata failure.

Apply in the NInfer route before forwarding a Responses request. This is not a
complete Codex router; retain existing authentication, routing and normalization.
"""
from copy import deepcopy


def strip_codex_transport_metadata(payload):
    result = deepcopy(payload)
    items = result.get('input')
    if isinstance(items, list):
        for item in items:
            if isinstance(item, dict):
                item.pop('internal_chat_message_metadata_passthrough', None)
    return result


if __name__ == '__main__':
    source = {'input': [
        {'type': 'function_call', 'call_id': 'test-call', 'name': 'read_file',
         'arguments': '{"path":"src/example.ts"}',
         'internal_chat_message_metadata_passthrough': {'test': True}},
        {'type': 'function_call_output', 'call_id': 'test-call', 'output': '한국어'},
        {'role': 'assistant', 'phase': 'commentary', 'content': 'Inspecting'}]}
    result = strip_codex_transport_metadata(source)
    assert 'internal_chat_message_metadata_passthrough' in source['input'][0]
    expected = deepcopy(source)
    expected['input'][0].pop('internal_chat_message_metadata_passthrough')
    assert result == expected
    assert strip_codex_transport_metadata({'input': 'hello'}) == {'input': 'hello'}
    print('Metadata removal and content/call-ID preservation PASS')
