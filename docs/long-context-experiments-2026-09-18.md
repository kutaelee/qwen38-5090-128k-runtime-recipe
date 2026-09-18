# Long-context experiments — 2026-09-18

This note records the long-context work that was tested and then parked. It is kept as negative/partial evidence so the same paths are not repeated later.

## Production baseline

The production baseline was restored after every experiment and remained healthy:

- Qwen3.8-27B NInfer artifact: `qwen3_8_27b_nvfp4.ninfer`
- SHA-256: `552c374c685dce302603b95fbe940fb04243c0cd44c083efc644ad3d980d462c`
- mixed NVFP4/FP8 weights
- FP8 KV
- MTP3
- 240K configured context
- tool-call qualification: 40/40
- `/health`: 200

The experiments below did not replace this baseline.

## 1. nvfp4full + hq-e8-2b

The candidate used an `nvfp4full` artifact with a lower weight footprint and a compressed `hq-e8-2b` KV path.

What worked:

- Tool/API protocol passed when the candidate used FP8 KV.
- `nvfp4full + FP8 KV + DFlash2` passed the 40-call tool suite and smoke checks.
- This isolated the earlier raw-tool-markup failures away from the OpenAI/Responses parser layer.

What failed:

- `nvfp4full + hq-e8-2b + DFlash2`: 4/40 in the first isolation pass.
- `nvfp4full + hq-e8-2b + no speculation`: 4/40 with the same early failure pattern.
- A later reproducer improved only marginally to 5/40 after residual-plane clearing/synchronization changes.
- Fresh cache-miss sequences were the failure surface: the first few requests worked, then the runtime produced one-token stops or malformed tool markup.
- Prefix-cache hits could still succeed, so the failure was state/path dependent rather than a deterministic prompt or parser failure.

Conclusion:

> `hq-e8-2b` was the blocker in this candidate stack. DFlash2 was not the root cause.

The codec/fork path was not promoted.

## 2. 512K / 1M attempt

FP8 KV did not fit the intended long-context target on a 32 GB RTX 5090.

Observed/planned memory budget in the tested candidate:

- nvfp4full weights: about 17 GiB
- FP8 KV at 512K: about 17 GiB
- runtime overhead: about 2 GiB
- total: about 36 GiB

The compressed-KV path was therefore required for the attempted 512K+ configuration, but `hq-e8-2b` had already failed the native-context correctness gate.

The run intentionally stopped rather than treating a configured max-context value as proof of usable 512K/1M context.

## 3. rk4v4-e8 600K reproduction attempt

A later attempt switched to the published RTX 5090 `rk4v4-e8` route instead of continuing to debug `hq-e8-2b`.

The local reproduction did not reach the 600K runtime gate because of an artifact/runtime-version mismatch:

- the selected splickz fork contained the E8 KV mode;
- the locally selected newer NInfer model artifact also contained DFlash2 objects;
- the older fork did not have the later DFlash2 artifact binding;
- startup stopped with an unconsumed object such as `dflash2/feature_projection`.

This was an artifact compatibility failure before the long-context correctness test, not evidence that the published rk4v4-e8 600K result was false.

No compatibility patch was promoted because the long-context branch was deprioritized before spending more time on fork reconciliation.

## 4. Decision

The long-context branch is parked for now.

Reasons:

1. The current 240K production route is already fast and stable for the workloads retained in this repository.
2. Extending the same 27B model to 512K/1M increases runtime/KV/fork complexity but does not improve the model's underlying capability.
3. The immediate higher-value change is to keep the current weights, FP8 KV, and 240K context and qualify **DFlash2 K=7** as a speculative-decoding replacement for MTP3.
4. Higher-capability work is being handled separately with the Qwen3.8-Flash-Next route rather than by forcing the 27B runtime to 1M.

## 5. What is and is not proven

Proven locally:

- current production baseline can be restored cleanly;
- candidate FP8 KV + DFlash2 tool path can pass 40/40;
- `hq-e8-2b` in the tested fork has a reproducible sequential/new-sequence failure surface;
- the attempted rk4v4 reproduction was blocked by artifact/runtime binding mismatch before 600K execution.

Not proven locally:

- usable 512K agent quality;
- usable 600K/650K agent quality;
- usable 1M context;
- DFlash2 superiority over MTP3 on the production long-agent workload.

Those claims remain out of scope until a future long-context branch is reopened.

## Next production experiment

Keep all of the following fixed:

- current Qwen3.8-27B NVFP4 artifact
- upstream NInfer production runtime
- FP8 KV
- 240K configured context
- existing agent/harness policies

Change only:

- `MTP3 -> DFlash2 K=7`

Promote only if tool correctness and task acceptance remain non-inferior and the practical throughput/E2E result improves.
