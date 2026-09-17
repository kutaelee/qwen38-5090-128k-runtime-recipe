# Qwen3.8-27B on one RTX 5090

[English](README.md) · [한국어](README.ko.md)

I put this repo together after testing Qwen3.8-27B on a single 32 GB RTX 5090 across NInfer, llama.cpp, and SGLang. It contains the configs I actually used, the benchmark numbers I kept, and the routing setup I use to switch between runtimes without keeping more than one generation backend on the GPU at a time.

No model weights are stored or redistributed here.

## TL;DR

- **NInfer + NVFP4 + FP8 KV + MTP3** gave the best raw decode numbers in my depth tests: **190.6 tok/s at 38.7K**, **176.9 tok/s at 83.9K**, and **169.8 tok/s at 114K** prompt tokens.
- In a longer real agent run captured on **2026-09-16**, the in-progress snapshot had reached **101 completed requests**, **96,241 output tokens**, **132.23 tok/s aggregate decode**, and **51.71% MTP acceptance**.
- **llama.cpp Q5_K_M + MTP3** is still the conservative default in this repo because its completed 100K+ coding run has the cleanest end-to-end validation record.
- **SGLang NVFP4** is kept as the serving/concurrency baseline.

The important caveat: these are not perfectly matched A/B runs. Runtime versions, prompt shapes, harnesses, and workloads differ. Treat the numbers as measured operating points, not as a universal ranking.

[Hugging Face showcase](https://huggingface.co/spaces/kutaelee/Qwen3.8-27B-RTX5090-128K-Recipe) · [Benchmark summary](benchmarks/runtime-comparison.md) · [NInfer live long-agent telemetry](benchmarks/ninfer-long-agent-live-2026-09-16.md) · [NInfer qualification](benchmarks/ninfer-qualification-2026-09-09.md) · [Q5 long-agent qualification](benchmarks/long-agent-qualification-2026-08-19.md) · [Reproduction guide](docs/reproducibility.md)

![Workload-aware runtime routing](assets/architecture.svg)

## 1. What this setup is for

The target is simple: run Qwen3.8-27B on one RTX 5090 and choose the runtime based on the job.

Only one generation runtime is meant to be resident at a time. The router stops the backend it owns, checks that the port and VRAM were released, then starts the next backend on loopback only.

| Use case | Runtime | Why I keep it |
| --- | --- | --- |
| Fast single-agent / long-running work | NInfer + NVFP4 + FP8 KV + MTP3 | Best raw decode numbers in the retained depth tests; ~94K Codex tool path passed after an adapter fix; long agent runs have completed in local use |
| Conservative single-agent default | llama.cpp + Q5_K_M + Q8_0 K/V + MTP3 | Best completed long-agent validation record currently retained in this repo |
| Serving / concurrency baseline | SGLang + NVFP4 + FP8 E4M3 KV | Stable serving setup with FlashInfer; MTP off |

Raw decode speed is useful, but it is not the same thing as agent throughput. A faster decoder can still lose time in prefill, tool use, retries, compaction, or a bad agent trajectory.

## 2. Test machine

| Component | Tested setup |
| --- | --- |
| GPU | NVIDIA GeForce RTX 5090, 32,607 MiB reported |
| Driver | 610.74 |
| Host | Windows; NInfer in WSL2/Linux, SGLang in WSL2/Docker, llama.cpp on native Windows CUDA |
| Concurrency in published measurements | 1 generation runtime, 1 request, 1 GPU |

## 3. NInfer: NVFP4 + FP8 KV + MTP3

This is the fastest route in the measurements currently published here.

**Runtime / model**

- Runtime: [`Neroued/ninfer`](https://github.com/Neroued/ninfer), tested integration revision [`a16b6442…c750`](https://github.com/Neroued/ninfer/commit/a16b6442856620b7e4856acb25215acbf7e3c750)
- Model artifact: [`neroued/Qwen3.8-27B-nvfp4-NInfer`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer), tested revision [`11dbbbbb…31be`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer/tree/11dbbbbbc33db198afe2f02c9232c771ff7031be)
- File: `qwen3_8_27b_nvfp4.ninfer`
- SHA-256: `552c374c685dce302603b95fbe940fb04243c0cd44c083efc644ad3d980d462c`
- Linux/WSL2, RTX 5090 (`sm_120a`), CUDA Toolkit 13.1+
- OpenAI-compatible endpoint on `127.0.0.1:8083`
- NVFP4 weights, FP8 KV, MTP3, concurrency 1
- Runtime/KV capacity configured to 240,000 tokens
- Qwen Code path kept at a 120,000-token working ceiling with the existing 0.7 auto-compaction policy

Config: [`configs/ninfer-nvfp4-mtp3.example.sh`](configs/ninfer-nvfp4-mtp3.example.sh)

### Depth test — 2026-09-09

| Label | Actual prompt tokens | Median decode | Draft acceptance |
| --- | ---: | ---: | ---: |
| Short | 54 | 222.0 tok/s | 83.92% |
| 32K | 38,717 | 190.6 tok/s | 75.55% |
| 80K | 83,917 | 176.9 tok/s | 73.84% |
| 114K | 113,956 | 169.8 tok/s | 75.82% |

Across the 12 measured generations, the server produced 3,600 output tokens and accepted 2,502 of 3,243 proposed draft tokens (**77.15%**).

The short prompt is not matched to the historical Q5 short test, so I do not use it to claim a direct speedup ratio.

### Codex tool-path check at ~94K

The first Codex CLI run failed because the Responses compatibility layer forwarded `internal_chat_message_metadata_passthrough`, which NInfer did not accept. I changed the NInfer-side adapter to strip that unsupported metadata while leaving tool arguments, outputs, call IDs, and message content intact.

The same bounded read → edit → test task then completed in **33.409 s** and passed **3/3** independent fixture checks. The three generations decoded at **183.2 / 174.5 / 140.5 tok/s**.

That proves the repaired tool path worked for this test. It is not an average TPS figure for long autonomous coding.

### Long-agent run — 2026-09-16 snapshot

| Metric | Snapshot |
| --- | ---: |
| Completed requests | **101** |
| Generated output tokens | **96,241** |
| Aggregate decode | **132.23 tok/s** |
| Mean request decode | **140.59 tok/s** |
| Median request decode | **136.2 tok/s** |
| Aggregate MTP acceptance | **51.71%** |
| Prompt depth seen in the retained log segment | **at least 88,250 tokens** |
| Final task result | pending at the time of the snapshot |

`Aggregate decode` is output-token weighted, not a simple average of per-request TPS.

This snapshot is numerically higher than the older Q5 long-run average of 109.51 tok/s, but the workloads and harnesses are different, so I do not present that gap as a runtime-only speedup.

Details: [live telemetry](benchmarks/ninfer-long-agent-live-2026-09-16.md) · [qualification report](benchmarks/ninfer-qualification-2026-09-09.md)

## 4. llama.cpp Q5_K_M + MTP3

This remains the default route when I care more about using the best completed validation record than chasing the highest raw decode number.

- Model: [`bartowski/Qwen3.8-27B-GGUF`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF), tested revision [`f0eec4a4…c034`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF/tree/f0eec4a4bb4975114a030d048952d83c0a53c034)
- File: `Qwen3.8-27B-Q5_K_M.gguf`
- SHA-256: `E731E180460B906F373294A4E2DE10541E80EE676AF7F8C949A84DBB6ED3CAA8`
- llama.cpp build 10435, commit [`9e40df63…7e99`](https://github.com/ggml-org/llama.cpp/commit/9e40df63ba151d771d8b247ac4011cf203337e99)
- Context: 131,072
- KV: Q8_0 K / Q8_0 V
- Flash Attention on; 66/66 layers on GPU; no CPU fallback
- `parallel=1`, `batch=2048`, `ubatch=512`, vision off
- MTP3: `--spec-type draft-mtp --spec-draft-n-max 3`

The retained qualification peaked at about **28.63 GB VRAM used**, leaving roughly **3.98 GiB free**.

Config: [`configs/llamacpp-q5-mtp3-128k.example.ps1`](configs/llamacpp-q5-mtp3-128k.example.ps1)

In the 2026-08-19 100K+ autonomous coding run, average decode was **109.51 tok/s**, max observed context was **106,829 tokens**, and MTP acceptance was **89.61%**. After fixing test-harness cleanup issues, the post-run checks passed `typecheck`, `lint`, `build`, and `vitest 12/12`.

One earlier long run failed because the agent generated an oversized regex and lost the useful trajectory. Another run was stopped by Qwen Code's native `action_stagnation` detector during legitimate multi-file exploration. With an external semantic guard and `skipLoopDetection: true`, the later qualification went much deeper and completed successfully.

I do not treat those failures as evidence of a Q5 quantization or MTP correctness bug.

## 5. SGLang NVFP4 serving baseline

- Model: [`RadixArk/Qwen3.8-27B-NVFP4`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4), tested revision [`52d1adc5…b854`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4/tree/52d1adc5f38aa5ebf099c29ed7025ba34cfbb854)
- SGLang package: `0.0.0.dev0+qwen38.27b.g561c8f3`
- Build commit: [`c4271c3f…51c5`](https://github.com/sgl-project/sglang/commit/c4271c3fe1262fc2adbd162c33b25de5255251c5)
- Container digest: `sha256:506525a5907ea22c9d445afb7c03603959b912de034d86915cf17da814f1a124`
- Context: 131,072
- KV: FP8 E4M3, available pool about 148,997 tokens
- FlashInfer
- MTP off
- `max-running-requests=1`, `max-mamba-cache-size=5`
- CPU layer offload: 0

Measured steady decode median was about **69.3 tok/s**; at 80K+ context it was about **60.8 tok/s**.

Config: [`configs/sglang-nvfp4-128k.example.sh`](configs/sglang-nvfp4-128k.example.sh)

## 6. Quick comparison

### Decode vs. context depth

| Runtime | Short | 32K label | 80K label | 114K label | Configured context |
| --- | ---: | ---: | ---: | ---: | ---: |
| SGLang NVFP4 | ~69.3 | — | ~60.8 | — | 128K |
| Q5_K_M + MTP3 | 151.72 | 120.29 | 98.59 | 94.66 | 128K |
| NInfer NVFP4 + MTP3 | **222.0** | **190.6** | **176.9** | **169.8** | 240K runtime capacity; 120K Qwen Code working ceiling |

For NInfer, the actual prompts behind the 32K / 80K / 114K labels were **38,717 / 83,917 / 113,956 tokens**.

Missing cells are unmeasured. I leave them blank instead of estimating them.

### Agent evidence currently retained

| Runtime | What has actually been checked |
| --- | --- |
| NInfer NVFP4 + MTP3 | ~94K Codex read/edit/test path passed after the adapter fix; previous long tasks completed in local use; 2026-09-16 instrumented long run retained as an in-progress snapshot |
| Q5_K_M + MTP3 | Completed 100K+ autonomous coding trajectory with post-run typecheck/lint/build/vitest validation |
| SGLang NVFP4 | Tool/runtime correctness and a medium web task; useful as the serving baseline rather than the strongest long-agent result |

Full tables: [`benchmarks/runtime-comparison.md`](benchmarks/runtime-comparison.md) · [`benchmarks/runtime-comparison.csv`](benchmarks/runtime-comparison.csv)

## 7. Routing

The sample router is intentionally boring. [`configs/local-model-router.example.json`](configs/local-model-router.example.json) is a routing spec, not a controller you can install and forget about.

The lifecycle I use is:

1. Pick the route for the task.
2. Stop only the runtime owned by the router.
3. Confirm its port is closed and GPU memory was released.
4. Start one backend through the machine's GPU scheduler.
5. Check `/v1/models` and fail closed if the model ID or port is wrong.
6. Apply route-specific agent/harness settings.
7. Validate the resulting diff and task acceptance separately from runtime speed.

See [agent routing](docs/agent-routing.md) for the failure and cleanup rules.

## 8. Reproducing the setup

1. Download model artifacts from the upstream repositories.
2. Use the exact revisions listed above; verify the GGUF SHA-256 if you use that route.
3. Build the pinned NInfer revision in WSL2/Linux, or install the pinned llama.cpp/SGLang versions for those routes.
4. Replace the example model/cache paths under `configs/` with your own paths.
5. Keep the API bound to loopback unless you intentionally add authentication and network controls.
6. Start one backend at a time.
7. Run `scripts/healthcheck.example.ps1` against `/v1/models`.
8. Check correctness first, throughput second. Keep bounded tool tests and long-agent tests separate.

Full procedure: [docs/reproducibility.md](docs/reproducibility.md)

## 9. Limitations

- This is one RTX 5090 system, not a multi-machine benchmark.
- The long-agent runs are not matched, multi-seed A/B experiments.
- Comparable end-to-end wall time was not captured for the Q5 re-qualification.
- Earlier successful NInfer long runs were observed locally, but the older runs do not have the same retained telemetry as the 2026-09-16 instrumented run.
- Prompt depth and shape differ between runtimes. The NInfer 32K / 80K / 114K labels are actually 38,717 / 83,917 / 113,956 prompt tokens.
- NInfer's 240K figure is configured runtime/KV capacity. The retained September 9 depth suite does **not** claim a measured 160K–240K workload.
- Driver, kernels, model revisions, runtime commits, agent versions, tool patterns, compaction, and MTP acceptance can all move the numbers.
- Vision was not tested in these recipes.

More detail: [docs/limitations.md](docs/limitations.md)

## 10. Upstream projects and licenses

This repo does not own or redistribute the linked model weights.

- [`Qwen/Qwen3.8-27B`](https://huggingface.co/Qwen/Qwen3.8-27B) — base model, Apache-2.0 metadata
- [`RadixArk/Qwen3.8-27B-NVFP4`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4) — NVFP4 artifact, Apache-2.0 metadata
- [`bartowski/Qwen3.8-27B-GGUF`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF) — GGUF artifact, Apache-2.0 metadata
- [`neroued/Qwen3.8-27B-nvfp4-NInfer`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer) — NInfer artifact, Apache-2.0 metadata
- [`Neroued/ninfer`](https://github.com/Neroued/ninfer) — Apache-2.0
- [`ggml-org/llama.cpp`](https://github.com/ggml-org/llama.cpp) — MIT
- [`sgl-project/sglang`](https://github.com/sgl-project/sglang) — Apache-2.0
- [`QwenLM/qwen-code`](https://github.com/QwenLM/qwen-code) — Apache-2.0

Check the model card and license for the exact revision you download. The repo's MIT license does not override upstream licenses.

Exact revisions and license sources: [docs/upstream-licenses.md](docs/upstream-licenses.md)

## 11. License / credits

The original configs, docs, small validation scripts, and diagrams in this repo are MIT licensed. Model artifacts and third-party runtimes keep their own licenses.

Thanks to the Qwen, Neroued/NInfer, RadixArk, bartowski, llama.cpp, SGLang, and Qwen Code maintainers and contributors.
