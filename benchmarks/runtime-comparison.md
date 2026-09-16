# Runtime comparison

[English](runtime-comparison.md) · [한국어](runtime-comparison.ko.md)

## Synthetic / serving decode throughput

| Runtime | Short | 32K label | 80K label | 114K label |
| --- | ---: | ---: | ---: | ---: |
| SGLang NVFP4 | ~69.3 | not measured | ~60.8 | not measured |
| Q5_K_M llama.cpp MTP3 | 151.72 | 120.29 | 98.59 | 94.66 |
| NInfer NVFP4 + FP8 KV + MTP3 | **222.0** | **190.6** | **176.9** | **169.8** |

The SGLang 80K+ value is the 60.77 tok/s median from 43 log samples in the counted long run, rounded to 60.8. Its steady decode median was 69.325 tok/s, rounded to 69.3.

The NInfer row is from the 2026-09-09 local depth probes. The actual prompt sizes behind the historical 32K / 80K / 114K labels were **38,717 / 83,917 / 113,956 tokens**. The short NInfer prompt contained 54 tokens and is not matched to the historical Q5 short prompt. Different artifacts, chat templates, APIs and cache implementations also prevent strict runtime-only attribution. This is therefore a historical comparison, not a contemporaneous matched A/B.

Across the deep-context points, NInfer measured approximately **1.58× / 1.79× / 1.79×** the historical Q5 decode rates. The 12 NInfer depth generations produced 3,600 output tokens and accepted 2,502 / 3,243 proposed draft tokens (**77.15%**).

## Observed autonomous agent telemetry — CourseBench long task

| Metric | SGLang NVFP4 Baseline | Q5_K_M + llama.cpp + MTP3 (2026-08-19) |
| --- | --- | --- |
| Average Generation Throughput | ~60.8–69.3 tok/s | **109.51 tok/s** |
| Speculative Drafting (MTP) | Off | **89.61% acceptance** (87,494 accepted / 97,638 drafted) |
| MTP Positional Acceptance | N/A | P0: 95.16%, P1: 89.57%, P2: 84.09% |
| Maximum Observed Context | ~80K+ | **106,829 tokens** |
| Prefix Cache Reuse | Chunked prefill | **16,675,200 tokens cached** (96.8% hit rate) |
| Peak VRAM Consumption | 29.8 GB | **28.63 GB** (3.98 GB free headroom) |

NInfer is intentionally not added to this table. A comparable long-autonomous NInfer run has not been completed, so its depth-probe decode rates must not be presented as autonomous-agent throughput.

## NInfer bounded Codex path at ~94K — post-fix retest

A real Codex CLI task received the 84K reference context plus normal instructions/tools, producing prompt sizes of about 94K. The initial run failed because the Responses compatibility layer forwarded unsupported `internal_chat_message_metadata_passthrough`. A scoped NInfer-only adapter repair stripped that metadata while preserving tool arguments, outputs, call IDs, and message content.

The same bounded read → edit → test task then completed successfully:

| Metric | Observation |
| --- | ---: |
| Codex exit / wall time | 0 / **33.409 s** |
| Successful tool executions | 2 (read; edit + test) |
| API generations | 3 |
| Prompt tokens per request | 94,338 / 94,544 / 94,682 |
| Server decode tok/s | **183.2 / 174.5 / 140.5** |
| Client-facing TTFT | 19.2 s / 197 ms / 313 ms |
| Accepted / proposed draft tokens | 169 / 249 (**67.87%**) |
| Independent fixture tests | **3/3 PASS** |

The generations contained only 48 / 79 / 120 output tokens. These values establish bounded tool-path compatibility and successful task completion after the adapter repair; they are **not** a representative long-agent average TPS benchmark.

## Correctness and capacity

### Existing SGLang / Q5 qualification

| Gate | SGLang NVFP4 | Q5_K_M MTP3 |
| --- | --- | --- |
| Server context | 131,072 | 131,072 |
| Available KV capacity | approximately 148,997 tokens | context allocation and 113.9K workload passed |
| CPU layer offload | 0 | 0; all 66/66 layers on GPU |
| Basic | 6/6 | 6/6 |
| JSON schema | 20/20 | 20/20 |
| Tool calls | 40/40 | 40/40 |
| 32K NIAH | 5/5 | 5/5 |
| 80K NIAH | 5/5 | 5/5 |
| 113K+ NIAH | 5/5 | 5/5 |
| CUDA/OOM/output corruption | 0 | 0 |

### NInfer qualification evidence

| Gate | Observed result |
| --- | --- |
| Runtime context / KV allocation | 240,000 tokens configured; no 160K–240K workload executed |
| Basic instruction | 3/3 |
| Constrained JSON schema | Unsupported: HTTP 400 `response_format_not_supported` |
| Original plain JSON prompt | 0/20 strict parse; responses included Markdown fences |
| Explicit raw-JSON-only diagnostic | 20/20 on a separate prompt variant |
| Single-turn tool name/arguments | 40/40 `read_file` requests |
| Recall at ~38K / ~84K / ~114K | 5/5 facts at each depth |
| Restricted Python coding fixture | 2/3 tasks, each repeated 3 times after warm-up |
| Actual Codex read/edit/test round trip | Initial FAIL; post-fix bounded retest PASS, independent tests 3/3 |
| CUDA/OOM in retained depth/qualification logs | 0 observed |

The historical Q5 NIAH used an enum schema containing the expected answers, while the NInfer recall probe did not place the answers in the response schema. These checks are not treated as equivalent model-quality measurements.

## Agent trajectories

### NInfer NVFP4 + MTP3
- **Bounded ~94K Codex qualification:** initial Responses compatibility failure preserved; post-fix retest completed read/edit/test and independent tests 3/3 PASS.
- **Long autonomous:** not yet qualified.
- The published 222.0 / 190.6 / 176.9 / 169.8 tok/s depth figures are runtime decode measurements, not autonomous-agent averages.

### SGLang NVFP4
- One counted medium web-project run
- Wall time: 526.388 seconds
- Tool calls: 86
- Typecheck, lint, tests 8/8, build, and `git diff --check`: pass
- Major desktop/mobile browser flows: pass
- Final gate: fail, due to one unauthorized generated shadcn file modification and missing mobile Sheet focus restoration

### Q5_K_M MTP3
- **Bounded qualification:** 10/10 TSX fixtures and multi-file build/test 2/2 passed.
- **Historical run:** in one counted run without loop guard, zero semantic edits after 541 s (consumed 32,768 tokens on an oversized regex).
- **Re-qualification (2026-08-19):** under `skipLoopDetection: true` and external semantic guard, completed deep autonomous implementation (1,026 lines across `App.tsx`, `data.ts`, `index.css`, `App.test.tsx`, `test-setup.ts`).
  - `typecheck`: PASS (0 errors)
  - `lint`: PASS (0 errors)
  - `vitest`: 12/12 PASS (100%)
  - `build`: PASS (313 ms)
  - `git diff --check`: PASS (0 errors)
  - Comparable end-to-end wall-time was not captured for this run.

## Interpretation

The latest published local measurements change the raw-throughput picture: **NInfer is the fastest measured decode route in the available depth probes**, including 169.8 tok/s at 113,956 prompt tokens. That does not make it the default agent runtime yet.

Q5_K_M + llama.cpp + MTP3 remains the default because it has the strongest retained long-autonomous qualification: a 100K+ coding trajectory with 109.51 tok/s average decode, 89.61% speculative acceptance, and post-run typecheck/lint/build/vitest acceptance. NInfer has passed a bounded ~94K Codex tool path after a scoped compatibility repair, but a comparable long-autonomous qualification is still missing.

Raw decode TPS, bounded task wall time, and long-agent task throughput are therefore reported separately rather than collapsed into one ranking.

See [NInfer qualification](ninfer-qualification-2026-09-09.md) for raw measurements, prompt hashes, failure preservation, and the adapter-repair retest.
