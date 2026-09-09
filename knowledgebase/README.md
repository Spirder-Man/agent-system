# 知识库：克隆之后有什么、没有什么

桌面上的 `化工知识库`（国标全文等）**不是 Git 仓库的一部分**，远程 `git clone` 不会拿到那份目录。这是有意的：国家标准全文不能进公开仓。

数据分三层。评委无 GPU 验收（甲醇 × 硝酸禁配）只用第 1 层，**不依赖**第 2、3 层，也**不依赖**向量入库。

| 层 | 是什么 | 进不进 Git | 远程克隆后 |
|----|--------|------------|------------|
| 1. 结构化种子 | 危化品名称 / CAS / 禁忌配对 / 安全距离 / 法规号白名单 | **进** `init_database.sql`、`db/migrations/002_chemical_knowledge_graph.sql` | compose 第一次起库会自动灌入。储存兼容性走规则引擎，不读国标 PDF |
| 2. 可公开样例 | 虚构「XX园区」规定、演示案例 | **进** 本目录 `园区规则/`、`历史案例/` | 克隆即有，可供 BM25 / 知识库页演示 |
| 3. 国标全文与向量 | GB 15603、GB 30000 等正文；`knowledge_chunks` 里的 embedding | **不进**。向量是运行时算出来的，不是随仓库下发的数据包 | 自备合法副本放到 `国标/`（或 `.env` 的 `KNOWLEDGE_BASE_PATH` 指向本机语料）。有 GPU 且 8081 embed 健康时才会写入向量 |

本机完整语料若在仓库外，只在 `.env` 写绝对路径（不要提交 `.env`）：

```
KNOWLEDGE_BASE_PATH=（本机语料目录的绝对路径）
```

不要把该路径提交进 Git。容器内进程看到的仍是 `/app/knowledgebase`。

## 目录约定

```
knowledgebase/
  README.md                 # 本说明
  国标/README.md            # 只说明如何自备，不含标准正文
  化工专业条例/README.md
  园区规则/                 # 仓库内虚构样例
  历史案例/                 # 仓库内虚构样例
```

缺第 3 层时：API 仍启动；`/health` 里 `knowledge_base_docs` 可能只有样例条数；RAG 向量召回差或仅 BM25。不要因此认为甲醇 × 硝酸验收失败。

不要把国标 PDF/TXT 或企业内部制度 `git add` 进本仓库。离线大赛包若含语料，在仓库外的 `cpu/knowledgebase`，见 [开源项目分发落地方案](../docs/infra/deploy/开源项目分发落地方案.md)。模块边界见 [docs/knowledgebase/说明书.md](../docs/knowledgebase/说明书.md)。
