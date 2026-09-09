[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Distro = 'Ubuntu',
    [ValidateRange(60, 86400)][int]$MaxRuntimeSeconds = 21600,
    [string]$Agent = 'codex-qwen38-ninfer-runtime'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$config = Join-Path $root 'configs\ninfer-nvfp4-mtp3.example.sh'
$revision = '11dbbbbbc33db198afe2f02c9232c771ff7031be'
$filename = 'qwen3_8_27b_nvfp4.ninfer'

if (-not (Test-Path -LiteralPath $config -PathType Leaf)) {
    throw "NInfer configuration is missing: $config"
}
if (Get-NetTCPConnection -State Listen -LocalPort 8083 -ErrorAction SilentlyContinue) {
    throw 'Port 8083 is already in use.'
}

$wslHome = (& wsl.exe -d $Distro -- printenv HOME).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($wslHome)) {
    throw "Unable to resolve HOME in WSL distribution '$Distro'."
}
$resolvedConfig = [IO.Path]::GetFullPath($config)
$drive = $resolvedConfig.Substring(0, 1).ToLowerInvariant()
$tail = $resolvedConfig.Substring(2).Replace('\', '/')
$wslConfig = "/mnt/$drive$tail"
$wslModel = "$wslHome/models/huggingface/hub/models--neroued--Qwen3.8-27B-nvfp4-NInfer/snapshots/$revision/$filename"

& wsl.exe -d $Distro -- test -x "$wslHome/src/ninfer/build/apps/ninfer-serve"
if ($LASTEXITCODE -ne 0) { throw 'Pinned NInfer server binary is missing in WSL.' }
& wsl.exe -d $Distro -- test -f $wslModel
if ($LASTEXITCODE -ne 0) { throw "Pinned NInfer artifact is missing: $wslModel" }

$workload = 'qwen38-ninfer-single-agent-model-qwen3-8-27b-nvfp4-rev11dbbbbb'
$gpuqArgs = @(
    'run', '--vram', '30000', '--eta', '3600', '--priority', '60',
    '--max-runtime', [string]$MaxRuntimeSeconds,
    '--agent', $Agent, '--workload', $workload,
    '--cwd', $root, '--',
    'wsl.exe', '-d', $Distro, '--',
    'env', "NINFER_MODEL=$wslModel", 'bash', $wslConfig
)

if ($PSCmdlet.ShouldProcess("gpuq workload $workload", 'Start NInfer on 127.0.0.1:8083')) {
    $jobId = & gpuq @gpuqArgs
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($jobId)) {
        throw "gpuq submission failed for $workload"
    }
    $jobId.Trim()
}
