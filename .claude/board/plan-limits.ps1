param(
    [string]$StatusFile = (Join-Path $env:LOCALAPPDATA "rauchen-game-board\statusline.json")
)

$limits = [ordered]@{}
$limitsAt = $null
if (Test-Path $StatusFile) {
    $status = Get-Content -Raw $StatusFile | ConvertFrom-Json
    if ($status.rate_limits) {
        foreach ($p in $status.rate_limits.PSObject.Properties) {
            if ($null -eq $p.Value.used_percentage) { continue }
            $limits[$p.Name] = [ordered]@{
                used     = [double]$p.Value.used_percentage
                resetsAt = if ($p.Value.resets_at) { [long]$p.Value.resets_at * 1000 } else { $null }
            }
        }
    }
    $limitsAt = [DateTimeOffset]::new((Get-Item $StatusFile).LastWriteTimeUtc).ToUnixTimeMilliseconds()
}

[ordered]@{
    limits    = $limits
    limitsAt  = $limitsAt
    updatedAt = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
} | ConvertTo-Json -Depth 4 -Compress
