#Requires -Version 5.1
# ============================================================
# gpu-eval-analyze.ps1
# 从 eval.json 抽指标、对照测试总纲 Task 11 历史基线、拉飞致云
# docker compose 日志切片、生成 D1-D6 analysis.md。
#
# 不要调用 download-analysis.ps1（写死 AutoDL 主机和密码）。
# 日志源：SSH → docker compose logs，不是 /root/autodl-tmp/logs。
#
# 用法（一般由 gpu-five-layer.ps1 调用）:
#   powershell -File scripts/gpu-eval-analyze.ps1 -EvalJson ... -OutDir ... -SshPort 65037
# ============================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$EvalJson,

    [Parameter(Mandatory = $true)]
    [string]$OutDir,

    [string]$SshHost = 'workspace.featurize.cn',
    [string]$SshUser = 'featurize',
    [int]$SshPort = 0,
    [string]$RemoteComposeDir = '/opt/agent1/容器化部署/gpu',
    [string]$LatestEvalJson = '',
    [switch]$SkipRemoteLogs
)

$ErrorActionPreference = 'Continue'

function ConvertTo-UnitRate {
    param([object]$Value)
    if ($null -eq $Value -or $Value -eq '') { return $null }
    try { $n = [double]$Value } catch { return $null }
    if ($n -gt 1.0) { return $n / 100.0 }
    return $n
}

function Get-Prop {
    param($Obj, [string[]]$Names)
    if ($null -eq $Obj) { return $null }
    foreach ($n in $Names) {
        try {
            $v = $Obj.$n
            if ($null -ne $v -and "$v" -ne '') { return $v }
        } catch { }
    }
    return $null
}

function Get-Cases {
    param($Report)
    if ($null -eq $Report) { return @() }
    $c = $Report.cases
    if ($null -eq $c) { $c = $Report.Cases }
    if ($null -eq $c) { return @() }
    if ($c -is [System.Array]) { return @($c) }
    return @($c)
}

function Format-Pct {
    param($UnitRate)
    if ($null -eq $UnitRate) { return 'N/A' }
    return ('{0:N1}%' -f ([double]$UnitRate * 100.0))
}

function Count-Match {
    param([string]$Path, [string]$Pattern)
    if (-not (Test-Path -LiteralPath $Path)) { return 'N/A' }
    try {
        $n = @(Select-String -LiteralPath $Path -Pattern $Pattern -AllMatches -ErrorAction SilentlyContinue).Count
        return $n
    } catch { return 'N/A' }
}

if (-not (Test-Path -LiteralPath $EvalJson)) {
    Write-Host "[gpu-eval-analyze] FATAL: eval.json not found: $EvalJson" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$sliceDir = Join-Path $OutDir 'log_slices'
New-Item -ItemType Directory -Force -Path $sliceDir | Out-Null

$report = Get-Content -LiteralPath $EvalJson -Raw -Encoding UTF8 | ConvertFrom-Json

# ── 抽出指标（兼容 camelCase / snake_case / 0-1 与 0-100）──
$metrics = [ordered]@{
    total                  = [int](Get-Prop $report @('total', 'Total'))
    tool_call_rate         = ConvertTo-UnitRate (Get-Prop $report @('toolCallRate', 'tool_call_rate', 'ToolCallRate'))
    parameter_accuracy     = ConvertTo-UnitRate (Get-Prop $report @('parameterAccuracy', 'parameter_accuracy', 'ParameterAccuracy'))
    conclusion_accuracy    = ConvertTo-UnitRate (Get-Prop $report @('conclusionAccuracy', 'conclusion_accuracy', 'ConclusionAccuracy'))
    mean_precision_at_k    = ConvertTo-UnitRate (Get-Prop $report @('meanPrecisionAtK', 'mean_precision_at_k', 'MeanPrecisionAtK'))
    mean_recall_at_k       = ConvertTo-UnitRate (Get-Prop $report @('meanRecallAtK', 'mean_recall_at_k', 'MeanRecallAtK'))
    mean_precision_at_10   = ConvertTo-UnitRate (Get-Prop $report @('meanPrecisionAt10', 'mean_precision_at_10', 'MeanPrecisionAt10'))
    mean_recall_at_10      = ConvertTo-UnitRate (Get-Prop $report @('meanRecallAt10', 'mean_recall_at_10', 'MeanRecallAt10'))
    mean_mrr               = ConvertTo-UnitRate (Get-Prop $report @('meanMrr', 'mean_mrr', 'MeanMRR', 'meanMRR'))
    mean_faithfulness      = ConvertTo-UnitRate (Get-Prop $report @('meanFaithfulness', 'mean_faithfulness', 'MeanFaithfulness'))
    verified_claims        = Get-Prop $report @('totalVerifiedClaims', 'total_verified_claims', 'TotalVerifiedClaims')
    hallucinated_claims    = Get-Prop $report @('totalHallucinatedClaims', 'total_hallucinated_claims', 'TotalHallucinatedClaims')
    cases_count            = $null
    cases_with_errors      = $null
    model                  = [string](Get-Prop $report @('model', 'Model'))
    timestamp              = [string](Get-Prop $report @('timestamp', 'Timestamp'))
}

$cases = Get-Cases $report
$metrics.cases_count = $cases.Count
$metrics.cases_with_errors = @($cases | Where-Object { $_.error -or $_.Error }).Count
if ($metrics.total -le 0) { $metrics.total = $cases.Count }

$vClaims = 0.0
$hClaims = 0.0
if ($null -ne $metrics.verified_claims) { $vClaims = [double]$metrics.verified_claims }
if ($null -ne $metrics.hallucinated_claims) { $hClaims = [double]$metrics.hallucinated_claims }
$hallucRate = $null
if (($vClaims + $hClaims) -gt 0) {
    $hallucRate = $hClaims / ($vClaims + $hClaims)
}

# 测试总纲 Task 11 历史基线（0-1）。理想 Top-5≥85% / 结论≥90% 从未达到，不作死门槛。
$historical = [ordered]@{
    source                 = '测试总纲.md v2.2 Task 11'
    tool_call_rate         = 0.857
    parameter_accuracy     = 0.825
    conclusion_accuracy    = 0.651
    mean_precision_at_k    = 0.505
    mean_precision_at_10   = 0.359
    mean_mrr               = 0.584
    mean_faithfulness      = 0.239
}

$alertThresholdConclusion = 0.05
$alertThresholdHalluc = 0.10
$alerts = New-Object System.Collections.Generic.List[string]

function Add-HistAlert {
    param([string]$Name, $Current, $Baseline, [double]$DropThreshold = 0.05)
    if ($null -eq $Current -or $null -eq $Baseline) { return $null }
    $delta = [double]$Current - [double]$Baseline
    $alert = $false
    if (([double]$Baseline - [double]$Current) -gt $DropThreshold) {
        $msg = ("HIST_{0}_DROP current={1:N3} baseline={2:N3} delta={3:N3}" -f $Name, $Current, $Baseline, $delta)
        $script:alerts.Add($msg)
        $alert = $true
    }
    return [ordered]@{ current = $Current; baseline = $Baseline; delta = $delta; alert = $alert }
}

$vsHistorical = [ordered]@{
    tool_call_rate      = Add-HistAlert 'TOOL' $metrics.tool_call_rate $historical.tool_call_rate
    parameter_accuracy  = Add-HistAlert 'PARAM' $metrics.parameter_accuracy $historical.parameter_accuracy
    conclusion_accuracy = Add-HistAlert 'CONCLUSION' $metrics.conclusion_accuracy $historical.conclusion_accuracy
    mean_precision_at_k = Add-HistAlert 'P@5' $metrics.mean_precision_at_k $historical.mean_precision_at_k
}

$vsLatest = $null
if ($LatestEvalJson -and (Test-Path -LiteralPath $LatestEvalJson)) {
    $prev = Get-Content -LiteralPath $LatestEvalJson -Raw -Encoding UTF8 | ConvertFrom-Json
    $prevConclusion = ConvertTo-UnitRate (Get-Prop $prev @('conclusionAccuracy', 'conclusion_accuracy', 'ConclusionAccuracy'))
    $prevHalluc = $null
    $pv = Get-Prop $prev @('totalVerifiedClaims', 'total_verified_claims')
    $ph = Get-Prop $prev @('totalHallucinatedClaims', 'total_hallucinated_claims')
    if ($null -ne $pv -and $null -ne $ph -and (([double]$pv + [double]$ph) -gt 0)) {
        $prevHalluc = [double]$ph / ([double]$pv + [double]$ph)
    }
    $drop = 0.0
    $rise = 0.0
    if ($null -ne $prevConclusion -and $null -ne $metrics.conclusion_accuracy) {
        $drop = [Math]::Max(0.0, [double]$prevConclusion - [double]$metrics.conclusion_accuracy)
        if ($drop -gt $alertThresholdConclusion) {
            $alerts.Add(("LATEST_CONCLUSION_DROP drop={0:N3} (> {1})" -f $drop, $alertThresholdConclusion))
        }
    }
    if ($null -ne $prevHalluc -and $null -ne $hallucRate) {
        $rise = [Math]::Max(0.0, [double]$hallucRate - [double]$prevHalluc)
        if ($rise -gt $alertThresholdHalluc) {
            $alerts.Add(("LATEST_HALLUCINATION_RISE rise={0:N3} (> {1})" -f $rise, $alertThresholdHalluc))
        }
    }
    $vsLatest = [ordered]@{
        conclusion_accuracy = @{ previous = $prevConclusion; current = $metrics.conclusion_accuracy; drop = $drop }
        hallucination_rate  = @{ previous = $prevHalluc; current = $hallucRate; rise = $rise }
    }
}

$comparison = [ordered]@{
    historical_baseline = $historical
    current             = $metrics
    hallucination_rate  = $hallucRate
    vs_historical       = $vsHistorical
    vs_latest           = $vsLatest
    alerts              = @($alerts)
    note                = '指标退化只写入 alerts，不单独把 GPU 栈判失败。召回/结论未达总纲理想值 85%/90% 不否决。飞致云当前镜像若 GetStatus 未投影 RAG 字段，mean_* 可为 null。'
}

$comparisonPath = Join-Path $OutDir 'comparison.json'
($comparison | ConvertTo-Json -Depth 8) | Out-File -FilePath $comparisonPath -Encoding UTF8
Write-Host "[gpu-eval-analyze] comparison.json -> $comparisonPath"

# ── 远程 docker compose 日志（一次 SSH）──
$apiLog = Join-Path $sliceDir 'api-eval-window.log'
$llmLog = Join-Path $sliceDir 'llama-llm-tail.log'
$embedLog = Join-Path $sliceDir 'llama-embed-tail.log'
$combinedLog = Join-Path $sliceDir 'compose-since-2h.log'
$fullReportPath = Join-Path $OutDir 'eval.full.json'
$logNote = 'skipped'
$fullReportPulled = $false

if (-not $SkipRemoteLogs) {
    if ($SshPort -le 0) {
        $logNote = 'no SshPort; skipped docker logs'
        Write-Host "[gpu-eval-analyze] WARN: $logNote" -ForegroundColor Yellow
    } elseif (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
        $logNote = 'ssh not in PATH; skipped docker logs'
        Write-Host "[gpu-eval-analyze] WARN: $logNote" -ForegroundColor Yellow
    } else {
        Write-Host "[gpu-eval-analyze] SSH docker compose logs (password/key if prompted)..."
        $remote = @"
set +e
DIR='$RemoteComposeDir'
if [ ! -f "`$DIR/docker-compose.yml" ]; then
  if [ -f /opt/agent1/gpu/docker-compose.yml ]; then DIR=/opt/agent1/gpu
  else
    FOUND=`$(find /opt/agent1 -name docker-compose.yml 2>/dev/null | head -1)
    if [ -n "`$FOUND" ]; then DIR=`$(dirname "`$FOUND"); fi
  fi
fi
echo "COMPOSE_DIR=`$DIR"
cd "`$DIR" || exit 1
echo '===COMPOSE_API==='
sudo docker compose logs --since 2h --no-color api 2>/dev/null | tail -n 4000
echo '===COMPOSE_LLAMA_SERVER==='
sudo docker compose logs --since 2h --no-color llama-server 2>/dev/null | tail -n 400
echo '===COMPOSE_LLAMA_EMBED==='
sudo docker compose logs --since 2h --no-color llama-embed 2>/dev/null | tail -n 200
echo '===EVAL_REPORT_JSON==='
sudo docker compose exec -T api cat /app/Data/eval_report.json 2>/dev/null || true
echo '===END==='
exit 0
"@
        $sshArgs = @(
            '-p', "$SshPort",
            '-o', 'StrictHostKeyChecking=accept-new',
            '-o', 'ServerAliveInterval=30',
            "${SshUser}@${SshHost}",
            $remote
        )
        $rawOut = & ssh @sshArgs 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            $logNote = "ssh docker logs exit=$LASTEXITCODE"
            Write-Host "[gpu-eval-analyze] WARN: $logNote" -ForegroundColor Yellow
            $rawOut | Out-File -FilePath $combinedLog -Encoding UTF8
        } else {
            $logNote = "docker compose logs --since 2h from $RemoteComposeDir"
            $rawOut | Out-File -FilePath $combinedLog -Encoding UTF8
            function Split-MarkerBlock {
                param([string]$Text, [string]$Start, [string]$End)
                $i = $Text.IndexOf($Start)
                if ($i -lt 0) { return '' }
                $i += $Start.Length
                $j = $Text.IndexOf($End, $i)
                if ($j -lt 0) { return $Text.Substring($i).Trim() }
                return $Text.Substring($i, $j - $i).Trim()
            }
            (Split-MarkerBlock $rawOut '===COMPOSE_API===' '===COMPOSE_LLAMA_SERVER===') | Out-File -FilePath $apiLog -Encoding UTF8
            (Split-MarkerBlock $rawOut '===COMPOSE_LLAMA_SERVER===' '===COMPOSE_LLAMA_EMBED===') | Out-File -FilePath $llmLog -Encoding UTF8
            (Split-MarkerBlock $rawOut '===COMPOSE_LLAMA_EMBED===' '===EVAL_REPORT_JSON===') | Out-File -FilePath $embedLog -Encoding UTF8
            $fullJson = Split-MarkerBlock $rawOut '===EVAL_REPORT_JSON===' '===END==='
            if ($fullJson -and $fullJson.Trim().StartsWith('{')) {
                $fullJson.Trim() | Out-File -FilePath $fullReportPath -Encoding UTF8
                $fullReportPulled = $true
                Write-Host "[gpu-eval-analyze] pulled /app/Data/eval_report.json"
            }
        }
    }
} else {
    $logNote = 'SkipRemoteLogs'
}

# 若容器内全文报告带 RAG 字段，用它补全 comparison.current
if ($fullReportPulled) {
    try {
        $full = Get-Content -LiteralPath $fullReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($pair in @(
                @{ k = 'mean_precision_at_k'; names = @('meanPrecisionAtK', 'mean_precision_at_k', 'MeanPrecisionAtK') },
                @{ k = 'mean_recall_at_k'; names = @('meanRecallAtK', 'mean_recall_at_k', 'MeanRecallAtK') },
                @{ k = 'mean_precision_at_10'; names = @('meanPrecisionAt10', 'mean_precision_at_10', 'MeanPrecisionAt10') },
                @{ k = 'mean_recall_at_10'; names = @('meanRecallAt10', 'mean_recall_at_10', 'MeanRecallAt10') },
                @{ k = 'mean_mrr'; names = @('meanMrr', 'mean_mrr', 'MeanMRR', 'meanMRR') },
                @{ k = 'mean_faithfulness'; names = @('meanFaithfulness', 'mean_faithfulness', 'MeanFaithfulness') }
            )) {
            if ($null -eq $metrics[$pair.k]) {
                $metrics[$pair.k] = ConvertTo-UnitRate (Get-Prop $full $pair.names)
            }
        }
        $vsHistorical.mean_precision_at_k = Add-HistAlert 'P@5' $metrics.mean_precision_at_k $historical.mean_precision_at_k
        $comparison.current = $metrics
        $comparison.alerts = @($alerts)
        ($comparison | ConvertTo-Json -Depth 8) | Out-File -FilePath $comparisonPath -Encoding UTF8
    } catch {
        Write-Host "[gpu-eval-analyze] WARN: could not merge eval.full.json: $_" -ForegroundColor Yellow
    }
}

# ── 失败模式分组 ──
$failA = New-Object System.Collections.Generic.List[object]
$failB = New-Object System.Collections.Generic.List[object]
$failC = New-Object System.Collections.Generic.List[object]
$failD = New-Object System.Collections.Generic.List[object]
$toolDist = @{}
$toolOkCount = 0
$noToolCount = 0

foreach ($c in $cases) {
    $q = [string](Get-Prop $c @('query', 'Query'))
    $tm = Get-Prop $c @('toolMatch', 'tool_match', 'ToolMatch')
    $pm = Get-Prop $c @('paramMatch', 'param_match', 'ParamMatch')
    $cm = Get-Prop $c @('conclusionMatch', 'conclusion_match', 'ConclusionMatch')
    $exp = Get-Prop $c @('expectedTools', 'expected_tools', 'ExpectedTool')
    $act = Get-Prop $c @('actualTools', 'actual_tools', 'ActualTools')
    $err = Get-Prop $c @('error', 'Error')
    $exp0 = ''
    if ($exp -is [System.Array] -and $exp.Count -gt 0) { $exp0 = [string]$exp[0] }
    elseif ($null -ne $exp) { $exp0 = [string]$exp }
    $act0 = ''
    if ($act -is [System.Array] -and $act.Count -gt 0) { $act0 = [string]$act[0] }
    elseif ($null -ne $act) { $act0 = [string]$act }

    $tmB = $false; if ($null -ne $tm) { try { $tmB = [bool]$tm } catch { } }
    $pmB = $false; if ($null -ne $pm) { try { $pmB = [bool]$pm } catch { } }
    $cmB = $false; if ($null -ne $cm) { try { $cmB = [bool]$cm } catch { } }

    if ($act0) {
        if (-not $toolDist.ContainsKey($act0)) { $toolDist[$act0] = 0 }
        $toolDist[$act0] = [int]$toolDist[$act0] + 1
        $toolOkCount++
    } else { $noToolCount++ }

    $row = [ordered]@{ query = $q; expected = $exp0; actual = $act0; error = $err; toolMatch = $tmB; paramMatch = $pmB; conclusionMatch = $cmB }
    if (-not $tmB) { $failA.Add($row) }
    elseif (-not $pmB) { $failB.Add($row) }
    elseif (-not $cmB) { $failC.Add($row) }
    elseif ($err) { $failD.Add($row) }
}

$toolDistText = if ($toolDist.Count -eq 0) { '(no actualTools in report cases)' } else {
    ($toolDist.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "  $($_.Key): $($_.Value)" }) -join "`n"
}

function Write-FailSection {
    param($List, [string]$Title)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("#### $Title ($($List.Count) 例)")
    [void]$sb.AppendLine('')
    if ($List.Count -eq 0) {
        [void]$sb.AppendLine('无')
        [void]$sb.AppendLine('')
        return $sb.ToString()
    }
    foreach ($r in $List) {
        [void]$sb.AppendLine(("- ``{0}`` → 期望: ``{1}``, 实际: ``{2}``" -f $r.query, $r.expected, $r.actual))
    }
    [void]$sb.AppendLine('')
    return $sb.ToString()
}

$apiLines = if (Test-Path -LiteralPath $apiLog) { @(Get-Content -LiteralPath $apiLog -ErrorAction SilentlyContinue).Count } else { 'N/A' }
$pipelineLines = Count-Match $apiLog 'Pipeline|AgentDialog|ExecuteEval'
$fcViolations = Count-Match $apiLog '工具调用=0|FC.?违约|Function.?Call'
$apiErrors = Count-Match $apiLog '\bERR\b|FATAL|fail'
$apiWarns = Count-Match $apiLog '\bWRN\b|WARN'

$alertMd = if ($alerts.Count -gt 0) { ($alerts | ForEach-Object { "- $_" }) -join "`n" } else { 'no quality alerts vs historical/latest (5%/10% thresholds)' }

$p0 = if ($apiErrors -ne 'N/A' -and [int]$apiErrors -gt 0) { "WARN ${apiErrors} ERR" } else { 'OK none / no slice' }
$p1conc = if ($vsLatest -and $vsLatest.conclusion_accuracy.drop -gt $alertThresholdConclusion) { 'WARN regression' } else { 'OK stable or no latest' }
$toolPctNum = $metrics.tool_call_rate
$p1tool = if ($null -ne $toolPctNum -and [double]$toolPctNum -lt 0.80) { "WARN $(Format-Pct $toolPctNum)" } else { "OK $(Format-Pct $toolPctNum)" }
$p2fc = if ($fcViolations -ne 'N/A' -and [int]$fcViolations -gt 3) { "WARN $fcViolations" } else { 'OK / no slice' }
$p3wrn = if ($apiWarns -ne 'N/A' -and [int]$apiWarns -gt 5) { "WARN $apiWarns WRN" } else { 'OK / no slice' }

$analysisId = 'analysis-' + (Get-Date -Format 'yyyyMMdd-HHmm')
$analysisPath = Join-Path $OutDir 'analysis.md'
$failAppendix = New-Object System.Text.StringBuilder
$allFails = New-Object System.Collections.Generic.List[object]
foreach ($item in $failA) { [void]$allFails.Add($item) }
foreach ($item in $failB) { [void]$allFails.Add($item) }
foreach ($item in $failC) { [void]$allFails.Add($item) }
foreach ($item in $failD) { [void]$allFails.Add($item) }
if ($allFails.Count -eq 0) {
    [void]$failAppendix.AppendLine('all cases passed tool/param/conclusion, or cases projection has no match fields')
} else {
    foreach ($r in $allFails) {
        [void]$failAppendix.AppendLine(('### {0}' -f $r.query))
        [void]$failAppendix.AppendLine('')
        [void]$failAppendix.AppendLine('| dim | status |')
        [void]$failAppendix.AppendLine('|------|------|')
        $tm = if ($r.toolMatch) { 'PASS' } else { 'FAIL' }
        $pm = if ($r.paramMatch) { 'PASS' } else { 'FAIL' }
        $cm = if ($r.conclusionMatch) { 'PASS' } else { 'FAIL' }
        [void]$failAppendix.AppendLine(('| toolMatch | {0} |' -f $tm))
        [void]$failAppendix.AppendLine(('| paramMatch | {0} |' -f $pm))
        [void]$failAppendix.AppendLine(('| conclusionMatch | {0} |' -f $cm))
        [void]$failAppendix.AppendLine(('| expected | `{0}` |' -f $r.expected))
        [void]$failAppendix.AppendLine(('| actual | `{0}` |' -f $r.actual))
        if ($r.error) { [void]$failAppendix.AppendLine(('| error | {0} |' -f $r.error)) }
        [void]$failAppendix.AppendLine('')
    }
}

$fullReportLabel = if ($fullReportPulled) { 'eval.full.json' } else { 'not pulled' }
$mrrText = if ($null -eq $metrics.mean_mrr) { 'N/A' } else { '{0:N3}' -f $metrics.mean_mrr }

$tplPath = Join-Path $PSScriptRoot 'gpu-eval-analysis-template.md'
if (-not (Test-Path -LiteralPath $tplPath)) {
    Write-Host '[gpu-eval-analyze] FATAL: template missing' -ForegroundColor Red
    exit 1
}
$md = Get-Content -LiteralPath $tplPath -Raw -Encoding UTF8
$repl = @{
    '__ANALYSIS_ID__'     = $analysisId
    '__MODEL__'           = [string]$metrics.model
    '__EVAL_TS__'         = [string]$metrics.timestamp
    '__OUT_DIR__'         = [string]$OutDir
    '__LOG_NOTE__'        = [string]$logNote
    '__FULL_REPORT__'     = $fullReportLabel
    '__TOTAL__'           = [string]$metrics.total
    '__TOOL_RATE__'       = Format-Pct $metrics.tool_call_rate
    '__PARAM_ACC__'       = Format-Pct $metrics.parameter_accuracy
    '__CONCLUSION_ACC__'  = Format-Pct $metrics.conclusion_accuracy
    '__P5__'              = Format-Pct $metrics.mean_precision_at_k
    '__R5__'              = Format-Pct $metrics.mean_recall_at_k
    '__P10__'             = Format-Pct $metrics.mean_precision_at_10
    '__R10__'             = Format-Pct $metrics.mean_recall_at_10
    '__MRR__'             = $mrrText
    '__FAITH__'           = Format-Pct $metrics.mean_faithfulness
    '__ERR_CASES__'       = [string]$metrics.cases_with_errors
    '__TOOL_DIST__'       = [string]$toolDistText
    '__API_LINES__'       = [string]$apiLines
    '__FAIL_A__'          = Write-FailSection $failA 'A-no-tool IntentRouter/FC'
    '__FAIL_B__'          = Write-FailSection $failB 'B-bad-param FactExtractor'
    '__FAIL_C__'          = Write-FailSection $failC 'C-bad-conclusion Verifier'
    '__FAIL_D__'          = Write-FailSection $failD 'D-other'
    '__PIPELINE_LINES__'  = [string]$pipelineLines
    '__FC_VIOLATIONS__'   = [string]$fcViolations
    '__API_ERRORS__'      = [string]$apiErrors
    '__API_WARNS__'       = [string]$apiWarns
    '__P0__'              = $p0
    '__P1CONC__'          = $p1conc
    '__P1TOOL__'          = $p1tool
    '__P2FC__'            = $p2fc
    '__P3WRN__'           = $p3wrn
    '__ALERT_MD__'        = $alertMd
    '__TOOL_OK__'         = [string]$toolOkCount
    '__NO_TOOL__'         = [string]$noToolCount
    '__FAIL_APPENDIX__'   = $failAppendix.ToString()
    '__ANALYSIS_PATH__'   = $analysisPath
    '__EVAL_JSON__'       = $EvalJson
    '__COMPARISON_PATH__' = $comparisonPath
    '__COMBINED_LOG__'    = $combinedLog
    '__API_LOG__'         = $apiLog
    '__LLM_LOG__'         = $llmLog
    '__EMBED_LOG__'       = $embedLog
}
foreach ($k in $repl.Keys) {
    $md = $md.Replace($k, [string]$repl[$k])
}
Set-Content -LiteralPath $analysisPath -Value $md -Encoding UTF8
Write-Host ('[gpu-eval-analyze] analysis.md -> {0}' -f $analysisPath)

$alertSidecar = Join-Path $OutDir 'alerts.json'
ConvertTo-Json -InputObject @($alerts) -Depth 4 | Out-File -FilePath $alertSidecar -Encoding UTF8

if ($alerts.Count -gt 0) {
    Write-Host '[gpu-eval-analyze] alerts:' -ForegroundColor Yellow
    $alerts | ForEach-Object { Write-Host ('  - {0}' -f $_) -ForegroundColor Yellow }
} else {
    Write-Host '[gpu-eval-analyze] no metric alerts vs historical/latest'
}

exit 0
