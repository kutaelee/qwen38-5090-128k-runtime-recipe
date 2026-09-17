# Qwen3.8-27B on a single RTX 5090

[English](README.md) · [한국어](README.ko.md)

A practical setup for running Qwen3.8-27B on one 32 GB RTX 5090, with configs and measurements from actual local use.

This repo covers three runtime setups I use for different jobs:

- **NInfer + NVFP4 + FP8 KV + MTP3** for fast single-agent work
- **llama.cpp + Q5_K_M + MTP3** as the safer, better-documented fallback
- **SGLang + NVFP4** for serving/concurrency experiments

It does **not** contain modified model weights. The point is to keep the runtime configs, exact revisions, benchmark notes, and failure cases in one place so the setup can be reproduced without guessing.

[Benchmarks](benchmarks/runtime-comparison.md) · [NInfer long-agent telemetry](benchmarks/ninfer-long-agent-live-2026-09-16.md) · [Reproduction guide](docs/reproducibility.md) · [Hugging Face showcase](https://huggingface.co/spaces/kutaelee/Qwen3.8-27B-RTX5090-128K-Recipe)

![Workload-aware runtime routing](assets/architecture.svg)

## Quick results

On my RTX 5090, NInfer with NVFP4 + FP8 KV + MTP3 measured:

| Actual prompt tokens | Decode | Draft acceptance |
| ---: | ---: | ---: |
| 54 | 222.0 tok/s | 83.92% |
| 38,717 | 190.6 tok/s | 75.55% |
| 83,917 | 176.9 tok/s | 73.84% |
| 113,956 | 169.8 tok/s | 75.82% |

A separate long-running coding-agent workload reached this later live snapshot:

- 562 completed requests
- 248,381 generated output tokens
- 171.26 tok/s output-weighted aggregate decode
- 178.77 tok/s mean request decode
- 180.55 tok/s median request decode
- 75.37% aggregate MTP acceptance
- an earlier retained log segment had already reached at least 88,250 prompt tokens; the latest maximum context has not yet been re-derived from the 562-request snapshot

Those numbers are from local measurements, not a matched benchmark against every other runtime. The Q5 and NInfer runs were done at different times and with different workloads, so I do not treat the gap as a clean runtime-only speedup. The latest NInfer figures are still live telemetry rather than a completed qualification result.

## Why multiple runtimes?

I originally wanted one setup that did everything. In practice, that was less useful than keeping a few known-good routes and loading only one at a time.

| Use case | Runtime | Why I keep it |
| --- | --- | --- |
| Fast single-agent / long coding work | NInfer + NVFP4 + FP8 KV + MTP3 | Best decode numbers I have measured on this machine, including 100K+ prompt depth |
| Conservative fallback | llama.cpp + Q5_K_M + Q8_0 K/V + MTP3 | The completed long-agent run has the strongest retained end-to-end acceptance evidence in this repo |
| Serving / concurrency | SGLang + NVFP4 + FP8 KV | Stable serving baseline with FlashInfer and chunked prefill |

Only one generation runtime is meant to own the GPU at a time. The router example stops the previous runtime, checks that the port/VRAM were released, and then starts the selected backend.

The important distinction is:

> **decode tok/s is not the same thing as agent throughput.**

A runtime can benchmark well and still lose time on tool calls, prefill, cache misses, harness behavior, or bad agent trajectories. That is why this repo keeps both synthetic depth measurements and actual agent runs.

## Test machine

| Component | Setup |
| --- | --- |
| GPU | NVIDIA GeForce RTX 5090, 32,607 MiB reported |
| Driver | 610.74 |
| Host | Windows |
| NInfer | WSL2 / Linux |
| SGLang | WSL2 / Docker |
| llama.cpp | Native Windows CUDA |
| Published benchmark concurrency | 1 request, 1 generation runtime, 1 GPU |

## NInfer: NVFP4 + FP8 KV + MTP3

This is currently the fastest single-agent route I have measured on this machine.

### Tested setup

- Runtime: [`Neroued/ninfer`](https://github.com/Neroued/ninfer)
- Pinned runtime revision: [`a16b6442…c750`](https://github.com/Neroued/ninfer/commit/a16b6442856620b7e4856acb25215acbf7e3c750)
- Model artifact: [`neroued/Qwen3.8-27B-nvfp4-NInfer`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer)
- Tested artifact revision: [`11dbbbbb…31be`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer/tree/11dbbbbbc33db198afe2f02c9232c771ff7031be)
- File: `qwen3_8_27b_nvfp4.ninfer`
- SHA-256: `552c374c685dce302603b95fbe940fb04243c0cd44c083efc644ad3d980d462c`
- Linux / WSL2
- CUDA Toolkit 13.1 or newer
- OpenAI-compatible endpoint on `127.0.0.1:8083`
- NVFP4 weights
- FP8 KV cache
- MTP3
- concurrency 1
- configured runtime/KV capacity: 240,000 tokens

For Qwen Code I still use a **120,000-token working ceiling** with the existing 0.7 auto-compaction policy. The 240K figure above is runtime capacity, not a claim that I have validated useful agent behavior all the way to 240K.

Example config: [`configs/ninfer-nvfp4-mtp3.example.sh`](configs/ninfer-nvfp4-mtp3.example.sh)

### 94K Codex compatibility issue

One ~94K Codex CLI test initially failed because the Responses compatibility layer forwarded `internal_chat_message_metadata_passthrough`, which the NInfer path did not accept.

I changed the NInfer-only adapter to strip that unsupported metadata while keeping tool arguments, outputs, call IDs, and message content intact. Re-running the same bounded read → edit → test task then completed in **33.409 seconds** and passed **3/3** independent fixture checks.

The three generations decoded at:

- 183.2 tok/s
- 174.5 tok/s
- 140.5 tok/s

They were short generations, so I keep this as tool-path/compatibility evidence rather than presenting it as an average agent TPS result.

Full notes: [NInfer qualification](benchmarks/ninfer-qualification-2026-09-09.md)

### Long-running agent use

NInfer has also completed longer local coding-agent jobs for me. Earlier successful runs were not recorded with the same telemetry bundle, so I do not retroactively attach made-up numbers to them.

The instrumented run that started on 2026-09-16 is kept separately here:

[NInfer long-agent telemetry](benchmarks/ninfer-long-agent-live-2026-09-16.md)

The latest live snapshot reached **562 requests / 248,381 output tokens / 171.26 tok/s aggregate decode / 75.37% MTP acceptance**. The workload is still treated as in progress, so final task acceptance, final maximum context, and cleanup/failure accounting remain pending rather than being presented as completed qualification evidence.

## llama.cpp Q5_K_M + MTP3

I keep this as the conservative fallback because its completed long-agent run is better documented end to end.

### Tested setup

- Model: [`bartowski/Qwen3.8-27B-GGUF`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF)
- Tested revision: [`f0eec4a4…c034`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF/tree/f0eec4a4bb4975114a030d048952d83c0a53c034)
- File: `Qwen3.8-27B-Q5_K_M.gguf`
- SHA-256: `E731E180460B906F373294A4E2DE10541E80EE676AF7F8C949A84DBB6ED3CAA8`
- llama.cpp build 10435
- commit: [`9e40df63…7e99`](https://github.com/ggml-org/llama.cpp/commit/9e40df63ba151d771d8b247ac4011cf203337e99)
- context: 131,072
- K/V cache: Q8_0 / Q8_0
- Flash Attention on
- 66/66 layers on GPU
- CPU fallback: 0
- `parallel=1`
- `batch=2048`
- `ubatch=512`
- MTP3: `--spec-type draft-mtp --spec-draft-n-max 3`

Peak VRAM use in the retained qualification was about **28.63 GB**, leaving about **3.98 GiB** free.

Example config: [`configs/llamacpp-q5-mtp3-128k.example.ps1`](configs/llamacpp-q5-mtp3-128k.example.ps1)

### Completed long-agent run

The 2026-08-19 run reached:

- ~109.51 tok/s average decode
- 106,829 max observed context
- 89.61% MTP acceptance
- 16.675M cached prefix tokens
- 96.8% cache hit rate

After fixing test-harness cleanup issues, the post-run acceptance checks were:

- `typecheck PASS`
- `lint PASS`
- `build PASS`
- `vitest 12/12 PASS`

Comparable end-to-end wall time was not captured, so this should not be read as a clean speed comparison with NInfer.

Full notes: [Q5 long-agent qualification](benchmarks/long-agent-qualification-2026-08-19.md)

## SGLang NVFP4

This is the serving/concurrency baseline in the repo rather than the fastest single-agent setup.

### Tested setup

- Model: [`RadixArk/Qwen3.8-27B-NVFP4`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4)
- Tested revision: [`52d1adc5…b854`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4/tree/52d1adc5f38aa5ebf099c29ed7025ba34cfbb854)
- SGLang package: `0.0.0.dev0+qwen38.27b.g561c8f3`
- image build commit: [`c4271c3f…51c5`](https://github.com/sgl-project/sglang/commit/c4271c3fe1262fc2adbd162c33b25de5255251c5)
- pinned container digest: `sha256:506525a5907ea22c9d445afb7c03603959b912de034d86915cf17da814f1a124`
- context: 131,072
- KV: FP8 E4M3
- available KV pool: ~148,997 tokens
- FlashInfer
- MTP off
- `max-running-requests=1`
- `max-mamba-cache-size=5`
- CPU layer offload: 0

Measured steady decode was about **69.3 tok/s**, and about **60.8 tok/s** at 80K+ context.

Example config: [`configs/sglang-nvfp4-128k.example.sh`](configs/sglang-nvfp4-128k.example.sh)

## Benchmark summary

These are the published local depth numbers. They are useful for seeing how decode changes as the prompt grows, but they are **not a matched same-day A/B test**.

| Runtime | Short | ~32K label | ~80K label | ~114K label |
| --- | ---: | ---: | ---: | ---: |
| SGLang NVFP4 | ~69.3 | — | ~60.8 | — |
| Q5_K_M + MTP3 | 151.72 | 120.29 | 98.59 | 94.66 |
| NInfer NVFP4 + MTP3 | **222.0** | **190.6** | **176.9** | **169.8** |

For NInfer, the actual prompt lengths behind those labels were **38,717 / 83,917 / 113,956 tokens**. The short prompt also differs from the historical Q5 short prompt.

Machine-readable results: [`benchmarks/runtime-comparison.csv`](benchmarks/runtime-comparison.csv)

Methodology: [`docs/methodology.md`](docs/methodology.md)

## Routing

The public router file is intentionally just a small data spec:

[`configs/local-model-router.example.json`](configs/local-model-router.example.json)

The intended lifecycle is straightforward:

1. Pick the route for the workload.
2. Stop only the runtime owned by the router.
3. Check that its port and VRAM were released.
4. Start one backend through the machine's GPU scheduler.
5. Verify `/v1/models` returns the expected model ID.
6. If the port/model does not match, stop instead of guessing.
7. Run the task with the route-specific harness settings.
8. Validate the resulting changes separately from runtime performance.

More detail: [agent routing](docs/agent-routing.md)

## Reproducing the setup

1. Download model artifacts directly from the upstream repositories.
2. Check the revision and hashes against the values in this README.
3. Build the pinned NInfer source in WSL2/Linux, or install the corresponding llama.cpp/SGLang runtime.
4. Adapt the example paths under `configs/` to your machine.
5. Keep the API bound to loopback unless you intentionally add authentication/network controls.
6. Start only one generation backend.
7. Run [`scripts/healthcheck.example.ps1`](scripts/healthcheck.example.ps1) against `/v1/models`.
8. Check correctness first, then benchmark throughput.
9. Keep bounded coding tests and long-running agent tests separate.

Full guide: [docs/reproducibility.md](docs/reproducibility.md)

## Things this repo does not prove

- This is one RTX 5090 system, not a multi-machine hardware study.
- The Q5 and NInfer long-agent runs are not matched A/B workloads.
- The short prompts and context-depth probes are not identical between every runtime.
- I did not capture comparable end-to-end wall time for the Q5 re-qualification.
- 240K is NInfer runtime/KV capacity in this setup; it is not evidence of validated 240K agent quality.
- The current NInfer 562-request snapshot is still live telemetry, not a completed end-to-end qualification.
- The latest NInfer maximum prompt/context has not yet been re-derived from the 562-request summary; the retained lower bound remains 88,250 tokens from an earlier log segment.
- Driver, kernels, runtime commits, model revisions, harness behavior, tool patterns, and MTP acceptance can all move the numbers.
- Vision was not tested here.

More detail: [docs/limitations.md](docs/limitations.md)

## Upstream projects

This repo does not redistribute the linked model weights.

- [`Qwen/Qwen3.8-27B`](https://huggingface.co/Qwen/Qwen3.8-27B)
- [`neroued/Qwen3.8-27B-nvfp4-NInfer`](https://huggingface.co/neroued/Qwen3.8-27B-nvfp4-NInfer)
- [`RadixArk/Qwen3.8-27B-NVFP4`](https://huggingface.co/RadixArk/Qwen3.8-27B-NVFP4)
- [`bartowski/Qwen3.8-27B-GGUF`](https://huggingface.co/bartowski/Qwen3.8-27B-GGUF)
- [`Neroued/ninfer`](https://github.com/Neroued/ninfer)
- [`ggml-org/llama.cpp`](https://github.com/ggml-org/llama.cpp)
- [`sgl-project/sglang`](https://github.com/sgl-project/sglang)
- [`QwenLM/qwen-code`](https://github.com/QwenLM/qwen-code)

Check the model card and license for the exact revision you download. The licenses checked for this repo are listed in [docs/upstream-licenses.md](docs/upstream-licenses.md).

## License

The original configs, documentation, validation scripts, and diagrams in this repository are MIT licensed. Upstream models and runtimes keep their own licenses.

Thanks to the Qwen, NInfer, RadixArk, bartowski, llama.cpp, SGLang, and Qwen Code maintainers and contributors.
