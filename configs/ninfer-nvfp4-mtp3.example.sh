#!/usr/bin/env bash
set -Eeuo pipefail

# NInfer is built and run inside WSL2/Linux ext4. Keep both source and model
# outside this Git repository and outside /mnt/*.
: "${NINFER_ROOT:=$HOME/src/ninfer}"
: "${NINFER_MODEL:?Set NINFER_MODEL to the canonical qwen3_8_27b_nvfp4.ninfer path}"

readonly EXPECTED_NINFER_REVISION="a16b6442856620b7e4856acb25215acbf7e3c750"
readonly NINFER_BIN="$NINFER_ROOT/build/apps/ninfer-serve"

case "$NINFER_ROOT:$NINFER_MODEL" in
  *:/mnt/*|/mnt/*:*)
    echo "NInfer source and model must be on WSL ext4, not /mnt/*." >&2
    exit 1
    ;;
esac

if [[ ! -x "$NINFER_BIN" ]]; then
  echo "Missing executable: $NINFER_BIN" >&2
  exit 1
fi
if [[ ! -f "$NINFER_MODEL" ]]; then
  echo "Missing model artifact: $NINFER_MODEL" >&2
  exit 1
fi

actual_revision="$(git -C "$NINFER_ROOT" rev-parse HEAD)"
if [[ "$actual_revision" != "$EXPECTED_NINFER_REVISION" ]]; then
  echo "NInfer revision mismatch: expected $EXPECTED_NINFER_REVISION, got $actual_revision" >&2
  exit 1
fi

exec "$NINFER_BIN" "$NINFER_MODEL" \
  --model-id qwen3.8-27b \
  --host 127.0.0.1 \
  --port 8083 \
  --max-context 240000 \
  --kv-capacity 240000 \
  --max-concurrency 1 \
  --kv-dtype fp8 \
  --device-state-slots 2 \
  --host-state-slots 8 \
  --host-kv-mib 8192 \
  --spec mtp \
  --draft-tokens 3 \
  --lm-head-draft \
  --no-thinking
