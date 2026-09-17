# NInfer long-agent live telemetry — started 2026-09-16

This note preserves an **in-progress** long-running agent telemetry series from the local RTX 5090 workstation. It is not a final benchmark result and must not be presented as a completed qualification until the workload exits and its task-level acceptance is recorded.

## Runtime and harness

- Model: `neroued/Qwen3.8-27B-nvfp4-NInfer`
- Runtime: NInfer
- Weight format: NVFP4
- KV: FP8
- Speculation: MTP3
- Concurrency: 1 active generation request
- Workload: real multi-turn agent work using `openai-chat` with tool calls
- NInfer reported `max_model_len`: **240,000 tokens**
- Hermes `qwen38-ninfer` `context_length`: **240,000 tokens**
- Hermes `max_tokens`: **16,384 tokens**

The NInfer server and Hermes route were therefore both configured for a 240K context window during the deep-context observations below. This is different from the separate Qwen Code route documented elsewhere in the repository.

If a 0.75 compaction policy is applied after reserving `max_tokens`, the arithmetic threshold is `(240,000 - 16,384) × 0.75 = 167,712` tokens. That value is included only to make the configuration math explicit; it is not presented as a server-reported compaction event.

## Latest aggregate snapshot — 2026-09-17

The latest fully summarized snapshot from this instrumented NInfer/NVFP4 workload reached:

| Metric | Observation |
| --- | ---: |
| Completed requests | **601** |
| Generated output tokens | **259,335** |
| Aggregate decode throughput | **171.05 tok/s** |
| Mean request decode throughput | **178.36 tok/s** |
| Median request decode throughput | **180.2 tok/s** |
| Aggregate MTP acceptance | **75.60%** |

`Aggregate decode throughput` is output-token weighted: total generated output tokens divided by the sum of each completed request's estimated decode time (`output_tokens / request_decode_tps`). It remains the preferred summary for this run because a 100-token request and a multi-thousand-token request should not receive equal weight.

The summary counter reports 601 completed requests, while the retained server request identifiers in the later excerpt extend through `req#606`. Request IDs are therefore treated as identifiers rather than assumed to be a contiguous completed-request count.

## Later deep-context evidence — req#598 to req#606

A later retained log excerpt extends the observed prompt depth from the earlier 88K region to **160,688 prompt tokens** while the same NInfer + NVFP4 + FP8 KV + MTP3 route remained active.

Selected completed requests:

| Request | Prompt | Output | Cache | Prefill | Decode | MTP acceptance | TTFT |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `req#598` | 146,659 | 1,573 | 99.8% | 973 tok/s | 172.4 tok/s | 87.6% | 322 ms |
| `req#599` | 148,339 | 65 | 76.7% | 1.76k tok/s | 178.8 tok/s | 98.0% | 19.8 s |
| `req#600` | 148,881 | 483 | 99.7% | 973 tok/s | 177.6 tok/s | 84.7% | 564 ms |
| `req#601` | 139,078 | 1,480 | 0.0% | 3.24k tok/s | 147.3 tok/s | 64.7% | 43.0 s |
| `req#602` | 152,995 | 32 | 0.0% | 3.06k tok/s | 155.3 tok/s | 80.0% | 50.1 s |
| `req#603` | 155,886 | 55 | 98.2% | 2.19k tok/s | 178.2 tok/s | 93.3% | 1.4 s |
| `req#604` | 158,217 | 1,095 | 98.6% | 2.02k tok/s | 144.9 tok/s | 65.5% | 1.2 s |
| `req#605` | 159,538 | 1,034 | 95.9% | 1.98k tok/s | 186.5 tok/s | 94.1% | 3.4 s |
| `req#606` | **160,688** | 418 | 95.2% | 1.95k tok/s | **139.1 tok/s** | 62.5% | 4.0 s |

This excerpt is useful for one specific claim: **the retained MTP3 run was still producing usable decode throughput around 160K prompt depth.** It does not establish what happens at 180K, 200K, or 240K, and it is not a matched comparison against DFlash.

The request-level decode range in this excerpt is wide because generation length, cache state, speculative acceptance, and tool-turn shape differ. For example, `req#605` decoded at 186.5 tok/s with 94.1% MTP acceptance, while `req#606` decoded at 139.1 tok/s with 62.5% acceptance only ~1.1K prompt tokens later. Prompt depth alone is therefore not enough to explain request throughput.

### Prefill observations

The same excerpt also contains two uncached long-prompt requests:

- `req#601`: 139,078 prompt tokens, 0% cache, **3.24k tok/s request-level prefill**, 43.0 s TTFT.
- `req#602`: 152,995 prompt tokens, 0% cache, **3.06k tok/s request-level prefill**, 50.1 s TTFT.

Five-second server telemetry during the later prefill sequence briefly reported **5.73k tok/s** (`28,672 tokens / 5 s`) and other windows in the ~4.3–4.9k tok/s range. Those interval counters are not directly interchangeable with whole-request prefill rates, and they should not be used as a clean cross-runtime comparison without matched cache state and prompt shape.

Cached requests show the opposite tradeoff clearly: reported whole-request prefill rates can look lower while TTFT collapses to sub-second or low-single-digit seconds because most of the prefix is reused. Cache percentage, TTFT, request-level prefill, and interval prefill are therefore retained as separate metrics.

## Earlier retained snapshot — 2026-09-16

The first published snapshot from this telemetry series was:

| Metric | Observation |
| --- | ---: |
| Completed requests | **101** |
| Generated output tokens | **96,241** |
| Aggregate decode throughput | **132.23 tok/s** |
| Mean request decode throughput | **140.59 tok/s** |
| Median request decode throughput | **136.2 tok/s** |
| Aggregate MTP acceptance | **51.71%** |

That retained log segment showed prompt sizes growing through at least **88,250 tokens**. Individual completed requests in the displayed 79K–88K region included long generations such as:

| Request | Prompt | Output | Decode | MTP acceptance |
| --- | ---: | ---: | ---: | ---: |
| `req#84` | 79,769 | 5,556 | 130.6 tok/s | 49.7% |
| `req#89` | 81,836 | 1,819 | 112.9 tok/s | 36.8% |
| `req#91` | 82,557 | 3,454 | 130.5 tok/s | 49.0% |
| `req#92` | 85,254 | 1,171 | 120.0 tok/s | 42.3% |
| `req#93` | 86,559 | 981 | 123.1 tok/s | 43.2% |
| `req#94` | 88,250 | 166 | 146.6 tok/s | 58.5% |

These request-level values are useful for showing that the aggregate is not produced only by short synthetic completions. The run also contains many shorter tool-turn generations, so mean request TPS is intentionally not treated as the headline throughput metric.

The later 601-request aggregate is materially higher than this earlier point, but that should not be read as a controlled runtime improvement. The workload mix, prompt lengths, cache state, generation lengths, and speculative acceptance can all change over a long agent session.

## Separate two-worker observation

In a separate local experiment, the 240K budget was split across **two ~120K agent workers**. Each worker was observed near **150 tok/s**, for roughly **300 tok/s aggregate generation throughput** across the two concurrent workers.

This is an operational observation, not a controlled single-stream benchmark. It trades per-worker context for aggregate throughput and should not be compared directly with the single-request decode figures above. The raw telemetry bundle for that historical two-worker run is not retained here, so the repository does not treat the ~300 tok/s aggregate figure as qualification-grade evidence.

## Long-running-use status

Long-running NInfer agent tasks had already completed successfully in prior local use before this telemetry series. Those earlier successful runs were not retained in this repository as a comparable, instrumented telemetry bundle, so this note does **not** retroactively assign them synthetic metrics or a reproducible benchmark score.

Accordingly, the evidence status is:

- **Long-running practical use:** previously observed successful completion.
- **Instrumented long-running telemetry:** fully summarized through 601 requests / 259,335 output tokens / 171.05 tok/s aggregate decode / 75.60% MTP acceptance.
- **Deep-context request evidence:** retained through `req#606`, reaching **160,688 prompt tokens**.
- **Current run task-level acceptance:** pending because the workload has not yet been published as completed with independent acceptance evidence.
- **Matched MTP vs DFlash A/B:** not established.
- **Matched Q5 vs NInfer A/B:** not established; the historical Q5 long-agent run used a different workload/harness condition.

## Comparison boundary

The historical Q5/MTP3 qualification recorded **109.51 tok/s average decode** on a 100K+ autonomous coding trajectory. The latest NInfer live snapshot is numerically higher, but the two runs are not a matched contemporaneous A/B. The repository therefore reports both observations without claiming a causal runtime-only speedup or a universal winner.

The September 9 depth probes remain separate evidence: NInfer measured 190.6 tok/s at 38,717 prompt tokens, 176.9 tok/s at 83,917, and 169.8 tok/s at 113,956. The September 17 live excerpt extends practical prompt depth evidence to 160,688 tokens, but under a changing agent workload rather than a controlled depth probe. Synthetic/depth decode, live agent decode, prefill behavior, and end-to-end task completion are reported separately.

## Completion update required

When the current workload finishes, update this file with:

1. final completed request count and generated output tokens;
2. final aggregate/mean/median decode TPS and MTP acceptance;
3. maximum observed prompt/context;
4. final task result and independent acceptance evidence;
5. any CUDA/OOM/runtime/adapter failures;
6. whether cleanup released the runtime/port/VRAM correctly.

Until then, the latest numbers remain explicitly dated **live telemetry**, not a final qualification result.
