# 评委验收：甲醇 vs 硝酸 → 禁配 + GB 15603（不依赖 GPU）
# Windows PowerShell 5.1 / 7 可用，不需要 bash / python。
# 物质名用 Unicode 码位，避免无 BOM 源文件在 5.1 下解析失败。
$ErrorActionPreference = 'Stop'
$Api = if ($env:DEMO_API_URL) { $env:DEMO_API_URL.TrimEnd('/') } else { 'http://localhost:5000' }
$User = if ($env:DEMO_USER) { $env:DEMO_USER } else { 'admin' }
$Pass = if ($env:DEMO_PASSWORD) { $env:DEMO_PASSWORD } else { 'changeme' }

$substanceA = -join @([char]0x7532, [char]0x9187)
$substanceB = -join @([char]0x785D, [char]0x9178)

Write-Host "Waiting for $Api/health/live ..."
$live = $false
for ($i = 1; $i -le 40; $i++) {
    try {
        $r = Invoke-WebRequest -Uri "$Api/health/live" -UseBasicParsing -TimeoutSec 5
        if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) { $live = $true; break }
    } catch { }
    if ($i -lt 40) { Start-Sleep -Seconds 3 }
}
if (-not $live) {
    Write-Host 'API did not become live. Try: docker compose -f docker-compose.demo.yml logs api'
    exit 1
}
Write-Host 'API live'

$utf8 = [System.Text.Encoding]::UTF8
$loginJson = (@{ username = $User; password = $Pass } | ConvertTo-Json -Compress)
$login = Invoke-RestMethod -Uri "$Api/api/Auth/login" -Method POST -ContentType 'application/json; charset=utf-8' -Body $utf8.GetBytes($loginJson)
$token = $login.token
if (-not $token) { $token = $login.Token }
if (-not $token) {
    Write-Host 'Login failed: no token'
    exit 1
}

$compatJson = (@{ substanceA = $substanceA; substanceB = $substanceB } | ConvertTo-Json -Compress)
$resp = Invoke-RestMethod -Uri "$Api/api/Compliance/storage/compatibility" -Method POST -ContentType 'application/json; charset=utf-8' -Headers @{
    Authorization = "Bearer $token"
} -Body $utf8.GetBytes($compatJson)
$text = ($resp | ConvertTo-Json -Depth 8 -Compress)
Write-Host $text
if ($text -notmatch 'GB 15603') {
    Write-Host 'Acceptance failed: GB 15603 not found. Check API logs.'
    exit 1
}
$needles = @(
    (-join @([char]0x7981, [char]0x6B62)),
    (-join @([char]0x4E25, [char]0x7981)),
    (-join @([char]0x4E0D, [char]0x53EF)),
    (-join @([char]0x4E0D, [char]0x80FD, [char]0x540C, [char]0x5E93)),
    (-join @([char]0x7981, [char]0x914D))
)
$hit = $false
foreach ($w in $needles) {
    if ($text.Contains($w)) { $hit = $true; break }
}
if (-not $hit) {
    Write-Host 'Acceptance failed: incompatibility wording not found. Check API logs.'
    exit 1
}
Write-Host 'PASS: methanol vs nitric storage ban (rule engine, no GPU)'
exit 0
