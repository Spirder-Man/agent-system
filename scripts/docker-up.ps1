#Requires -Version 5.1
# Agent1 one-click deploy (API + Web + postgres + llama). Windows PowerShell.
# Usage from agent-system:
#   powershell -ExecutionPolicy Bypass -File scripts/docker-up.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/docker-up.ps1 gpu
#   powershell -ExecutionPolicy Bypass -File scripts/docker-up.ps1 cpu

$ErrorActionPreference = "Continue"

$ProjectDir = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectDir

$Mode = "gpu"
if ($args.Count -ge 1 -and $args[0]) {
    $Mode = ([string]$args[0]).ToLowerInvariant()
}
if ($Mode -ne "gpu" -and $Mode -ne "cpu") {
    Write-Host "Unknown mode: $Mode"
    Write-Host "Usage: powershell -ExecutionPolicy Bypass -File scripts/docker-up.ps1 [gpu|cpu]"
    exit 1
}

$ComposeFiles = @("-f", "docker-compose.yml")
if ($Mode -eq "cpu") {
    $ComposeFiles += @("-f", "docker-compose.cpu.yml")
}

function Invoke-Compose {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ComposeArgs)
    & docker compose @ComposeFiles @ComposeArgs
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose failed: $($ComposeArgs -join ' ')"
    }
}

function Import-DotEnv {
    param([string]$Path)
    Get-Content -LiteralPath $Path -Encoding UTF8 | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }
        $idx = $line.IndexOf("=")
        if ($idx -lt 1) { return }
        $key = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()
        if ($value.Length -ge 2) {
            $q = $value[0]
            if (($q -eq [char]34 -or $q -eq [char]39) -and $value[-1] -eq $q) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }
        Set-Item -Path ("Env:" + $key) -Value $value
    }
}

function Test-HttpOk {
    param([string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
        return ($resp.StatusCode -eq 200)
    } catch {
        return $false
    }
}

$VisionVramThresholdMib = 20000

function Test-VisionOcrExplicit {
    $raw = $env:ENABLE_VISION_OCR
    if ([string]::IsNullOrWhiteSpace($raw)) { return $false }
    return $raw -match '^(?i)(true|false)$'
}

function Get-MaxGpuMemoryMib {
    $raw = & nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>$null
    $max = 0
    foreach ($line in @($raw)) {
        $n = 0
        if ([int]::TryParse((("$line").Trim()), [ref]$n) -and $n -gt $max) { $max = $n }
    }
    return $max
}

function Resolve-StartVision {
    if (Test-VisionOcrExplicit) {
        $on = [System.Convert]::ToBoolean($env:ENABLE_VISION_OCR.ToLowerInvariant())
        Write-Host ("   ENABLE_VISION_OCR={0} (from .env, skip auto-detect)" -f $env:ENABLE_VISION_OCR)
        return $on
    }
    $maxVram = Get-MaxGpuMemoryMib
    if ($maxVram -ge $VisionVramThresholdMib) {
        $env:ENABLE_VISION_OCR = "true"
        Write-Host ("   GPU VRAM {0} MiB >= {1} -> ENABLE_VISION_OCR=true, start llama-vision" -f $maxVram, $VisionVramThresholdMib)
        return $true
    }
    $env:ENABLE_VISION_OCR = "false"
    Write-Host ("   GPU VRAM {0} MiB < {1} -> skip llama-vision, ENABLE_VISION_OCR=false" -f $maxVram, $VisionVramThresholdMib)
    Write-Host "   8B+VL same card needs ~24GB. To force: set ENABLE_VISION_OCR=true in .env and re-run docker-up."
    return $false
}

Write-Host "========================================"
Write-Host ("  Agent1 deploy (backend + frontend / {0})" -f $Mode)
Write-Host ("  {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Write-Host "========================================"

if (-not (Test-Path -LiteralPath ".env")) {
    Write-Host ""
    Write-Host "No .env found, copying from .env.example ..."
    Copy-Item -LiteralPath ".env.example" -Destination ".env"
    Write-Host ".env created. Fill DB_PASSWORD and JWT_KEY, then re-run."
    exit 1
}

Write-Host ""
Write-Host "Loading .env ..."
Import-DotEnv ".env"

Write-Host "Checking Docker ..."
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker is not running. Start Docker Desktop first."
    exit 1
}
Write-Host "   Docker OK"

if (-not $env:WEB_PORT -and $env:OS -eq "Windows_NT") {
    $env:WEB_PORT = "8088"
    Write-Host "   Windows: WEB_PORT defaulting to 8088 (port 80 is often blocked)"
}

$startVision = $false
if ($Mode -eq "gpu") {
    $nvidia = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($nvidia) {
        $gpuLines = & nvidia-smi --query-gpu=name --format=csv,noheader 2>$null
        $gpuCount = @($gpuLines | Where-Object { $_ -and $_.Trim() }).Count
        if ($gpuCount -gt 0) {
            Write-Host ("   GPU: {0} device(s) -> llama-server -ngl 99" -f $gpuCount)
            Write-Host "   Embedding stays CPU (-ngl 0). 8B+VL on one GPU wants ~24GB VRAM (3090)."
        } else {
            Write-Host "   No GPU detected. Use: powershell -File scripts/docker-up.ps1 cpu"
        }
    } else {
        Write-Host "   nvidia-smi not found. On Windows use cpu mode."
    }
    $startVision = Resolve-StartVision
} else {
    Write-Host "   Mode: CPU (no CUDA / no GPU reservation / vision not started)"
    $env:ENABLE_VISION_OCR = "false"
}

Write-Host ""
Write-Host "Checking GGUF models ..."
$modelRoot = $ProjectDir + "\models"
if ($env:MODELS_PATH) { $modelRoot = $env:MODELS_PATH }
$llmModel = Join-Path $modelRoot "Qwen_Qwen3-8B-Q4_K_M.gguf"
$embModel = Join-Path $modelRoot "nomic-embed-text-v1.5.f16.gguf"
$vlModel = Join-Path $modelRoot "Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"
$mmproj = Join-Path $modelRoot "mmproj-Qwen2.5-VL-7B-Instruct-f16.gguf"
if (-not (Test-Path -LiteralPath $llmModel) -or -not (Test-Path -LiteralPath $embModel)) {
    Write-Host ("   Missing GGUF under {0}" -f $modelRoot)
    Write-Host "   Need Qwen_Qwen3-8B-Q4_K_M.gguf and nomic-embed-text-v1.5.f16.gguf"
    Write-Host "   Set MODELS_PATH in .env, or put files in ./models"
    Write-Host "   postgres / api / web will still start."
} else {
    Write-Host ("   GGUF files found in {0}" -f $modelRoot)
}
if ($Mode -eq "gpu") {
    if (-not (Test-Path -LiteralPath $vlModel) -or -not (Test-Path -LiteralPath $mmproj)) {
        Write-Host "   Missing VL GGUF (Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf + mmproj-Qwen2.5-VL-7B-Instruct-f16.gguf)"
        if ($startVision) {
            Write-Host "   llama-vision will not be healthy; OCR / 识图 unavailable."
        } else {
            Write-Host "   VL files optional while vision is skipped."
        }
    } else {
        Write-Host "   VL + mmproj found (8083)"
    }
}

Write-Host ""
Write-Host "Checking knowledge base ..."
$kbRoot = Join-Path $ProjectDir "knowledgebase"
if ($env:KNOWLEDGE_BASE_PATH) { $kbRoot = $env:KNOWLEDGE_BASE_PATH }
Write-Host ("   Host KNOWLEDGE_BASE_PATH: {0}" -f $kbRoot)
if (-not (Test-Path -LiteralPath $kbRoot)) {
    Write-Host "   Directory missing. API will start with knowledge_base_docs=0."
} else {
    Write-Host "   Directory exists (container path remains /app/knowledgebase)"
}

Write-Host ""
Write-Host "Pulling PostgreSQL image ..."
& docker compose @ComposeFiles pull postgres | Out-Null

if ($Mode -eq "cpu") {
    Write-Host "Building llama.cpp CPU image (first run takes several minutes) ..."
    Invoke-Compose build llama-server llama-embed
} elseif ($startVision) {
    Write-Host "Building llama.cpp CUDA image (first run ~10 min, ~8G) ..."
    Invoke-Compose build llama-server llama-embed llama-vision
} else {
    Write-Host "Building llama.cpp CUDA image (first run ~10 min, ~8G; vision skipped) ..."
    Invoke-Compose build llama-server llama-embed
}

Write-Host "Building API image ..."
Invoke-Compose build api

Write-Host "Building Web image ..."
Invoke-Compose build web

Write-Host ""
if ($Mode -eq "gpu") {
    if ($startVision) {
        Write-Host "Starting postgres / llama-server / llama-embed / llama-vision / api / web ..."
        # Named llama-vision starts even with profiles: [vision]; do not drop the service name.
        Invoke-Compose up -d postgres llama-server llama-embed llama-vision api web
    } else {
        Write-Host "Removing leftover llama-vision (stop + rm -f; unless-stopped would return after Docker restart) ..."
        & docker compose @ComposeFiles stop llama-vision 2>$null | Out-Null
        & docker compose @ComposeFiles rm -f llama-vision 2>$null | Out-Null
        Write-Host "Starting postgres / llama-server / llama-embed / api / web (no vision) ..."
        Invoke-Compose up -d postgres llama-server llama-embed api web
    }
} else {
    Write-Host "Removing leftover llama-vision if present ..."
    & docker compose @ComposeFiles stop llama-vision 2>$null | Out-Null
    & docker compose @ComposeFiles rm -f llama-vision 2>$null | Out-Null
    Write-Host "Starting postgres / llama-server / llama-embed / api / web (no vision) ..."
    Invoke-Compose up -d postgres llama-server llama-embed api web
}

Write-Host ""
Write-Host "Waiting for services ..."
$dbUser = "postgres"
if ($env:DB_USERNAME) { $dbUser = $env:DB_USERNAME }
Write-Host "   PostgreSQL ..."
while ($true) {
    & docker compose @ComposeFiles exec -T postgres pg_isready -U $dbUser 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 2
}
Write-Host "   PostgreSQL OK"

Write-Host "   llama-server / llama-embed (model load) ..."

$apiPort = "5000"
if ($env:API_PORT) { $apiPort = $env:API_PORT }
Write-Host ("   API (http://localhost:{0}/health/live) ..." -f $apiPort)
$apiOk = $false
for ($i = 1; $i -le 30; $i++) {
    if (Test-HttpOk ("http://localhost:{0}/health/live" -f $apiPort)) {
        Write-Host "   API OK"
        $apiOk = $true
        break
    }
    Start-Sleep -Seconds 3
}
if (-not $apiOk) {
    Write-Host "   API not healthy yet. Check: docker compose logs api llama-server"
}

$webPort = "80"
if ($env:WEB_PORT) { $webPort = $env:WEB_PORT }
Write-Host ("   Web (http://localhost:{0}/nginx-health) ..." -f $webPort)
$webOk = $false
for ($i = 1; $i -le 20; $i++) {
    if (Test-HttpOk ("http://localhost:{0}/nginx-health" -f $webPort)) {
        Write-Host "   Web OK"
        $webOk = $true
        break
    }
    Start-Sleep -Seconds 2
}
if (-not $webOk) {
    Write-Host "   Web not healthy yet. Check: docker compose logs web"
}

$dbPort = "5432"
if ($env:DB_PORT) { $dbPort = $env:DB_PORT }
$llamaPort = "8080"
if ($env:LLAMA_PORT) { $llamaPort = $env:LLAMA_PORT }
$embedPort = "8081"
if ($env:LLAMA_EMBED_PORT) { $embedPort = $env:LLAMA_EMBED_PORT }
$visionPort = "8083"
if ($env:LLAMA_VISION_PORT) { $visionPort = $env:LLAMA_VISION_PORT }

$obsExtra = ""
if ($Mode -eq "cpu") { $obsExtra = "-f docker-compose.cpu.yml " }
$composeCli = ($ComposeFiles -join " ")

Write-Host ""
Write-Host "========================================"
Write-Host ("  Agent1 backend + frontend ready ({0})" -f $Mode)
Write-Host "========================================"
Write-Host ""
Write-Host "  URLs:"
Write-Host ("  Web:              http://localhost:{0}" -f $webPort)
Write-Host ("  API Swagger:      http://localhost:{0}/swagger" -f $apiPort)
Write-Host ("  API Health:       http://localhost:{0}/health" -f $apiPort)
Write-Host ("  PostgreSQL:       localhost:{0}" -f $dbPort)
Write-Host ("  llama.cpp LLM:    http://localhost:{0}" -f $llamaPort)
Write-Host ("  llama.cpp Embed:  http://localhost:{0}" -f $embedPort)
    if ($startVision) {
        Write-Host ("  llama.cpp Vision: http://localhost:{0}" -f $visionPort)
    } elseif ($Mode -eq "gpu") {
        Write-Host "  llama.cpp Vision: skipped (ENABLE_VISION_OCR=false)"
    }
Write-Host ""
Write-Host "  Optional observability:"
Write-Host ("  docker compose -f docker-compose.yml {0}-f docker-compose.obs.yml up -d" -f $obsExtra)
Write-Host ""
Write-Host "  Commands:"
Write-Host ("  docker compose {0} logs -f api" -f $composeCli)
Write-Host ("  docker compose {0} logs -f web" -f $composeCli)
Write-Host ("  docker compose {0} down" -f $composeCli)
Write-Host ""
Write-Host "  Status:"
& docker compose @ComposeFiles ps
