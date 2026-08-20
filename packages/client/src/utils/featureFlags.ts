// 构建时特性开关（feature flags）。
//
// 通过 Vite 环境变量 `VITE_DISABLED_FEATURES`（逗号分隔的特性 key）在构建期
// 禁用某些前端功能入口。它只负责「隐藏入口」（路由 / 侧边栏菜单 / tab / 按钮），
// 不删除任何代码、不触碰后端接口，从而保持与官方上游最小差异、便于后续同步。
//
// 用法示例：
//   VITE_DISABLED_FEATURES=devices,apiRelay,pet,usage,performance,versionPreview npm run build
//
// 特性 key 一览（与功能对应）：
//   devices        —— 设备互联（PageSidebarNav 入口 + connections 页面，含 app/mcu/devices 三个 tab）
//   apiRelay       —— 饲料 / API Relay（跳转 apikey.fun 的外链按钮）
//   pet            —— 宠物（桌面宠物 desktop.pet + 宠物图鉴 hermes.petdex）
//   usage          —— 用量统计
//   performance    —— 性能监控
//   versionPreview —— 版本预览

const DISABLED = new Set(
  (import.meta.env.VITE_DISABLED_FEATURES || '')
    .split(',')
    .map((s: string) => s.trim())
    .filter(Boolean),
)

/** 判断某个特性是否启用（未被禁用）。 */
export function isFeatureEnabled(feature: string): boolean {
  return !DISABLED.has(feature)
}
