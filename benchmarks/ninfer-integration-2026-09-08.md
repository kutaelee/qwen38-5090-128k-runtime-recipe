# NInfer integration smoke results — 2026-09-08

**Result: startup and Codex Responses connectivity PASS; performance and long-agent qualification not performed.** This report summarizes retained server logs and Codex CLI event output. Private paths, session identifiers and raw workstation logs are excluded. No throughput benchmark or runtime comparison was run.

## Reproducible identity

| Component | Tested identity |
| --- | --- |
| GPU | RTX 5090 32 GB |
| Host / guest | Windows / WSL2 Ubuntu 26.04 |
| NVIDIA driver | 610.74 |
| CUDA compiler | 13.3.73 |
| NInfer | `a16b6442856620b7e4856acb25215acbf7e3c750` |
| Artifact repository | [neroued/Qwen3.8-27B-nvfp4-NInfer](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer) |
| Artifact revision | `11dbbbbbc33db198afe2f02c9232c771ff7031be` |
| Artifact | `qwen3_8_27b_nvfp4.ninfer`, 23,719,496,192 bytes |
| Verified SHA-256 | `552c374c685dce302603b95fbe940fb04243c0cd44c083efc644ad3d980d462c` |
| Codex CLI | 0.153.4 |

The [launcher](../configs/ninfer-nvfp4-mtp3.example.sh) uses FP8 KV, MTP3, concurrency 1, thinking OFF, 240,000 runtime/KV tokens, two cached device states, eight host states and 8 GiB host KV. Codex's catalog context is 120,000. The existing Qwen Code 120,000 / 0.7 auto-compaction settings were preserved; Qwen Code was not exercised in this smoke test.

Build used Ninja, Release mode, the pinned source, `CUDACXX=/usr/local/cuda/bin/nvcc`, and `cmake --build <BUILD_DIR> -j 8`.

## Observed startup

One completed startup reported weights ready in 4.7 s, CUDA graphs ready in 5.3 s and engine ready in 21.9 s. These are server log timings, not repeated cold/warm statistics or scheduler-to-ready wall time.

| Server-reported allocation | Value |
| --- | ---: |
| Weights | 19.7 GiB |
| Runtime allocation | 8.52 GiB |
| Free memory at capacity report | 2.02 GiB |
| KV capacity | 240,000 tokens, FP8 |
| Pinned host state | 1.15 GiB |
| Pinned host KV | 8.00 GiB |

Allocation does not prove 240K prefill or long-context correctness. Host caching is explicitly enabled; this is not a claim of zero host-memory use. No CUDA/OOM error appears in the retained server log.

## Request evidence

| Request | Input tokens | Output tokens | Server TTFT | Result |
| --- | ---: | ---: | ---: | --- |
| Direct Responses smoke | 17 | 2 | 795 ms | `OK` |
| Codex through local adapter | 6,438 | 5 | 2.6 s | `NINFER_OK`, exit 0 |
| Independent Codex repeat through adapter | 10,231 | 5 | 7.9 s | `NINFER_OK`, exit 0 |

Codex's retained JSON event output for the first adapter call reports `reasoning_output_tokens=0`. The server logged thinking OFF for all three requests. The app-server model list exposed `qwen3.8-27b` with `hidden=false` and reasoning effort `none`; the catalog set both context limits to 120,000. The visible desktop menu was not operated directly.

Outputs were only two to five tokens. Consequently, their logged decode rates and three-token draft acceptance samples are not used as performance evidence or added to the comparative benchmark table. The two Codex prompts also differed in tool/context overhead. No tools were executed, so tool-call correctness, coding quality and long-agent completion remain untested.

## Compatibility findings

- Sending `chat_template_kwargs.enable_thinking` to Responses produced `chat_template_option_not_supported`. The server-level `--no-thinking` setting was used instead.
- A direct Codex provider request produced `include_not_supported` for `include:["reasoning.encrypted_content"]`.
- The successful path was Codex → local compatibility router → NInfer. The router removed `include`, `reasoning` and `chat_template_kwargs`. This documents the tested adapter behavior; it does not claim complete Responses compatibility.
- Codex encountered WebSocket HTTP 426 and successfully fell back to HTTP. Skill-budget and MCP-shutdown warnings were also observed; the request still exited successfully.

To reproduce the connectivity check after configuring a local Responses adapter and starting NInfer:

```powershell
codex exec -m qwen3.8-27b `
  -c 'model_provider="<LOCAL_ADAPTER_PROVIDER>"' `
  -c 'model_reasoning_effort="none"' `
  -c 'model_context_window=120000' `
  'Reply exactly NINFER_OK. Do not use tools.'
```

The public recipe does not install the workstation-specific Codex router or provide automatic model startup from the model menu.

## Lifecycle findings and remaining check

GPUQ accepted cancellation, but its cooperative signal did not stop the WSL server. The exact owned Linux process was identified and terminated gracefully; port 8083 closed, the reservation completed, and GPU usage returned to approximately 156 MiB at that observation.

A workload-specific [cleanup script](../scripts/Stop-NInferQwen38.ps1) and local scheduler allowlist were then added. Script syntax and the already-stopped case passed; the scheduler loaded the updated configuration. **Automatic cancellation of a live NInfer instance after this change remains unverified:** another GPU workload occupied the device, so the follow-up reservation was canceled while queued. No unrelated workload was stopped. Do not interpret the cleanup configuration as a passed end-to-end lifecycle test.

## Validation and scope

Repository release validation, JSON parsing, PowerShell parsing, shell syntax and whitespace checks passed. Existing benchmark values and Qwen Code settings were retained. No weights or private raw logs are included in this publication.

At the time of this smoke check, only a basic Codex response was qualified. The [September 9 follow-up](ninfer-qualification-2026-09-09.md) adds measured decode/recall, live cancellation and a bounded 94K Codex tool round trip after a scoped metadata adapter fix. Full autonomous coding and 240K workload behavior remain unqualified.
