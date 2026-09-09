#Requires -Version 5.1
# Pack three source-only release archives (cpu / gpu / docker). No GGUF.
# Usage (repo root):
#   powershell -ExecutionPolicy Bypass -File scripts/pack-source-releases.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/pack-source-releases.ps1 -Version v0.1.0

param(
    [string]$Version = "v0.1.0"
)

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectDir

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git not found"
}

$dirty = git status --porcelain
if ($dirty) {
    Write-Host "Warning: working tree is not clean. git archive uses HEAD, not uncommitted files."
}

$Dist = Join-Path $ProjectDir "dist"
New-Item -ItemType Directory -Force -Path $Dist | Out-Null
$StagingRoot = Join-Path $Dist "_staging"
if (Test-Path $StagingRoot) {
    Remove-Item -Recurse -Force $StagingRoot
}
New-Item -ItemType Directory -Force -Path $StagingRoot | Out-Null

$editions = @(
    @{ Name = "cpu";    Start = "scripts/packaging/START-cpu.md" },
    @{ Name = "gpu";    Start = "scripts/packaging/START-gpu.md" },
    @{ Name = "docker"; Start = "scripts/packaging/START-docker.md" }
)

function Copy-StartMd {
    param([string]$Src, [string]$DestDir)
    $dest = Join-Path $DestDir "START.md"
    $text = [System.IO.File]::ReadAllText((Join-Path $ProjectDir $Src), [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($dest, $text, [System.Text.UTF8Encoding]::new($false))
}

foreach ($ed in $editions) {
    $folder = "cangwei-$($ed.Name)-$Version"
    $stage = Join-Path $StagingRoot $folder
    New-Item -ItemType Directory -Force -Path $stage | Out-Null

    $tarTmp = Join-Path $StagingRoot "$folder-src.tar"
    git archive --format=tar --prefix="$folder/" HEAD -o $tarTmp
    if ($LASTEXITCODE -ne 0) { throw "git archive failed" }
    tar -xf $tarTmp -C $StagingRoot
    Remove-Item $tarTmp -Force

    Copy-StartMd -Src $ed.Start -DestDir $stage

    $zipPath = Join-Path $Dist "$folder.zip"
    $tgzPath = Join-Path $Dist "$folder.tar.gz"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    if (Test-Path $tgzPath) { Remove-Item $tgzPath -Force }

    Compress-Archive -Path $stage -DestinationPath $zipPath -CompressionLevel Optimal
    tar -czf $tgzPath -C $StagingRoot $folder

    Write-Host "Wrote $zipPath"
    Write-Host "Wrote $tgzPath"
}

Remove-Item -Recurse -Force $StagingRoot
Write-Host "Done. Files in $Dist"
Get-ChildItem $Dist -File | ForEach-Object { "{0,12}  {1}" -f $_.Length, $_.Name }
