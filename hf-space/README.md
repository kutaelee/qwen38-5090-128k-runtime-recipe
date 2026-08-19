---
title: Qwen3.8-27B RTX 5090 128K Recipe
emoji: 🧭
colorFrom: indigo
colorTo: blue
sdk: static
app_file: index.html
fullWidth: true
header: mini
short_description: Dual-runtime 128K agent recipe for one RTX 5090
license: mit
models:
  - Qwen/Qwen3.8-27B
  - RadixArk/Qwen3.8-27B-NVFP4
  - bartowski/Qwen3.8-27B-GGUF
tags:
  - qwen3
  - qwen3-8
  - rtx-5090
  - local-llm
  - sglang
  - llama-cpp
  - mtp
  - nvfp4
  - long-context
  - coding-agent
---

# Qwen3.8-27B on RTX 5090 — 128K Dual-Runtime Agent Recipe

> **No model weights are hosted here.**

This static showcase summarizes a reproducible single-GPU deployment recipe:

- single-agent autonomous long task & fast implementation → Q5_K_M + llama.cpp + MTP3;
- high-concurrency multi-tenant serving baseline → NVFP4 + SGLang;
- one resident runtime at a time.

Canonical source and scripts: <https://github.com/kutaelee/qwen38-5090-128k-runtime-recipe>

Reproducibility discussion and issues: <https://github.com/kutaelee/qwen38-5090-128k-runtime-recipe/issues>

In the 2026-08-19 re-qualification under a revised semantic guard, Q5_K_M + MTP3 completed a full-stack autonomous implementation (12/12 tests PASS, typecheck PASS, build PASS) sustaining 109.51 tok/s with 89.61% MTP draft acceptance.
