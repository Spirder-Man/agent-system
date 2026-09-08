# OS2026 demo recorder. ASCII-only so Windows PowerShell 5.1 can parse it.
# Requires: Featurize stack is up, SSH tunnel open (18088 if local 8088 is taken).
# Do not point at Vite :5173.
#
#   cd agent-system
#   $env:E2E_ADMIN_PASSWORD = 'changeme'
#   .\scripts\record-os2026-demo.ps1
#   .\scripts\record-os2026-demo.ps1 -BaseUrl http://localhost:18088
#   .\scripts\record-os2026-demo.ps1 -Headless

param(
    [string]$BaseUrl = '',
    [string]$Password = '',
    [string]$User = 'admin',
    [switch]$Headless
)

$ErrorActionPreference = 'Stop'
$code = 1

if (-not $BaseUrl) { $BaseUrl = $env:PLAYWRIGHT_BASE_URL }
if (-not $Password) { $Password = $env:E2E_ADMIN_PASSWORD }
if ($env:E2E_ADMIN_USER) { $User = $env:E2E_ADMIN_USER }

$webRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\agent1-web')).Path

function Test-PlainGet {
    param([string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 4
        return ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400)
    } catch {
        return $false
    }
}

if (-not $BaseUrl) {
    $candidates = @(
        'http://localhost:18088',
        'http://127.0.0.1:18088',
        'http://localhost:8088',
        'http://127.0.0.1:8088'
    )
    foreach ($cand in $candidates) {
        if (Test-PlainGet ($cand + '/nginx-health')) {
            $BaseUrl = $cand
            break
        }
    }
}

if (-not $BaseUrl) {
    Write-Host 'Nginx /nginx-health not found on 18088 or 8088.' -ForegroundColor Red
    Write-Host 'On Featurize: compose up. On this PC, open the SSH tunnel first:'
    Write-Host '  ssh -p PORT -L 18088:127.0.0.1:8088 featurize@workspace.featurize.cn'
    exit 1
}

if ($BaseUrl -match '5173') {
    Write-Host ("Refusing {0}: Vite DEV login is fake." -f $BaseUrl) -ForegroundColor Red
    exit 1
}

if (-not $Password) { $Password = 'changeme' }

$live = $BaseUrl.TrimEnd('/') + '/health/live'
if (-not (Test-PlainGet $live)) {
    Write-Host ("API not ready: {0}" -f $live) -ForegroundColor Red
    Write-Host 'Wait for api /health/live, or tunnel local 5000 as well.'
    exit 1
}

Write-Host ("[demo] BaseUrl={0}  user={1}" -f $BaseUrl, $User)
try {
    $loginUrl = $BaseUrl.TrimEnd('/') + '/api/Auth/login'
    $loginBody = @{ username = $User; password = $Password } | ConvertTo-Json
    $login = Invoke-RestMethod -Uri $loginUrl -Method POST -ContentType 'application/json' -TimeoutSec 15 -Body $loginBody
    if (-not $login.token) { throw 'login response has no token' }
    Write-Host ("[demo] login probe OK role={0}" -f $login.role)
} catch {
    Write-Host ("login probe failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'HTTP 500 = AUTH_ACCOUNTS_JSON stripped; recreate api. HTTP 401 = wrong -Password.'
    exit 1
}

$env:PLAYWRIGHT_BASE_URL = $BaseUrl
$env:E2E_ADMIN_PASSWORD = $Password
$env:E2E_ADMIN_USER = $User

$pwArgs = @('playwright', 'test', '--config=playwright.demo.config.ts')
if ($Headless) {
    $env:DEMO_HEADLESS = '1'
} else {
    $env:DEMO_HEADLESS = '0'
    $pwArgs += '--headed'
}

Push-Location $webRoot
try {
    if (-not (Test-Path 'node_modules\@playwright\test')) {
        Write-Host '[demo] npm install (first run)...'
        npm install
    }
    & npx @pwArgs
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}

$webm = Join-Path $webRoot 'demo-output\os2026-demo.webm'
if (Test-Path $webm) {
    Write-Host ("[demo] video: {0}" -f $webm)
    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($ffmpeg) {
        $mp4 = Join-Path $webRoot 'demo-output\os2026-demo.mp4'
        & ffmpeg -y -i $webm -c:v libx264 -pix_fmt yuv420p -movflags +faststart $mp4
        if ($LASTEXITCODE -eq 0) {
            Write-Host ("[demo] mp4: {0}" -f $mp4)
        }
    } else {
        Write-Host '[demo] ffmpeg not found; convert webm to mp4 before upload.'
    }
} else {
    Write-Host '[demo] missing demo-output\os2026-demo.webm ; see agent1-web\test-results\' -ForegroundColor Yellow
}

exit $code
