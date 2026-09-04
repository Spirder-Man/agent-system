import { describe, it, expect, vi } from 'vitest';
import { adminApi } from '../admin';

const mockGet = vi.fn();

vi.mock('../client', () => ({
  get: (...args: unknown[]) => mockGet(...args),
  post: vi.fn(),
  put: vi.fn(),
  del: vi.fn(),
}));

describe('adminApi', () => {
  it('getDbInfo 应调用 GET /api/admin/db/info', () => {
    adminApi.getDbInfo();
    expect(mockGet).toHaveBeenCalledWith('/api/admin/db/info');
  });

  it('validateDb 应调用 GET /api/admin/db/validate', () => {
    adminApi.validateDb();
    expect(mockGet).toHaveBeenCalledWith('/api/admin/db/validate');
  });
});
