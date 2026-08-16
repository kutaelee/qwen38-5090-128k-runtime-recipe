# Agent routing

## Default policy

| Purpose | Route |
| --- | --- |
| quick code, small exact patches, bounded tool use | Q5_K_M + llama.cpp + MTP3 |
| complex code, long context, analysis | NVFP4 + SGLang |
| autonomous work, planning, integration | NVFP4 + SGLang |

Task size is determined before model load. A large prompt is not automatically a long task, and a small repository is not automatically bounded. Prefer the long route when the task needs multi-stage planning, cross-file integration, repeated test repair, or substantial context reconstruction.

## Qwen Code wire profile

The tested agent settings use:

```text
contextWindowSize = 120000
max_tokens = 32768
temperature = 0
top_p = 1
timeout = 600000
maxRetries = 1
chat_template_kwargs.enable_thinking = false
skipLoopDetection = true
model.maxToolCallsPerTurn = absent
```

The production controller may set a total wall/tool safety envelope. It should not confuse that run-level envelope with a per-turn cap.

## Narrow no-progress detection

Different-file exploration is progress. After compaction, rereading necessary files can also be progress. Warn only on observable repetition such as:

- the same file and materially identical range three times without new evidence;
- the same command and unchanged result three times;
- the same failing test, hypothesis, patch shape, and failure three times;
- the same DOM/selector inspection three times without a new hypothesis.

After one warning, require a new hypothesis or semantic action. A second identical cycle may stop as semantic no progress.

## Fail closed

Do not silently fall back to another model when:

- the selected port is unavailable;
- `/v1/models` returns a different model;
- the other runtime is still resident;
- the task-local settings differ from the qualified context/sampling profile;
- the agent modifies unauthorized paths;
- independent verification fails.

Q5 remains a valid bounded worker even though it is not promoted for autonomous work by the current evidence.
