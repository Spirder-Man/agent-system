// ============================================================
// P2: 知识库管理 API 模块
// 对齐后端 KnowledgeBaseController 端点。
// ============================================================

import { get, post, put } from './client';
import type {
  SearchModeResponse,
  SearchModeUpdateRequest,
  RagTestRequest,
  RagTestResponse,
  IncrementalLoadResponse,
} from '../types/api';

export const knowledgeBaseApi = {
  /** 获取当前检索模式 */
  getSearchMode: () => get<SearchModeResponse>('/api/knowledgebase/search-mode'),

  /** 切换检索模式（当前会话有效） */
  setSearchMode: (data: SearchModeUpdateRequest) =>
    put<{ previous: string; current: string; warning: string }>(
      '/api/knowledgebase/search-mode',
      data,
    ),

  /** 执行 RAG 检索测试 */
  ragTest: (data: RagTestRequest) =>
    post<RagTestResponse>('/api/knowledgebase/rag-test', data),

  /** 触发知识库增量更新 */
  incrementalLoad: () =>
    post<IncrementalLoadResponse>('/api/knowledgebase/incremental-load'),
};
