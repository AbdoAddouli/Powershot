<#
.SYNOPSIS
    Sends a signed test payload to the SCADA ingestion endpoint (Phase 8 verification).

.DESCRIPTION
    Builds a small SCADA/PI envelope, computes X-SCADA-Signature = hex(HMAC-SHA256(
    raw body, shared secret)) over the exact body bytes, and POSTs it to the
    /services/apexrest/api/scada/measurements endpoint on the "ouil gas" org.

    Reads configuration from the repo-root .env (SCADA_SHARED_SECRET, SCADA_ENDPOINT).
    Optionally accepts -ReadingsJson to send a custom payload.

.EXAMPLE
    .\sender.ps1
    .\sender.ps1 -ReadingsJson '{"readings":[{"tag":"WELL-TEST.OIL_FLOW","timestamp":"2026-08-30T10:00:00Z","value":100,"measurementType":"Oil Flow"}]}'
#>
param(
    [string]$ReadingsJson,
    [string]$EnvFile = (Join-Path $PSScriptRoot '..\.env'),
    [string]$TargetOrg = 'ouil gas'
)

$ErrorActionPreference = 'Stop'

function Load-EnvFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Env file not found: $Path"
    }
    $map = @{}
    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
            $i = $line.IndexOf('=')
            $key = $line.Substring(0, $i).Trim()
            $val = $line.Substring($i + 1).Trim()
            $map[$key] = $val
        }
    }
    return $map
}

$envMap = Load-EnvFile $EnvFile
$secret   = $envMap['SCADA_SHARED_SECRET']
$endpoint = $envMap['SCADA_ENDPOINT']

if ([string]::IsNullOrWhiteSpace($secret)) {
    throw 'SCADA_SHARED_SECRET is empty in the env file.'
}
if ([string]::IsNullOrWhiteSpace($endpoint)) {
    throw 'SCADA_ENDPOINT is empty in the env file.'
}

# OAuth bearer token for the authenticated ingest path (the org has no public
# Force.com/MyDomain site, so guest access is unavailable). Prefer SCADA_ACCESS_TOKEN
# from the env file; otherwise derive a live session token from the SFDX org connection.
$accessToken = $envMap['SCADA_ACCESS_TOKEN']
if ([string]::IsNullOrWhiteSpace($accessToken)) {
    Write-Host "SCADA_ACCESS_TOKEN not set - fetching a session token for target org '$TargetOrg'..."
    $prevErr = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $raw = & sf org display --target-org $TargetOrg --json 2>$null
    $ErrorActionPreference = $prevErr
    $tokenJson = ($raw | Out-String) | ConvertFrom-Json
    if ($null -eq $tokenJson -or $null -eq $tokenJson.result) {
        throw "Could not authenticate to target org '$TargetOrg'."
    }
    $accessToken = $tokenJson.result.accessToken
}

if ([string]::IsNullOrWhiteSpace($ReadingsJson)) {
    $body = @{
        readings = @(
            @{
                tag            = 'WELL-TEST.OIL_FLOW'
                timestamp      = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss'Z'")
                value          = 100
                pressure       = 1220
                temperature    = 41.5
                measurementType = 'Oil Flow'
                quality        = 'Good'
            }
        )
    } | ConvertTo-Json -Depth 5 -Compress
} else {
    # Use the supplied JSON exactly as-is so the signer + sender use identical bytes.
    $body = $ReadingsJson.Trim()
}

# Compute HMAC-SHA256 over the exact body bytes (UTF-8).
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$secretBytes = [System.Text.Encoding]::UTF8.GetBytes($secret)
$hmac = [System.Security.Cryptography.HMACSHA256]::new($secretBytes)
$hash     = $hmac.ComputeHash($bodyBytes)
$signature = ($hash | ForEach-Object { $_.ToString('x2') }) -join ''

Write-Host "POST $endpoint"
Write-Host "Body: $body"
Write-Host "X-SCADA-Signature: $signature"

try {
    $resp = Invoke-RestMethod -Method Post -Uri $endpoint `
        -ContentType 'application/json' `
        -Headers @{
            'X-SCADA-Signature' = $signature
            'Authorization'     = "Bearer $accessToken"
        } `
        -Body $body
    Write-Host "Status: 200 OK"
    $resp | ConvertTo-Json -Depth 6
} catch {
    $code    = $_.Exception.Response.StatusCode.value__
    $msgBody = ''
    if ($_.Exception.Response -and $_.Exception.Response.GetResponseStream()) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $msgBody = $reader.ReadToEnd()
    }
    Write-Host "Status: ${code} (${msgBody})" -ForegroundColor Red
}
