[CmdletBinding()]
param(
    [string]$LlamaServer = 'C:\Tools\llama.cpp\llama-server.exe',
    [string]$ModelPath = 'C:\Models\Qwen3.8\Qwen3.8-27B-Q5_K_M.gguf',
    [ValidateRange(1024, 65535)][int]$Port = 8082
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $LlamaServer -PathType Leaf)) { throw "Missing llama-server: $LlamaServer" }
if (-not (Test-Path -LiteralPath $ModelPath -PathType Leaf)) { throw "Missing GGUF: $ModelPath" }
if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) { throw "Port $Port is already in use." }

& $LlamaServer `
  --model $ModelPath `
  --ctx-size 131072 `
  --cache-type-k q8_0 `
  --cache-type-v q8_0 `
  --flash-attn on `
  --gpu-layers all `
  --split-mode none `
  --main-gpu 0 `
  --parallel 1 `
  --batch-size 2048 `
  --ubatch-size 512 `
  --fit off `
  --no-mmproj `
  --host 127.0.0.1 `
  --port $Port `
  --jinja `
  --no-webui `
  --metrics `
  --no-context-shift `
  --spec-type draft-mtp `
  --spec-draft-n-max 3

exit $LASTEXITCODE
