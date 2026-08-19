# Qwen3.8-27B on RTX 5090 — 128K Dual-Runtime Agent Recipe

> **Q5_K_M + MTP3 sustained ~109.5 tok/s during a 100K+ autonomous coding trajectory on a single RTX 5090, with 89.6% speculative acceptance.** A previous long-agent rejection was not reproduced under the revised semantic guard, while final production promotion remains gated on comparable end-to-end wall-time measurement across multiple seeds.

**This repository does not contain modified model weights. It provides reproducible RTX 5090 inference configurations, benchmarks, and an agent-routing recipe for Qwen3.8-27B.**

[Hugging Face showcase](https://huggingface.co/spaces/kutaelee/Qwen3.8-27B-RTX5090-128K-Recipe) · [Benchmark results](benchmarks/runtime-comparison.md) · [Latest long-agent qualification](benchmarks/long-agent-qualification-2026-08-19.md) · [Reproduction guide](docs/reproducibility.md) · [Publishing guide](docs/publishing.md)

![Workload-aware runtime routing](assets/architecture.svg)

## 1. Overview

This recipe runs Qwen3.8-27B at a 131,072-token server context on one 32 GB RTX 5090. It does not keep two models resident at once. A task router stops and cleans up the previous runtime, then starts exactly one of two loopback-only backends:

- **Single-agent long / complex candidate:** `bartowski/Qwen3.8-27B-GGUF` (`Qwen3.8-27B-Q5_K_M.gguf`) on llama.cpp with Q8_0 K/V and MTP3.
- **High-concurrency / serving baseline:** `RadixArk/Qwen3.8-27B-NVFP4` on SGLang with FP8 E4M3 KV, FlashInfer, and MTP off.

The central finding is not a top-line TPS record:

> **Raw decode TPS is not agent throughput.**

The Q5/MTP3 route decoded roughly 1.5–2× faster in runtime benchmarks and was accurate on bounded coding. In a re-qualification under a revised semantic guard, Q5/MTP3 completed a 100K+ context autonomous web project (12/12 tests PASS, typecheck PASS, build PASS) at ~109.5 tok/s average decode.

## 2. Why two runtimes?

The two backends optimize different failure surfaces.

| Workload | Selected runtime | Reason |
| --- | --- | --- |
| `quick-code`, bounded edits, structured tool use | Q5_K_M + llama.cpp + MTP3 | High decode throughput (151 tok/s short, 109 tok/s in agent run), 10/10 single-file qualification, multi-file build/test pass |
| `single-agent-long`, autonomous web implementation | Q5_K_M + llama.cpp + MTP3 (Candidate) | Demonstrated deep autonomous implementation (12/12 tests PASS, typecheck PASS, build PASS) under revised guard |
| `high-concurrency`, multi-tenant serving, analysis | NVFP4 + SGLang | Stable 80K+ context serving baseline and FlashInfer chunked prefill |

This is a **workload-aware routing result**, not a claim that either artifact is universally better.

## 3. Hardware

| Component | Tested system |
| --- | --- |
| GPU | NVIDIA GeForce RTX 5090, 32,607 MiB reported |
| Driver | 610.74 |
| Host | Windows with WSL2/Docker for SGLang; native Windows CUDA for llama.cpp |
| Concurrency | One generation runtime, one request, one GPU |

No model weights are stored in this repository. See [Upstream models/projects](#11-upstream-modelsprojects).

## 4. Runtime A — SGLang NVFP4

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

## 5. Runtime B — llama.cpp Q5 + MTP3

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

## 6. Benchmark results

### A. Synthetic / Serving Throughput vs Context Depth

| Runtime | Short | 32K | 80K | 114K | Context | Serving Role |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| SGLang NVFP4 | ~69.3 | — | ~60.8 | — | 128K | serving / concurrency baseline |
| Q5 + MTP3 | 151.72 | 120.29 | 98.59 | 94.66 | 128K | single-user fast decode |

### B. Observed Autonomous Agent Run (CourseBench Long Task)

| Metric | SGLang NVFP4 Baseline | Q5_K_M + llama.cpp + MTP3 (2026-08-19) |
| --- | --- | --- |
| Average Decode Throughput | ~60.8–69.3 tok/s | **109.51 tok/s** |
| MTP Speculative Acceptance | Off | **89.61%** (P0: 95.16%, P1: 89.57%, P2: 84.09%) |
| Max Context Observed | ~80K+ | **106,829 tokens** |
| Prefix Cache Reuse | Chunked prefill | **16.675M tokens cached** (96.8% hit rate) |
| Peak VRAM | 29.8 GB | **28.63 GB** (3.98 GB headroom) |

Missing cells were not measured under the same published suite and are intentionally left blank. See [methodology](docs/methodology.md) and the machine-readable [`runtime-comparison.csv`](benchmarks/runtime-comparison.csv).

## 7. Agent qualification

| Runtime | Bounded coding | Long autonomous |
| --- | --- | --- |
| SGLang NVFP4 | Runtime/tool correctness passed | Medium web task completed in 526.388 s; build gates and major browser flows passed; final implementation gate failed on one unauthorized generated-file change and mobile Sheet focus restoration |
| Q5 + MTP3 | 10/10 TSX fixtures plus multi-file build/test 2/2 passed | **Historical run:** Rejected after 541 s without semantic edit (oversized regex).<br>**Re-qualification (2026-08-19):** Deep trajectory completed under revised semantic guard; `typecheck PASS`, `lint PASS`, `build PASS`, `vitest 12/12 PASS`. |

### Root Cause Analysis (RCA) on Q5 Long-Task Behavior

The earlier Q5/MTP3 rejection is not evidence of a Q5 quantization or MTP correctness defect.

Two distinct failure surfaces have now been observed:
1. **A bad model/agent trajectory in the earlier counted run:** including an oversized regex generation and context reconstruction failure.
2. **False-positive native Qwen Code `action_stagnation` detection:** during legitimate multi-file exploration, the default loop detector halted execution at turn 5 (21.9 s).

With an external semantic guard and the native detector bypassed (`skipLoopDetection: true`), Q5/MTP3 completed a substantially deeper autonomous implementation trajectory in the latest qualification.

## 8. Routing strategy

The example router is data-only and intentionally small: [`configs/local-model-router.example.json`](configs/local-model-router.example.json). A production controller should:

1. Classify the bounded task before loading a model.
2. Stop only the runtime it owns and verify its port/VRAM were released.
3. Start the selected runtime through the machine's GPU scheduler.
4. Verify `/v1/models` returns the expected immutable model ID.
5. Run Qwen Code with task-local settings (`skipLoopDetection: true`, external semantic guard).
6. Independently validate the diff and acceptance gates.

See [agent routing](docs/agent-routing.md) for failure handling and lifecycle boundaries.

## 9. Reproduction

1. Obtain model artifacts directly from the upstream repositories. Do not copy them into this repository.
2. Verify the exact revision and, for the tested GGUF, the file SHA-256 shown above.
3. Build or install the pinned runtimes.
4. Adapt the generic model/cache paths in `configs/`; retain loopback-only publishing.
5. Start only one backend.
6. Run `scripts/healthcheck.example.ps1` against `/v1/models`.
7. Run correctness before throughput, then bounded and long-agent suites separately.

Full steps and evidence requirements are in [reproducibility.md](docs/reproducibility.md).

## 10. Limitations

- The hardware sample is one RTX 5090 system.
- The long-agent comparison contains counted trajectories per reported runtime condition; it is not a statistical model-quality benchmark across multiple seeds.
- Comparable end-to-end wall-time was not captured for the Q5 re-qualification run.
- SGLang and Q5 measurements do not populate every identical context depth.
- Driver, kernels, model revisions, runtime commits, and agent versions can materially change results.
- No vision path was tested in these recipes.

More detail: [limitations.md](docs/limitations.md).

## 11. Upstream models/projects

This project does not own, modify, sublicense, or redistribute the linked model weights.

- [`Qwen/Qwen3.8-27B`](https://huggingface.co/Qwen/Qwen3.8-27B) — base model, Apache-2.0 metadata
- [`RadixArk/Qwen3.8-27B-NVFP4`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4) — NVFP4 artifact, Apache-2.0 metadata
- [`bartowski/Qwen3.8-27B-GGUF`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF) — GGUF artifact, Apache-2.0 metadata
- [`ggml-org/llama.cpp`](https://github.com/ggml-org/llama.cpp) — MIT
- [`sgl-project/sglang`](https://github.com/sgl-project/sglang) — Apache-2.0
- [`QwenLM/qwen-code`](https://github.com/QwenLM/qwen-code) — Apache-2.0

Always review the license and model card at the exact revision you download. The repository license does not replace upstream model or runtime licenses.
