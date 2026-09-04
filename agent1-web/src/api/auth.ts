import { post } from './client';
import type { LoginRequest, LoginResponse, RefreshRequest } from '../types/api';

export const authApi = {
  login: (data: LoginRequest) =>
    post<LoginResponse>('/api/auth/login', data),

  refresh: (data: RefreshRequest) =>
    post<LoginResponse>('/api/auth/refresh', data),

  logout: () =>
    post<void>('/api/auth/logout'),
};
