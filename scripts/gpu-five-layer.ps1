#Requires -Version 5.1
# ============================================================
# gpu-five-layer.ps1
# 公司电脑一条编排：SSH 多端口隧道 → Gate1 → L0/L1 白盒 → L2 甲醇问句
# → Playwright e2e-real →（gpu-full）Eval 63 条 + 识图 + D1-D6 日志。
#
# 不要 npm run test:e2e:real（pretest 会跑 health-check.ps1 + benzene）。
# 不要 int-test-task11.sh / download-analysis.ps1（AutoDL 路径）。
#
# 用法（工作目录 agent-system/）:
#   $env:E2E_ADMIN_PASSWORD = '7758521'
#   $env:E2E_AUDITOR_PASSWORD = '7758521'
#   $env:E2E_VIEWER_PASSWORD = '7758521'
#   .\scripts\gpu-five-layer.ps1 -SshPort 65037 -Profile gpu-quick
#   .\scripts\gpu-five-layer.ps1 -SshPort 65037 -Profile gpu-full -VisionImage "D:\path\to\ghs.jpg"
# ============================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$SshPort = 0,

    [string]$SshHost = 'workspace.featurize.cn',
    [string]$SshUser = 'featurize',

    [ValidateSet('gpu-quick', 'gpu-full')]
    [string]$Profile = 'gpu-quick',

    [string]$VisionImage = '',
    [string]$RemoteComposeDir = '/opt/agent1/容器化部署/gpu',

    [switch]$SkipWhitebox,
    [switch]$SkipTunnel,
    [switch]$SkipRemoteLogs,

    # 本机 Docker 已占 8088/5000/8080/8081 时强制改绑 18088/15000/18080/18081/18083
    [switch]$AltTunnelPorts
)

$ErrorActionPreference = 'Continue'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir = Join-Path $RepoRoot ("eval_reports\{0}" -f $stamp)
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$adminPwd = $env:E2E_ADMIN_PASSWORD
if (-not $adminPwd) { $adminPwd = 'changeme' }

$startedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$sshProc = $null
$hardFail = $false
$alerts = New-Object System.Collections.Generic.List[string]

$l4SkipDetail = 'gpu-quick (Eval/vision/analyze not in this profile)'
if ($Profile -eq 'gpu-full') { $l4SkipDetail = '' }
$layers = [ordered]@{
    gate1       = [ordered]@{ status = 'PENDING'; detail = '' }
    l0_l1       = [ordered]@{ status = 'PENDING'; detail = '' }
    l2          = [ordered]@{ status = 'PENDING'; detail = ''; elapsedSec = $null; toolsUsed = @() }
    l3          = [ordered]@{ status = 'PENDING'; detail = '' }
    l4_eval     = [ordered]@{ status = $(if ($Profile -eq 'gpu-full') { 'PENDING' } else { 'SKIP' }); detail = $l4SkipDetail }
    l4_vision   = [ordered]@{ status = $(if ($Profile -eq 'gpu-full') { 'PENDING' } else { 'SKIP' }); detail = $l4SkipDetail }
    l4_analyze  = [ordered]@{ status = $(if ($Profile -eq 'gpu-full') { 'PENDING' } else { 'SKIP' }); detail = $l4SkipDetail }
}

function Test-TcpListen {
    param([int]$Port)
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
        $listener.Start()
        $listener.Stop()
        return $false
    } catch {
        return $true
    }
}

# 本机 Docker 常占 8088/5000/8080/8081（无 8083）。SSH -L 同端口会绑失败，Gate1 就会测到本机栈。
$localWeb = 8088
$localApi = 5000
$localLlm = 8080
$localEmbed = 8081
$localVision = 8083
$busy = New-Object System.Collections.Generic.List[string]
foreach ($pair in @(
        @{ n = 'web:8088'; p = 8088 },
        @{ n = 'api:5000'; p = 5000 },
        @{ n = 'llm:8080'; p = 8080 },
        @{ n = 'embed:8081'; p = 8081 }
    )) {
    if (Test-TcpListen $pair.p) { $busy.Add($pair.n) }
}
if ($AltTunnelPorts -or ($busy.Count -gt 0 -and -not $SkipTunnel)) {
    $localWeb = 18088
    $localApi = 15000
    $localLlm = 18080
    $localEmbed = 18081
    $localVision = 18083
    if ($busy.Count -gt 0) {
        Write-Host ""
        Write-Host ("[tunnel] local ports already in use: {0}" -f ($busy -join ', ')) -ForegroundColor Yellow
        Write-Host "[tunnel] likely this PC Docker (no llama-vision). SSH will bind 18088/15000/18080/18081/18083 -> Featurize 8088/5000/8080/8081/8083" -ForegroundColor Yellow
        Write-Host "[tunnel] otherwise Gate1 would pass local 8080/5000/8088 and FAIL only 8083." -ForegroundColor Yellow
    }
    $altBusy = New-Object System.Collections.Generic.List[string]
    foreach ($pair in @(
            @{ n = '18088'; p = 18088 },
            @{ n = '15000'; p = 15000 },
            @{ n = '18080'; p = 18080 },
            @{ n = '18081'; p = 18081 },
            @{ n = '18083'; p = 18083 }
        )) {
        if (Test-TcpListen $pair.p) { $altBusy.Add($pair.n) }
    }
    if ($altBusy.Count -gt 0) {
        Write-Host ("FATAL: alternate tunnel ports also in use: {0}. Stop those listeners or use -SkipTunnel after a manual ssh -L." -f ($altBusy -join ',')) -ForegroundColor Red
        exit 1
    }
}
$script:apiBase = "http://127.0.0.1:$localApi"
$script:webBase = "http://127.0.0.1:$localWeb"
$script:llmHealth = "http://127.0.0.1:$localLlm/health"
$script:embedHealth = "http://127.0.0.1:$localEmbed/health"
$script:visionHealth = "http://127.0.0.1:$localVision/health"
$script:webHealth = "http://127.0.0.1:$localWeb/nginx-health"
$script:apiLive = "http://127.0.0.1:$localApi/health/live"

function Write-Step([string]$Msg) {
    Write-Host ""
    Write-Host "━━━ $Msg ━━━" -ForegroundColor Cyan
}

function Test-HttpOk {
    param([string]$Url, [int]$TimeoutSec = 10)
    try {
        $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec
        return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 300)
    } catch {
        $msg = $_.Exception.Message
        if ($_.Exception.InnerException) { $msg = $_.Exception.InnerException.Message }
        Write-Host ("    {0}" -f $msg) -ForegroundColor DarkYellow
        return $false
    }
}

function Invoke-Json {
    param(
        [string]$Method,
        [string]$Url,
        [object]$BodyObj = $null,
        [string]$Token = '',
        [int]$TimeoutSec = 60
    )
    $headers = @{ Accept = 'application/json' }
    if ($Token) { $headers['Authorization'] = "Bearer $Token" }
    $params = @{
        Uri             = $Url
        Method          = $Method
        Headers         = $headers
        UseBasicParsing = $true
        TimeoutSec      = $TimeoutSec
    }
    $json = $null
    if ($null -ne $BodyObj) {
        $json = $BodyObj | ConvertTo-Json -Compress -Depth 6
        $params.Body = $json
        $params.ContentType = 'application/json; charset=utf-8'
    }
    try {
        $resp = Invoke-WebRequest @params
        $parsed = $null
        if ($resp.Content) {
            try { $parsed = $resp.Content | ConvertFrom-Json } catch { $parsed = $resp.Content }
        }
        return @{ StatusCode = [int]$resp.StatusCode; Json = $parsed; Raw = $resp.Content }
    } catch {
        $raw = ''
        $code = 0
        $ex = $_.Exception
        if ($ex.Response) {
            try { $code = [int]$ex.Response.StatusCode } catch { }
            try {
                $rs = $ex.Response.GetResponseStream()
                if ($rs) {
                    $reader = New-Object System.IO.StreamReader($rs)
                    $raw = $reader.ReadToEnd()
                }
            } catch { }
        }
        $decoded = $raw
        if ($raw) {
            try {
                $errObj = $raw | ConvertFrom-Json
                $errText = [string]$errObj.error
                $trace = [string]$errObj.traceId
                if ($errText) { $decoded = ("error={0} traceId={1}" -f $errText, $trace) }
            } catch { }
        }
        throw ("HTTP {0} {1} {2}" -f $code, $Url, $decoded)
    }
}

function Save-Summary {
    param([int]$Code)
    $summary = [ordered]@{
        profile    = $Profile
        startedAt  = $startedAt
        finishedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        ssh        = [ordered]@{
            host = $SshHost; port = $SshPort; user = $SshUser; skipTunnel = [bool]$SkipTunnel
            local = [ordered]@{ web = $localWeb; api = $localApi; llm = $localLlm; embed = $localEmbed; vision = $localVision }
        }
        outDir     = $outDir
        layers     = $layers
        alerts     = @($alerts)
        exitCode   = $Code
        note       = 'gpu-quick 不能对外写 GPU 全量通过。指标退化只在 alerts。exit 1 当且仅当 Gate1 或 L2 或 L3 或（full 的 Eval 未 completed）或（full 缺识图/识图失败）。'
    }
    $path = Join-Path $outDir 'five-layer-summary.json'
    ($summary | ConvertTo-Json -Depth 8) | Out-File -FilePath $path -Encoding UTF8
    Write-Host ""
    Write-Host "===== five-layer summary ($Profile) =====" -ForegroundColor Green
    foreach ($k in $layers.Keys) {
        $st = $layers[$k].status
        $color = 'Gray'
        if ($st -eq 'PASS') { $color = 'Green' }
        elseif ($st -eq 'FAIL') { $color = 'Red' }
        elseif ($st -eq 'SKIP') { $color = 'Yellow' }
        Write-Host ("  {0,-12} {1,-6} {2}" -f $k, $st, $layers[$k].detail) -ForegroundColor $color
    }
    Write-Host "  out: $path"
}

function Stop-TunnelIfOurs {
    if ($SkipTunnel) { return }
    if ($null -eq $script:sshProc) { return }
    try {
        if (-not $script:sshProc.HasExited) {
            Write-Host "[tunnel] stopping ssh pid=$($script:sshProc.Id)"
            Stop-Process -Id $script:sshProc.Id -Force -ErrorAction SilentlyContinue
        }
    } catch { }
}

function Get-AdminToken {
    $urls = @(
        "$script:apiBase/api/Auth/login",
        "$script:webBase/api/Auth/login"
    )
    $last = ''
    foreach ($url in $urls) {
        try {
            $login = Invoke-Json -Method POST -Url $url -BodyObj @{ username = 'admin'; password = $adminPwd } -TimeoutSec 30
            $t = [string]$login.Json.token
            if (-not $t) { $t = [string]$login.Json.Token }
            if ($t) {
                Write-Host ("  login OK via {0}" -f $url)
                return $t
            }
            $last = ("{0} HTTP {1} no token body={2}" -f $url, $login.StatusCode, $login.Raw)
        } catch {
            $last = "$_"
            Write-Host ("  login fail {0}" -f $last) -ForegroundColor Yellow
        }
    }
    throw $last
}

function Install-WebNpmIfMissing {
    $web = Join-Path $RepoRoot 'agent1-web'
    $pw = Join-Path $web 'node_modules\@playwright\test\package.json'
    $vt = Join-Path $web 'node_modules\vitest\package.json'
    if ((Test-Path -LiteralPath $pw) -and (Test-Path -LiteralPath $vt)) { return }
    Write-Host '  npm install in agent1-web (vitest / @playwright/test missing on this PC)...'
    Push-Location $web
    try {
        & npm install
        if ($LASTEXITCODE -ne 0) { throw "npm install exit=$LASTEXITCODE" }
    } finally {
        Pop-Location
    }
}

try {

if (-not $SkipTunnel -and $SshPort -le 0) {
    Write-Host "FATAL: -SshPort is required unless -SkipTunnel" -ForegroundColor Red
    $layers.gate1.status = 'FAIL'
    $layers.gate1.detail = 'missing SshPort'
    Save-Summary 1
    exit 1
}

# ── 1. SSH 多端口隧道 ──
if ($SkipTunnel) {
    Write-Step ("Tunnel SKIP (-SkipTunnel); expecting {0} {1} {2} {3} {4}" -f $script:webHealth, $script:apiLive, $script:llmHealth, $script:embedHealth, $script:visionHealth)
} else {
    Write-Step ("SSH tunnel local {0}/{1}/{2}/{3}/{4} -> Featurize 8088/5000/8080/8081/8083" -f $localWeb, $localApi, $localLlm, $localEmbed, $localVision)
    $sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
    if (-not $sshCmd) {
        $layers.gate1.status = 'FAIL'
        $layers.gate1.detail = 'OpenSSH ssh not in PATH'
        Save-Summary 1
        exit 1
    }
    Write-Host "SSH opens in a NEW window. Enter the Featurize password there (this window waits for the tunnel)."
    $sshArgs = @(
        '-N',
        '-p', "$SshPort",
        '-o', 'ServerAliveInterval=30',
        '-o', 'ServerAliveCountMax=10',
        '-o', 'StrictHostKeyChecking=accept-new',
        '-o', 'ExitOnForwardFailure=yes',
        '-L', "127.0.0.1:${localWeb}:127.0.0.1:8088",
        '-L', "127.0.0.1:${localApi}:127.0.0.1:5000",
        '-L', "127.0.0.1:${localLlm}:127.0.0.1:8080",
        '-L', "127.0.0.1:${localEmbed}:127.0.0.1:8081",
        '-L', "127.0.0.1:${localVision}:127.0.0.1:8083",
        "${SshUser}@${SshHost}"
    )
    $script:sshProc = Start-Process -FilePath $sshCmd.Source -ArgumentList $sshArgs -PassThru
    $ok = $false
    $listenOk = $false
    Write-Host ("[tunnel] waiting up to 90s for 127.0.0.1:{0} to listen (password goes in the SSH window)..." -f $localWeb)
    for ($i = 0; $i -lt 90; $i++) {
        Start-Sleep -Seconds 1
        if ($script:sshProc.HasExited) {
            $layers.gate1.status = 'FAIL'
            $layers.gate1.detail = "ssh exited early code=$($script:sshProc.ExitCode) (wrong password, or instance/SSH port gone)"
            Save-Summary 1
            exit 1
        }
        if (Test-TcpListen $localWeb) {
            $listenOk = $true
            break
        }
    }
    if (-not $listenOk) {
        $layers.gate1.status = 'FAIL'
        $layers.gate1.detail = ("local {0} never listened; SSH window still waiting for password or bind failed" -f $localWeb)
        Save-Summary 1
        Stop-TunnelIfOurs
        exit 1
    }
    for ($i = 0; $i -lt 20; $i++) {
        if (Test-HttpOk $script:webHealth 3) {
            $ok = $true
            break
        }
        Start-Sleep -Seconds 1
    }
    if (-not $ok) {
        $layers.gate1.status = 'FAIL'
        $layers.gate1.detail = 'nginx-health not up within 20s'
        Save-Summary 1
        Stop-TunnelIfOurs
        exit 1
    }
    Write-Host "[tunnel] nginx-health OK"
}

# ── 2. Gate1 ──
Write-Step "Gate1 health (fail = stop)"
$health = @(
    @{ name = 'llama-server'; url = $script:llmHealth },
    @{ name = 'llama-embed'; url = $script:embedHealth },
    @{ name = 'llama-vision'; url = $script:visionHealth },
    @{ name = 'api'; url = $script:apiLive },
    @{ name = 'web'; url = $script:webHealth }
)
$healthFail = New-Object System.Collections.Generic.List[string]
foreach ($h in $health) {
    $tries = 1
    if ($h.name -eq 'api') { $tries = 12 }
    $pass = $false
    for ($i = 0; $i -lt $tries; $i++) {
        if (Test-HttpOk $h.url 15) {
            $pass = $true
            break
        }
        if ($i -lt ($tries - 1)) {
            Write-Host ("  wait api health/live ({0}/{1})..." -f ($i + 1), $tries) -ForegroundColor DarkYellow
            Start-Sleep -Seconds 5
        }
    }
    if ($pass) {
        Write-Host ("  PASS {0} {1}" -f $h.name, $h.url) -ForegroundColor Green
    } else {
        Write-Host ("  FAIL {0} {1}" -f $h.name, $h.url) -ForegroundColor Red
        $healthFail.Add($h.name)
    }
}
if ($healthFail.Count -gt 0) {
    $layers.gate1.status = 'FAIL'
    $layers.gate1.detail = 'down: ' + ($healthFail -join ',')
    if ($healthFail -contains 'llama-vision') {
        Write-Host "llama-vision :8083 failed. On Featurize run:" -ForegroundColor Yellow
        Write-Host "  cd /opt/agent1/容器化部署/gpu"
        Write-Host "  sudo docker compose ps llama-vision"
        Write-Host "  sudo docker compose logs --tail 80 llama-vision"
        Write-Host "  curl -sf http://127.0.0.1:8083/health && echo VISION_OK"
    }
    Save-Summary 1
    Stop-TunnelIfOurs
    exit 1
}
$layers.gate1.status = 'PASS'
$layers.gate1.detail = ("local {0}/{1}/{2}/{3}/{4} -> remote 8088/5000/8080/8081/8083" -f $localWeb, $localApi, $localLlm, $localEmbed, $localVision)

# ── 3. L0/L1 白盒（不阻断 L2）──
if ($SkipWhitebox) {
    Write-Step "L0/L1 SKIP (-SkipWhitebox)"
    $layers.l0_l1.status = 'SKIP'
    $layers.l0_l1.detail = 'SkipWhitebox'
} else {
    Write-Step 'L0/L1 whitebox - local FAIL does not block L2'
    $wb = New-Object System.Collections.Generic.List[string]
    Write-Host "  ArchitectureTest..."
    & dotnet test (Join-Path $RepoRoot 'ArchitectureTest\ArchitectureTest.csproj') --nologo
    if ($LASTEXITCODE -ne 0) { $wb.Add("ArchitectureTest exit=$LASTEXITCODE") }

    Write-Host "  Agent1.Tests (exclude Integration/ApiIntegration)..."
    & dotnet test (Join-Path $RepoRoot 'Agent1.Tests\Agent1.Tests.csproj') --nologo --filter 'Category!=Integration&Category!=ApiIntegration'
    if ($LASTEXITCODE -ne 0) { $wb.Add("Agent1.Tests exit=$LASTEXITCODE") }

    Write-Host "  agent1-web vitest..."
    Push-Location (Join-Path $RepoRoot 'agent1-web')
    try {
        Install-WebNpmIfMissing
        & npm test -- --run
        if ($LASTEXITCODE -ne 0) { $wb.Add("vitest exit=$LASTEXITCODE") }
    } catch {
        $wb.Add("vitest: $_")
    } finally {
        Pop-Location
    }

    if ($wb.Count -gt 0) {
        $layers.l0_l1.status = 'FAIL'
        $layers.l0_l1.detail = $wb -join '; '
        Write-Host "  whitebox FAIL recorded; continuing L2 (orthogonal to GPU)" -ForegroundColor Yellow
    } else {
        $layers.l0_l1.status = 'PASS'
        $layers.l0_l1.detail = 'ArchitectureTest + unit + vitest'
    }
}

# ── 4. L2 HTTP 安全距离（避开关键词快路径）──
# /api/Compliance/check 走 ExecuteEvalFastAsync：PlanToolsByKeywords 命中就会跳过 llama FC。
# 「甲醇/硝酸/安全距离/苯」都是 KeywordTriggers，0.6s + GetSafetyDistance 仍不是 GPU 证据。
# 工具真名是 GetSafetyDistance（手册曾误写成 CheckSafetyDistance）。
Write-Step "L2 HTTP safety-distance (not benzene, not keyword fast-path)"
$apiBase = $script:apiBase
$token = ''
try {
    $token = Get-AdminToken
    Write-Host "  login OK"
} catch {
    $layers.l2.status = 'FAIL'
    $layers.l2.detail = "login: $_"
    $hardFail = $true
}

if ($layers.l2.status -ne 'FAIL') {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $l2Query = '甲类仓库与明火点最少隔开多少米 编号' + (Get-Date -Format 'yyyyMMddHHmmss')
        Write-Host ("  query: {0}" -f $l2Query)
        $check = Invoke-Json -Method POST -Url "$apiBase/api/Compliance/check" -Token $token -TimeoutSec 180 -BodyObj @{
            query = $l2Query
        }
        $sw.Stop()
        $elapsed = $sw.Elapsed.TotalSeconds
        $layers.l2.elapsedSec = [Math]::Round($elapsed, 2)
        $tools = @()
        if ($check.Json.toolsUsed) { $tools = @($check.Json.toolsUsed) }
        elseif ($check.Json.ToolsUsed) { $tools = @($check.Json.ToolsUsed) }
        $layers.l2.toolsUsed = $tools
        $toolJoin = ($tools | ForEach-Object { "$_" }) -join ','
        $reason = New-Object System.Collections.Generic.List[string]
        if ($elapsed -lt 3) { $reason.Add(('elapsed={0:N2}s less than 3s fast-path/cache' -f $elapsed)) }
        $hasDistanceTool = ($toolJoin -match 'GetSafetyDistance') -or ($toolJoin -match 'CheckSafetyDistance')
        if (-not $hasDistanceTool) {
            $reason.Add("toolsUsed=[$toolJoin] missing GetSafetyDistance")
        }
        if ($check.StatusCode -lt 200 -or $check.StatusCode -ge 300) {
            $reason.Add("HTTP $($check.StatusCode)")
        }
        if ($reason.Count -gt 0) {
            $layers.l2.status = 'FAIL'
            $layers.l2.detail = $reason -join '; '
            $hardFail = $true
        } else {
            $layers.l2.status = 'PASS'
            $layers.l2.detail = ("{0:N1}s tools=[{1}]" -f $elapsed, $toolJoin)
        }
        Write-Host ("  L2 {0}: {1}" -f $layers.l2.status, $layers.l2.detail)
    } catch {
        $sw.Stop()
        $layers.l2.status = 'FAIL'
        $layers.l2.detail = $_
        $layers.l2.elapsedSec = [Math]::Round($sw.Elapsed.TotalSeconds, 2)
        $hardFail = $true
    }
}

# ── 5. L3 Playwright（无 pretest / 无 benzene）──
$loginFailed = ($layers.l2.status -eq 'FAIL' -and [string]$layers.l2.detail -like 'login:*')
if ($loginFailed) {
    Write-Step "L3 Playwright SKIP (login failed; same 500 as L2 — do not wait 20 min)"
    $layers.l3.status = 'SKIP'
    $layers.l3.detail = 'skipped because /api/Auth/login failed'
    Write-Host ""
    Write-Host "  HTTP 500 here is NOT a wrong password (that would be 401)." -ForegroundColor Yellow
    Write-Host "  Production AuthController throws if AUTH_ACCOUNTS_JSON is empty/invalid." -ForegroundColor Yellow
    Write-Host "  Keep the tunnel SSH window open. In a SECOND SSH session:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host ("    ssh -p {0} {1}@{2}" -f $SshPort, $SshUser, $SshHost)
    Write-Host ("    cd {0}" -f $RemoteComposeDir)
    Write-Host "    sudo docker compose exec -T api printenv AUTH_ACCOUNTS_JSON"
    Write-Host "    sudo docker compose logs api --since 2h | grep -E '未处理异常|AUTH_ACCOUNTS|生产环境必须|已加载'"
    Write-Host ""
    Write-Host "  If AUTH is empty or [], quote it in .env / compose then:" -ForegroundColor Yellow
    Write-Host "    sudo docker compose up -d --force-recreate --no-deps api"
    Write-Host "  Do not docker compose down -v, do not rebuild-llama."
} else {
    Write-Step ("L3 Playwright e2e-real via Nginx :{0}" -f $localWeb)
    $env:PLAYWRIGHT_BASE_URL = $script:webBase.Replace('127.0.0.1', 'localhost')
    $env:VITE_PROXY_TARGET = $script:apiBase.Replace('127.0.0.1', 'localhost')
    $env:E2E_ADMIN_PASSWORD = $adminPwd
    if (-not $env:E2E_AUDITOR_PASSWORD) { $env:E2E_AUDITOR_PASSWORD = $adminPwd }
    if (-not $env:E2E_VIEWER_PASSWORD) { $env:E2E_VIEWER_PASSWORD = $adminPwd }

    if ($Profile -eq 'gpu-quick') {
        $layers.l3.detail = 'grep-invert llm-quality; no pretest'
    } else {
        $layers.l3.detail = 'all 9 specs; no pretest'
    }

    Push-Location (Join-Path $RepoRoot 'agent1-web')
    $pwExit = 1
    try {
        Install-WebNpmIfMissing
        $npmExtra = @()
        if ($Profile -eq 'gpu-quick') { $npmExtra = @('--', '--grep-invert', 'llm-quality') }
        Write-Host ("  npm run test:e2e:real:docker {0}" -f ($npmExtra -join ' '))
        & npm run test:e2e:real:docker @npmExtra
        $pwExit = $LASTEXITCODE
    } catch {
        Write-Host ("  playwright: $_") -ForegroundColor Red
        $pwExit = 1
    } finally {
        Pop-Location
    }
    if ($pwExit -eq 0) {
        $layers.l3.status = 'PASS'
    } else {
        $layers.l3.status = 'FAIL'
        $layers.l3.detail = ($layers.l3.detail + "; npx exit=$pwExit")
        $hardFail = $true
    }
}

# ── 6. L4 gpu-full only ──
if ($Profile -ne 'gpu-full') {
    Write-Step "L4 Eval/Vision/Analyze SKIP (profile=gpu-quick)"
} else {
    Write-Step "L4 Eval/run (poll up to 1800s)"
    $evalOk = $false
    $evalJsonPath = Join-Path $outDir 'eval.json'
    try {
        $token = Get-AdminToken
        if (-not $token) { throw 'no JWT' }
        $run = Invoke-Json -Method POST -Url "$apiBase/api/Eval/run" -Token $token -TimeoutSec 30
        $taskId = [string]$run.Json.taskId
        if (-not $taskId) { $taskId = [string]$run.Json.TaskId }
        if (-not $taskId) { throw "Eval/run HTTP $($run.StatusCode) body=$($run.Raw)" }
        Write-Host "  taskId=$taskId"
        $deadline = (Get-Date).AddSeconds(1800)
        $statusName = 'queued'
        $statusObj = $null
        while ((Get-Date) -lt $deadline) {
            Start-Sleep -Seconds 15
            $st = Invoke-Json -Method GET -Url "$apiBase/api/Eval/status/$taskId" -Token $token -TimeoutSec 30
            $statusObj = $st.Json
            $statusName = [string]$statusObj.status
            if (-not $statusName) { $statusName = [string]$statusObj.Status }
            Write-Host ("  status={0}" -f $statusName)
            if ($statusName -eq 'completed' -or $statusName -eq 'failed') { break }
        }
        if ($statusName -ne 'completed') {
            $layers.l4_eval.status = 'FAIL'
            $layers.l4_eval.detail = "status=$statusName"
            $hardFail = $true
        } else {
            $report = $statusObj.report
            if (-not $report) { $report = $statusObj.Report }
            if ($null -eq $report) { throw 'completed but no report' }
            ($report | ConvertTo-Json -Depth 20) | Out-File -FilePath $evalJsonPath -Encoding UTF8
            $layers.l4_eval.status = 'PASS'
            $layers.l4_eval.detail = ('completed {0}' -f $evalJsonPath)
            $evalOk = $true
        }
    } catch {
        $layers.l4_eval.status = 'FAIL'
        $layers.l4_eval.detail = "$_"
        $hardFail = $true
    }

    Write-Step "L4 Vision POST /api/Multimodal/analyze"
    if (-not $VisionImage -or -not (Test-Path -LiteralPath $VisionImage)) {
        $layers.l4_vision.status = 'FAIL'
        $layers.l4_vision.detail = 'missing -VisionImage (gpu-full requires a jpg/png/webp)'
        $hardFail = $true
    } else {
        $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
        if (-not $curl) {
            $layers.l4_vision.status = 'FAIL'
            $layers.l4_vision.detail = 'curl.exe not found (needed for multipart)'
            $hardFail = $true
        } else {
            $bodyFile = Join-Path $outDir 'vision-body.json'
            $swv = [System.Diagnostics.Stopwatch]::StartNew()
            $httpCode = & curl.exe -sS -o $bodyFile -w '%{http_code}' -X POST `
                -H "Authorization: Bearer $token" `
                -F "image=@`"$VisionImage`"" `
                -F 'analysisType=hazard-label' `
                "$script:apiBase/api/Multimodal/analyze"
            $swv.Stop()
            $vsec = $swv.Elapsed.TotalSeconds
            $codeNum = 0
            try { $codeNum = [int]("$httpCode".Trim()) } catch { $codeNum = 0 }
            if ($codeNum -eq 200 -and $vsec -ge 3) {
                $layers.l4_vision.status = 'PASS'
                $layers.l4_vision.detail = ("HTTP {0} {1:N1}s" -f $codeNum, $vsec)
            } else {
                $layers.l4_vision.status = 'FAIL'
                $layers.l4_vision.detail = ("HTTP {0} {1:N1}s (need 200 and >=3s)" -f $httpCode, $vsec)
                $hardFail = $true
            }
        }
    }

    Write-Step "L4 D1-D6 analyze (docker logs, not AutoDL)"
    if ($evalOk -and (Test-Path -LiteralPath $evalJsonPath)) {
        $latestEval = Join-Path $RepoRoot 'eval_reports\latest\eval.json'
        $analyzeArgs = @{
            EvalJson          = $evalJsonPath
            OutDir            = $outDir
            SshHost           = $SshHost
            SshUser           = $SshUser
            SshPort           = $SshPort
            RemoteComposeDir  = $RemoteComposeDir
        }
        if (Test-Path -LiteralPath $latestEval) { $analyzeArgs.LatestEvalJson = $latestEval }
        if ($SkipRemoteLogs) { $analyzeArgs.SkipRemoteLogs = $true }
        & (Join-Path $PSScriptRoot 'gpu-eval-analyze.ps1') @analyzeArgs
        if ($LASTEXITCODE -eq 0) {
            $layers.l4_analyze.status = 'PASS'
            $layers.l4_analyze.detail = 'comparison.json + analysis.md'
        } else {
            $layers.l4_analyze.status = 'FAIL'
            $layers.l4_analyze.detail = "gpu-eval-analyze exit=$LASTEXITCODE"
            # analyze 失败不单独作为 hardFail（计划: exit 1 不含 analyze）
        }
        $alertFile = Join-Path $outDir 'alerts.json'
        if (Test-Path -LiteralPath $alertFile) {
            try {
                $aj = Get-Content -LiteralPath $alertFile -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($a in @($aj)) {
                    if ($a) { $alerts.Add([string]$a) }
                }
            } catch { }
        }
        $latestDir = Join-Path $RepoRoot 'eval_reports\latest'
        New-Item -ItemType Directory -Force -Path $latestDir | Out-Null
        Copy-Item -LiteralPath $evalJsonPath -Destination (Join-Path $latestDir 'eval.json') -Force
    } else {
        $layers.l4_analyze.status = 'FAIL'
        $layers.l4_analyze.detail = 'no eval.json'
    }
}

# 白盒 FAIL 记入 summary，不改变 GPU hardFail（与 GPU 正交）
$exitCode = 0
if ($hardFail) { $exitCode = 1 }
# Gate1 already exited 1
Save-Summary $exitCode
exit $exitCode

} finally {
    Stop-TunnelIfOurs
}
