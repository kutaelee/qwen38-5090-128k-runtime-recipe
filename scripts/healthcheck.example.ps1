[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Endpoint,
    [Parameter(Mandatory)][string]$ExpectedModel,
    [ValidateRange(1, 60)][int]$TimeoutSeconds = 5
)

$ErrorActionPreference = 'Stop'
$base = $Endpoint.TrimEnd('/')
$models = Invoke-RestMethod -Method Get -Uri "$base/models" -TimeoutSec $TimeoutSeconds
$served = @($models.data | ForEach-Object { $_.id })
if ($served -notcontains $ExpectedModel -and $served -notcontains 'any') {
    throw "Model mismatch. Expected '$ExpectedModel'; endpoint returned: $($served -join ', ')"
}

[pscustomobject]@{
    status = 'ready'
    endpoint = $base
    expected_model = $ExpectedModel
    served_models = $served
} | ConvertTo-Json -Depth 4
