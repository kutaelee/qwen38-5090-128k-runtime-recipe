[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Endpoint,
    [Parameter(Mandatory)][string]$Model,
    [Parameter(Mandatory)][string]$PromptFile,
    [ValidateRange(1, 20)][int]$Runs = 3,
    [ValidateRange(1, 32768)][int]$MaxTokens = 300,
    [string]$OutputCsv = 'results\benchmark-output.csv'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $PromptFile -PathType Leaf)) { throw "Prompt file not found: $PromptFile" }
$prompt = Get-Content -Raw -LiteralPath $PromptFile -Encoding utf8
$rows = @()

for ($run = 1; $run -le $Runs; $run++) {
    $body = @{
        model = $Model
        messages = @(@{ role = 'user'; content = $prompt })
        temperature = 0
        max_tokens = $MaxTokens
        stream = $false
    } | ConvertTo-Json -Depth 8

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-RestMethod -Method Post -Uri ($Endpoint.TrimEnd('/') + '/chat/completions') -ContentType 'application/json' -Body $body -TimeoutSec 600
    $stopwatch.Stop()
    $completionTokens = [int64]$response.usage.completion_tokens
    $rows += [pscustomobject]@{
        run = $run
        prompt_tokens = [int64]$response.usage.prompt_tokens
        completion_tokens = $completionTokens
        wall_seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 3)
        end_to_end_completion_tps = [math]::Round($completionTokens / $stopwatch.Elapsed.TotalSeconds, 3)
        finish_reason = $response.choices[0].finish_reason
    }
}

$parent = Split-Path -Parent $OutputCsv
if (-not [string]::IsNullOrWhiteSpace($parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
$rows | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding utf8
$rows | Format-Table -AutoSize

Write-Warning 'This script reports end-to-end completion throughput. Use runtime metrics/logs for server decode TPS, TTFT, cache hits, and speculative acceptance.'
