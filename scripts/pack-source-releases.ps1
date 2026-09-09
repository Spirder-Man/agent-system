#Requires -Version 5.1
# Pack three source-only release archives. Delegates to pack-source-releases.py
#   powershell -ExecutionPolicy Bypass -File scripts/pack-source-releases.ps1 [-Version v0.1.0]

param(
    [string]$Version = "v0.1.0"
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectDir

$py = Get-Command py -ErrorAction SilentlyContinue
if (-not $py) { throw "Python launcher 'py' not found. Install Python 3." }
& py -3 (Join-Path $PSScriptRoot "pack-source-releases.py") $Version
if ($LASTEXITCODE -ne 0) { throw "pack-source-releases.py failed" }
