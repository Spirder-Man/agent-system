import { describe, it, expect, vi } from 'vitest';
import { knowledgeBaseApi } from '../knowledgeBase';

const mockGet = vi.fn();
const mockPost = vi.fn();
const mockPut = vi.fn();

vi.mock('../client', () => ({
  get: (...args: unknown[]) => mockGet(...args),
  post: (...args: unknown[]) => mockPost(...args),
  put: (...args: unknown[]) => mockPut(...args),
}));

describe('knowledgeBaseApi', () => {
  it('getSearchMode 应调用 GET /api/knowledgebase/search-mode', () => {
    knowledgeBaseApi.getSearchMode();
    expect(mockGet).toHaveBeenCalledWith('/api/knowledgebase/search-mode');
  });

  it('setSearchMode 应调用 PUT /api/knowledgebase/search-mode', () => {
    knowledgeBaseApi.setSearchMode({ mode: 'Hybrid' });
    expect(mockPut).toHaveBeenCalledWith('/api/knowledgebase/search-mode', { mode: 'Hybrid' });
  });

  it('ragTest 应调用 POST /api/knowledgebase/rag-test', () => {
    knowledgeBaseApi.ragTest({ query: '苯', topK: 5 });
    expect(mockPost).toHaveBeenCalledWith('/api/knowledgebase/rag-test', { query: '苯', topK: 5 });
  });

  it('incrementalLoad 应调用 POST /api/knowledgebase/incremental-load', () => {
    knowledgeBaseApi.incrementalLoad();
    expect(mockPost).toHaveBeenCalledWith('/api/knowledgebase/incremental-load');
  });
});
