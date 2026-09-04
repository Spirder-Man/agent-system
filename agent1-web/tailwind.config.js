/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{vue,js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
  // 避免与 Element Plus 样式冲突
  corePlugins: {
    preflight: false,
  },
  // 全局禁用所有过渡和动画
  future: {
    disableColorOpacityUtilitiesByDefault: false,
  },
};
