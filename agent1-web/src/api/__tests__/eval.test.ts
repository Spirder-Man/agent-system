import { describe, it, expect, vi } from 'vitest';
import { evalApi } from '../eval';

const mockGet = vi.fn();
const mockPost = vi.fn();
const mockDel = vi.fn();

vi.mock('../client', () => ({
  get: (...args: unknown[]) => mockGet(...args),
  post: (...args: unknown[]) => mockPost(...args),
  put: vi.fn(),
  del: (...args: unknown[]) => mockDel(...args),
}));

describe('evalApi', () => {
  it('run 应调用 POST /api/eval/run', () => {
    evalApi.run();
    expect(mockPost).toHaveBeenCalledWith('/api/eval/run');
  });

  it('getStatus 应调用 GET /api/eval/status/{taskId}', () => {
    evalApi.getStatus('abc123');
    expect(mockGet).toHaveBeenCalledWith('/api/eval/status/abc123');
  });

  it('cancel 应调用 DELETE /api/eval/status/{taskId}', () => {
    evalApi.cancel('abc123');
    expect(mockDel).toHaveBeenCalledWith('/api/eval/status/abc123');
  });
});
