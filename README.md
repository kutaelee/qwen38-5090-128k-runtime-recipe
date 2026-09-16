# Qwen3.8-27B on RTX 5090 — 128K Multi-Runtime Agent Recipe

[English](README.md) · [한국어](README.ko.md)

> **NInfer NVFP4 + FP8 KV + MTP3 measured 190.6 tok/s at ~38.7K, 176.9 tok/s at ~83.9K, and 169.8 tok/s at ~114K on a single RTX 5090.** After a scoped Responses compatibility repair, a bounded ~94K Codex read/edit/test task completed in 33.409 s and passed 3/3 independent fixture tests. **Q5_K_M + MTP3 remains the default** because it has the stronger long-autonomous qualification: ~109.5 tok/s average decode during a 100K+ coding trajectory with 89.6% speculative acceptance.

**This repository does not contain modified model weights. It provides reproducible RTX 5090 inference configurations, benchmarks, and an agent-routing recipe for Qwen3.8-27B.**

[Hugging Face showcase](https://huggingface.co/spaces/kutaelee/Qwen3.8-27B-RTX5090-128K-Recipe) · [Benchmark results](benchmarks/runtime-comparison.md) · [Latest NInfer qualification](benchmarks/ninfer-qualification-2026-09-09.md) · [Latest long-agent qualification](benchmarks/long-agent-qualification-2026-08-19.md) · [Reproduction guide](docs/reproducibility.md) · [Publishing guide](docs/publishing.md)

![Workload-aware runtime routing](assets/architecture.svg)

Latest: [NInfer measured comparison and bounded Codex qualification](benchmarks/ninfer-qualification-2026-09-09.md). Q5 remains the default pending comparable long-autonomous NInfer qualification.

## 1. Overview

This recipe runs Qwen3.8-27B on one 32 GB RTX 5090 without keeping multiple generation runtimes resident. A task router stops and cleans up the previous runtime, then starts exactly one loopback-only backend:

- **NInfer qualification candidate:** `neroued/Qwen3.8-27B-nvfp4-NInfer` on NInfer with FP8 KV and MTP3. The runtime has a 240,000-token logical ceiling while Qwen Code retains its existing 120,000-token operating ceiling and 0.7 auto-compaction policy.
- **Default single-agent:** `bartowski/Qwen3.8-27B-GGUF` (`Qwen3.8-27B-Q5_K_M.gguf`) on llama.cpp with Q8_0 K/V and MTP3.
- **Serving / concurrency:** `RadixArk/Qwen3.8-27B-NVFP4` on SGLang with FP8 E4M3 KV, FlashInfer, and MTP off.

The central finding is not a top-line TPS record:

> **Raw decode TPS is not agent throughput.**

In the published local depth probes, NInfer produced the highest measured raw decode rates: **190.6 tok/s at 38,717 prompt tokens, 176.9 at 83,917, and 169.8 at 113,956**. These are historical comparisons against Q5 measurements rather than a contemporaneous matched A/B, and the short prompts are not equivalent.

Q5/MTP3 remains the default because its long-agent evidence is stronger. In the 2026-08-19 re-qualification, it executed a 100K+ autonomous implementation trajectory at ~109.5 tok/s average decode; post-run canonical acceptance reached `typecheck PASS`, `lint PASS`, `build PASS`, and `vitest 12/12 PASS` after correcting test-harness cleanup issues.

## 2. Why three runtime roles?

The roles separate single-agent execution, rollback, and concurrent serving without simultaneous GPU residency.

| Workload | Selected runtime | Reason |
| --- | --- | --- |
| explicit NInfer qualification | NInfer NVFP4 + FP8 KV + MTP3 | Highest measured raw decode in the published local depth probes; bounded 94K Codex path passed after adapter repair |
| default single-agent work | Q5_K_M + llama.cpp + MTP3 | Existing locally measured long-autonomous agent qualification remains intact |
| `high-concurrency`, multi-tenant serving, analysis | NVFP4 + SGLang | Stable 80K+ context serving baseline and FlashInfer chunked prefill |

This is a **workload-aware routing result**, not a claim that either artifact is universally better.

## 3. Hardware

| Component | Tested system |
| --- | --- |
| GPU | NVIDIA GeForce RTX 5090, 32,607 MiB reported |
| Driver | 610.74 |
| Host | Windows with WSL2/Linux for NInfer, WSL2/Docker for SGLang, and native Windows CUDA for llama.cpp |
| Concurrency | One generation runtime, one request, one GPU |

No model weights are stored in this repository. See [Upstream models/projects](#12-upstream-modelsprojects).

## 4. Candidate runtime — NInfer NVFP4 + MTP3

Integration profile:

- Runtime source: [`Neroued/ninfer`](https://github.com/Neroued/ninfer), pinned integration revision [`a16b6442…c750`](https://github.com/Neroued/ninfer/commit/a16b6442856620b7e4856acb25215acbf7e3c750)
- Artifact: [`neroued/Qwen3.8-27B-nvfp4-NInfer`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer), revision [`11dbbbbb…31be`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer/tree/11dbbbbbc33db198afe2f02c9232c771ff7031be)
- File: `qwen3_8_27b_nvfp4.ninfer`; SHA-256 `552c374c685dce302603b95fbe940fb04243c0cd44c083efc644ad3d980d462c`
- Linux/WSL2, RTX 5090 (`sm_120a`), CUDA Toolkit 13.1 or newer, source build
- OpenAI-compatible loopback serving on `127.0.0.1:8083`
- NVFP4 weights, FP8 KV, MTP3, optimized proposal head, concurrency 1
- Runtime context and KV capacity: 240,000 tokens
- Qwen Code operating context: 120,000 tokens; existing 0.7 auto-compaction and non-thinking request policy retained

Measured depth probes on 2026-09-09:

| Label | Actual prompt tokens | Median decode | Draft acceptance |
| --- | ---: | ---: | ---: |
| Short | 54 | 222.0 tok/s | 83.92% |
| 32K label | 38,717 | 190.6 tok/s | 75.55% |
| 80K label | 83,917 | 176.9 tok/s | 73.84% |
| 114K label | 113,956 | 169.8 tok/s | 75.82% |

The 12 measured generations produced 3,600 output tokens with 2,502 / 3,243 proposed draft tokens accepted (**77.15%**). The short prompt differs materially from the historical Q5 short prompt, so its ratio is not a matched speedup.

See [`configs/ninfer-nvfp4-mtp3.example.sh`](configs/ninfer-nvfp4-mtp3.example.sh) and the full [NInfer qualification report](benchmarks/ninfer-qualification-2026-09-09.md).

A real Codex CLI bounded task at ~94K prompt tokens initially failed because the Responses compatibility layer forwarded `internal_chat_message_metadata_passthrough`. The NInfer-only adapter was changed to strip that unsupported metadata while preserving tool arguments, outputs, call IDs, and message content. The same task then completed in **33.409 s**, performed read → edit → test, and passed **3/3** independent fixture assertions. Its three generations decoded at **183.2 / 174.5 / 140.5 tok/s**. This is bounded tool-path evidence, not a representative long-agent average or full CourseBench qualification.

On this workstation pattern, [`scripts/Start-NInferQwen38.ps1`](scripts/Start-NInferQwen38.ps1) submits the WSL server through `gpuq`; it does not bypass GPU ownership or silently stop another runtime. GPUQ operators can allowlist [`scripts/Stop-NInferQwen38.ps1`](scripts/Stop-NInferQwen38.ps1) as the exact cleanup command for this workload so WSL cancellation does not orphan the Linux/CUDA worker.

## 5. Default runtime — llama.cpp Q5 + MTP3

The existing measured single-agent runtime remains the default. Its artifact identity, launch options, and evidence are unchanged.

Tested configuration:

- Artifact repository: [`bartowski/Qwen3.8-27B-GGUF`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF), tested revision [`f0eec4a4…c034`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF/tree/f0eec4a4bb4975114a030d048952d83c0a53c034)
- File: `Qwen3.8-27B-Q5_K_M.gguf`
- File SHA-256: `E731E180460B906F373294A4E2DE10541E80EE676AF7F8C949A84DBB6ED3CAA8`
- llama.cpp build 10435, commit [`9e40df63…7e99`](https://github.com/ggml-org/llama.cpp/commit/9e40df63ba151d771d8b247ac4011cf203337e99)
- Server context: 131,072
- KV: Q8_0 K and Q8_0 V
- Flash Attention on; all 66/66 layers on GPU; CPU fallback 0
- `parallel=1`, `batch=2048`, `ubatch=512`, vision off
- MTP3: `--spec-type draft-mtp --spec-draft-n-max 3`

Peak qualification retained approximately **3.98 GiB free VRAM** (28.63 GB peak used). See [`configs/llamacpp-q5-mtp3-128k.example.ps1`](configs/llamacpp-q5-mtp3-128k.example.ps1).

## 6. Serving runtime — SGLang NVFP4

Tested configuration:

- Model: [`RadixArk/Qwen3.8-27B-NVFP4`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4), pinned tested revision [`52d1adc5…b854`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4/tree/52d1adc5f38aa5ebf099c29ed7025ba34cfbb854)
- SGLang package: `0.0.0.dev0+qwen38.27b.g561c8f3`
- Image build commit: [`c4271c3f…51c5`](https://github.com/sgl-project/sglang/commit/c4271c3fe1262fc2adbd162c33b25de5255251c5)
- Pinned container digest: `sha256:506525a5907ea22c9d445afb7c03603959b912de034d86915cf17da814f1a124`
- Server context: 131,072
- KV: FP8 E4M3; available pool approximately 148,997 tokens
- Attention: FlashInfer
- MTP/speculation: off
- `max-running-requests=1`, `max-mamba-cache-size=5`
- CPU layer offload: 0

Measured steady decode median was approximately **69.3 tok/s**; at 80K+ context it was approximately **60.8 tok/s**. See [`configs/sglang-nvfp4-128k.example.sh`](configs/sglang-nvfp4-128k.example.sh).

## 7. Benchmark results

### A. Synthetic / serving decode throughput vs context depth

| Runtime | Short | 32K label | 80K label | 114K label | Configured context | Role |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| SGLang NVFP4 | ~69.3 | — | ~60.8 | — | 128K | serving / concurrency baseline |
| Q5 + MTP3 | 151.72 | 120.29 | 98.59 | 94.66 | 128K | default single-agent |
| NInfer NVFP4 + MTP3 | **222.0** | **190.6** | **176.9** | **169.8** | 240K logical; 120K Qwen Code operating ceiling | qualification candidate |

For NInfer, the actual prompts behind the 32K / 80K / 114K labels were **38,717 / 83,917 / 113,956 tokens**. These values reuse the historical depth generator but are not a contemporaneous matched A/B against Q5. The short prompts also differ materially.

### B. Observed autonomous agent run (CourseBench long task)

| Metric | SGLang NVFP4 Baseline | Q5_K_M + llama.cpp + MTP3 (2026-08-19) |
| --- | --- | --- |
| Average Decode Throughput | ~60.8–69.3 tok/s | **109.51 tok/s** |
| MTP Speculative Acceptance | Off | **89.61%** (P0: 95.16%, P1: 89.57%, P2: 84.09%) |
| Max Context Observed | ~80K+ | **106,829 tokens** |
| Prefix Cache Reuse | Chunked prefill | **16.675M tokens cached** (96.8% hit rate) |
| Peak VRAM | 29.8 GB | **28.63 GB** (3.98 GB headroom) |

NInfer is intentionally absent from this autonomous-agent table because a comparable long-autonomous run has not been completed.

### C. NInfer bounded Codex path at ~94K after adapter repair

| Metric | Observation |
| --- | --- |
| Codex exit / wall time | 0 / **33.409 s** |
| Successful tool executions | 2 (read; edit + test) |
| API generations | 3 |
| Prompt tokens per request | 94,338 / 94,544 / 94,682 |
| Server decode tok/s | **183.2 / 174.5 / 140.5** |
| Client-facing TTFT | 19.2 s / 197 ms / 313 ms |
| Accepted / proposed draft tokens | 169 / 249 (**67.87%**) |
| Independent fixture tests | **3/3 PASS** |

These generations were only 48 / 79 / 120 output tokens, so they are not presented as a representative agent-average TPS benchmark.

Missing cells were not measured under the same published suite and are intentionally left blank. See [methodology](docs/methodology.md) and the machine-readable [`runtime-comparison.csv`](benchmarks/runtime-comparison.csv).

## 8. Existing agent qualification

| Runtime | Bounded coding / tool path | Long autonomous |
| --- | --- | --- |
| NInfer NVFP4 + MTP3 | Initial ~94K Codex run failed on Responses metadata compatibility; scoped adapter repair retest completed read/edit/test and independent tests 3/3 PASS | **Not yet qualified** |
| SGLang NVFP4 | Runtime/tool correctness passed | Medium web task completed in 526.388 s; build gates and major browser flows passed; final implementation gate failed on one unauthorized generated-file change and mobile Sheet focus restoration |
| Q5 + MTP3 | 10/10 TSX fixtures plus multi-file build/test 2/2 passed | **Historical run:** Rejected after 541 s without semantic edit (oversized regex).<br>**Re-qualification (2026-08-19):** Deep 100K+ trajectory under revised semantic guard; post-run canonical acceptance after test-harness fixes: `typecheck PASS`, `lint PASS`, `build PASS`, `vitest 12/12 PASS`. Comparable E2E wall-time was not captured. |

### Root Cause Analysis (RCA) on Q5 Long-Task Behavior

The earlier Q5/MTP3 rejection is not evidence of a Q5 quantization or MTP correctness defect.

Two distinct failure surfaces have now been observed:
1. **A bad model/agent trajectory in the earlier counted run:** including an oversized regex generation and context reconstruction failure.
2. **False-positive native Qwen Code `action_stagnation` detection:** during legitimate multi-file exploration, the default loop detector halted execution at turn 5 (21.9 s).

With an external semantic guard and the native detector bypassed (`skipLoopDetection: true`), Q5/MTP3 completed a substantially deeper autonomous implementation trajectory in the latest qualification.

## 9. Routing strategy

The example router is data-only and intentionally small: [`configs/local-model-router.example.json`](configs/local-model-router.example.json). Q5/MTP3 remains the default with its existing long-agent qualification; NInfer is a qualification candidate, and SGLang remains the serving baseline. The public file is a routing specification, not an installed controller.

1. Classify the task before loading a model; Q5 is the default single-agent route; NInfer is explicitly selectable for qualification.
2. Stop only the runtime it owns and verify its port/VRAM were released.
3. Start the selected runtime through the machine's GPU scheduler.
4. Verify `/v1/models` returns the expected model ID; fail closed on a port or model mismatch.
5. Run Qwen Code with task-local settings (`skipLoopDetection: true`, external semantic guard).
6. Independently validate the diff and acceptance gates.

See [agent routing](docs/agent-routing.md) for failure handling and lifecycle boundaries.

## 10. Reproduction

1. Obtain model artifacts directly from the upstream repositories. Do not copy them into this repository.
2. Verify the exact revision and, for the tested GGUF, the file SHA-256 shown above.
3. Build the pinned NInfer source in WSL2/Linux or install the existing pinned fallback/serving runtimes.
4. Adapt the generic model/cache paths in `configs/`; retain loopback-only publishing.
5. Start only one backend.
6. Run `scripts/healthcheck.example.ps1` against `/v1/models`.
7. For a new local qualification, run correctness before throughput, then bounded and long-agent suites separately. Do not promote the September 9 bounded NInfer retest to long-agent qualification.

Full steps and evidence requirements are in [reproducibility.md](docs/reproducibility.md).

## 11. Limitations

- The hardware sample is one RTX 5090 system.
- The long-agent comparison contains counted trajectories per reported runtime condition; it is not a statistical model-quality benchmark across multiple seeds.
- Comparable end-to-end wall-time was not captured for the Q5 re-qualification run.
- The exact private semantic-guard wrapper used in the qualification is not published here; the public repo includes the task-local Qwen Code settings and the guard policy/stop conditions needed to implement an equivalent controller.
- Runtime depth points and prompt shapes are not fully identical. In particular, the NInfer 32K / 80K / 114K labels correspond to 38,717 / 83,917 / 113,956 actual prompt tokens, and the short prompt is not matched to Q5.
- NInfer's 240K value is configured runtime/KV capacity; no 160K–240K workload is claimed here.
- Driver, kernels, model revisions, runtime commits, and agent versions can materially change results.
- No vision path was tested in these recipes.
- **NInfer remains a qualification candidate.** The [September 9 report](benchmarks/ninfer-qualification-2026-09-09.md) records higher raw decode speed, an initial Codex metadata compatibility failure, and a scoped adapter repair that passed the same bounded ~94K read/edit/test task in 33.409 s. Full autonomous qualification remains outstanding; the original failure is retained.

More detail: [limitations.md](docs/limitations.md).

## 12. Upstream models/projects

This project does not own, modify, sublicense, or redistribute the linked model weights.

- [`Qwen/Qwen3.8-27B`](https://huggingface.co/Qwen/Qwen3.8-27B) — base model, Apache-2.0 metadata
- [`RadixArk/Qwen3.8-27B-NVFP4`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4) — NVFP4 artifact, Apache-2.0 metadata
- [`bartowski/Qwen3.8-27B-GGUF`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF) — GGUF artifact, Apache-2.0 metadata
- [`neroued/Qwen3.8-27B-nvfp4-NInfer`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer) — NInfer artifact, Apache-2.0 metadata
- [`Neroued/ninfer`](https://github.com/Neroued/ninfer) — NInfer runtime, Apache-2.0
- [`ggml-org/llama.cpp`](https://github.com/ggml-org/llama.cpp) — MIT
- [`sgl-project/sglang`](https://github.com/sgl-project/sglang) — Apache-2.0
- [`QwenLM/qwen-code`](https://github.com/QwenLM/qwen-code) — Apache-2.0

Always review the license and model card at the exact revision you download. The repository license does not replace upstream model or runtime licenses.

The exact revisions and license sources checked for this release are recorded in [upstream-licenses.md](docs/upstream-licenses.md).

## 13. License / acknowledgements

The original recipe, documentation, small validation scripts, and diagrams in this repository are MIT licensed. Model artifacts and upstream runtimes retain their respective licenses. Thanks to the Qwen, Neroued/NInfer, RadixArk, bartowski, llama.cpp, SGLang, and Qwen Code maintainers and contributors.
