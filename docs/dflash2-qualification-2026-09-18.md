# DFlash2 K=7 qualification — 2026-09-18

This note records the local qualification of DFlash2 as a replacement for MTP3 on the existing 240K Qwen3.8-27B NInfer route.

## Configuration boundary

Held constant:

- Qwen3.8-27B NVFP4 NInfer artifact
- model SHA-256: `552c374c685dce302603b95fbe940fb04243c0cd44c083efc644ad3d980d462c`
- upstream NInfer production runtime
- FP8 KV
- 240,000 configured context / KV capacity
- concurrency 1
- existing tool/API harness and no-thinking policy

Changed:

- MTP3: `--spec mtp --draft-tokens 3`
- DFlash2 candidate: `--spec dflash2 --draft-tokens 7`

Both routes keep `--lm-head-draft`.

## Correctness gates

| Gate | MTP3 baseline | DFlash2 K=7 | Result |
| --- | ---: | ---: | --- |
| Tool calls | 40/40 | 40/40 | PASS |
| Smoke suite | 9/9 | 8/9* | PASS with known limitation |
| Tool-result round trip | PASS | PASS | PASS |
| Responses round trip | PASS | PASS | PASS |
| Malformed / abnormal stops | 0 | 0 | PASS |

\* The missing smoke case is the known upstream Responses `include` limitation and was not treated as a DFlash2 regression. The summary retained for this run reports the limitation on both paths even though the baseline smoke counter was recorded as 9/9, so the raw fixture/report should be used for any later exact accounting.

No quality regression was observed in this bounded correctness suite. This is not a matched long-agent quality benchmark.

## Performance observation

The local bounded A/B reported:

| Metric | MTP3 baseline | DFlash2 K=7 |
| --- | ---: | ---: |
| Decode throughput | ~80–110 tok/s | ~290–300 tok/s |
| Draft tokens / round | 3 | 7 |
| Draft acceptance | ~75% | ~57–60% |
| TTFT on the 292-token fixture | ~80–90 ms | ~80–90 ms |
| VRAM | ~29.6 GiB | ~29.6 GiB |

The ~290–300 tok/s figure is a bounded local workload observation. It must not be compared directly with the separate long-running MTP3 telemetry (171.05 tok/s aggregate / 180.2 tok/s median) as if it were a matched long-agent speedup.

## Decision

**PROMOTE DFlash2 K=7 as the preferred 240K candidate**, with MTP3 retained as the rollback route.

Promotion means the DFlash2 profile passed the local correctness gate and is approved for the production-route cutover. A future matched long-agent A/B can refine the practical end-to-end speed claim, but is not required to keep the bounded DFlash2 profile documented.

Rollback remains the existing MTP3 config and scripts.

## Files

- `configs/ninfer-nvfp4-dflash2-240k.example.sh`
- local start/stop scripts for the DFlash2 route
- local qualification evidence under `results/qualification-20260918/` when published
