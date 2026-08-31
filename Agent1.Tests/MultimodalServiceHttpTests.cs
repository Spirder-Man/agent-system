// ============================================================================
// MultimodalService HTTP 路径测试 — 覆盖成功 / HttpError / EmptyResponse /
// Timeout / ServiceUnavailable 五条响应分支 + 请求体契约（Base64 图片、
// MIME 推断、max_tokens、防重复参数）。
//
// 与 AiInferenceTests.MultimodalServiceTests（结构测试）互补：
//   结构测试 = 文件缺失 + 工厂方法 + 真实环境不可达
//   本测试   = 注入 Mock HttpClient，零网络依赖，覆盖全部 HTTP 分支
//
// 实现原理：MultimodalService 提供 HttpClient 注入构造（生产行为不变），
// 测试用 MockMultimodalHandler 预设响应，不发起真实网络请求。
// ============================================================================
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Agent1.Config;
using Agent1.Services;
using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Agent1.Tests;

/// <summary>可编程 Mock HttpMessageHandler — 记录最后一次请求体，便于断言请求契约。</summary>
public class MockMultimodalHandler : HttpMessageHandler
{
    private readonly Func<HttpRequestMessage, Task<HttpResponseMessage>> _responder;

    public HttpRequestMessage? LastRequest { get; private set; }
    public string? LastRequestBody { get; private set; }

    public MockMultimodalHandler(Func<HttpRequestMessage, Task<HttpResponseMessage>> responder)
    {
        _responder = responder;
    }

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        LastRequest = request;
        if (request.Content != null)
            LastRequestBody = await request.Content.ReadAsStringAsync(cancellationToken);
        return await _responder(request);
    }
}

public class MultimodalServiceHttpTests : IDisposable
{
    // 1x1 透明 PNG（最小合法图片）
    private const string TinyPngBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";

    private readonly List<string> _tempFiles = new();

    public MultimodalServiceHttpTests()
    {
        // xUnit 不保证测试执行顺序，配置加载放构造函数确保每个测试有效
        try { AppConfig.Instance.ToString(); }
        catch
        {
            var config = new ConfigurationBuilder()
                .AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Llm:ModelId"] = "test-model",
                    ["Llm:Endpoint"] = "http://localhost:11434",
                    ["Llm:MultimodalModelId"] = "test-vl",
                    ["Llm:MultimodalEndpoint"] = "http://localhost:8083/v1",
                    ["Database:Host"] = "localhost",
                    ["Database:Port"] = "5432",
                    ["Database:DatabaseName"] = "testdb",
                    ["Database:Password"] = "pwd",
                    ["VectorSearch:EmbeddingModelId"] = "test-embed",
                    ["PromptTemplates:SystemRole"] = "test",
                    ["PromptTemplates:EvalFastPrompt"] = "test {SystemRole} {UserInput}",
                    ["PromptTemplates:EvalFastQueryPrompt"] = "test {SystemRole} {UserInput}"
                }).Build();
            AppConfig.Load(config);
        }
    }

    public void Dispose()
    {
        foreach (var f in _tempFiles)
        {
            try { File.Delete(f); } catch { /* 清理失败不影响测试结论 */ }
        }
    }

    // ── 辅助：创建临时图片 + 注入 Mock 的 Service ──

    private string CreateTempImage(string extension = ".png")
    {
        var path = Path.Combine(Path.GetTempPath(), $"mm-{Guid.NewGuid():N}{extension}");
        File.WriteAllBytes(path, Convert.FromBase64String(TinyPngBase64));
        _tempFiles.Add(path);
        return path;
    }

    private static (MultimodalService service, MockMultimodalHandler handler) CreateService(
        Func<HttpRequestMessage, Task<HttpResponseMessage>> responder,
        TimeSpan? timeout = null)
    {
        var handler = new MockMultimodalHandler(responder);
        var client = new HttpClient(handler)
        {
            BaseAddress = new Uri("http://mock-vision.local/v1"),
            Timeout = timeout ?? TimeSpan.FromSeconds(10)
        };
        return (new MultimodalService(client), handler);
    }

    private static HttpResponseMessage JsonResponse(HttpStatusCode status, string json)
        => new(status)
        {
            Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")
        };

    private static string ChatCompletionJson(string content)
        => $@"{{""choices"":[{{
                ""message"":{{""content"":""{content}""}}
            }}]}}";

    // ═══════════════════════════════════════════
    // 成功路径
    // ═══════════════════════════════════════════

    [Fact]
    public async Task AnalyzeImageDetailed_Http200_ReturnsOkWithContent()
    {
        var (service, _) = CreateService(_ => Task.FromResult(
            JsonResponse(HttpStatusCode.OK, ChatCompletionJson("图片显示 GHS 火焰标识，信号词：危险"))));

        using (service)
        {
            var result = await service.AnalyzeImageDetailedAsync(CreateTempImage(), "分析这张标签");

            result.Success.Should().BeTrue();
            result.Content.Should().Contain("GHS");
            result.ErrorCategory.Should().BeNull();
        }
    }

    [Fact]
    public async Task AnalyzeImageAsync_Wrapper_ReturnsRawContentOnSuccess()
    {
        var (service, _) = CreateService(_ => Task.FromResult(
            JsonResponse(HttpStatusCode.OK, ChatCompletionJson("储罐无腐蚀痕迹"))));

        using (service)
        {
            var result = await service.AnalyzeImageAsync(CreateTempImage(), "检查储罐");

            result.Should().Be("储罐无腐蚀痕迹");
        }
    }

    // ═══════════════════════════════════════════
    // 失败路径：HTTP 错误
    // ═══════════════════════════════════════════

    [Fact]
    public async Task AnalyzeImageDetailed_Http500_ReturnsHttpErrorWithStatusAndBody()
    {
        var (service, _) = CreateService(_ => Task.FromResult(
            new HttpResponseMessage(HttpStatusCode.InternalServerError)
            {
                Content = new StringContent("{\"error\":\"KV cache overflow\"}")
            }));

        using (service)
        {
            var result = await service.AnalyzeImageDetailedAsync(CreateTempImage(), "分析");

            result.Success.Should().BeFalse();
            result.ErrorCategory.Should().Be("HttpError");
            // 实现用 HttpStatusCode 枚举名格式化错误消息（如 InternalServerError），非数字状态码
            result.Content.Should().Contain("InternalServerError");
            result.Content.Should().Contain("KV cache overflow");
        }
    }

    // ═══════════════════════════════════════════
    // 失败路径：空响应
    // ═══════════════════════════════════════════

    [Fact]
    public async Task AnalyzeImageDetailed_EmptyChoices_ReturnsEmptyResponse()
    {
        var (service, _) = CreateService(_ => Task.FromResult(
            JsonResponse(HttpStatusCode.OK, """{"choices":[]}""")));

        using (service)
        {
            var result = await service.AnalyzeImageDetailedAsync(CreateTempImage(), "分析");

            result.Success.Should().BeFalse();
            result.ErrorCategory.Should().Be("EmptyResponse");
        }
    }

    [Fact]
    public async Task AnalyzeImageDetailed_NullContent_ReturnsEmptyResponse()
    {
        var (service, _) = CreateService(_ => Task.FromResult(
            JsonResponse(HttpStatusCode.OK, """{"choices":[{"message":{"content":null}}]}""")));

        using (service)
        {
            var result = await service.AnalyzeImageDetailedAsync(CreateTempImage(), "分析");

            result.Success.Should().BeFalse();
            result.ErrorCategory.Should().Be("EmptyResponse");
        }
    }

    [Fact]
    public async Task AnalyzeImageDetailed_BlankContent_ReturnsEmptyResponse()
    {
        var (service, _) = CreateService(_ => Task.FromResult(
            JsonResponse(HttpStatusCode.OK, ChatCompletionJson("   "))));

        using (service)
        {
            var result = await service.AnalyzeImageDetailedAsync(CreateTempImage(), "分析");

            result.Success.Should().BeFalse();
            result.ErrorCategory.Should().Be("EmptyResponse");
        }
    }

    // ═══════════════════════════════════════════
    // 失败路径：连接失败 / 超时
    // ═══════════════════════════════════════════

    [Fact]
    public async Task AnalyzeImageDetailed_ConnectionFailure_ReturnsServiceUnavailable()
    {
        var (service, _) = CreateService(_ =>
            throw new HttpRequestException("Connection refused (127.0.0.1:8083)"));

        using (service)
        {
            var result = await service.AnalyzeImageDetailedAsync(CreateTempImage(), "分析");

            result.Success.Should().BeFalse();
            result.ErrorCategory.Should().Be("ServiceUnavailable");
            result.Content.Should().Contain("视觉服务不可达");
        }
    }

    [Fact]
    public async Task AnalyzeImageDetailed_Timeout_ReturnsTimeoutCategory()
    {
        // handler 延迟 5 秒，client 超时 1 秒 → 触发 TaskCanceledException → Timeout 分类
        var (service, _) = CreateService(async _ =>
        {
            await Task.Delay(TimeSpan.FromSeconds(5), CancellationToken.None);
            return JsonResponse(HttpStatusCode.OK, ChatCompletionJson("太迟了"));
        }, timeout: TimeSpan.FromSeconds(1));

        using (service)
        {
            var result = await service.AnalyzeImageDetailedAsync(CreateTempImage(), "分析");

            result.Success.Should().BeFalse();
            result.ErrorCategory.Should().Be("Timeout");
            result.Content.Should().Contain("超时");
        }
    }

    // ═══════════════════════════════════════════
    // 请求体契约（防止静默破坏 llama.cpp 兼容格式）
    // ═══════════════════════════════════════════

    [Fact]
    public async Task AnalyzeImageDetailed_RequestCarriesBase64ImageAndAntiRepeatParams()
    {
        var (service, handler) = CreateService(_ => Task.FromResult(
            JsonResponse(HttpStatusCode.OK, ChatCompletionJson("ok"))));

        using (service)
        {
            await service.AnalyzeImageDetailedAsync(CreateTempImage(".png"), "分析这张图", maxTokens: 800);

            handler.LastRequest.Should().NotBeNull();
            handler.LastRequest!.RequestUri!.AbsolutePath.Should().Be("/v1/chat/completions");

            using var doc = JsonDocument.Parse(handler.LastRequestBody!);
            var root = doc.RootElement;

            // 图片以 Base64 data URL 传入（llama.cpp OpenAI 兼容格式）
            var content = root.GetProperty("messages")[0].GetProperty("content");
            var imageUrl = content.EnumerateArray()
                .First(c => c.GetProperty("type").GetString() == "image_url")
                .GetProperty("image_url").GetProperty("url").GetString();
            imageUrl.Should().StartWith("data:image/png;base64,");

            // 防无限重复参数 + 自定义 max_tokens
            root.GetProperty("temperature").GetDouble().Should().Be(0.3);
            root.GetProperty("repeat_penalty").GetDouble().Should().Be(1.1);
            root.GetProperty("max_tokens").GetInt32().Should().Be(800);

            // 中文强制指令（Qwen2.5-VL 中文原生双保险）
            var text = content.EnumerateArray()
                .First(c => c.GetProperty("type").GetString() == "text")
                .GetProperty("text").GetString();
            text.Should().Contain("请始终使用中文回复");

            // 非流式
            root.GetProperty("stream").GetBoolean().Should().BeFalse();
        }
    }

    [Fact]
    public async Task AnalyzeImageDetailed_JpgImage_UsesJpegMime()
    {
        var (service, handler) = CreateService(_ => Task.FromResult(
            JsonResponse(HttpStatusCode.OK, ChatCompletionJson("ok"))));

        using (service)
        {
            await service.AnalyzeImageDetailedAsync(CreateTempImage(".jpg"), "分析");

            using var doc = JsonDocument.Parse(handler.LastRequestBody!);
            var content = doc.RootElement.GetProperty("messages")[0].GetProperty("content");
            var imageUrl = content.EnumerateArray()
                .First(c => c.GetProperty("type").GetString() == "image_url")
                .GetProperty("image_url").GetProperty("url").GetString();
            imageUrl.Should().StartWith("data:image/jpeg;base64,");
        }
    }

    [Fact]
    public async Task OcrPageAsync_SendsMaxTokens3000()
    {
        var (service, handler) = CreateService(_ => Task.FromResult(
            JsonResponse(HttpStatusCode.OK, ChatCompletionJson("4.1.2 储存要求"))));

        using (service)
        {
            var result = await service.OcrPageAsync(CreateTempImage(".png"));

            result.Success.Should().BeTrue();
            result.Content.Should().Contain("4.1.2");

            using var doc = JsonDocument.Parse(handler.LastRequestBody!);
            doc.RootElement.GetProperty("max_tokens").GetInt32().Should().Be(3000);

            // OCR 专用提示词：只输出转写结果
            var content = doc.RootElement.GetProperty("messages")[0].GetProperty("content");
            var text = content.EnumerateArray()
                .First(c => c.GetProperty("type").GetString() == "text")
                .GetProperty("text").GetString();
            text.Should().Contain("逐字转写");
        }
    }
}
