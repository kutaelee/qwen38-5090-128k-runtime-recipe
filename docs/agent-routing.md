# Agent routing

## Default policy

| Purpose | Route |
| --- | --- |
| quick code, small exact patches, bounded tool use | Q5_K_M + llama.cpp + MTP3 |
| single-agent autonomous long task, complex implementation | Q5_K_M + llama.cpp + MTP3 (Candidate) |
| high-concurrency multi-tenant serving, analysis baseline | NVFP4 + SGLang |

Task size is determined before model load. Prefer the Q5/MTP3 route for high-speed single-agent interactive workflows and bounded tasks. When running deep autonomous trajectories, ensure the harness uses `skipLoopDetection: true` and an external semantic guard.

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
