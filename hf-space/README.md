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
---

# Qwen3.8-27B on RTX 5090 — 128K Dual-Runtime Agent Recipe

> **No model weights are hosted here.**

This static showcase summarizes a reproducible single-GPU deployment recipe:

- long / complex / autonomous work → NVFP4 + SGLang;
- quick / bounded implementation → Q5_K_M + llama.cpp + MTP3;
- one resident runtime at a time.

Canonical source and scripts: <https://github.com/kutaelee/qwen38-5090-128k-runtime-recipe>

Reproducibility discussion and issues: <https://github.com/kutaelee/qwen38-5090-128k-runtime-recipe/issues>

Suggested discovery terms: `qwen3`, `qwen3.8`, `rtx-5090`, `llama.cpp`, `sglang`, `mtp`, `nvfp4`, `gguf`, `long-context`, `local-llm`, `coding-agent`.

The 151.72 tok/s Q5 result did not beat the approximately 69 tok/s SGLang route in one counted autonomous coding trajectory. That is an N=1 trajectory result, not a general ranking of model formats.
