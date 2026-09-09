[CmdletBinding()]
param(
    [string]$Distro = 'Ubuntu',
    [ValidateRange(1, 60)][int]$GraceSeconds = 15
)

$ErrorActionPreference = 'Stop'

$wslHome = (& wsl.exe -d $Distro -- printenv HOME).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($wslHome)) {
    throw "Unable to resolve HOME in WSL distribution '$Distro'."
}

$binary = "$wslHome/src/ninfer/build/apps/ninfer-serve"
$pattern = '^' + [regex]::Escape($binary) +
    ' .*--model-id qwen3\.8-27b .*--port 8083( |$)'

function Get-NInferPid {
    $matches = @(& wsl.exe -d $Distro -- pgrep -f $pattern 2>$null)
    if ($LASTEXITCODE -notin @(0, 1)) {
        throw 'Unable to inspect the task-owned NInfer process.'
    }
    $pids = @($matches | Where-Object { $_ -match '^\d+$' })
    if ($pids.Count -gt 1) {
        throw "Refusing to stop multiple matching NInfer processes: $($pids -join ', ')"
    }
    if ($pids.Count -eq 1) { return [int]$pids[0] }
    return $null
}

$pidToStop = Get-NInferPid
if ($null -eq $pidToStop) {
    return
}

& wsl.exe -d $Distro -- kill -TERM $pidToStop
if ($LASTEXITCODE -ne 0) {
    throw "Failed to request graceful stop for NInfer PID $pidToStop."
}

$deadline = (Get-Date).AddSeconds($GraceSeconds)
do {
    Start-Sleep -Milliseconds 500
    $remaining = Get-NInferPid
} while ($null -ne $remaining -and (Get-Date) -lt $deadline)

if ($null -ne $remaining) {
    & wsl.exe -d $Distro -- kill -KILL $remaining
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to stop NInfer PID $remaining after the grace period."
    }
}
