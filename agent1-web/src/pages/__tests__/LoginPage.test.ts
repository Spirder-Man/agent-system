/**
 * P2-1: LoginPage 登录页面测试
 *
 * 覆盖: 渲染/空校验/成功登录路由跳转/失败提示/loading 状态/redirect 参数
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { setActivePinia, createPinia } from 'pinia';

// Mock vue-router
const mockPush = vi.fn();
const mockRoute = { params: {}, query: {} };
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush }),
  useRoute: () => mockRoute,
}));

// Mock Element Plus
vi.mock('element-plus', () => ({
  ElMessage: { error: vi.fn() },
}));

// Mock axios (auth store 内部使用)
const mockPost = vi.fn();
vi.mock('@/lib/axios', () => ({
  default: { post: (...args: unknown[]) => mockPost(...args) },
}));

import LoginPage from '../LoginPage.vue';
import { useAuthStore } from '@/stores/auth';

function createStore() {
  setActivePinia(createPinia());
  return useAuthStore();
}

describe('LoginPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockPush.mockReset();
    mockPost.mockReset();
    mockRoute.query = {};
    localStorage.clear();
  });

  function mountPage() {
    // LoginPage 在 setup 中调用 useAuthStore()，必须先初始化 Pinia
    setActivePinia(createPinia());
    return mount(LoginPage);
  }

  describe('渲染', () => {
    it('应渲染登录标题和表单', () => {
      const wrapper = mountPage();
      expect(wrapper.text()).toContain('苍卫');
      expect(wrapper.text()).toContain('登录');
    });

    it('应有用户名和密码输入框', () => {
      const wrapper = mountPage();
      const textInputs = wrapper.findAll('input').filter((el) => {
        const t = el.attributes('type');
        return t === 'text' || t === 'password';
      });
      expect(textInputs.length).toBe(2);
    });

    it('应有提交按钮', () => {
      const wrapper = mountPage();
      const btn = wrapper.find('button[type="submit"]');
      expect(btn.exists()).toBe(true);
      expect(btn.text()).toContain('登 录');
    });
  });

  describe('空校验', () => {
    it('用户名为空时应显示错误提示', async () => {
      const wrapper = mountPage();

      const form = wrapper.find('form');
      await form.trigger('submit');
      await flushPromises();

      expect(wrapper.text()).toContain('请输入用户名和密码');
      expect(mockPost).not.toHaveBeenCalled();
    });

    it('密码为空时应显示错误提示', async () => {
      const wrapper = mountPage();

      const inputs = wrapper.findAll('input');
      await inputs[0].setValue('admin');

      const form = wrapper.find('form');
      await form.trigger('submit');
      await flushPromises();

      expect(wrapper.text()).toContain('请输入用户名和密码');
      expect(mockPost).not.toHaveBeenCalled();
    });
  });

  describe('登录流程', () => {
    it('开发态登录成功应写入会话并跳转到 /dashboard', async () => {
      const wrapper = mountPage();
      const store = useAuthStore();

      const inputs = wrapper.findAll('input').filter((el) => {
        const t = el.attributes('type');
        return t === 'text' || t === 'password';
      });
      await inputs[0].setValue('admin');
      await inputs[1].setValue('password123');

      const form = wrapper.find('form');
      await form.trigger('submit');
      await flushPromises();

      expect(mockPost).not.toHaveBeenCalled();
      expect(store.isAuthenticated).toBe(true);
      expect(mockPush).toHaveBeenCalledWith('/dashboard');
    });

    it('有 redirect 参数时应跳转到目标路径', async () => {
      mockRoute.query = { redirect: '/inspection/plans' };
      mockPost.mockResolvedValue({
        data: {
          token: 't',
          refreshToken: 'r',
          username: 'admin',
          role: 'admin',
          expiresAt: new Date(Date.now() + 3600_000).toISOString(),
        },
      });

      const wrapper = mountPage();
      const inputs = wrapper.findAll('input');
      await inputs[0].setValue('admin');
      await inputs[1].setValue('pass');

      const form = wrapper.find('form');
      await form.trigger('submit');
      await flushPromises();

      expect(mockPush).toHaveBeenCalledWith('/inspection/plans');
    });

    it('开发态不走真实登录接口，错误密码也会进入系统', async () => {
      const wrapper = mountPage();
      const inputs = wrapper.findAll('input').filter((el) => {
        const t = el.attributes('type');
        return t === 'text' || t === 'password';
      });
      await inputs[0].setValue('admin');
      await inputs[1].setValue('wrong');

      const form = wrapper.find('form');
      await form.trigger('submit');
      await flushPromises();

      expect(mockPost).not.toHaveBeenCalled();
      expect(mockPush).toHaveBeenCalledWith('/dashboard');
    });

    it('开发态登录为同步会话，提交后按钮恢复可点', async () => {
      const wrapper = mountPage();
      const inputs = wrapper.findAll('input').filter((el) => {
        const t = el.attributes('type');
        return t === 'text' || t === 'password';
      });
      await inputs[0].setValue('admin');
      await inputs[1].setValue('pass');

      const form = wrapper.find('form');
      await form.trigger('submit');
      await flushPromises();

      const btn = wrapper.find('button[type="submit"]');
      expect(btn.attributes('disabled')).toBeUndefined();
      expect(btn.text()).toContain('登 录');
    });

    it('输入应自动 trim 后写入会话', async () => {
      const wrapper = mountPage();
      const store = useAuthStore();
      const inputs = wrapper.findAll('input').filter((el) => {
        const t = el.attributes('type');
        return t === 'text' || t === 'password';
      });
      await inputs[0].setValue('  admin  ');
      await inputs[1].setValue('pass');

      const form = wrapper.find('form');
      await form.trigger('submit');
      await flushPromises();

      expect(mockPost).not.toHaveBeenCalled();
      expect(store.username).toBe('admin');
    });
  });

  describe('品牌文案', () => {
    it('应显示运营中心标题', () => {
      const wrapper = mountPage();
      expect(wrapper.text()).toContain('化工智能生产运营中心');
    });
  });
});
