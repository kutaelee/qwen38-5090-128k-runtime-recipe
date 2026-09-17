# Limitations

## Experimental scope

- One RTX 5090 with 32,607 MiB reported VRAM
- One driver and OS/WSL environment
- One pinned NInfer artifact integration revision, one pinned SGLang NVFP4 checkpoint revision, and one pinned Q5_K_M GGUF revision
- One NInfer source revision, one SGLang image, and one llama.cpp commit
- Sequential, single-request serving for the published single-agent measurements
- Text/tool/coding workloads; vision disabled

## Benchmark comparability

The throughput table has intentionally missing cells. SGLang and Q5 were not both measured at every identical depth in the same run. Do not interpolate the missing results.

Raw server decode, API wall throughput, prefill speed, TTFT, tool latency, and complete agent wall time are different metrics. Synthetic decode benchmarks are reported separately from observed agent-run decode averages and request-level live telemetry.

The current NInfer/Hermes long-agent route is configured for a 240,000-token context window, but the retained practical evidence only reaches 160,688 prompt tokens so far. Do not extrapolate the observed 160K behavior to 180K, 200K, or 240K.

The NInfer live run has a summarized snapshot of 601 completed requests / 259,335 output tokens / 171.05 tok/s output-weighted aggregate decode / 75.60% MTP acceptance. This is live telemetry, not a completed qualification result, and it is not a matched MTP-vs-DFlash A/B.

Request-level prefill is also cache-sensitive. In the retained 139K–153K uncached examples, whole-request prefill was about 3.24k and 3.06k tok/s, while five-second server intervals briefly reported up to 5.73k tok/s. These metrics are not interchangeable with each other or with warm cached TTFT.

## Agent evidence

- SGLang completed the product task in 526.388 s but failed the complete acceptance contract because of an unauthorized generated-file edit and a focus-restoration defect.
- Q5/MTP3 in the 2026-08-19 re-qualification completed a deep full-stack implementation passing all acceptance gates (`typecheck`, `lint`, `vitest 12/12`, `build`). Comparable end-to-end wall-time was not captured for this run.
- NInfer/MTP3 has prior successful long-running practical use and an instrumented live run reaching 601 summarized requests plus retained request-level evidence through 160,688 prompt tokens. Final task-level acceptance, final failure accounting, and cleanup evidence for the current run remain pending.

Neither outcome should be generalized into a universal model-quality ranking. Agent versions, prompts, tool schemas, compaction, loop controls, runtime chat templates, cache state, speculative acceptance, and random trajectory effects may change the result.

## Operational constraints

- The examples do not implement a universal cross-platform GPU scheduler.
- Multiple 27B generation runtimes are not intended to remain resident simultaneously on a 32 GB card.
- The SGLang checkpoint's upstream repository has moved beyond the tested revision; the recipe pins the tested revision.
- MTP was not enabled for the 128K SGLang role.
- Q5/MTP3 free-VRAM headroom is a measured peak value (28.63 GB peak used, ~3.98 GiB free), not a guarantee for every driver or display workload.
- NInfer's [September 9 qualification](../benchmarks/ninfer-qualification-2026-09-09.md) adds decode/recall measurements through 114K and verified live cancellation. The initial Codex metadata failure was repaired and the same bounded 94K read/edit/test task passed; this does not establish full autonomous project completion. Constrained JSON remains unsupported.
- A separate historical two-worker observation saw close to 150 tok/s per ~120K worker, or roughly 300 tok/s aggregate generation throughput. The complete raw telemetry bundle was not retained, so this is operational evidence only and must not be presented as 300 tok/s single-stream decode or qualification-grade concurrency data.
