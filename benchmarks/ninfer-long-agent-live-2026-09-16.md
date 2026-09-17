# NInfer long-agent live telemetry — started 2026-09-16

This note preserves an **in-progress** long-running agent telemetry series from the local RTX 5090 workstation. It is not a final benchmark result and must not be presented as a completed qualification until the workload exits and its task-level acceptance is recorded.

## Runtime

- Model: `neroued/Qwen3.8-27B-nvfp4-NInfer`
- Runtime: NInfer
- Weight format: NVFP4
- KV: FP8
- Speculation: MTP3
- Concurrency: 1 active generation request
- Workload: real multi-turn agent work using `openai-chat` with tool calls

## Latest live snapshot — 2026-09-17

The latest reported snapshot from this instrumented NInfer/NVFP4 workload reached:

| Metric | Observation |
| --- | ---: |
| Completed requests | **562** |
| Generated output tokens | **248,381** |
| Aggregate decode throughput | **171.26 tok/s** |
| Mean request decode throughput | **178.77 tok/s** |
| Median request decode throughput | **180.55 tok/s** |
| Aggregate MTP acceptance | **75.37%** |

`Aggregate decode throughput` is output-token weighted: total generated output tokens divided by the sum of each completed request's estimated decode time (`output_tokens / request_decode_tps`). It remains the preferred summary for this run because a 100-token request and a multi-thousand-token request should not receive equal weight.

The latest summary above did not include a newly derived maximum prompt/context value. The previously retained log segment had already shown prompt sizes reaching at least **88,250 tokens**. That older lower bound remains valid evidence, but it is not presented as the maximum context reached by the 562-request snapshot.

The current run is still treated as live telemetry. Final task acceptance, final maximum context, runtime/adapter failure accounting, and cleanup evidence remain pending until the workload finishes and those artifacts are captured.

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

The later 562-request aggregate is materially higher than this earlier point, but that should not be read as a controlled runtime improvement. The workload mix, prompt lengths, cache state, generation lengths, and speculative acceptance can all change over a long agent session.

## Long-running-use status

Long-running NInfer agent tasks had already completed successfully in prior local use before this telemetry series. Those earlier successful runs were not retained in this repository as a comparable, instrumented telemetry bundle, so this note does **not** retroactively assign them synthetic metrics or a reproducible benchmark score.

Accordingly, the evidence status is:

- **Long-running practical use:** previously observed successful completion.
- **Instrumented long-running telemetry:** observed through 562 requests / 248,381 output tokens / 171.26 tok/s aggregate decode.
- **Current run task-level acceptance:** pending because the workload has not yet been published as completed with independent acceptance evidence.
- **Matched Q5 vs NInfer A/B:** not established; the historical Q5 long-agent run used a different workload/harness condition.

## Comparison boundary

The historical Q5/MTP3 qualification recorded **109.51 tok/s average decode** on a 100K+ autonomous coding trajectory. The latest NInfer live snapshot is numerically higher, but the two runs are not a matched contemporaneous A/B. The repository therefore reports both observations without claiming a causal runtime-only speedup or a universal winner.

The September 9 depth probes remain separate evidence: NInfer measured 190.6 tok/s at 38,717 prompt tokens, 176.9 tok/s at 83,917, and 169.8 tok/s at 113,956. Synthetic/depth decode, live agent aggregate decode, and end-to-end task completion are reported separately.

## Completion update required

When the current workload finishes, update this file with:

1. final completed request count and generated output tokens;
2. final aggregate/mean/median decode TPS and MTP acceptance;
3. maximum observed prompt/context;
4. final task result and independent acceptance evidence;
5. any CUDA/OOM/runtime/adapter failures;
6. whether cleanup released the runtime/port/VRAM correctly.

Until then, the latest numbers remain an explicitly dated **live snapshot**, not a final qualification result.
