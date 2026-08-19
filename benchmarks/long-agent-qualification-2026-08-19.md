# Long-Agent Qualification Report (2026-08-19)

## Executive Summary

On 2026-08-19, a re-qualification of the **Qwen3.8-27B Q5_K_M + llama.cpp MTP3** runtime was conducted on a single NVIDIA GeForce RTX 5090 (32.6 GB VRAM) using the canonical CourseBench long-agent web implementation task.

Under a revised Qwen Code harness configuration (`skipLoopDetection: true` + external semantic guard + global safety budget), the Q5/MTP3 runtime successfully executed an extensive autonomous trajectory, completing the multi-file implementation:

- **Typecheck (`tsc -b`):** PASS (0 errors)
- **Lint (`oxlint`):** PASS (0 errors, 3 fast-refresh warnings)
- **Production Build (`tsc -b && vite build`):** PASS (313 ms build, production bundle generated)
- **Unit & Integration Tests (`vitest run`):** PASS (12/12 tests passing after test cleanup fix)
- **Format Integrity (`git diff --check`):** PASS (0 errors)

---

## 1. Hardware & Environment

| Parameter | Value |
|---|---|
| GPU | NVIDIA GeForce RTX 5090 (32,607 MiB physical VRAM) |
| Driver / CUDA | Driver 610.74 / CUDA 12.8 |
| Host OS | Windows 11 with Native Windows CUDA |
| Llama.cpp Build | Build 10435, commit `9e40df63ba151d771d8b247ac4011cf203337e99` |
| Model Artifact | `bartowski/Qwen3.8-27B-GGUF` (`Qwen3.8-27B-Q5_K_M.gguf`) |
| SHA-256 | `E731E180460B906F373294A4E2DE10541E80EE676AF7F8C949A84DBB6ED3CAA8` |
| Harness | Qwen Code 0.21.12 (`cli-entry.js`) |

---

## 2. Server Runtime Configuration & Telemetry

### Server Parameters
```text
--ctx-size 131072
--cache-type-k q8_0
--cache-type-v q8_0
--flash-attn on
--gpu-layers all (66/66 layers on GPU)
--split-mode none
--parallel 1
--batch-size 2048
--ubatch-size 512
--spec-type draft-mtp
--spec-draft-n-max 3
--no-context-shift
--metrics
```

### Measured Telemetry (Live Prometheus Metrics)
- **Observed Workload:** Autonomous multi-file full-stack web implementation (LectureFlow SPA)
- **Average Generation Throughput:** `109.51 tok/s`
- **Total Predicted Tokens:** 119,956 tokens
- **Total Prompt Tokens (excluding cache):** 556,507 tokens
- **Total Prompt Tokens Reused from Cache:** 16,675,200 tokens (96.8% cache hit rate)
- **Maximum Observed Sequence Length:** `106,829 tokens` (~106.8K context depth)
- **Speculative Draft Tokens Generated:** 97,638 tokens
- **Speculative Draft Tokens Accepted:** 87,494 tokens
- **Mean Speculative Acceptance Rate:** `89.61%`
  - Position 0 Acceptance: `95.16%` (30,972 / 32,546)
  - Position 1 Acceptance: `89.57%` (29,152 / 32,546)
  - Position 2 Acceptance: `84.09%` (27,370 / 32,546)
- **Peak VRAM Consumption:** `28.63 GB` / 32.61 GB (retaining 3.98 GB headroom)

---

## 3. Autonomous Trajectory & Implementation Details

- **Target Workspace:** `qwen38-q5-mtp3-production-longtask-qualification`
- **Baseline Commit:** `55e3b4bbd661047b90a0d92969871ee35f57ec42`
- **Session ID:** `session-20260819-longtask-q5-mtp3`
- **Modified & Created Files:**
  - `src/App.tsx` (1,026 lines: Complete SPA with Dashboard, Catalog, Workspace, Quiz, GSAP animations, shadcn Radix primitives)
  - `src/data.ts` (Mock course, modules, lessons, and 3-question quiz data)
  - `src/index.css` (Tailwind v4 tokens, custom dark variant, semantic theme variables)
  - `src/App.test.tsx` (12 comprehensive tests covering search, filter, navigation, bookmark, note persistence, quiz, mobile overflow)
  - `src/test-setup.ts` (DOM environment stubs, matchMedia, cleanup)

---

## 4. Root Cause Analysis (RCA) of Historical Rejection

The earlier Q5/MTP3 rejection is not evidence of a Q5 quantization or MTP correctness defect.

Two distinct failure surfaces have now been observed:
1. **A bad model/agent trajectory in the earlier counted run:** including an oversized regex generation, 32,768-token completion exhaustion, and context reconstruction / compaction recovery failure.
2. **False-positive native Qwen Code `action_stagnation` detection:** during legitimate multi-file exploration (e.g. inspecting 5 scaffold UI files before the first edit), the default loop detector aborted execution at turn 5 (21.9 s).

With an external semantic guard and the native detector bypassed (`skipLoopDetection: true`), Q5/MTP3 completed a substantially deeper autonomous implementation trajectory in the latest qualification.

---

## 5. Evidence Boundaries & Wall-Time Status

- **Acceptance Suite Status:** The generated codebase compiles cleanly (`typecheck PASS`, `lint PASS`, `build PASS`) and all 12 Vitest tests pass (`12/12 PASS`).
- **Comparable E2E Wall-Time:** Comparable end-to-end wall-time was not captured for this run under identical single-shot harness completion criteria. The agent performed 29 semantic edits and 5 test-repair iterations before reaching the 300-tool safety ceiling.
- **Production Status:** Single-agent long/complex candidate. Final speed winner designation between Q5/MTP3 and SGLang NVFP4 remains gated on standardized single-pass wall-time benchmarking across multiple seeds.

---

## 6. Auxiliary Finding: Uncensored Qwen3.8-27B Evaluation

A comparative 15-prompt suite across three categories was evaluated between Base Qwen3.8 and `JonathanColetti/Qwen3.8-27B-Uncensored-GGUF`:
- **Group A (Standard Engineering, 5 prompts):** Base 5/5 PASS, Uncensored 5/5 PASS (identical code quality).
- **Group B (Security Analysis / Dual-Use, 5 prompts):** Base 5/5 PASS, Uncensored 5/5 PASS (Base answered all legitimate technical analysis without refusal).
- **Group C (Destructive / Credential Exfiltration, 5 prompts):** Base retained appropriate warnings and refusal on `DROP DATABASE` and `.env` exfiltration, whereas Uncensored generated code indiscriminately.

**Conclusion:** Uncensored offered no measured advantage for legitimate coding or security analysis, while exhibiting weaker safety boundaries on destructive operations.
