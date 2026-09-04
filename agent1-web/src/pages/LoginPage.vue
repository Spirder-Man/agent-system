<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from '@/stores/auth';

const router = useRouter();
const route = useRoute();
const auth = useAuthStore();
const username = ref('');
const password = ref('');
const loading = ref(false);
const errorMsg = ref('');
const showPassword = ref(false);
const rememberMe = ref(false);
const activeLoginTab = ref<'password' | 'sso' | 'qrcode'>('password');

async function handleLogin() {
  errorMsg.value = '';
  if (!username.value.trim() || !password.value.trim()) {
    errorMsg.value = '请输入用户名和密码';
    return;
  }
  loading.value = true;

  const isDevMode = import.meta.env.DEV;
  if (isDevMode) {
    const mockUser = {
      token: 'dev-mock-token-' + Date.now(),
      refreshToken: 'dev-mock-refresh-' + Date.now(),
      username: username.value.trim() || 'admin',
      role: (username.value.trim() as 'admin' | 'auditor' | 'viewer') || 'admin',
      expiresAt: new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString(),
    };
    auth.setAuth(mockUser);
    loading.value = false;
    router.push((route.query.redirect as string) || '/dashboard');
    return;
  }

  const ok = await auth.login({ username: username.value.trim(), password: password.value });
  loading.value = false;
  if (ok) router.push((route.query.redirect as string) || '/dashboard');
}

const particles = ref<{ x: number; y: number; size: number; speedX: number; speedY: number; opacity: number }[]>([]);
let animationFrameId: number;

function initParticles() {
  const arr = [];
  for (let i = 0; i < 60; i++) {
    arr.push({
      x: Math.random() * 100,
      y: Math.random() * 100,
      size: Math.random() * 2 + 0.5,
      speedX: (Math.random() - 0.5) * 0.02,
      speedY: (Math.random() - 0.5) * 0.02,
      opacity: Math.random() * 0.4 + 0.1,
    });
  }
  particles.value = arr;
}

function animateParticles() {
  particles.value = particles.value.map(p => {
    let newX = p.x + p.speedX;
    let newY = p.y + p.speedY;
    if (newX < 0) newX = 100;
    if (newX > 100) newX = 0;
    if (newY < 0) newY = 100;
    if (newY > 100) newY = 0;
    return { ...p, x: newX, y: newY };
  });
  animationFrameId = requestAnimationFrame(animateParticles);
}

onMounted(() => {
  initParticles();
  animateParticles();
});

onUnmounted(() => {
  if (animationFrameId) cancelAnimationFrame(animationFrameId);
});
</script>

<template>
  <div class="login-page">
    <!-- ① 背景图层 -->
    <div class="login-background" />

    <!-- ② 背景装饰层 -->
    <div class="background-overlay" />
    <div class="particles-container">
      <div
        v-for="(p, i) in particles"
        :key="i"
        class="particle"
        :style="{
          left: p.x + '%',
          top: p.y + '%',
          width: p.size + 'px',
          height: p.size + 'px',
          opacity: p.opacity,
        }"
      />
    </div>

    <!-- ③ 左侧品牌展示 -->
    <section class="brand-panel">
      <div class="hero-section">
        <h1 class="main-title">化工智能生产运营中心</h1>
        <p class="brand-slogan">数据驱动 · 智能决策 · 安全合规 · 高效运营</p>
        <p class="sub-title">Chemical Intelligent Production Operation Center V2.3</p>
      </div>

      <div class="features-section">
        <div class="feature-item">
          <div class="feature-icon icon-green">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
          </div>
          <div class="feature-content">
            <span class="feature-title">智能感知</span>
            <span class="feature-desc">实时监控生产全流程</span>
          </div>
        </div>
        <div class="feature-item">
          <div class="feature-icon icon-blue">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
            </svg>
          </div>
          <div class="feature-content">
            <span class="feature-title">数据驱动</span>
            <span class="feature-desc">多维分析辅助决策</span>
          </div>
        </div>
        <div class="feature-item">
          <div class="feature-icon icon-purple">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/>
            </svg>
          </div>
          <div class="feature-content">
            <span class="feature-title">高效协同</span>
            <span class="feature-desc">保障生产安全稳定</span>
          </div>
        </div>
        <div class="feature-item">
          <div class="feature-icon icon-cyan">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
            </svg>
          </div>
          <div class="feature-content">
            <span class="feature-title">合规管理</span>
            <span class="feature-desc">全流程合规管控</span>
          </div>
        </div>
      </div>

      <div class="hud-section">
        <div class="hud-card">
          <div class="hud-label">生产负荷</div>
          <div class="hud-value">78.5%</div>
          <div class="hud-trend trend-up">↑ 5.2%</div>
        </div>
        <div class="hud-card">
          <div class="hud-label">合规率</div>
          <div class="hud-value">98.6%</div>
          <div class="hud-trend trend-up">较昨日 ↑ 1.3%</div>
        </div>
        <div class="hud-card">
          <div class="hud-label">能耗监控</div>
          <div class="hud-value">1,256 <span class="hud-unit">kWh</span></div>
          <div class="hud-trend trend-down">较昨日 ↓ 2.1%</div>
        </div>
        <div class="hud-card hud-card-status">
          <div class="hud-label">设备运行状态</div>
          <div class="hud-status-list">
            <div class="hud-status-item">
              <span class="hud-status-dot dot-green" />
              <span>运行设备</span>
              <span class="hud-status-num">128 台</span>
            </div>
            <div class="hud-status-item">
              <span class="hud-status-dot dot-blue" />
              <span>待机设备</span>
              <span class="hud-status-num">12 台</span>
            </div>
            <div class="hud-status-item">
              <span class="hud-status-dot dot-red" />
              <span>报警设备</span>
              <span class="hud-status-num">3 台</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ④ 右侧登录 -->
    <section class="login-panel">
      <div class="login-card">
        <div class="shield-decoration">
          <svg class="security-icon" viewBox="0 0 100 100" fill="none">
            <defs>
              <filter id="glow">
                <feGaussianBlur stdDeviation="5" result="coloredBlur"/>
                <feMerge>
                  <feMergeNode in="coloredBlur"/>
                  <feMergeNode in="SourceGraphic"/>
                </feMerge>
              </filter>
              <linearGradient id="shieldGradient" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0%" stop-color="#93C5FD"/>
                <stop offset="50%" stop-color="#60A5FA"/>
                <stop offset="100%" stop-color="#3B82F6"/>
              </linearGradient>
            </defs>
            <circle cx="50" cy="52" r="38" fill="#60A5FA" opacity="0.2" filter="url(#glow)"/>
            <g class="orbit-ring">
              <ellipse cx="50" cy="52" rx="42" ry="35" fill="none" stroke="#93C5FD" stroke-width="1.5" opacity="0.5"/>
              <ellipse cx="50" cy="52" rx="35" ry="40" fill="none" stroke="#BFDBFE" stroke-width="1" opacity="0.6"/>
            </g>
            <circle cx="15" cy="52" r="3.5" fill="#60A5FA" opacity="0.9"/>
            <circle cx="85" cy="52" r="3.5" fill="#60A5FA" opacity="0.9"/>
            <circle cx="50" cy="15" r="3" fill="#93C5FD" opacity="0.7"/>
            <circle cx="50" cy="89" r="3" fill="#93C5FD" opacity="0.7"/>
            <path d="M50 22 L75 28 C75 28 78 30 78 35 L76 55 C75 72 50 82 50 82 C50 82 25 72 24 55 L22 35 C22 30 25 28 25 28 L50 22 Z"
                  fill="url(#shieldGradient)"
                  stroke="#DBEAFE"
                  stroke-width="2"
                  opacity="0.9"/>
            <rect x="41" y="48" width="18" height="22" rx="4" fill="white" opacity="0.95"/>
            <path d="M45 48 V40 C45 32 55 32 55 40 V48"
                  fill="none"
                  stroke="white"
                  stroke-width="3.5"
                  stroke-linecap="round"
                  opacity="0.95"/>
            <circle cx="50" cy="54" r="2" fill="#3B82F6"/>
          </svg>
        </div>

        <div class="welcome-header">
          <h2 class="welcome-title">欢迎登录</h2>
          <p class="welcome-subtitle">请使用您的账号登录系统</p>
        </div>

        <form @submit.prevent="handleLogin" class="login-form">
          <transition name="shake">
            <div v-if="errorMsg" class="error-alert">
              <svg class="error-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"/>
              </svg>
              <span>{{ errorMsg }}</span>
            </div>
          </transition>

          <div class="form-group">
            <label class="form-label">用户名</label>
            <div class="input-wrapper">
              <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/>
              </svg>
              <input v-model="username" type="text" class="form-input" placeholder="请输入用户名" autocomplete="username" />
            </div>
          </div>

          <div class="form-group">
            <label class="form-label">密码</label>
            <div class="input-wrapper">
              <svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
              </svg>
              <input v-model="password" :type="showPassword ? 'text' : 'password'" class="form-input" placeholder="请输入密码" autocomplete="current-password" />
              <button type="button" @click="showPassword = !showPassword" class="toggle-password">
                <svg v-if="!showPassword" class="eye-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z"/>
                  <path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
                <svg v-else class="eye-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88"/>
                </svg>
              </button>
            </div>
          </div>

          <div class="form-options">
            <label class="remember-me">
              <input type="checkbox" v-model="rememberMe" class="checkbox-input" />
              <span class="checkbox-custom"></span>
              <span class="remember-text">记住我</span>
            </label>
            <a href="#" class="forgot-link">忘记密码?</a>
          </div>

          <button type="submit" :disabled="loading" class="login-button">
            <span v-if="loading" class="loading-content">
              <svg class="spinner" viewBox="0 0 24 24" fill="none">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
              </svg>
              登录中...
            </span>
            <span v-else>登 录</span>
          </button>
        </form>

        <div class="other-login">
          <div class="divider">
            <span class="divider-line"></span>
            <span class="divider-text">其他登录方式</span>
            <span class="divider-line"></span>
          </div>
          <div class="login-tabs">
            <button :class="['tab-btn', { active: activeLoginTab === 'password' }]" @click="activeLoginTab = 'password'">
              <div class="tab-icon icon-account">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"/>
                </svg>
              </div>
              <span class="tab-label">账号登录</span>
            </button>
            <button :class="['tab-btn', { active: activeLoginTab === 'sso' }]" @click="activeLoginTab = 'sso'">
              <div class="tab-icon icon-sso">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  <path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                </svg>
              </div>
              <span class="tab-label">SSO登录</span>
            </button>
            <button :class="['tab-btn', { active: activeLoginTab === 'qrcode' }]" @click="activeLoginTab = 'qrcode'">
              <div class="tab-icon icon-qrcode">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="3" y="3" width="7" height="7" rx="1"/>
                  <rect x="14" y="3" width="7" height="7" rx="1"/>
                  <rect x="3" y="14" width="7" height="7" rx="1"/>
                  <rect x="14" y="14" width="7" height="7" rx="1"/>
                </svg>
              </div>
              <span class="tab-label">扫码登录</span>
            </button>
          </div>
        </div>
      </div>
    </section>

    <!-- ⑤ 底部 -->
    <footer class="login-footer">
      © 2024 Agent1 化工智能生产运营中心
    </footer>
  </div>
</template>

<style scoped>
::-webkit-scrollbar { display: none; }
html, body { overflow: auto; scrollbar-width: none; -ms-overflow-style: none; }

/* ① 页面容器 */
.login-page {
  min-height: 100vh; min-width: 100vw; position: relative;
  display: flex; align-items: center;
  justify-content: center; box-sizing: border-box;
  padding: 8px 0 40px 0;
}

/* ① 背景图层 */
.login-background {
  position: absolute; inset: 0;
  background-image: url('@/assets/denglubeijing.png');
  background-size: cover; background-position: center;
  background-repeat: no-repeat; z-index: 0;
}

/* ② 背景装饰层 */
.background-overlay {
  position: absolute; inset: 0; z-index: 1;
  background: linear-gradient(135deg, rgba(255,255,255,0.15) 0%, rgba(200,220,255,0.08) 30%, rgba(255,255,255,0.12) 70%, rgba(255,255,255,0.18) 100%);
}
.particles-container { position: absolute; inset: 0; pointer-events: none; z-index: 2; }
.particle {
  position: absolute; border-radius: 50%;
  background: linear-gradient(135deg, #93c5fd, #60a5fa);
  box-shadow: 0 0 6px rgba(147,197,253,0.4);
}

/* ③ 左侧品牌展示 */
.brand-panel {
  position: relative; z-index: 3; display: flex; flex-direction: column;
  padding: 8px 56px; width: 55%; justify-self: stretch; align-self: stretch;
  justify-content: center;
}
.hero-section { margin-top: 0; text-align: left; }
.main-title { font-size: 36px; font-weight: 700; color: #123B78; margin: 0 0 8px 0; letter-spacing: -0.5px; line-height: 1.2; }
.brand-slogan { font-size: 16px; color: #315B91; margin: 0 0 4px 0; font-weight: 400; }
.sub-title { font-size: 12px; color: #7A96B8; margin: 0; font-weight: 400; letter-spacing: 0.5px; }

.features-section { display: flex; flex-direction: column; gap: 12px; margin-top: 20px; }
.feature-item { display: flex; align-items: center; gap: 12px; }
.feature-icon {
  width: 36px; height: 36px; border-radius: 10px;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.feature-icon svg { width: 18px; height: 18px; }
.icon-green { background: linear-gradient(135deg, #d1fae5, #a7f3d0); color: #059669; }
.icon-blue { background: linear-gradient(135deg, #dbeafe, #bfdbfe); color: #2563eb; }
.icon-purple { background: linear-gradient(135deg, #ede9fe, #ddd6fe); color: #7c3aed; }
.icon-cyan { background: linear-gradient(135deg, #cffafe, #a5f3fc); color: #0891b2; }
.feature-content { display: flex; flex-direction: column; gap: 2px; }
.feature-title { font-size: 15px; font-weight: 600; color: #334155; }
.feature-desc { font-size: 13px; color: #5d6b7e; font-weight: 500; }

/* HUD 数据卡 */
.hud-section { display: flex; gap: 12px; margin-top: 24px; flex-wrap: wrap; }
.hud-card {
  background: rgba(255,255,255,0.12); backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px); border: 1px solid rgba(255,255,255,0.35);
  border-radius: 12px; padding: 12px 16px; min-width: 120px; flex: 1;
}
.hud-card-status { min-width: 180px; }
.hud-label { font-size: 12px; color: #64748b; margin-bottom: 4px; font-weight: 500; }
.hud-value { font-size: 21px; font-weight: 700; color: #1e293b; line-height: 1.2; }
.hud-unit { font-size: 13px; font-weight: 400; color: #64748b; }
.hud-trend { font-size: 11px; margin-top: 2px; }
.trend-up { color: #059669; }
.trend-down { color: #dc2626; }
.hud-status-list { display: flex; flex-direction: column; gap: 8px; margin-top: 4px; }
.hud-status-item { display: flex; align-items: center; gap: 6px; font-size: 13px; color: #475569; }
.hud-status-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.dot-green { background: #059669; box-shadow: 0 0 4px rgba(5,150,105,0.4); }
.dot-blue { background: #3b82f6; box-shadow: 0 0 4px rgba(59,130,246,0.4); }
.dot-red { background: #dc2626; box-shadow: 0 0 4px rgba(220,38,38,0.4); animation: hudBlink 1.5s ease-in-out infinite; }
@keyframes hudBlink { 0%,100%{opacity:1} 50%{opacity:0.4} }
.hud-status-num { margin-left: auto; font-weight: 600; color: #1e293b; }

/* ④ 右侧登录 */
.login-panel {
  position: relative; z-index: 3; display: flex;
  align-items: center; justify-content: center;
  width: 45%; padding: 8px 40px; align-self: stretch;
}
.login-card {
  width: 100%; max-width: 480px;
  background: rgba(255,255,255,0.92); backdrop-filter: blur(20px);
  border-radius: 24px; padding: 32px 36px;
  box-shadow: 0 20px 60px rgba(30,90,160,0.12);
  border: 1px solid rgba(226,232,240,0.6);
  position: relative; animation: cardSlideUp 0.7s ease-out;
}
@keyframes cardSlideUp {
  0% { opacity: 0; transform: translateY(30px); }
  100% { opacity: 1; transform: translateY(0); }
}
.shield-decoration { position: absolute; top: 24px; right: 20px; width: 68px; height: 68px; }
.security-icon { width: 100%; height: 100%; }
@keyframes rotate { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.orbit-ring { animation: rotate 20s linear infinite; transform-origin: 50px 50px; }
@keyframes pulse { 0%,100% { opacity: 0.7; transform: scale(1); } 50% { opacity: 1; transform: scale(1.2); } }
.security-icon circle:nth-child(n+8) { animation: pulse 3s ease-in-out infinite; transform-origin: center; }
.security-icon circle:nth-child(8) { animation-delay: 0s; }
.security-icon circle:nth-child(9) { animation-delay: 0.75s; }
.security-icon circle:nth-child(10) { animation-delay: 1.5s; }
.security-icon circle:nth-child(11) { animation-delay: 2.25s; }

.welcome-header { margin-bottom: 18px; }
.welcome-title { font-size: 26px; font-weight: 700; color: #0f172a; margin: 0 0 6px 0; letter-spacing: -0.5px; }
.welcome-subtitle { font-size: 14px; color: #94a3b8; margin: 0; }

.login-form { display: flex; flex-direction: column; gap: 14px; }
.error-alert {
  display: flex; align-items: center; gap: 8px; padding: 10px 12px;
  background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px;
  color: #dc2626; font-size: 13px;
}
.error-icon { width: 16px; height: 16px; flex-shrink: 0; }
.form-group { display: flex; flex-direction: column; gap: 6px; }
.form-label { font-size: 14px; font-weight: 500; color: #334155; }
.input-wrapper { position: relative; display: flex; align-items: center; }
.input-icon {
  position: absolute; left: 14px; width: 18px; height: 18px;
  color: #94a3b8; pointer-events: none;
}
.form-input {
  width: 100%; height: 46px; padding: 0 14px 0 44px; font-size: 14px;
  color: #0f172a; background: #f8fafc; border: 1.5px solid #e2e8f0;
  border-radius: 10px; transition: all 0.2s ease; outline: none;
}
.form-input:hover { background: #ffffff; border-color: #cbd5e1; }
.form-input:focus { background: #ffffff; border-color: #3b82f6; box-shadow: 0 0 0 3px rgba(59,130,246,0.1); }
.form-input::placeholder { color: #94a3b8; }
.toggle-password {
  position: absolute; right: 14px; width: 20px; height: 20px;
  display: flex; align-items: center; justify-content: center;
  background: none; border: none; cursor: pointer; color: #94a3b8;
  transition: color 0.2s ease;
}
.toggle-password:hover { color: #64748b; }
.eye-icon { width: 18px; height: 18px; }

.form-options { display: flex; align-items: center; justify-content: space-between; }
.remember-me { display: flex; align-items: center; gap: 8px; cursor: pointer; }
.checkbox-input { display: none; }
.checkbox-custom {
  width: 16px; height: 16px; border: 1.5px solid #cbd5e1; border-radius: 4px;
  display: flex; align-items: center; justify-content: center; transition: all 0.2s ease;
}
.checkbox-input:checked + .checkbox-custom { background: #3b82f6; border-color: #3b82f6; }
.checkbox-input:checked + .checkbox-custom::after {
  content: ''; width: 5px; height: 8px; border: solid white;
  border-width: 0 2px 2px 0; transform: rotate(45deg);
}
.remember-text { font-size: 13px; color: #64748b; }
.forgot-link { font-size: 13px; color: #3b82f6; text-decoration: none; transition: color 0.2s ease; }
.forgot-link:hover { color: #2563eb; }

.login-button {
  width: 100%; height: 48px; font-size: 15px; font-weight: 600; color: white;
  background: linear-gradient(135deg, #3b82f6 0%, #2563eb 50%, #1d4ed8 100%);
  border: none; border-radius: 10px; cursor: pointer;
  transition: all 0.3s ease; box-shadow: 0 4px 14px rgba(59,130,246,0.35);
  position: relative; overflow: hidden;
}
.login-button::before {
  content: ''; position: absolute; top: 0; left: -100%; width: 100%; height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent);
  transition: left 0.5s ease;
}
.login-button:hover::before { left: 100%; }
.login-button:hover { transform: translateY(-1px); box-shadow: 0 6px 20px rgba(59,130,246,0.45); }
.login-button:active { transform: translateY(0); }
.login-button:disabled { opacity: 0.6; cursor: not-allowed; transform: none; }
.loading-content { display: flex; align-items: center; justify-content: center; gap: 8px; }
.spinner { width: 18px; height: 18px; animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

.other-login { margin-top: 18px; }
.divider { display: flex; align-items: center; gap: 12px; margin-bottom: 14px; }
.divider-line { flex: 1; height: 1px; background: #e2e8f0; }
.divider-text { font-size: 12px; color: #94a3b8; }
.login-tabs { display: flex; justify-content: center; gap: 32px; }
.tab-btn {
  display: flex; flex-direction: column; align-items: center; gap: 8px;
  background: none; border: none; cursor: pointer; transition: all 0.2s ease;
}
.tab-btn:hover .tab-icon { transform: scale(1.05); }
.tab-icon {
  width: 44px; height: 44px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center; transition: all 0.2s ease;
}
.tab-icon svg { width: 20px; height: 20px; }
.icon-account { background: linear-gradient(135deg, #d1fae5, #a7f3d0); color: #059669; }
.icon-sso { background: linear-gradient(135deg, #dbeafe, #bfdbfe); color: #2563eb; }
.icon-qrcode { background: linear-gradient(135deg, #ffedd5, #fed7aa); color: #ea580c; }
.tab-btn.active .icon-account { background: linear-gradient(135deg, #059669, #047857); color: white; box-shadow: 0 4px 12px rgba(5,150,105,0.3); }
.tab-btn.active .icon-sso { background: linear-gradient(135deg, #2563eb, #1d4ed8); color: white; box-shadow: 0 4px 12px rgba(37,99,235,0.3); }
.tab-btn.active .icon-qrcode { background: linear-gradient(135deg, #ea580c, #c2410c); color: white; box-shadow: 0 4px 12px rgba(234,88,12,0.3); }
.tab-label { font-size: 12px; color: #64748b; }

/* 错误抖动动画 */
.shake-enter-active { animation: shake 0.5s ease; }
@keyframes shake {
  0%, 100% { transform: translateX(0); }
  20% { transform: translateX(-8px); }
  40% { transform: translateX(8px); }
  60% { transform: translateX(-4px); }
  80% { transform: translateX(4px); }
}

/* ⑤ 底部 */
.login-footer {
  position: absolute; bottom: 10px; left: 80px; z-index: 3;
  font-size: 12px; color: #94a3b8;
}

/* 响应式：中等屏让两栏左右排列并保持品牌信息可见 */
@media (max-width: 1080px) {
  .brand-panel { padding: 8px 32px; }
  .login-panel { padding: 8px 24px; }
  .login-card { padding: 26px 28px; }
  .main-title { font-size: 28px; }
  .brand-slogan { font-size: 14px; }
}

/* 窄屏：上下堆叠，品牌信息浓缩为顶部横条，仍全部展示在一屏 */
@media (max-width: 860px) {
  .login-page { flex-direction: column; justify-content: flex-start; }
  .brand-panel {
    width: 100%; padding: 18px 20px 14px 20px; align-items: center;
    text-align: center; justify-content: flex-start; flex: none;
  }
  .hero-section { text-align: center; }
  .main-title { font-size: 22px; margin-bottom: 4px; }
  .brand-slogan { font-size: 13px; }
  .sub-title { font-size: 11px; }
  .features-section { display: none; }
  .hud-section { margin-top: 14px; gap: 8px; }
  .hud-card { padding: 8px 12px; min-width: 0; }
  .hud-value { font-size: 17px; }
  .hud-card-status, .hud-trend { display: none; }
  .login-panel { width: 100%; padding: 8px 16px 28px 16px; }
  .login-card { max-width: 440px; padding: 24px 24px; }
  .shield-decoration { width: 56px; height: 56px; top: 14px; right: 12px; }
  .login-footer { left: 50%; transform: translateX(-50%); bottom: 6px; }
}
</style>
