# Reproducibility

## 1. Acquire artifacts from upstream

Download directly from the linked Hugging Face repositories into a runtime-owned model cache. Do not place weights in this Git repository.

| Artifact | Tested revision | Verification |
| --- | --- | --- |
| `neroued/Qwen3.8-27B-nvfp4-NInfer` | integration pin `11dbbbbbc33db198afe2f02c9232c771ff7031be` | SHA-256 `552c374c685dce302603b95fbe940fb04243c0cd44c083efc644ad3d980d462c` |
| `RadixArk/Qwen3.8-27B-NVFP4` | `52d1adc5f38aa5ebf099c29ed7025ba34cfbb854` | immutable Hub revision |
| `bartowski/Qwen3.8-27B-GGUF` | `f0eec4a4bb4975114a030d048952d83c0a53c034` | immutable Hub revision |
| `Qwen3.8-27B-Q5_K_M.gguf` | same as above | SHA-256 `E731E180460B906F373294A4E2DE10541E80EE676AF7F8C949A84DBB6ED3CAA8` |

Review the model card and license at the exact revision before downloading.

## 2. Pin runtimes

- NInfer source: [`Neroued/ninfer`](https://github.com/Neroued/ninfer), integration pin `a16b6442856620b7e4856acb25215acbf7e3c750`
- SGLang image digest: `sha256:506525a5907ea22c9d445afb7c03603959b912de034d86915cf17da814f1a124`
- SGLang image build commit: `c4271c3fe1262fc2adbd162c33b25de5255251c5`
- llama.cpp commit: `9e40df63ba151d771d8b247ac4011cf203337e99` (build 10435)
- Qwen Code: stable 0.21.12 for the reported agent runs

Record the GPU model, driver, CUDA runtime, host OS, and runtime hashes in your own result manifest.

NInfer requires 64-bit Linux/WSL2, an RTX 5090 (`sm_120a`), CUDA Toolkit 13.1 or newer, CMake 3.28 or newer, a C++20 compiler, Ninja, the documented FFmpeg development libraries, and libcurl 7.85 or newer. Build the pinned source on WSL ext4:

```bash
git clone https://github.com/Neroued/ninfer.git "$HOME/src/ninfer"
git -C "$HOME/src/ninfer" checkout --detach a16b6442856620b7e4856acb25215acbf7e3c750
cmake -S "$HOME/src/ninfer" -B "$HOME/src/ninfer/build" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$HOME/src/ninfer/build" -j
```

Download the artifact directly into a WSL-native runtime-owned Hugging Face cache, pinning the immutable Hub revision. Record the path printed by `hf download` as `NINFER_MODEL`; do not copy it into this repository.

```bash
export NINFER_MODEL="$(hf download neroued/Qwen3.8-27B-nvfp4-NInfer \
  qwen3_8_27b_nvfp4.ninfer \
  --revision 11dbbbbbc33db198afe2f02c9232c771ff7031be \
  --cache-dir "$HOME/models/huggingface/hub")"
printf '%s  %s\n' \
  '552c374c685dce302603b95fbe940fb04243c0cd44c083efc644ad3d980d462c' \
  "$NINFER_MODEL" | sha256sum --check
```

## 3. Configure one backend

Copy an example to an untracked local file and replace only the generic model/cache paths:

```text
configs/sglang-nvfp4-128k.example.sh
configs/llamacpp-q5-mtp3-128k.example.ps1
configs/ninfer-nvfp4-mtp3.example.sh
```

Keep loopback binding, context, KV type, batch settings, MTP state, and single-request mode unchanged. Start only one generation runtime. NInfer uses a 240,000-token runtime ceiling while the unchanged Qwen Code profile remains at 120,000 tokens with 0.7 auto-compaction.

When NInfer is submitted through a host GPU queue, pair the start command with the exact, workload-scoped cleanup command in `scripts/Stop-NInferQwen38.ps1`. The cleanup script resolves one matching WSL process, requests a graceful stop, and only escalates for that verified PID after a bounded grace period.

## 4. Verify startup

Check:

- expected model ID from `/v1/models`;
- the selected runtime context (240,000 for NInfer; 131,072 for the existing runtimes);
- correct KV dtype;
- all model layers on GPU and CPU fallback 0;
- FlashInfer or Flash Attention enabled as applicable;
- MTP3 for NInfer and Q5; MTP off for SGLang;
- no CUDA/OOM errors.

Example:

```powershell
pwsh -File scripts/healthcheck.example.ps1 `
  -Endpoint http://127.0.0.1:8083/v1 `
  -ExpectedModel 'qwen3.8-27b'
```

## 5. Run gates in order

1. basic instruction and multilingual correctness;
2. strict JSON schema;
3. tool-call names and arguments;
4. long-context recall at actual prompt depths;
5. bounded coding with exact diff/build/test gates;
6. autonomous task with a frozen prompt and one-counted-run rule;
7. runtime cleanup and VRAM verification.

Stop performance testing when runtime correctness is corrupted.

## 6. Report without cherry-picking

Publish medians, min/max when available, sample counts, context depth, KV dtype, MTP state, runtime version, VRAM, and failed gates. Keep raw decode separate from end-to-end agent wall time. Do not rerun a failed counted trajectory and present only the best sample.

## 7. Validate this public recipe

```powershell
pwsh -NoProfile -File scripts/validate-release.ps1
```

Pass organization-specific private repository names or other local literals through `-ForbiddenLiteral` during a release audit.
