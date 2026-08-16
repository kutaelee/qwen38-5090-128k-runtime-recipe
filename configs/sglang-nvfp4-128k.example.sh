#!/usr/bin/env bash
set -euo pipefail

# Tested model revision. Upstream may have a newer HEAD.
MODEL_REVISION="${MODEL_REVISION:-52d1adc5f38aa5ebf099c29ed7025ba34cfbb854}"
HF_CACHE="${HF_CACHE:-/models/qwen38/huggingface/hub}"
PORT="${PORT:-30000}"
IMAGE="lmsysorg/sglang@sha256:506525a5907ea22c9d445afb7c03603959b912de034d86915cf17da814f1a124"
MODEL_PATH="/models/models--RadixArk--Qwen3.8-27B-NVFP4/snapshots/${MODEL_REVISION}"

# The host publish is loopback-only. The container listens on all interfaces
# only inside its isolated network namespace.
exec docker run --rm \
  --name qwen38-sglang-nvfp4-128k \
  --gpus all \
  --shm-size 32g \
  --ipc host \
  --publish "127.0.0.1:${PORT}:30000" \
  --env HF_HUB_OFFLINE=1 \
  --env TRANSFORMERS_OFFLINE=1 \
  --volume "${HF_CACHE}:/models:ro" \
  "${IMAGE}" \
  python3 -m sglang.launch_server \
    --trust-remote-code \
    --model-path "${MODEL_PATH}" \
    --context-length 131072 \
    --mem-fraction-static 0.85 \
    --kv-cache-dtype fp8_e4m3 \
    --attention-backend flashinfer \
    --chunked-prefill-size 2048 \
    --reasoning-parser qwen3 \
    --tool-call-parser qwen3_coder \
    --mm-feature-transport cpu \
    --mamba-ssm-dtype float32 \
    --mamba-radix-cache-strategy extra_buffer \
    --max-running-requests 1 \
    --max-mamba-cache-size 5 \
    --host 0.0.0.0 \
    --port 30000
