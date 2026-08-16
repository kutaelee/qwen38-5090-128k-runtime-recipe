[CmdletBinding()]
param(
    [string[]]$ForbiddenLiteral = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failures = [Collections.Generic.List[string]]::new()

function Add-Failure([string]$Message) { $script:failures.Add($Message) }

$required = @(
    'README.md', 'LICENSE', 'SECURITY.md', '.gitignore', 'AGENTS.md',
    'configs\sglang-nvfp4-128k.example.sh',
    'configs\llamacpp-q5-mtp3-128k.example.ps1',
    'configs\qwen-code-settings.example.json',
    'configs\local-model-router.example.json',
    'benchmarks\runtime-comparison.csv',
    'assets\architecture.svg', 'assets\performance-chart.svg',
    'hf-space\README.md', 'hf-space\index.html', 'social\x-thread-ko.md'
)
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) { Add-Failure "missing:$relative" }
}

foreach ($json in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.json') {
    try { $null = Get-Content -Raw -LiteralPath $json.FullName -Encoding utf8 | ConvertFrom-Json }
    catch { Add-Failure "invalid-json:$($json.FullName.Substring($root.Length + 1))" }
}

foreach ($ps1 in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ps1') {
    $tokens = $null; $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($ps1.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    if (@($errors).Count) { Add-Failure "invalid-powershell:$($ps1.FullName.Substring($root.Length + 1))" }
}

$textExtensions = @('.md', '.json', '.ps1', '.sh', '.csv', '.svg', '.html', '.gitignore')
$files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object {
    $_.FullName -notmatch '[\\/]\.git[\\/]' -and
    $_.FullName -ne $PSCommandPath -and
    ($textExtensions -contains $_.Extension -or $_.Name -in @('LICENSE', 'AGENTS.md', '.gitignore'))
})
$patterns = [ordered]@{
    windows_user_home = '(?i)[A-Z]:\\Users\\[^<\\\s]+'
    private_drive_path = '(?i)\b[DE]:\\(?:AI|Data|Workspace|LocalBackup)\\'
    unix_home = '(?i)(?:^|[\s"''])/home/[^/<\s]+'
    credential_assignment = '(?i)(api[_-]?key|token|secret|password|authorization)\s*[:=]\s*["''][^<\s][^"'']+'
    bearer = '(?i)\bBearer\s+[A-Za-z0-9._~-]{8,}'
    hf_token = '\bhf_[A-Za-z0-9]{12,}'
    openai_key = '\bsk-[A-Za-z0-9_-]{12,}'
    private_ip = '\b(?:10\.(?:\d{1,3}\.){2}\d{1,3}|192\.168\.(?:\d{1,3}\.)\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.(?:\d{1,3}\.)\d{1,3})\b'
    uuid = '\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\b'
}
foreach ($file in $files) {
    $text = Get-Content -Raw -LiteralPath $file.FullName -Encoding utf8
    foreach ($entry in $patterns.GetEnumerator()) {
        if ($text -match $entry.Value) { Add-Failure "sensitive-pattern:$($entry.Key):$($file.FullName.Substring($root.Length + 1))" }
    }
    foreach ($literal in $ForbiddenLiteral) {
        if (-not [string]::IsNullOrWhiteSpace($literal) -and $text.Contains($literal, [StringComparison]::OrdinalIgnoreCase)) {
            Add-Failure "forbidden-literal:$($file.FullName.Substring($root.Length + 1))"
        }
    }
}

$trackedWeights = @(& git -C $root ls-files 2>$null | Where-Object { $_ -match '(?i)\.(gguf|safetensors|bin|pt|pth|onnx|engine)$' })
if ($trackedWeights.Count) { Add-Failure 'model-weight-file-tracked' }

if (Test-Path -LiteralPath (Join-Path $root '.git')) {
    $historyNames = @(& git -C $root log --all --name-only --pretty=format: 2>$null | Where-Object { $_ -match '(?i)\.(gguf|safetensors|bin|pt|pth|onnx|engine)$' })
    if ($historyNames.Count) { Add-Failure 'model-weight-file-in-history' }
}

if ($failures.Count) {
    $failures | Sort-Object -Unique | ForEach-Object { Write-Error $_ }
    exit 1
}

[pscustomobject]@{
    status = 'PASS'
    scanned_files = $files.Count
    json_files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.json').Count
    powershell_files = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.ps1').Count
    tracked_weight_files = 0
    history_weight_files = 0
} | ConvertTo-Json
