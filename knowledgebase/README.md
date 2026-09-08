# 法规语料（不进 Git）

API 容器将本目录（或 `.env` 的 `KNOWLEDGE_BASE_PATH`）挂载为 `/app/knowledgebase`。  
**国家标准全文不在本仓库。** 使用方自备合法副本。开源仓只含 schema 与危化品结构化种子，见根 README「边界」。

建议子目录（与现有摄入约定一致）：

```
knowledgebase/
  国标/              # 国标 PDF 等，自备
  化工专业条例/
  园区规则/
  历史案例/
```

缺语料时服务仍可启动，`/health` 里 `knowledge_base_docs` 可能为 0，RAG 命中差。不要把国标 PDF 或企业内部制度提交进 Git。
