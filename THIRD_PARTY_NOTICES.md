# 第三方声明

本文件列出 Agent1 **直接依赖** 的开源组件及其许可证，供资格审核核验。版本以仓库内 `*.csproj` / `package.json` 为准。

传递依赖（各包再引入的库）以该包自带许可证为准，本文件不穷尽。

本仓库 **不含国家标准全文**。详见 [NOTICE](NOTICE) 与 README「数据与版权」。本仓库 **不是** 已定级备案或已测评的等级保护对象，见 [docs/project/等级保护口径.md](docs/project/等级保护口径.md)。

## 后端（NuGet）— 生产

来源：[Agent1/Agent1.csproj](Agent1/Agent1.csproj)、[Agent1.Api/Agent1.Api.csproj](Agent1.Api/Agent1.Api.csproj)

| 组件 | 版本（约） | 许可证 |
|------|-----------|--------|
| Microsoft.SemanticKernel | 1.74.0 | MIT |
| Microsoft.SemanticKernel.Connectors.OpenAI | 1.74.0 | MIT |
| Microsoft.SemanticKernel.Connectors.Ollama | 1.74.0-alpha | MIT |
| Microsoft.Extensions.Configuration | 8.0.0 | MIT |
| Microsoft.Extensions.Configuration.Json | 8.0.0 | MIT |
| Microsoft.Extensions.Configuration.EnvironmentVariables | 8.0.0 | MIT |
| Microsoft.Extensions.Configuration.Binder | 8.0.0 | MIT |
| Npgsql | 8.0.5 | PostgreSQL License |
| Dapper | 2.1.35 | Apache-2.0 |
| Pgvector | 0.3.2 | MIT |
| Microsoft.Data.Sqlite | 8.0.0 | MIT |
| PdfPig | 0.1.9 | Apache-2.0 |
| DocumentFormat.OpenXml | 3.2.0 | MIT |
| MailKit | 4.7.1.1 | MIT |
| Serilog.Extensions.Hosting | 8.0.0 | Apache-2.0 |
| Serilog.Sinks.Console | 5.0.1 | Apache-2.0 |
| Serilog.Sinks.File | 5.0.0 | Apache-2.0 |
| Serilog.Sinks.Seq | 8.0.0 | Apache-2.0 |
| Serilog.Settings.Configuration | 8.0.1 | Apache-2.0 |
| Microsoft.AspNetCore.Authentication.JwtBearer | 8.0.6 | MIT |
| BCrypt.Net-Next | 4.0.3 | MIT |
| Swashbuckle.AspNetCore | 6.6.2 | MIT |
| OpenTelemetry.Extensions.Hosting | 1.9.0 | Apache-2.0 |
| OpenTelemetry.Exporter.OpenTelemetryProtocol | 1.9.0 | Apache-2.0 |
| OpenTelemetry.Instrumentation.AspNetCore | 1.9.0 | Apache-2.0 |
| PDFtoImage | 4.1.1 | AGPL-3.0-or-later（NuGet 页面）；渲染依赖原生 PDFium，许可证见 PDFium / 上游项目 |

## 后端（NuGet）— 开发 / 测试

来源：[Agent1.Tests/Agent1.Tests.csproj](Agent1.Tests/Agent1.Tests.csproj)

| 组件 | 版本（约） | 许可证 |
|------|-----------|--------|
| xunit | 2.5.3 | Apache-2.0 |
| xunit.runner.visualstudio | 2.5.3 | Apache-2.0 |
| Moq | 4.20.0 | BSD-3-Clause |
| FluentAssertions | 6.10.0 | Apache-2.0 |
| Microsoft.NET.Test.Sdk | 17.10.0 | MIT |
| Microsoft.AspNetCore.Mvc.Testing | 8.0.0 | MIT |
| coverlet.collector | 6.0.0 | MIT |

## 运维小工具（NuGet）

来源：[ssh-runner/SshRunner.csproj](ssh-runner/SshRunner.csproj)、[ssh-tunnel/SshTunnel.csproj](ssh-tunnel/SshTunnel.csproj)

| 组件 | 版本（约） | 许可证 |
|------|-----------|--------|
| SSH.NET | 2024.2.0 / 2023.0.1 | MIT |

## 运行时另需自行部署（不随本仓分发二进制）

| 组件 | 用途 | 许可证 |
|------|------|--------|
| llama.cpp / llama-server | 本地 LLM 与 embedding | MIT |
| PostgreSQL 16 + pgvector | 关系库与向量检索 | PostgreSQL License |
| Qwen / nomic-embed 等 GGUF 权重 | 推理（评委自备，不入库） | 各模型协议 |

## 前端（npm）— 生产

来源：[agent1-web/package.json](agent1-web/package.json) `dependencies`

| 组件 | 版本（约） | 许可证 |
|------|-----------|--------|
| vue | 3.5 | MIT |
| vue-router | 4.4 | MIT |
| pinia | 2.2 | MIT |
| element-plus | 2.8 | MIT |
| @element-plus/icons-vue | 2.3 | MIT |
| axios | 1.7 | MIT |
| echarts | 5.5 | Apache-2.0 |
| vue-echarts | 7.0 | MIT |
| @tanstack/vue-query | 5.51 | MIT |
| highlight.js | 11.10 | BSD-3-Clause |
| markdown-it | 14.1 | MIT |
| vee-validate | 4.13 | MIT |
| zod | 3.23 | MIT |

## 前端（npm）— 开发 / 测试

来源：[agent1-web/package.json](agent1-web/package.json) `devDependencies`

| 组件 | 版本（约） | 许可证 |
|------|-----------|--------|
| vite | 5.4 | MIT |
| @vitejs/plugin-vue | 5.1 | MIT |
| typescript | 5.5 | Apache-2.0 |
| vue-tsc | 2.0 | MIT |
| vitest | 2.0 | MIT |
| @vue/test-utils | 2.4 | MIT |
| @testing-library/vue | 8.1 | MIT |
| msw | 2.4 | MIT |
| jsdom | 24.1 | MIT |
| @playwright/test | 1.46 | Apache-2.0 |
| eslint | 10.7 | MIT |
| eslint-plugin-vue | 10.10 | MIT |
| @vue/eslint-config-typescript | 14.9 | MIT |
| @vue/eslint-config-prettier | 10.2 | MIT |
| prettier | 3.9 | MIT |
| tailwindcss | 3.4 | MIT |
| postcss | 8.4 | MIT |
| autoprefixer | 10.4 | MIT |
| husky | 9.1 | MIT |
| lint-staged | 16.4 | MIT |
| @commitlint/cli | 21.2 | MIT |
| @commitlint/config-conventional | 21.2 | MIT |
| @types/markdown-it | 14.1 | MIT |

## 旁路（task-email MCP）

来源：[task-email/package.json](task-email/package.json)（非评委演示主路径）

| 组件 | 版本（约） | 许可证 |
|------|-----------|--------|
| @modelcontextprotocol/sdk | 1.12 | MIT |
| nodemailer | 6.9 | MIT |
