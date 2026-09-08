#Requires -Version 5.1
# Check (and optionally download) GGUF files for llama.cpp.
# Usage from agent-system/:
#   powershell -ExecutionPolicy Bypass -File scripts/download-models.ps1
# Optional: $env:AGENT1_MODEL_BASE_URL = "https://example.com/gguf"  (no trailing slash)
# Optional: $env:MODELS_PATH  or MODELS_PATH in .env

$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectDir

function Import-DotEnv {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
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
        if (-not [string]::IsNullOrWhiteSpace($env:MODELS_PATH) -and $key -eq "MODELS_PATH") { return }
        Set-Item -Path ("Env:" + $key) -Value $value
    }
}

Import-DotEnv (Join-Path $ProjectDir ".env")

$ModelsDir = $env:MODELS_PATH
if ([string]::IsNullOrWhiteSpace($ModelsDir)) {
    $ModelsDir = Join-Path $ProjectDir "models"
} elseif (-not [System.IO.Path]::IsPathRooted($ModelsDir)) {
    $ModelsDir = Join-Path $ProjectDir $ModelsDir
}

$SumsFile = Join-Path $ProjectDir "models\SHA256SUMS"
$BaseUrl = $env:AGENT1_MODEL_BASE_URL
if ($BaseUrl) { $BaseUrl = $BaseUrl.TrimEnd("/") }

$Required = @(
    @{ Name = "Qwen_Qwen3-8B-Q4_K_M.gguf"; MinBytes = 1GB; Required = $true },
    @{ Name = "nomic-embed-text-v1.5.f16.gguf"; MinBytes = 80MB; Required = $true },
    @{ Name = "Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"; MinBytes = 1GB; Required = $false },
    @{ Name = "mmproj-Qwen2.5-VL-7B-Instruct-f16.gguf"; MinBytes = 80MB; Required = $false }
)

function Get-ExpectedHash {
    param([string]$FileName)
    if (-not (Test-Path -LiteralPath $SumsFile)) { return "SKIP" }
    foreach ($raw in Get-Content -LiteralPath $SumsFile -Encoding UTF8) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith("#")) { continue }
        $parts = $line -split "\s+", 2
        if ($parts.Count -lt 2) { continue }
        if ($parts[1] -eq $FileName) { return $parts[0] }
    }
    return "SKIP"
}

New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null

Write-Host "========================================"
Write-Host "  Agent1 models check"
Write-Host ("  dir: {0}" -f $ModelsDir)
Write-Host "========================================"

$fail = $false
$warn = $false

foreach ($item in $Required) {
    $dest = Join-Path $ModelsDir $item.Name
    if (-not (Test-Path -LiteralPath $dest) -and $BaseUrl) {
        $url = "{0}/{1}" -f $BaseUrl, $item.Name
        Write-Host ("Downloading {0} ..." -f $item.Name)
        try {
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
        } catch {
            Write-Host ("Download failed: {0}" -f $url)
            Write-Host $_.Exception.Message
        }
    }

    if (-not (Test-Path -LiteralPath $dest)) {
        if ($item.Required) {
            Write-Host ("MISSING (required): {0}" -f $item.Name)
            $fail = $true
        } else {
            Write-Host ("missing (optional VL): {0}" -f $item.Name)
            $warn = $true
        }
        continue
    }

    $len = (Get-Item -LiteralPath $dest).Length
    if ($len -lt $item.MinBytes) {
        Write-Host ("TOO SMALL: {0} ({1} bytes, min {2})" -f $item.Name, $len, $item.MinBytes)
        if ($item.Required) { $fail = $true } else { $warn = $true }
        continue
    }

    $expect = Get-ExpectedHash $item.Name
    if ($expect -and $expect.ToUpperInvariant() -ne "SKIP") {
        $actual = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
        $expectNorm = $expect.ToLowerInvariant()
        if ($actual -ne $expectNorm) {
            Write-Host ("SHA256 mismatch: {0}" -f $item.Name)
            Write-Host ("  expected {0}" -f $expectNorm)
            Write-Host ("  actual   {0}" -f $actual)
            if ($item.Required) { $fail = $true } else { $warn = $true }
            continue
        }
    }

    Write-Host ("OK  {0}  ({1:N1} GB)" -f $item.Name, ($len / 1GB))
}

if ($fail -or $warn) {
    Write-Host ""
    Write-Host "Copy GGUF files into the models directory. Search keywords:"
    Write-Host "  Qwen3-8B Q4_K_M gguf"
    Write-Host "  nomic-embed-text-v1.5 f16 gguf"
    Write-Host "  Qwen2.5-VL-7B-Instruct Q4_K_M gguf"
    Write-Host "  mmproj Qwen2.5-VL-7B f16 gguf"
    Write-Host "See models/README.md. File names must match compose exactly."
    Write-Host "To download: set AGENT1_MODEL_BASE_URL to a directory URL that hosts those names."
}

if ($warn -and -not $fail) {
    Write-Host ""
    Write-Host "VL files missing: port 8083 OCR/vision will not work; LLM :8080 can still run."
}

if ($fail) { exit 1 }
Write-Host ""
Write-Host "Required GGUF files are present."
exit 0
