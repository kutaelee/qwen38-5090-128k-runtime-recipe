# Methodology

The evaluation keeps five questions separate. Combining them into a single “tokens per second” score would hide the failure modes this recipe is designed around.

## A. Runtime correctness

Basic instructions, Korean and English text, code explanation, strict JSON schemas, tool-call arguments, and coding outputs were checked for parseability and corruption. CUDA errors, OOM, NaN, gibberish, multilingual corruption, and malformed tool JSON were hard failures.

## B. Raw inference throughput

Decode throughput was read from the serving runtime after warm-up. Reported values include the context depth, KV dtype, speculative/MTP state, runtime version, GPU, and measured median when available. A single best sample is not promoted as the result.

The example benchmark script computes end-to-end completion tokens divided by API wall time. That is intentionally labelled differently from server decode TPS.

## C. Long-context recall

Needle-in-a-haystack prompts placed distinct facts at multiple depths. Long prompts had to complete prefill and return exact facts. Successful KV allocation without a real long prompt did not count as capacity evidence.

## D. Bounded coding

The bounded suite used fresh fixtures, exact permitted change paths, strict tool JSON, UTF-8 preservation, unrelated-diff checks, and independent build/test verification. The Q5/MTP3 qualification included ten single-file TSX tasks and one small multi-file task.

## E. Autonomous agent wall-clock

A medium web implementation exercised planning, repository inspection, multiple semantic edits, test repair, build gates, and browser acceptance. Wall time, tool calls, first edit, context growth, compaction, repeated actions, and final independent gates mattered more than synthetic decode speed.

## One-counted-run rule

The disclosed long-agent trajectory results are **N=1 per reported condition**. Once a counted run started, prompts, runtime settings, context, and acceptance criteria were not changed to rescue it. A failure was not retried until a favorable sample appeared.

This protects against cherry-picking but limits generalization. The Q5 failure is evidence about one trajectory under the recorded harness, not proof that Q5_K_M or llama.cpp is inherently unsuitable for long agents.

## Rounding

- 69.325 tok/s is displayed as ~69.3.
- 60.77 tok/s at 80K+ is displayed as ~60.8.
- 2,129 MiB minimum free VRAM is described as approximately 2.1 GiB.
- Unmeasured same-suite cells remain blank.
