# Limitations

## Experimental scope

- One RTX 5090 with 32,607 MiB reported VRAM
- One driver and OS/WSL environment
- One pinned NVFP4 checkpoint revision and one pinned Q5_K_M GGUF revision
- One SGLang image and one llama.cpp commit
- Sequential, single-request serving
- Text/tool/coding workloads; vision disabled

## Benchmark comparability

The throughput table has intentionally missing cells. SGLang and Q5 were not both measured at every identical depth in the same run. Do not interpolate the missing results.

Raw server decode, API wall throughput, prefill speed, TTFT, tool latency, and complete agent wall time are different metrics. The chart reports decode only.

## Agent evidence

The long autonomous comparison is N=1. SGLang completed the product task but failed the complete acceptance contract because of an unauthorized generated-file edit and a focus-restoration defect. Q5 did not reach a semantic edit before the SGLang wall baseline elapsed after producing an invalid oversized regex.

Neither outcome should be generalized into a universal model-quality ranking. Agent versions, prompts, tool schemas, compaction, loop controls, runtime chat templates, and random trajectory effects may change the result.

## Operational constraints

- The examples do not implement a universal cross-platform GPU scheduler.
- Both 27B runtimes are not intended to remain resident simultaneously on a 32 GB card.
- The SGLang checkpoint's upstream repository has moved beyond the tested revision; the recipe pins the tested revision.
- MTP was not enabled for the 128K SGLang role.
- Q5/MTP3 free-VRAM headroom is a measured peak value, not a guarantee for every driver or display workload.
