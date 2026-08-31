using System.Collections.Concurrent;
using System.ComponentModel.DataAnnotations;
using System.Net.Sockets;
using Agent1.Models;
using Agent1.Services;
using Agent1.Services.AI;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Agent1.Api.Controllers;

/// <summary>
/// 合规评测 API — 运行 50 条业务评测集。
/// 覆盖控制台功能：#13 合规评测集 [50条业务指标]。
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = "Viewer")]
public class EvalController : ControllerBase
{
    private readonly AgentDialog _agentDialog;
    private readonly ILlmService _llmService;
    private readonly IKnowledgeBaseService _knowledgeBase;
    private readonly ILogger<EvalController> _logger;
    private readonly Func<CancellationToken, Task<bool>>? _inferenceProbe;

    // 简易任务状态跟踪（进程级）
    private static readonly ConcurrentDictionary<string, EvalTaskStatus> TaskStore = new();

    public EvalController(
        AgentDialog agentDialog,
        ILlmService llmService,
        IKnowledgeBaseService knowledgeBase,
        ILogger<EvalController> logger,
        Func<CancellationToken, Task<bool>>? inferenceProbe = null)
    {
        _agentDialog = agentDialog;
        _llmService = llmService;
        _knowledgeBase = knowledgeBase;
        _logger = logger;
        _inferenceProbe = inferenceProbe;
    }

    /// <summary>
    /// 启动合规评测任务 — 异步后台执行 50 条业务评测。
    /// 立即返回 taskId，前端轮询 GET /api/eval/status/{taskId} 获取进度。
    /// 推理服务离线时返回 503（GPU 机按需开启，需先启动推理）。
    /// </summary>
    [HttpPost("run")]
    [Authorize(Policy = "Auditor")]
    public async Task<IActionResult> RunEval()
    {
        // 推理分离部署：GPU 机按需开启，经 SSH 隧道映射到本机 localhost:8080。
        // 入口先做 300ms TCP 探测，离线时快速失败，避免任务排队后后台整体报错。
        var online = _inferenceProbe != null
            ? await _inferenceProbe(HttpContext.RequestAborted)
            : await ProbeInferenceAsync("localhost", 8080, HttpContext.RequestAborted);
        if (!online)
        {
            _logger.LogWarning("评测入口拒绝: 推理服务离线 (localhost:8080 不可达)，请开启 GPU 实例");
            return StatusCode(StatusCodes.Status503ServiceUnavailable,
                new { error = "推理服务离线，请开启 GPU 实例" });
        }

        var taskId = Guid.NewGuid().ToString("N")[..8];
        var cts = new CancellationTokenSource();
        TaskStore[taskId] = new EvalTaskStatus
        {
            TaskId = taskId,
            Status = "queued",
            StartedAt = DateTime.Now,
            CancellationTokenSource = cts
        };

        _ = Task.Run(async () =>
        {
            try
            {
                TaskStore[taskId].Status = "running";

                var verifier = new ReflectionVerifier(_knowledgeBase);
                var engine = new EvalEngine(_agentDialog, _llmService, _knowledgeBase, verifier);

                var report = await engine.RunComplianceEvalAsync();

                TaskStore[taskId].Status = "completed";
                TaskStore[taskId].Report = report;
                TaskStore[taskId].CompletedAt = DateTime.Now;

                _logger.LogInformation("评测完成: TaskId={TaskId}, 模型={Model}, 用例数={Total}, 工具调用率={ToolRate}",
                    taskId, report.Model, report.Total, report.ToolCallRate);
            }
            catch (Exception ex)
            {
                TaskStore[taskId].Status = "failed";
                TaskStore[taskId].Error = ex.Message;
                TaskStore[taskId].CompletedAt = DateTime.Now;
                _logger.LogError(ex, "评测失败: TaskId={TaskId}", taskId);
            }
        }, cts.Token);

        return Accepted(new
        {
            taskId,
            status = "queued",
            checkUrl = $"/api/eval/status/{taskId}"
        });
    }

    /// <summary>
    /// TCP 探测推理服务是否在线（300ms 超时）。
    /// 分离部署下 API 所在工程机经 SSH 隧道在 localhost:8080 映射 GPU 推理端口，
    /// 连接成功视为在线；连接被拒或超时视为离线。
    /// </summary>
    public static async Task<bool> ProbeInferenceAsync(string host, int port, CancellationToken ct)
    {
        try
        {
            using var client = new TcpClient();
            using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeoutCts.CancelAfter(300);
            await client.ConnectAsync(host, port, timeoutCts.Token);
            return true;
        }
        catch (Exception ex) when (ex is SocketException or OperationCanceledException)
        {
            return false;
        }
    }

    /// <summary>查询评测任务状态与结果</summary>
    [HttpGet("status/{taskId}")]
    public IActionResult GetStatus(string taskId)
    {
        if (!TaskStore.TryGetValue(taskId, out var status))
        {
            return NotFound(new { error = $"任务 {taskId} 不存在或已过期" });
        }

        return Ok(new
        {
            status.TaskId,
            status.Status,
            status.StartedAt,
            status.CompletedAt,
            duration = status.CompletedAt.HasValue
                ? (status.CompletedAt.Value - status.StartedAt).TotalSeconds
                : (DateTime.Now - status.StartedAt).TotalSeconds,
            status.Error,
            report = status.Report != null ? new
            {
                status.Report.Model,
                status.Report.Timestamp,
                status.Report.Total,
                status.Report.ToolCallRate,
                status.Report.ParameterAccuracy,
                status.Report.ConclusionAccuracy,
                casesCount = status.Report.Cases.Count,
                casesWithErrors = status.Report.Cases.Count(c => !string.IsNullOrEmpty(c.Error)),
                cases = status.Report.Cases.Select(c => new
                {
                    query = c.Query,
                    toolMatch = c.ToolMatch,
                    paramMatch = c.ParamMatch,
                    conclusionMatch = c.ConclusionMatch,
                    expectedTools = new[] { c.ExpectedTool },
                    actualTools = c.ActualTools?.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries) ?? Array.Empty<string>(),
                    error = c.Error
                })
            } : null
        });
    }

    /// <summary>取消正在运行的评测任务</summary>
    [HttpDelete("status/{taskId}")]
    [Authorize(Policy = "Auditor")]
    public IActionResult CancelEval(string taskId)
    {
        if (!TaskStore.TryRemove(taskId, out var status))
        {
            return NotFound(new { error = $"任务 {taskId} 不存在" });
        }

        status.CancellationTokenSource?.Cancel();
        return Ok(new { taskId, cancelled = true });
    }
}

/// <summary>评测任务状态</summary>
public class EvalTaskStatus
{
    public string TaskId { get; set; } = "";
    public string Status { get; set; } = "queued"; // queued | running | completed | failed
    public DateTime StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
    public string? Error { get; set; }
    public EvalReport? Report { get; set; }
    public CancellationTokenSource? CancellationTokenSource { get; set; }
}
