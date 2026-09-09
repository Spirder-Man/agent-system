# 安全说明

公开作品名 **苍卫**（工程名 Agent1 / `agent-system`）。本仓库是开源审查辅助，**不是**已定级、已备案或已测评的等保对象，见 [docs/platform/等级保护口径.md](docs/platform/等级保护口径.md)。

## 请勿公开开 Issue 的情况

下列内容不要写进公开 Issue、PR 或讨论区：

- 可导致未授权访问、越权、注入、任意文件读写的细节（在修复发布前）
- `.env`、JWT、`JWT_KEY`、数据库口令、`AUTH_ACCOUNTS_JSON`
- 国家标准全文、企业内部未公开制度
- 真实园区 / 生产业务数据、可识别个人的日志

演示账号 `admin` / `changeme` 仅本地。生产必须改口令与密钥，且不要提交 `.env`。

## 如何私下报告

未公开邮箱。任选其一：

1. **GitHub**：仓库 [Security Advisories](https://github.com/Spirder-Man/agent-system/security/advisories/new)（Private vulnerability reporting）。
2. **Gitee**：私信仓库所有者（[liuchao_yue/agent-system](https://gitee.com/liuchao_yue/agent-system)），标题标明「安全漏洞」，不要贴完整利用步骤到公开区。

报告里请写：影响版本或 commit、复现所需权限、危害（例如能否绕过 JWT / 改审计链）。能附脱敏日志更好。维护者收到后会确认是否受理；小团队，请以工作日计，不要默认小时级响应。

## 使用方自己要做的

- 生产禁用文档中的演示口令；`JWT_KEY` 不少于 32 字符。
- 国标正文由使用方自备合法副本，不要推进 Git。
- 应用层哈希链与三角色是最小权限雏形，不能代替定级、备案、测评或密码模块。
