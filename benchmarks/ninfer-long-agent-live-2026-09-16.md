# NInfer long-agent live telemetry — 2026-09-16

This note preserves an **in-progress** long-running agent telemetry snapshot from the local RTX 5090 workstation. It is not a final benchmark result and must not be presented as a completed run until the workload exits and its task-level acceptance is recorded.

## Runtime

- Model: `neroued/Qwen3.8-27B-nvfp4-NInfer`
- Runtime: NInfer
- Weight format: NVFP4
- KV: FP8
- Speculation: MTP3
- Concurrency: 1 active generation request
- Workload: real multi-turn agent work using `openai-chat` with tool calls

## Live snapshot

Snapshot reported while the workload was still running on 2026-09-16:

| Metric | Observation |
| --- | ---: |
| Completed requests | **101** |
| Generated output tokens | **96,241** |
| Aggregate decode throughput | **132.23 tok/s** |
| Mean request decode throughput | **140.59 tok/s** |
| Median request decode throughput | **136.2 tok/s** |
| Aggregate MTP acceptance | **51.71%** |

`Aggregate decode throughput` is output-token weighted: total generated output tokens divided by the sum of each completed request's estimated decode time (`output_tokens / request_decode_tps`). It is the preferred summary for this run because a 100-token request and a multi-thousand-token request should not receive equal weight.

The same live log segment showed prompt sizes growing through at least **88,250 tokens** before this snapshot. Individual completed requests in the displayed 79K–88K region included long generations such as:

| Request | Prompt | Output | Decode | MTP acceptance |
| --- | ---: | ---: | ---: | ---: |
| `req#84` | 79,769 | 5,556 | 130.6 tok/s | 49.7% |
| `req#89` | 81,836 | 1,819 | 112.9 tok/s | 36.8% |
| `req#91` | 82,557 | 3,454 | 130.5 tok/s | 49.0% |
| `req#92` | 85,254 | 1,171 | 120.0 tok/s | 42.3% |
| `req#93` | 86,559 | 981 | 123.1 tok/s | 43.2% |
| `req#94` | 88,250 | 166 | 146.6 tok/s | 58.5% |

These request-level values are useful for showing that the aggregate is not produced only by short synthetic completions. The run also contains many shorter tool-turn generations, so mean request TPS is intentionally not treated as the headline throughput metric.

## Long-running-use status

Long-running NInfer agent tasks had already completed successfully in prior local use before this snapshot. Those earlier successful runs were not retained in this repository as a comparable, instrumented telemetry bundle, so this note does **not** retroactively assign them synthetic metrics or a reproducible benchmark score.

Accordingly, the evidence status is:

- **Long-running practical use:** previously observed successful completion.
- **Instrumented long-running telemetry:** now observed; current snapshot is 101 requests / 96,241 output tokens / 132.23 tok/s aggregate decode.
- **Current run task-level acceptance:** pending because this snapshot was taken before workload completion.
- **Matched Q5 vs NInfer A/B:** not established; the historical Q5 long-agent run used a different workload/harness condition.

## Comparison boundary

The historical Q5/MTP3 qualification recorded **109.51 tok/s average decode** on a 100K+ autonomous coding trajectory. The current NInfer snapshot's **132.23 tok/s aggregate decode** is numerically about 20.7% higher, but the two runs are not a matched contemporaneous A/B. The repository therefore reports both observations without claiming a causal runtime-only speedup or a universal winner.

The September 9 depth probes remain separate evidence: NInfer measured 190.6 tok/s at 38,717 prompt tokens, 176.9 tok/s at 83,917, and 169.8 tok/s at 113,956. Synthetic/depth decode, live agent aggregate decode, and end-to-end task completion are reported separately.

## Completion update required

When the current workload finishes, update this file with:

1. final completed request count and generated output tokens;
2. final aggregate/mean/median decode TPS and MTP acceptance;
3. maximum observed prompt/context;
4. final task result and independent acceptance evidence;
5. any CUDA/OOM/runtime/adapter failures;
6. whether cleanup released the runtime/port/VRAM correctly.

Until then, the numbers above remain an explicitly dated **live snapshot**, not the final qualification result.
