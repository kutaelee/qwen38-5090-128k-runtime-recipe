# Runtime comparison

## Synthetic Decode Throughput

| Runtime | Short | 32K | 80K | 114K |
| --- | ---: | ---: | ---: | ---: |
| SGLang NVFP4 | ~69.3 | not measured | ~60.8 | not measured |
| Q5_K_M llama.cpp MTP3 | 151.72 | 120.29 | 98.59 | 94.66 |

The SGLang 80K+ value is the 60.77 tok/s median from 43 log samples in the counted long run, rounded to 60.8. Its steady decode median was 69.325 tok/s, rounded to 69.3.

## Observed Autonomous Agent Telemetry (CourseBench Long Task)

| Metric | SGLang NVFP4 Baseline | Q5_K_M + llama.cpp + MTP3 (2026-08-19) |
| --- | --- | --- |
| Average Generation Throughput | ~60.8–69.3 tok/s | **109.51 tok/s** |
| Speculative Drafting (MTP) | Off | **89.61% acceptance** (87,494 accepted / 97,638 drafted) |
| MTP Positional Acceptance | N/A | P0: 95.16%, P1: 89.57%, P2: 84.09% |
| Maximum Observed Context | ~80K+ | **106,829 tokens** |
| Prefix Cache Reuse | Chunked prefill | **16,675,200 tokens cached** (96.8% hit rate) |
| Peak VRAM Consumption | 29.8 GB | **28.63 GB** (3.98 GB free headroom) |

## Correctness and capacity

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

## Agent trajectories

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
- **Re-qualification (2026-08-19):** under `skipLoopDetection: true` and external semantic guard, completed deep autonomous implementation (1,026 lines `App.tsx`, `data.ts`, `index.css`, `App.test.tsx`, `test-setup.ts`).
  - `typecheck`: PASS (0 errors)
  - `lint`: PASS (0 errors)
  - `vitest`: 12/12 PASS (100%)
  - `build`: PASS (313 ms)
  - `git diff --check`: PASS (0 errors)
  - Comparable end-to-end wall-time was not captured for this run.

## Interpretation

The measured Q5 backend is significantly faster in decode throughput (151 tok/s short, 109.5 tok/s observed during agent runs). With appropriate harness settings, Q5/MTP3 completed a full-stack autonomous implementation with 100% acceptance suite pass.
