# Reproducibility

## 1. Acquire artifacts from upstream

Download directly from the linked Hugging Face repositories into a runtime-owned model cache. Do not place weights in this Git repository.

| Artifact | Tested revision | Verification |
| --- | --- | --- |
| `RadixArk/Qwen3.8-27B-NVFP4` | `52d1adc5f38aa5ebf099c29ed7025ba34cfbb854` | immutable Hub revision |
| `bartowski/Qwen3.8-27B-GGUF` | `f0eec4a4bb4975114a030d048952d83c0a53c034` | immutable Hub revision |
| `Qwen3.8-27B-Q5_K_M.gguf` | same as above | SHA-256 `E731E180460B906F373294A4E2DE10541E80EE676AF7F8C949A84DBB6ED3CAA8` |

Review the model card and license at the exact revision before downloading.

## 2. Pin runtimes

- SGLang image digest: `sha256:506525a5907ea22c9d445afb7c03603959b912de034d86915cf17da814f1a124`
- SGLang image build commit: `c4271c3fe1262fc2adbd162c33b25de5255251c5`
- llama.cpp commit: `9e40df63ba151d771d8b247ac4011cf203337e99` (build 10435)
- Qwen Code: stable 0.21.12 for the reported agent runs

Record the GPU model, driver, CUDA runtime, host OS, and runtime hashes in your own result manifest.

## 3. Configure one backend

Copy an example to an untracked local file and replace only the generic model/cache paths:

```text
configs/sglang-nvfp4-128k.example.sh
configs/llamacpp-q5-mtp3-128k.example.ps1
```

Keep loopback binding, context, KV type, batch settings, MTP state, and single-request mode unchanged for a comparable run.

## 4. Verify startup

Check:

- expected model ID from `/v1/models`;
- 131,072 server context;
- correct KV dtype;
- all model layers on GPU and CPU fallback 0;
- FlashInfer or Flash Attention enabled as applicable;
- MTP off for SGLang and draft MTP n=3 for Q5;
- no CUDA/OOM errors.

Example:

```powershell
pwsh -File scripts/healthcheck.example.ps1 `
  -Endpoint http://127.0.0.1:30000/v1 `
  -ExpectedModel '<MODEL_ID>'
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
