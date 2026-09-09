# NInfer depth and Codex qualification — 2026-09-09

[English](ninfer-qualification-2026-09-09.md) · [한국어](ninfer-qualification-2026-09-09.ko.md)

**Decision: keep Q5/MTP3 as the default; NInfer remains a qualification candidate.** NInfer passed the tested decode and recall probes. The initial Codex tool round trip failed on a Responses compatibility error; a scoped adapter repair subsequently passed the same bounded 94K task. This is not a full autonomous qualification. Q5 was not rerun.

## Measured decode versus historical Q5

Same pinned NInfer artifact, driver and runtime as the [integration report](ninfer-integration-2026-09-08.md). FP8 KV, MTP3, thinking OFF, 240K allocation, concurrency 1. Each depth used one warm-up followed by three measured generations, temperature 0, 300 output tokens. Values below are server-log decode rates, not output divided by request wall time.

| Historical depth label | Q5 historical median tok/s | NInfer median tok/s | NInfer min–max | NInfer actual prompt tokens | Draft acceptance |
| --- | ---: | ---: | ---: | ---: | ---: |
| Short | 151.72 | 222.0 | 222.0–222.5 | 54 | 83.92% |
| 32K | 120.29 | 190.6 | 190.6–190.6 | 38,717 | 75.55% |
| 80K | 98.59 | 176.9 | 176.8–176.9 | 83,917 | 73.84% |
| 114K | 94.66 | 169.8 | 169.7–169.9 | 113,956 | 75.82% |

The historical Q5 depth generator actually produced 38,673 / 83,873 / 113,912 context tokens before the instruction/template, despite the 32K/80K/114K labels. NInfer reused that generator's 5/11/15 evidence units and the same RepositoryIndex generation instruction. The short prompt differs from historical Q5 (54 versus roughly 725 context tokens); its ratio is not a matched-prompt speedup. Different artifacts, chat templates, APIs and cache implementations also prevent a strict runtime-only attribution.

Deep-context measured decode was approximately 1.58x / 1.79x / 1.79x the historical Q5 values. This is a historical comparison, not a contemporaneous A/B. The 12 measured generations produced 3,600 tokens; accepted/proposed draft tokens were 2,502/3,243 (77.15%). This is below the proposed 85–90% target, despite higher decode speed. The historical 89.61% Q5 figure came from an agent workload and is not a matched acceptance baseline.

Raw per-run tokens, prompt hashes, timings and draft counts: [JSON](ninfer-depth-2026-09-09.json). Reproducer: [compare-runtimes.py](../scripts/compare-runtimes.py).

## Prefill, cache and memory

| Depth | Warm-up client TTFT | Repeated-prompt median client TTFT | Repeated-prompt median wall |
| --- | ---: | ---: | ---: |
| 38K | 5.537 s | 0.072 s | 1.645 s |
| 84K | 16.205 s | 0.087 s | 1.783 s |
| 114K | 25.959 s | 0.097 s | 1.864 s |

Repeated prompts reused almost all input tokens. These small TTFT values must not be presented as cold long-context prefill. The separate uncached recall requests reported approximately 7.06K / 5.21K tok/s prefill at 38K / 84K; client recall TTFT was 5.514 / 16.148 / 25.861 s at the three depths.

GPUQ observed whole-device peak usage of 29,436 MiB across the run. This includes other device allocations and is not a process-exclusive allocator measurement or a continuously sampled minimum-free statistic. Runtime configuration still uses host state/KV caches. No CUDA/OOM error was observed in the retained server log. No 160K–240K workload was executed.

## Correctness and failures

| Gate | Observed result |
| --- | --- |
| Basic instruction | 3/3 |
| Constrained JSON schema | Unsupported: HTTP 400 `response_format_not_supported` |
| Original plain JSON prompt | 0/20 strict parse; responses included Markdown fences |
| Explicit raw-JSON-only diagnostic | 20/20; separate prompt variant, no schema enforcement |
| Single-turn tool name/arguments | 40/40 `read_file` requests |
| Recall at 38K / 84K / 114K | 5/5 facts at each depth, no answers in schema |
| Restricted Python coding fixture | 2/3 tasks, each repeated 3 times after warm-up |
| Actual Codex read/edit/test round trip | Initial FAIL; post-fix bounded retest PASS (3/3 tests) |

The Python `unique` function used `list.append`, violating the deliberately restricted no-attributes fixture contract; it was not garbled code. The other two functions passed their test vectors. Explicit JSON-only results do not erase the original parse failures or provide constrained-generation support. See the separate [JSON diagnostic](../scripts/probe-json-explicit.py).

Historical Q5 NIAH used an enum schema containing the expected answers, so its 5/5 is not equivalent to the answer-free NInfer recall check. The new NInfer test asked for five retained facts at 10/25/50/75/90% positions. Recall success alone does not establish coding performance at that depth.

## Real Codex failure at 94K

A real Codex CLI 0.153.4 run received the 84K reference context plus its normal instructions/tools, for an observed 94,338 prompt tokens. The isolated task was to inspect a small JavaScript sum function, fix it to include even integers only, preserve tests, and run `node sum.test.cjs`.

The first tool request read both source and tests successfully. On the next round trip the adapter/upstream returned:

```text
parameter_not_supported
unsupported input member: internal_chat_message_metadata_passthrough
```

The run exited 1 after 31.253 s. Semantic edits: 0. Independent test rerun still failed (`10 !== 6`). The one successful generation logged 188.2 tok/s and 35/39 accepted draft tokens, but its output was only 46 tokens: **no representative agent-average TPS is claimed**. In particular, this does not beat or replace the historical 109.51 tok/s CourseBench result.

This was a bounded high-context agent probe, not a full CourseBench replay. No runtime or adapter repair was folded into this initial measured attempt.

## Post-fix Codex retest

The NInfer-only adapter now strips `internal_chat_message_metadata_passthrough` from Responses input items. It preserves tool arguments, outputs, call IDs and message content. Neither model/runtime settings nor other provider routes were changed. A reusable [minimal adapter and self-test](../scripts/ninfer-codex-input-compat.py) is included; it is not a complete router.

One post-fix retest used the same prompt, original fixture and Codex CLI. Codex read source/tests, edited the sum function, ran its tests, and returned a final response. Independent `node sum.test.cjs` also passed all three assertions. The retained read output matches the final test file; only the source function changed. The metadata HTTP 400 did not recur.

| Metric | Post-fix observation |
| --- | ---: |
| Codex exit / wall | 0 / 33.409 s |
| Successful tool executions | 2 (read; edit + test) |
| API generations | 3 |
| Actual prompt tokens per request | 94,338 / 94,544 / 94,682 |
| Total input / cached input / output tokens | 283,564 / 188,770 / 247 |
| Reasoning output tokens | 0 |
| Server decode tok/s per request | 183.2 / 174.5 / 140.5 |
| Client-facing server TTFT per request | 19.2 s / 197 ms / 313 ms |
| Accepted / proposed draft tokens | 169 / 249 (67.87%) |
| Independent fixture tests | 3/3 PASS |

These are only 48/79/120-token generations, not a representative agent TPS benchmark or evidence of full CourseBench success. This is an explicitly labeled repair retest, not a replacement for the initial counted failure. The harness's console print hit a Windows encoding error **after** saving Codex's successful exit and UTF-8 logs; the saved result and independent tests establish the outcome. Nonfatal WebSocket-to-HTTP fallback and local hook/MCP shutdown warnings also remained; they were not runtime correctness failures and were not repaired in this scope.

Outcome: **Codex bounded tool round-trip compatibility PASS after adapter repair; long autonomous promotion remains unqualified.**

## Publication scope

GPUQ cancellation completed automatically for this run: the reservation became canceled, port 8083 closed, and observed whole-device memory returned to 83 MiB. This verifies the cleanup path that remained untested in the September 8 integration report.

This report preserves negative outcomes and the historical Q5 measurements. Public routing keeps Q5 as default, NInfer explicitly selectable as a candidate, and SGLang as the serving route. No model weights, private source, session identifiers or workstation raw logs are published.
