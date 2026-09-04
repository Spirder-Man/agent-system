param(
    [string]$Server = "company-pc",
    [string]$RemoteDir = "D:/桌面/agent/开源大赛提交"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$md = Join-Path $ProjectRoot "docs\project\os2026-作品介绍.md"
$pdf = Join-Path $ProjectRoot "docs\project\os2026-作品介绍.pdf"

if (-not (Test-Path -LiteralPath $md)) { throw "md not found: $md" }
if (-not (Test-Path -LiteralPath $pdf)) { throw "pdf not found: $pdf" }

$winDir = $RemoteDir -replace "/", "\"
Write-Host "Target ${Server}:$winDir"

ssh -o BatchMode=yes -o ConnectTimeout=8 $Server ("cmd /c mkdir `"" + $winDir + "`"")
if ($LASTEXITCODE -ne 0) {
    throw "Remote mkdir failed. Check: ssh company-pc"
}

$dest = $Server + ":" + $RemoteDir + "/"
& scp $md $pdf $dest
if ($LASTEXITCODE -ne 0) { throw "scp failed" }

Write-Host "Uploaded:"
Write-Host "  $md"
Write-Host "  $pdf"
