import { describe, it, expect, vi } from 'vitest';
import { auditApi } from '../audit';

const mockGet = vi.fn();

vi.mock('../client', () => ({
  get: (...args: unknown[]) => mockGet(...args),
  post: vi.fn(),
  put: vi.fn(),
  del: vi.fn(),
}));

describe('auditApi', () => {
  it('getLogs 应调用 GET /api/audit/logs 并传递查询参数', () => {
    auditApi.getLogs({ from: '2025-01-01', to: '2025-06-01', user: 'admin', page: 1, pageSize: 20 });
    expect(mockGet).toHaveBeenCalledWith('/api/audit/logs', {
      params: { from: '2025-01-01', to: '2025-06-01', user: 'admin', page: 1, pageSize: 20 },
    });
  });

  it('verifyIntegrity 应调用 GET /api/audit/integrity', () => {
    auditApi.verifyIntegrity();
    expect(mockGet).toHaveBeenCalledWith('/api/audit/integrity');
  });

  it('exportReport 应调用 GET /api/audit/export 并传递时间范围', () => {
    auditApi.exportReport('2025-01-01', '2025-06-01');
    expect(mockGet).toHaveBeenCalledWith('/api/audit/export', {
      params: { from: '2025-01-01', to: '2025-06-01' },
    });
  });

  it('getStats 应调用 GET /api/audit/stats', () => {
    auditApi.getStats();
    expect(mockGet).toHaveBeenCalledWith('/api/audit/stats');
  });
});
