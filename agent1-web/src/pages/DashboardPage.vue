<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue';
import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';
import { LineChart, BarChart, PieChart, GaugeChart } from 'echarts/charts';
import {
  GridComponent, TooltipComponent, LegendComponent, TitleComponent,
  ToolboxComponent, DataZoomComponent, MarkLineComponent
} from 'echarts/components';
import VChart from 'vue-echarts';
import { useAuthStore } from '@/stores/auth';
import apiClient from '@/lib/axios';
import type { DashboardOverview } from '@/types/api';

use([
  CanvasRenderer, LineChart, BarChart, PieChart, GaugeChart,
  GridComponent, TooltipComponent, LegendComponent, TitleComponent,
  ToolboxComponent, DataZoomComponent, MarkLineComponent
]);

const auth = useAuthStore();
const overview = ref<DashboardOverview | null>(null);
const loading = ref(true);
const error = ref('');

// ========== 数字上涨动画工具 ==========
function useCountUp(target: number, duration = 1500, suffix = '') {
  const display = ref('0');
  const isAnimating = ref(false);
  let rafId: number;
  function start() {
    isAnimating.value = true;
    const startTime = performance.now();
    const startVal = 0;
    function step(now: number) {
      const progress = Math.min((now - startTime) / duration, 1);
      const easeOutQuart = 1 - Math.pow(1 - progress, 4);
      const current = startVal + (target - startVal) * easeOutQuart;
      display.value = current.toFixed(target < 10 ? 2 : 0) + suffix;
      if (progress < 1) rafId = requestAnimationFrame(step);
      else isAnimating.value = false;
    }
    rafId = requestAnimationFrame(step);
  }
  onUnmounted(() => cancelAnimationFrame(rafId));
  return { display, start, isAnimating };
}

// ========== 顶部 KPI 数据 ==========
const kpiTargets = [
  { label: '装置运行率', target: 96.8, suffix: '%', trend: '+1.2%', trendUp: true, unit: '目标 ≥95%', icon: 'activity', color: '#059669' },
  { label: '计划完成率', target: 92.4, suffix: '%', trend: '+3.1%', trendUp: true, unit: '月度累计', icon: 'calendar', color: '#2563eb' },
  { label: '安全运行天数', target: 1247, suffix: '', trend: '连续', trendUp: true, unit: '天无事故', icon: 'shield', color: '#0891b2' },
  { label: '质量合格率', target: 99.6, suffix: '%', trend: '+0.3%', trendUp: true, unit: '批次检验', icon: 'check', color: '#7c3aed' },
  { label: '综合能耗', target: 0.82, suffix: '', trend: '-5.2%', trendUp: false, unit: '吨标煤/吨产品', icon: 'zap', color: '#ea580c' },
  { label: '环保达标率', target: 100, suffix: '%', trend: '稳定', trendUp: true, unit: '排放监测', icon: 'leaf', color: '#16a34a' },
];

const kpiDisplays = kpiTargets.map(k => useCountUp(k.target, 2000, k.suffix));
const kpiData = computed(() => kpiTargets.map((k, i) => ({
  ...k,
  value: kpiDisplays[i].display.value,
  isAnimating: kpiDisplays[i].isAnimating.value,
})));

// ========== 工艺流程数据 ==========
const processNodes = ref([
  { id: 'R101', name: '反应釜 R-101', type: 'reactor', x: 120, y: 180, status: 'running', temp: 185, pressure: 2.4, flow: 120 },
  { id: 'T201', name: '精馏塔 T-201', type: 'tower', x: 320, y: 100, status: 'running', temp: 145, pressure: 1.8, flow: 95 },
  { id: 'E301', name: '换热器 E-301', type: 'exchanger', x: 320, y: 260, status: 'running', temp: 85, pressure: 3.2, flow: 150 },
  { id: 'V401', name: '储罐 V-401', type: 'tank', x: 520, y: 180, status: 'warning', temp: 35, pressure: 0.8, flow: 0, level: 78 },
  { id: 'P501', name: '离心泵 P-501', type: 'pump', x: 220, y: 320, status: 'running', temp: 45, pressure: 4.5, flow: 200 },
  { id: 'C601', name: '压缩机 C-601', type: 'compressor', x: 420, y: 320, status: 'stopped', temp: 25, pressure: 0.1, flow: 0 },
  { id: 'F701', name: '过滤器 F-701', type: 'filter', x: 120, y: 80, status: 'running', temp: 40, pressure: 2.0, flow: 110 },
  { id: 'H801', name: '加热炉 H-801', type: 'heater', x: 520, y: 80, status: 'running', temp: 320, pressure: 1.5, flow: 85 },
  { id: 'S901', name: '分离器 S-901', type: 'separator', x: 120, y: 320, status: 'running', temp: 55, pressure: 2.8, flow: 130 },
]);

// 流体粒子动画
const flowParticles = ref([
  { id: 1, linkIndex: 0, progress: 0, speed: 0.008 },
  { id: 2, linkIndex: 0, progress: 0.5, speed: 0.008 },
  { id: 3, linkIndex: 1, progress: 0.2, speed: 0.006 },
  { id: 4, linkIndex: 2, progress: 0, speed: 0.007 },
  { id: 5, linkIndex: 2, progress: 0.6, speed: 0.007 },
  { id: 6, linkIndex: 3, progress: 0.3, speed: 0.005 },
  { id: 7, linkIndex: 4, progress: 0, speed: 0.009 },
  { id: 8, linkIndex: 5, progress: 0.4, speed: 0.004 },
]);

let particleTimer: ReturnType<typeof setInterval> | null = null;
function startParticleAnimation() {
  particleTimer = setInterval(() => {
    flowParticles.value = flowParticles.value.map(p => {
      const newProgress = p.progress + p.speed;
      return { ...p, progress: newProgress >= 1 ? 0 : newProgress };
    });
  }, 50);
}

const processLinks = ref([
  { from: 'R101', to: 'T201', label: '气相' },
  { from: 'R101', to: 'E301', label: '液相' },
  { from: 'T201', to: 'V401', label: '产品' },
  { from: 'E301', to: 'V401', label: '冷凝' },
  { from: 'P501', to: 'R101', label: '进料' },
  { from: 'C601', to: 'T201', label: '回流' },
]);

const selectedNode = ref<typeof processNodes.value[0] | null>(null);

function showNodeDetail(node: typeof processNodes.value[0]) {
  selectedNode.value = node;
}
function closeNodeDetail() {
  selectedNode.value = null;
}
function nodeStatusColor(status: string) {
  return { running: '#059669', warning: '#d97706', stopped: '#6b7280', alarm: '#dc2626' }[status] || '#6b7280';
}
function nodeStatusText(status: string) {
  return { running: '运行中', warning: '预警', stopped: '停机', alarm: '报警' }[status] || '未知';
}

// ========== 实时趋势数据 ==========
const now = new Date();
const timeLabels = Array.from({ length: 12 }, (_, i) => {
  const d = new Date(now.getTime() - (11 - i) * 5 * 60000);
  return d.getHours().toString().padStart(2, '0') + ':' + d.getMinutes().toString().padStart(2, '0');
});

const tempPressureOption = ref({
  backgroundColor: 'transparent',
  tooltip: { trigger: 'axis', axisPointer: { type: 'cross' } },
  legend: { data: ['反应温度', '塔顶压力', '回流温度'], bottom: 0, textStyle: { fontSize: 11, color: '#475569' } },
  grid: { left: '3%', right: '4%', bottom: '15%', top: '10%', containLabel: true },
  xAxis: {
    type: 'category', boundaryGap: false, data: timeLabels,
    axisLine: { lineStyle: { color: '#cbd5e1' } },
    axisLabel: { color: '#64748b', fontSize: 10 }
  },
  yAxis: [
    {
      type: 'value', name: '温度 °C', position: 'left',
      axisLine: { lineStyle: { color: '#cbd5e1' } },
      axisLabel: { color: '#64748b', fontSize: 10 },
      splitLine: { lineStyle: { color: '#f1f5f9' } }
    },
    {
      type: 'value', name: '压力 MPa', position: 'right',
      axisLine: { lineStyle: { color: '#cbd5e1' } },
      axisLabel: { color: '#64748b', fontSize: 10 },
      splitLine: { show: false }
    },
  ],
  series: [
    {
      name: '反应温度', type: 'line', smooth: true, yAxisIndex: 0,
      data: [182, 184, 183, 185, 186, 185, 187, 186, 185, 184, 185, 185],
      itemStyle: { color: '#dc2626' },
      areaStyle: { color: 'rgba(220,38,38,0.08)' }
    },
    {
      name: '塔顶压力', type: 'line', smooth: true, yAxisIndex: 1,
      data: [1.75, 1.78, 1.80, 1.82, 1.81, 1.79, 1.80, 1.83, 1.82, 1.80, 1.81, 1.80],
      itemStyle: { color: '#2563eb' }
    },
    {
      name: '回流温度', type: 'line', smooth: true, yAxisIndex: 0,
      data: [82, 83, 84, 85, 84, 83, 85, 86, 85, 84, 85, 85],
      itemStyle: { color: '#0891b2' }
    },
  ],
});

// ========== 产能排行 ==========
const capacityOption = ref({
  backgroundColor: 'transparent',
  tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
  grid: { left: '3%', right: '8%', bottom: '3%', top: '5%', containLabel: true },
  xAxis: {
    type: 'value',
    axisLine: { lineStyle: { color: '#cbd5e1' } },
    axisLabel: { color: '#64748b', fontSize: 10 },
    splitLine: { lineStyle: { color: '#f1f5f9' } }
  },
  yAxis: {
    type: 'category', data: ['E装置', 'D装置', 'C装置', 'B装置', 'A装置'],
    axisLine: { lineStyle: { color: '#cbd5e1' } },
    axisLabel: { color: '#475569', fontSize: 11 }
  },
  series: [
    {
      name: '实际产能', type: 'bar', stack: 'total',
      data: [320, 450, 520, 680, 850],
      itemStyle: { color: '#3b82f6', borderRadius: [0, 4, 4, 0] }
    },
    {
      name: '计划产能', type: 'bar', stack: 'total',
      data: [80, 50, 30, 20, 50],
      itemStyle: { color: '#bfdbfe', borderRadius: [0, 4, 4, 0] }
    },
  ],
});

// ========== 设备状态 ==========
const equipmentOption = ref({
  backgroundColor: 'transparent',
  tooltip: { trigger: 'item' },
  legend: { orient: 'vertical', right: '5%', top: 'center', textStyle: { fontSize: 11, color: '#475569' } },
  series: [
    {
      name: '设备状态', type: 'pie', radius: ['45%', '70%'], center: ['40%', '50%'],
      avoidLabelOverlap: false,
      itemStyle: { borderRadius: 6, borderColor: '#fff', borderWidth: 2 },
      label: { show: false },
      emphasis: { label: { show: true, fontSize: 14, fontWeight: 'bold' } },
      data: [
        { value: 42, name: '正常运行', itemStyle: { color: '#059669' } },
        { value: 8, name: '待机', itemStyle: { color: '#3b82f6' } },
        { value: 3, name: '维护中', itemStyle: { color: '#f59e0b' } },
        { value: 2, name: '故障', itemStyle: { color: '#dc2626' } },
      ],
    },
  ],
});

// ========== 能耗仪表盘 ==========
const energyOption = ref({
  backgroundColor: 'transparent',
  series: [
    {
      type: 'gauge', startAngle: 200, endAngle: -20, min: 0, max: 100, splitNumber: 10,
      radius: '90%', center: ['50%', '55%'],
      itemStyle: { color: '#059669' },
      progress: { show: true, width: 12 },
      pointer: { show: true, length: '60%', width: 4 },
      axisLine: { lineStyle: { width: 12, color: [[1, '#e2e8f0']] } },
      axisTick: { distance: -18, splitNumber: 5, lineStyle: { width: 1, color: '#94a3b8' } },
      splitLine: { distance: -22, length: 10, lineStyle: { width: 2, color: '#94a3b8' } },
      axisLabel: { distance: -10, color: '#64748b', fontSize: 10 },
      anchor: { show: true, size: 15, itemStyle: { color: '#059669' } },
      title: { show: true, offsetCenter: [0, '70%'], fontSize: 12, color: '#475569' },
      detail: { valueAnimation: true, fontSize: 24, offsetCenter: [0, '40%'], formatter: '{value}%', color: '#1e293b' },
      data: [{ value: 82, name: '能效指数' }],
    },
  ],
});

// ========== 设备状态列表 ==========
const equipmentList = ref([
  { id: 'R-101', name: '反应釜 R-101', status: 'running', health: 98, lastMaint: '2025-07-15', nextMaint: '2025-09-15' },
  { id: 'T-201', name: '精馏塔 T-201', status: 'running', health: 95, lastMaint: '2025-06-20', nextMaint: '2025-08-20' },
  { id: 'E-301', name: '换热器 E-301', status: 'running', health: 92, lastMaint: '2025-07-01', nextMaint: '2025-10-01' },
  { id: 'V-401', name: '储罐 V-401', status: 'warning', health: 78, lastMaint: '2025-05-10', nextMaint: '2025-08-10' },
  { id: 'P-501', name: '离心泵 P-501', status: 'running', health: 96, lastMaint: '2025-07-20', nextMaint: '2025-08-20' },
  { id: 'C-601', name: '压缩机 C-601', status: 'stopped', health: 65, lastMaint: '2025-04-15', nextMaint: '2025-08-05' },
]);

// ========== 异常事件 ==========
const alarmList = ref([
  { id: 1, level: 'high', time: '10:23:15', device: 'V-401', message: '储罐液位接近上限 (78%)', status: 'pending' },
  { id: 2, level: 'medium', time: '09:45:32', device: 'C-601', message: '压缩机振动异常，建议检修', status: 'processing' },
  { id: 3, level: 'low', time: '08:12:08', device: 'E-301', message: '换热器温差偏小，效率下降', status: 'resolved' },
  { id: 4, level: 'medium', time: '07:30:45', device: 'T-201', message: '塔顶温度波动 ±2°C', status: 'processing' },
  { id: 5, level: 'low', time: '06:55:12', device: 'P-501', message: '泵轴承温度略高 (45°C)', status: 'resolved' },
]);

// ========== 原料库存 ==========
const stockList = ref([
  { name: '甲醇', percent: 78 },
  { name: '液氨', percent: 45 },
  { name: '硝酸', percent: 23 },
  { name: '硫酸', percent: 82 },
  { name: '氢氧化钠', percent: 56 },
]);

// ========== 环保排放 ==========
const envList = ref([
  { name: 'COD 排放', current: 45, limit: 100, unit: 'mg/L' },
  { name: '氨氮排放', current: 8, limit: 15, unit: 'mg/L' },
  { name: 'SO₂ 排放', current: 35, limit: 50, unit: 'mg/m³' },
  { name: 'NOx 排放', current: 42, limit: 80, unit: 'mg/m³' },
  { name: '颗粒物', current: 12, limit: 30, unit: 'mg/m³' },
]);

// ========== 人员岗位 ==========
const staffList = ref([
  { name: '张工', status: 'on' },
  { name: '李工', status: 'on' },
  { name: '王工', status: 'rest' },
  { name: '赵工', status: 'on' },
  { name: '刘工', status: 'off' },
  { name: '陈工', status: 'on' },
  { name: '杨工', status: 'on' },
  { name: '黄工', status: 'rest' },
]);

function alarmLevelColor(level: string) {
  return { high: 'bg-red-50 text-red-700 border-red-200', medium: 'bg-amber-50 text-amber-700 border-amber-200', low: 'bg-blue-50 text-blue-700 border-blue-200' }[level] || 'bg-slate-50 text-slate-600';
}
function alarmLevelText(level: string) {
  return { high: '高危', medium: '中危', low: '低危' }[level] || '一般';
}
function alarmStatusText(status: string) {
  return { pending: '待处理', processing: '处理中', resolved: '已解决' }[status] || status;
}

// ========== 实时数据更新模拟 ==========
let dataTimer: ReturnType<typeof setInterval> | null = null;

function startDataSimulation() {
  dataTimer = setInterval(() => {
    const lastIdx = tempPressureOption.value.series[0].data.length - 1;
    tempPressureOption.value.series[0].data[lastIdx] = 185 + Math.round((Math.random() - 0.5) * 4);
    tempPressureOption.value.series[1].data[lastIdx] = 1.80 + (Math.random() - 0.5) * 0.06;
    tempPressureOption.value.series[2].data[lastIdx] = 85 + Math.round((Math.random() - 0.5) * 3);
    tempPressureOption.value = { ...tempPressureOption.value };
  }, 5000);
}

// ========== API 数据获取 ==========
async function fetchAll() {
  loading.value = true; error.value = '';
  try {
    const { data } = await apiClient.get<DashboardOverview>('/api/dashboard/overview');
    if (import.meta.env.DEV && (!data || Object.keys(data).length === 0)) {
      overview.value = getMockOverviewData();
    } else {
      overview.value = data;
    }
  } catch {
    if (import.meta.env.DEV) overview.value = getMockOverviewData();
    else error.value = '加载仪表盘数据失败';
  } finally { loading.value = false; }
}

function getMockOverviewData(): DashboardOverview {
  return {
    totalAssets: 156, checkedAssets: 142, compliantAssets: 138, nonCompliantAssets: 4,
    totalFindings: 12, openFindings: 4, complianceRate: 0.88, remediationRate: 0.92,
    lastAutoScanAt: new Date().toISOString(), hasInventory: true,
    findingsBySeverity: { Critical: 1, High: 3, Medium: 5, Low: 3 },
    findingsByStatus: { Open: 4, Closed: 8 },
  };
}

function particleCoord(particle: (typeof flowParticles.value)[0], axis: 'x' | 'y'): number {
  const link = processLinks.value[particle.linkIndex];
  if (!link) return 0;
  const from = processNodes.value.find((n) => n.id === link.from);
  const to = processNodes.value.find((n) => n.id === link.to);
  const start = from?.[axis] ?? 0;
  const end = to?.[axis] ?? 0;
  return start + (end - start) * particle.progress;
}

onMounted(() => { fetchAll(); startDataSimulation(); startParticleAnimation(); kpiDisplays.forEach(d => d.start()); });
onUnmounted(() => { if (dataTimer) clearInterval(dataTimer); if (particleTimer) clearInterval(particleTimer); });
</script>

<template>
  <div class="dashboard-v2">
    <!-- 顶部标题栏 -->
    <div class="header-bar">
      <div class="flex items-center gap-3">
        <div class="header-icon">
          <svg class="w-6 h-6 text-blue-700" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h6v1.5H9V6.75zm0 3h6v1.5H9v-1.5zm0 3h6v1.5H9v-1.5z" />
          </svg>
        </div>
        <div>
          <h1 class="text-xl font-bold text-slate-800 tracking-wide">化工智能生产运营中心</h1>
          <p class="text-xs text-slate-400">Chemical Intelligent Production Operation Center V2.0</p>
        </div>
      </div>
      <div class="flex items-center gap-6 text-sm text-slate-500">
        <div class="flex items-center gap-2">
          <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
          <span>系统正常运行</span>
        </div>
        <div class="flex items-center gap-2">
          <svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span>{{ new Date().toLocaleString('zh-CN') }}</span>
        </div>
      </div>
    </div>

    <!-- KPI 栏 -->
    <div class="kpi-bar">
      <div v-for="kpi in kpiData" :key="kpi.label" class="kpi-card-v2">
        <div class="flex items-center justify-between mb-2">
          <div class="kpi-icon-v2" :style="{ backgroundColor: kpi.color + '15', color: kpi.color }">
            <svg v-if="kpi.icon === 'activity'" class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
            </svg>
            <svg v-else-if="kpi.icon === 'calendar'" class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" />
            </svg>
            <svg v-else-if="kpi.icon === 'shield'" class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
            </svg>
            <svg v-else-if="kpi.icon === 'check'" class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 01-1.043 3.296 3.745 3.745 0 01-3.296 1.043A3.745 3.745 0 0112 21c-1.268 0-2.39-.63-3.068-1.593a3.746 3.746 0 01-3.296-1.043 3.745 3.745 0 01-1.043-3.296A3.745 3.745 0 013 12c0-1.268.63-2.39 1.593-3.068a3.745 3.745 0 011.043-3.296 3.746 3.746 0 013.296-1.043A3.746 3.746 0 0112 3c1.268 0 2.39.63 3.068 1.593a3.746 3.746 0 013.296 1.043 3.746 3.746 0 011.043 3.296A3.745 3.745 0 0121 12z" />
            </svg>
            <svg v-else-if="kpi.icon === 'zap'" class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
            </svg>
            <svg v-else class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" />
            </svg>
          </div>
          <span class="text-xs font-semibold" :class="kpi.trendUp ? 'text-emerald-600' : 'text-red-500'">{{ kpi.trend }}</span>
        </div>
        <div class="text-2xl font-bold text-slate-800">{{ kpi.value }}</div>
        <div class="text-xs text-slate-500 mt-0.5">{{ kpi.label }}</div>
        <div class="text-[10px] text-slate-400 mt-1">{{ kpi.unit }}</div>
      </div>
    </div>

    <!-- 主体内容区 -->
    <div class="main-grid-v2">
      <!-- 左侧：工艺流程图 -->
      <div class="panel-v2 col-span-2 row-span-2">
        <div class="panel-header-v2">
          <div class="flex items-center gap-2">
            <div class="w-1 h-4 bg-blue-600 rounded"></div>
            <h3 class="text-sm font-semibold text-slate-800">工艺流程数字孪生</h3>
          </div>
          <div class="flex items-center gap-3 text-xs text-slate-400">
            <span class="flex items-center gap-1"><span class="w-2 h-2 rounded-full bg-emerald-500 status-dot"></span>运行</span>
            <span class="flex items-center gap-1"><span class="w-2 h-2 rounded-full bg-amber-500 status-dot-warning"></span>预警</span>
            <span class="flex items-center gap-1"><span class="w-2 h-2 rounded-full bg-slate-400"></span>停机</span>
          </div>
        </div>
        <div class="p-4 relative process-bg">
          <svg class="w-full h-80" viewBox="0 0 640 400" preserveAspectRatio="xMidYMid meet">
            <!-- 管道连线 -->
            <g v-for="(link, i) in processLinks" :key="i">
              <line
                :x1="processNodes.find(n => n.id === link.from)?.x"
                :y1="processNodes.find(n => n.id === link.from)?.y"
                :x2="processNodes.find(n => n.id === link.to)?.x"
                :y2="processNodes.find(n => n.id === link.to)?.y"
                stroke="#cbd5e1" stroke-width="3" stroke-linecap="round"
              />
              <text
                :x="((processNodes.find(n => n.id === link.from)?.x || 0) + (processNodes.find(n => n.id === link.to)?.x || 0)) / 2"
                :y="((processNodes.find(n => n.id === link.from)?.y || 0) + (processNodes.find(n => n.id === link.to)?.y || 0)) / 2 - 6"
                text-anchor="middle" font-size="10" fill="#94a3b8" font-weight="500"
              >{{ link.label }}</text>
            </g>
            <!-- 设备节点 -->
            <g v-for="node in processNodes" :key="node.id" class="cursor-pointer" @click="showNodeDetail(node)">
              <!-- 反应釜 -->
              <template v-if="node.type === 'reactor'">
                <rect :x="node.x - 35" :y="node.y - 30" width="70" height="60" rx="8" :fill="nodeStatusColor(node.status) + '15'" :stroke="nodeStatusColor(node.status)" stroke-width="2" />
                <rect :x="node.x - 25" :y="node.y - 20" width="50" height="40" rx="4" :fill="nodeStatusColor(node.status) + '30'" />
                <text :x="node.x" :y="node.y + 38" text-anchor="middle" font-size="10" fill="#475569" font-weight="600">{{ node.name }}</text>
                <circle :cx="node.x + 28" :cy="node.y - 22" r="5" :fill="nodeStatusColor(node.status)" />
              </template>
              <!-- 精馏塔 -->
              <template v-if="node.type === 'tower'">
                <rect :x="node.x - 20" :y="node.y - 50" width="40" height="100" rx="4" :fill="nodeStatusColor(node.status) + '15'" :stroke="nodeStatusColor(node.status)" stroke-width="2" />
                <line :x1="node.x - 15" :y1="node.y - 35" :x2="node.x + 15" :y2="node.y - 35" :stroke="nodeStatusColor(node.status)" stroke-width="1" />
                <line :x1="node.x - 15" :y1="node.y - 15" :x2="node.x + 15" :y2="node.y - 15" :stroke="nodeStatusColor(node.status)" stroke-width="1" />
                <line :x1="node.x - 15" :y1="node.y + 5" :x2="node.x + 15" :y2="node.y + 5" :stroke="nodeStatusColor(node.status)" stroke-width="1" />
                <text :x="node.x" :y="node.y + 58" text-anchor="middle" font-size="10" fill="#475569" font-weight="600">{{ node.name }}</text>
                <circle :cx="node.x + 22" :cy="node.y - 45" r="5" :fill="nodeStatusColor(node.status)" />
              </template>
              <!-- 换热器 -->
              <template v-if="node.type === 'exchanger'">
                <ellipse :cx="node.x" :cy="node.y" rx="35" ry="25" :fill="nodeStatusColor(node.status) + '15'" :stroke="nodeStatusColor(node.status)" stroke-width="2" />
                <line :x1="node.x - 20" :y1="node.y" :x2="node.x + 20" :y2="node.y" :stroke="nodeStatusColor(node.status)" stroke-width="1.5" />
                <text :x="node.x" :y="node.y + 38" text-anchor="middle" font-size="10" fill="#475569" font-weight="600">{{ node.name }}</text>
                <circle :cx="node.x + 30" :cy="node.y - 18" r="5" :fill="nodeStatusColor(node.status)" />
              </template>
              <!-- 储罐 -->
              <template v-if="node.type === 'tank'">
                <rect :x="node.x - 30" :y="node.y - 35" width="60" height="70" rx="6" :fill="nodeStatusColor(node.status) + '15'" :stroke="nodeStatusColor(node.status)" stroke-width="2" />
                <rect :x="node.x - 24" :y="node.y + 5" width="48" height="24" rx="2" :fill="nodeStatusColor(node.status) + '40'" />
                <text :x="node.x" :y="node.y + 45" text-anchor="middle" font-size="10" fill="#475569" font-weight="600">{{ node.name }}</text>
                <text :x="node.x" :y="node.y + 20" text-anchor="middle" font-size="9" fill="#fff" font-weight="bold">{{ node.level }}%</text>
              </template>
                            <!-- 泵 -->
              <template v-if="node.type === 'pump'">
                <circle :cx="node.x" :cy="node.y" r="25" :fill="nodeStatusColor(node.status) + '15'" :stroke="nodeStatusColor(node.status)" stroke-width="2" />
                <polygon :points="`${node.x-8},${node.y-10} ${node.x+12},${node.y} ${node.x-8},${node.y+10}`" :fill="nodeStatusColor(node.status)" />
                <text :x="node.x" :y="node.y + 38" text-anchor="middle" font-size="10" fill="#475569" font-weight="600">{{ node.name }}</text>
                <circle :cx="node.x + 22" :cy="node.y - 18" r="5" :fill="nodeStatusColor(node.status)" />
              </template>
              <!-- 压缩机 -->
              <template v-if="node.type === 'compressor'">
                <rect :x="node.x - 30" :y="node.y - 25" width="60" height="50" rx="6" :fill="nodeStatusColor(node.status) + '15'" :stroke="nodeStatusColor(node.status)" stroke-width="2" />
                <circle :cx="node.x" :cy="node.y" r="15" :fill="nodeStatusColor(node.status) + '30'" />
                <line :x1="node.x - 10" :y1="node.y" :x2="node.x + 10" :y2="node.y" :stroke="nodeStatusColor(node.status)" stroke-width="2" />
                <text :x="node.x" :y="node.y + 38" text-anchor="middle" font-size="10" fill="#475569" font-weight="600">{{ node.name }}</text>
                <circle :cx="node.x + 28" :cy="node.y - 20" r="5" :fill="nodeStatusColor(node.status)" />
              </template>
              <!-- 过滤器 -->
              <template v-if="node.type === 'filter'">
                <rect :x="node.x - 25" :y="node.y - 20" width="50" height="40" rx="4" :fill="nodeStatusColor(node.status) + '15'" :stroke="nodeStatusColor(node.status)" stroke-width="2" />
                <line :x1="node.x - 15" :y1="node.y - 5" :x2="node.x + 15" :y2="node.y - 5" :stroke="nodeStatusColor(node.status)" stroke-width="1.5" />
                <line :x1="node.x - 15" :y1="node.y + 5" :x2="node.x + 15" :y2="node.y + 5" :stroke="nodeStatusColor(node.status)" stroke-width="1.5" />
                <line :x1="node.x - 10" :y1="node.y - 10" :x2="node.x - 10" :y2="node.y + 10" :stroke="nodeStatusColor(node.status)" stroke-width="1" />
                <line :x1="node.x" :y1="node.y - 10" :x2="node.x" :y2="node.y + 10" :stroke="nodeStatusColor(node.status)" stroke-width="1" />
                <line :x1="node.x + 10" :y1="node.y - 10" :x2="node.x + 10" :y2="node.y + 10" :stroke="nodeStatusColor(node.status)" stroke-width="1" />
                <text :x="node.x" :y="node.y + 32" text-anchor="middle" font-size="10" fill="#475569" font-weight="600">{{ node.name }}</text>
                <circle :cx="node.x + 22" :cy="node.y - 15" r="5" :fill="nodeStatusColor(node.status)" />
              </template>
              <!-- 加热炉 -->
              <template v-if="node.type === 'heater'">
                <rect :x="node.x - 30" :y="node.y - 25" width="60" height="50" rx="6" :fill="nodeStatusColor(node.status) + '15'" :stroke="nodeStatusColor(node.status)" stroke-width="2" />
                <path :d="`M${node.x-15},${node.y+10} Q${node.x},${node.y-15} ${node.x+15},${node.y+10}`" :stroke="nodeStatusColor(node.status)" stroke-width="2" fill="none" />
                <circle :cx="node.x" :cy="node.y + 5" r="4" :fill="nodeStatusColor(node.status)" class="heater-flame" />
                <text :x="node.x" :y="node.y + 38" text-anchor="middle" font-size="10" fill="#475569" font-weight="600">{{ node.name }}</text>
                <circle :cx="node.x + 28" :cy="node.y - 20" r="5" :fill="nodeStatusColor(node.status)" />
              </template>
              <!-- 分离器 -->
              <template v-if="node.type === 'separator'">
                <ellipse :cx="node.x" :cy="node.y" rx="30" ry="20" :fill="nodeStatusColor(node.status) + '15'" :stroke="nodeStatusColor(node.status)" stroke-width="2" />
                <line :x1="node.x - 20" :y1="node.y" :x2="node.x + 20" :y2="node.y" :stroke="nodeStatusColor(node.status)" stroke-width="1" />
                <circle :cx="node.x - 10" :cy="node.y - 5" r="4" :fill="nodeStatusColor(node.status) + '40'" />
                <circle :cx="node.x + 8" :cy="node.y + 5" r="3" :fill="nodeStatusColor(node.status) + '40'" />
                <text :x="node.x" :y="node.y + 32" text-anchor="middle" font-size="10" fill="#475569" font-weight="600">{{ node.name }}</text>
                <circle :cx="node.x + 25" :cy="node.y - 15" r="5" :fill="nodeStatusColor(node.status)" />
              </template>
            </g>
            <!-- 流体粒子 -->
            <g v-for="particle in flowParticles" :key="particle.id">
              <circle
                :cx="particleCoord(particle, 'x')"
                :cy="particleCoord(particle, 'y')"
                r="3"
                fill="#3b82f6"
                opacity="0.7"
                class="flow-particle"
              />
            </g>
          </svg>

          <!-- 设备详情弹窗 -->
          <div v-if="selectedNode" class="node-detail-popup">
            <div class="flex items-center justify-between mb-3">
              <h4 class="text-sm font-bold text-slate-800">{{ selectedNode.name }}</h4>
              <button @click="closeNodeDetail" class="text-slate-400 hover:text-slate-600">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            <div class="space-y-2 text-xs">
              <div class="flex justify-between"><span class="text-slate-500">状态</span><span class="font-medium" :style="{ color: nodeStatusColor(selectedNode.status) }">{{ nodeStatusText(selectedNode.status) }}</span></div>
              <div class="flex justify-between"><span class="text-slate-500">温度</span><span class="font-medium text-slate-800">{{ selectedNode.temp }} °C</span></div>
              <div class="flex justify-between"><span class="text-slate-500">压力</span><span class="font-medium text-slate-800">{{ selectedNode.pressure }} MPa</span></div>
              <div class="flex justify-between" v-if="selectedNode.flow !== undefined"><span class="text-slate-500">流量</span><span class="font-medium text-slate-800">{{ selectedNode.flow }} m³/h</span></div>
              <div class="flex justify-between" v-if="selectedNode.level !== undefined"><span class="text-slate-500">液位</span><span class="font-medium text-slate-800">{{ selectedNode.level }}%</span></div>
            </div>
          </div>
        </div>
      </div>

      <!-- 右上：实时趋势 -->
      <div class="panel-v2">
        <div class="panel-header-v2">
          <div class="flex items-center gap-2">
            <div class="w-1 h-4 bg-red-500 rounded"></div>
            <h3 class="text-sm font-semibold text-slate-800">温压趋势预测</h3>
          </div>
          <span class="text-xs text-slate-400">实时</span>
        </div>
        <div class="p-2 h-64">
          <v-chart class="w-full h-full" :option="tempPressureOption" autoresize />
        </div>
      </div>

      <!-- 右中：产能排行 -->
      <div class="panel-v2">
        <div class="panel-header-v2">
          <div class="flex items-center gap-2">
            <div class="w-1 h-4 bg-blue-500 rounded"></div>
            <h3 class="text-sm font-semibold text-slate-800">装置产能排行</h3>
          </div>
          <span class="text-xs text-slate-400">吨/日</span>
        </div>
        <div class="p-2 h-48">
          <v-chart class="w-full h-full" :option="capacityOption" autoresize />
        </div>
      </div>

      <!-- 右下：设备状态 + 能耗 -->
      <div class="grid grid-cols-2 gap-4">
        <div class="panel-v2">
          <div class="panel-header-v2">
            <div class="flex items-center gap-2">
              <div class="w-1 h-4 bg-emerald-500 rounded animate-pulse"></div>
              <h3 class="text-sm font-semibold text-slate-800">设备状态分布</h3>
            </div>
          </div>
          <div class="p-2 h-48">
            <v-chart class="w-full h-full" :option="equipmentOption" autoresize />
          </div>
        </div>
        <div class="panel-v2">
          <div class="panel-header-v2">
            <div class="flex items-center gap-2">
              <div class="w-1 h-4 bg-orange-500 rounded animate-pulse"></div>
              <h3 class="text-sm font-semibold text-slate-800">能耗监控</h3>
            </div>
          </div>
          <div class="p-2 h-48">
            <v-chart class="w-full h-full" :option="energyOption" autoresize />
          </div>
        </div>
      </div>

      <!-- 新增：原料库存监控 -->
      <div class="panel-v2">
        <div class="panel-header-v2">
          <div class="flex items-center gap-2">
            <div class="w-1 h-4 bg-purple-500 rounded animate-pulse"></div>
            <h3 class="text-sm font-semibold text-slate-800">原料库存监控</h3>
          </div>
          <span class="text-xs text-slate-400">实时</span>
        </div>
        <div class="p-4 space-y-3">
          <div v-for="(stock, i) in stockList" :key="i" class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <span class="w-2 h-2 rounded-full" :class="stock.percent < 30 ? 'bg-red-500 animate-ping' : stock.percent < 60 ? 'bg-amber-500' : 'bg-emerald-500'"></span>
              <span class="text-xs text-slate-600">{{ stock.name }}</span>
            </div>
            <div class="flex items-center gap-2">
              <div class="w-24 h-2 bg-slate-100 rounded-full overflow-hidden">
                <div class="h-full rounded-full transition-all duration-700" :class="stock.percent < 30 ? 'bg-red-500' : stock.percent < 60 ? 'bg-amber-500' : 'bg-emerald-500'" :style="{ width: stock.percent + '%' }"></div>
              </div>
              <span class="text-xs font-medium w-10 text-right" :class="stock.percent < 30 ? 'text-red-600' : 'text-slate-700'">{{ stock.percent }}%</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 新增：环保排放指标 -->
      <div class="panel-v2">
        <div class="panel-header-v2">
          <div class="flex items-center gap-2">
            <div class="w-1 h-4 bg-teal-500 rounded animate-pulse"></div>
            <h3 class="text-sm font-semibold text-slate-800">环保排放指标</h3>
          </div>
          <span class="text-xs text-emerald-600 font-medium flex items-center gap-1">
            <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse"></span>全部达标
          </span>
        </div>
        <div class="p-4 space-y-3">
          <div v-for="(env, i) in envList" :key="i">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs text-slate-600">{{ env.name }}</span>
              <span class="text-xs font-medium" :class="env.current > env.limit ? 'text-red-600' : 'text-emerald-600'">{{ env.current }} / {{ env.limit }} {{ env.unit }}</span>
            </div>
            <div class="h-2 bg-slate-100 rounded-full overflow-hidden">
              <div class="h-full rounded-full transition-all duration-700" :class="env.current > env.limit ? 'bg-red-500' : 'bg-teal-500'" :style="{ width: Math.min((env.current / env.limit) * 100, 100) + '%' }"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- 新增：人员岗位状态 -->
      <div class="panel-v2">
        <div class="panel-header-v2">
          <div class="flex items-center gap-2">
            <div class="w-1 h-4 bg-indigo-500 rounded animate-pulse"></div>
            <h3 class="text-sm font-semibold text-slate-800">人员岗位状态</h3>
          </div>
          <span class="text-xs text-slate-400">{{ staffList.filter(s => s.status === 'on').length }}/{{ staffList.length }} 在岗</span>
        </div>
        <div class="p-4">
          <div class="grid grid-cols-4 gap-3">
            <div v-for="(staff, i) in staffList" :key="i" class="text-center p-2 rounded-lg border" :class="staff.status === 'on' ? 'bg-emerald-50 border-emerald-100' : staff.status === 'off' ? 'bg-slate-50 border-slate-100' : 'bg-amber-50 border-amber-100'">
              <div class="w-8 h-8 rounded-full mx-auto mb-1 flex items-center justify-center text-xs font-bold" :class="staff.status === 'on' ? 'bg-emerald-100 text-emerald-700' : staff.status === 'off' ? 'bg-slate-200 text-slate-500' : 'bg-amber-100 text-amber-700'">
                {{ staff.name.charAt(0) }}
              </div>
              <div class="text-[10px] text-slate-700 font-medium">{{ staff.name }}</div>
              <div class="text-[9px]" :class="staff.status === 'on' ? 'text-emerald-600' : staff.status === 'off' ? 'text-slate-400' : 'text-amber-600'">{{ staff.status === 'on' ? '在岗' : staff.status === 'off' ? '离岗' : '休息' }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 底部：异常事件列表 -->
    <div class="panel-v2 mt-4">
      <div class="panel-header-v2">
        <div class="flex items-center gap-2">
          <div class="w-1 h-4 bg-red-600 rounded"></div>
          <h3 class="text-sm font-semibold text-slate-800">异常事件列表</h3>
        </div>
        <span class="text-xs text-slate-400">{{ alarmList.filter(a => a.status !== 'resolved').length }} 待处理</span>
      </div>
      <div class="p-4">
        <table class="w-full text-xs">
          <thead>
            <tr class="text-slate-400 border-b border-slate-100">
              <th class="text-left py-2 font-medium">时间</th>
              <th class="text-left py-2 font-medium">设备</th>
              <th class="text-left py-2 font-medium">事件描述</th>
              <th class="text-left py-2 font-medium">等级</th>
              <th class="text-left py-2 font-medium">状态</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="alarm in alarmList" :key="alarm.id" class="border-b border-slate-50 hover:bg-slate-50">
              <td class="py-2.5 text-slate-600">{{ alarm.time }}</td>
              <td class="py-2.5 font-medium text-slate-700">{{ alarm.device }}</td>
              <td class="py-2.5 text-slate-600">{{ alarm.message }}</td>
              <td class="py-2.5">
                <span class="px-2 py-0.5 rounded text-[10px] font-medium border" :class="alarmLevelColor(alarm.level)">{{ alarmLevelText(alarm.level) }}</span>
              </td>
              <td class="py-2.5">
                <span class="px-2 py-0.5 rounded text-[10px] font-medium" :class="alarm.status === 'resolved' ? 'bg-emerald-50 text-emerald-700' : alarm.status === 'processing' ? 'bg-amber-50 text-amber-700' : 'bg-red-50 text-red-700'">{{ alarmStatusText(alarm.status) }}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard-v2 {
  @apply -m-6 p-6 bg-slate-50 min-h-screen;
}
.header-bar {
  @apply flex items-center justify-between bg-white rounded-xl shadow-sm border border-slate-200 px-6 py-4 mb-5;
}
.header-icon {
  @apply w-10 h-10 rounded-lg bg-blue-50 flex items-center justify-center;
}
.kpi-bar {
  @apply grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4 mb-5;
}
.kpi-card-v2 {
  @apply bg-white rounded-xl p-4 border border-slate-200 shadow-sm;
}
.kpi-icon-v2 {
  @apply w-9 h-9 rounded-lg flex items-center justify-center;
}
.main-grid-v2 {
  @apply grid grid-cols-1 lg:grid-cols-3 gap-5;
}
.panel-v2 {
  @apply bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden;
}
.panel-header-v2 {
  @apply flex items-center justify-between px-4 py-3 border-b border-slate-100;
}
.node-detail-popup {
  @apply absolute top-4 right-4 w-56 bg-white rounded-xl border border-slate-200 shadow-lg p-4 z-10;
}

/* ========== 动态效果 ========== */
@keyframes breathe {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.6; transform: scale(0.95); }
}
@keyframes shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}
@keyframes nodePulse {
  0% { filter: drop-shadow(0 0 2px currentColor); }
  50% { filter: drop-shadow(0 0 8px currentColor); }
  100% { filter: drop-shadow(0 0 2px currentColor); }
}

/* 状态指示点呼吸效果 */
.status-dot {
  animation: breathe 2s ease-in-out infinite;
}
.status-dot-warning {
  animation: breathe 1s ease-in-out infinite;
}
.status-dot-alarm {
  animation: breathe 0.5s ease-in-out infinite;
}

/* 面板标题动态渐变 */
.panel-header-v2 h3 {
  position: relative;
}
.panel-header-v2 h3::after {
  content: '';
  position: absolute;
  bottom: -2px;
  left: 0;
  width: 100%;
  height: 2px;
  background: linear-gradient(90deg, transparent, currentColor, transparent);
  background-size: 200% 100%;
  animation: shimmer 3s linear infinite;
  opacity: 0.3;
}

/* KPI 卡片悬浮动画 */
.kpi-card-v2 {
  transition: all 0.3s ease;
}
.kpi-card-v2:hover {
  transform: translateY(-4px);
  box-shadow: 0 12px 24px -8px rgba(0,0,0,0.15);
}

/* 设备节点脉冲 */
g.cursor-pointer circle[r="5"] {
  animation: nodePulse 2s ease-in-out infinite;
}

/* 进度条流光 */
.h-2 > div {
  position: relative;
  overflow: hidden;
}
.h-2 > div::after {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent);
  animation: shimmer 2s linear infinite;
}

/* 流体粒子动画 */
.flow-particle {
  animation: particleGlow 1.5s ease-in-out infinite alternate;
}
@keyframes particleGlow {
  0% { opacity: 0.4; r: 2; }
  100% { opacity: 1; r: 4; }
}

/* 加热炉火焰跳动 */
.heater-flame {
  animation: flameFlicker 0.8s ease-in-out infinite alternate;
}
@keyframes flameFlicker {
  0% { transform: translateY(0); opacity: 0.8; }
  100% { transform: translateY(-3px); opacity: 1; }
}

/* 工艺流程图背景网格 */
.process-bg {
  background-image: radial-gradient(circle, #e2e8f0 1px, transparent 1px);
  background-size: 20px 20px;
}

/* 数字上涨高亮 */
.count-up-active {
  animation: countHighlight 0.3s ease;
}
@keyframes countHighlight {
  0% { color: #3b82f6; transform: scale(1.1); }
  100% { color: inherit; transform: scale(1); }
}
</style>