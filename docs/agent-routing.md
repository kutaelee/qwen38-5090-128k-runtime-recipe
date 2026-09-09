# Agent routing

## Default policy

| Purpose | Route |
| --- | --- |
| quick code, bounded tool use, complex or autonomous single-agent work | NInfer NVFP4 + FP8 KV + MTP3 |
| explicit rollback after a reviewed NInfer startup/integration failure | Q5_K_M + llama.cpp + MTP3 |
| high-concurrency multi-tenant serving, analysis baseline | NVFP4 + SGLang |

Task purpose is determined before model load. NInfer is the default single-agent route; llama.cpp is an explicit fallback rather than a silent recovery path. When running deep autonomous trajectories, the existing harness still uses `skipLoopDetection: true` and the same external semantic guard.

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

The production controller may set a total wall/tool safety envelope (e.g. 300 tools / 45 min). It should not confuse that run-level envelope with a per-turn cap.

The NInfer server may expose a 240,000-token logical ceiling, but this does not raise the Qwen Code operating ceiling. `contextWindowSize = 120000` and `autoCompactThreshold = 0.7` remain unchanged.

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

An NInfer startup failure is reported directly. Selecting `single-agent-fallback` is an explicit operator decision; the router does not hide the failure by automatically switching runtimes.
