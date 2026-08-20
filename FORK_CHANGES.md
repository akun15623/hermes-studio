# Fork 本地改动对照维护手册

> 本文档记录本 fork（`akun15623/hermes-studio`）相对官方上游（`EKKOLearnAI/hermes-studio`）的**本地改动**，
> 用于后续同步官方更新时对照维护、以及重新 fork 时快速复原本地改动。
>
> **约定：每次新增 / 修改本地改动后，必须同步更新本文档。**

---

## 1. 仓库与基线信息

| 项 | 值 |
|---|---|
| 本仓库 | `https://github.com/akun15623/hermes-studio.git`（`origin`） |
| 官方上游 | `EKKOLearnAI/hermes-studio`（尚未配置 `upstream` remote） |
| 当前基线 commit | `ec2b9e9ab546497b373db57dc08aa91c0ec3e33a`（官方 PR #2627 `feat(models): manage the fallback provider chain from the Web UI`） |
| 项目版本 | `hermes-web-ui` v0.6.44 |
| 前端源码目录 | `packages/client/src/` |

---

## 2. 目的与设计原则

**目的**：隐藏 / 关闭本 fork 用不到的部分 Hermes Studio 功能入口，同时让后续同步官方更新时 merge 冲突尽可能少。

**设计原则（务必遵守）**：

1. **只隐藏入口，不删除代码**。禁用动作发生在「路由注册 / 侧边栏菜单 / tab / 按钮」这一层，
   底层组件、后端接口一律不动。这样官方上游的代码结构完全不被破坏，merge 时几乎零冲突。
2. **运行时过滤，而非编译期删代码**。被禁用的路由仍在产物（chunk）里，只是运行时不再注册到 router，
   浏览器不会加载对应 chunk。目的是「入口消失」，不是「体积变小」。
3. **改动集中、正交**。所有禁用逻辑都挂在「新增的独立文件 + 少量 `meta` 标记 + `v-if`/`filter`」上，
   不散落在业务逻辑里。官方后续新增路由 / 菜单（不带 `feature` 标记）会被自动放行，不受影响。

---

## 3. 特性开关机制（featureFlags）

### 3.1 新增文件：`packages/client/src/utils/featureFlags.ts`

这是本 fork 的核心新增文件，全文如下（重新 fork 时直接复制即可）：

```ts
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
//   devices        —— 设备互联（Connections 面板的 devices tab）
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
```

### 3.2 两个 helper 的分工（关键）

| helper | 用途 | 使用位置 |
|---|---|---|
| `isFeatureEnabled(key)` | 直接判断某特性是否禁用 | tab、按钮等**不经过路由**的入口 |
| `hasRoute('hermes.xxx')` | 判断某路由是否已注册（路由被 filter 掉后自动返回 false） | 侧边栏菜单项 |

> 菜单项优先用 `hasRoute()`：路由一旦被 filter 掉，`router.hasRoute()` 返回 false，菜单自动消失，
> 无需额外维护开关状态。tab / 按钮这类不挂在路由上的入口才用 `isFeatureEnabled()`。

---

## 4. 详细改动清单

共 **6 个文件**：1 个新增 + 5 个修改。以下是每个文件的**全部**改动点（精确到 diff 级）。

### 4.1 新增：`packages/client/src/utils/featureFlags.ts`

见 3.1 节全文。

### 4.2 修改：`packages/client/src/router/index.ts`

改动点（4 处）：

1. **import 行**：
   ```diff
   -import { createRouter, createWebHashHistory } from 'vue-router'
   +import { createRouter, createWebHashHistory, type RouteRecordRaw, type RouteLocation } from 'vue-router'
   ```
   并新增 `import { isFeatureEnabled } from '@/utils/featureFlags'`。

2. **路由数组类型化**（原本直接内联在 `createRouter` 里）：
   ```diff
   -const router = createRouter({
   -  history: createWebHashHistory(),
   -  routes: [
   +const routes: RouteRecordRaw[] = [
   ```
   （路由数组尾部再补上 `createRouter` 调用，见第 4 点。）

3. **7 个路由加 `meta.feature` 标记**：

   | 路由 path / name | 新增的 meta |
   |---|---|
   | `/desktop-pet` (`desktop.pet`) | `meta: { public: true, feature: 'pet' }` |
   | `/hermes/usage` (`hermes.usage`) | `meta: { feature: 'usage' }` |
   | `/hermes/performance` (`hermes.performance`) | `meta: { requiresSuperAdmin: true, feature: 'performance' }` |
   | `/hermes/petdex` (`hermes.petdex`) | `meta: { feature: 'pet' }` |
   | `/hermes/connections` (`hermes.connections`) | `meta: { feature: 'devices' }` |
   | `/hermes/devices` (`hermes.devices`) | `meta: { requiresSuperAdmin: true, feature: 'devices' }` |
   | `/hermes/version-preview` (`hermes.versionPreview`) | `meta: { requiresSuperAdmin: true, feature: 'versionPreview' }` |

   注意：原有的 `public` / `requiresSuperAdmin` 等 meta 字段**保留**，只追加 `feature` 字段。

4. **数组末尾追加 filter + 恢复 createRouter**：
   ```ts
   ].filter((r) => {
     const feature = (r.meta as { feature?: string } | undefined)?.feature
     return feature === undefined || isFeatureEnabled(feature)
   })

   const router = createRouter({
     history: createWebHashHistory(),
     routes,
   })
   ```

   > 附带：3 个 redirect 箭头函数参数补了显式类型 `(to: RouteLocation) =>`，
   > 因为数组从内联字面量抽成 `RouteRecordRaw[]` 后需要显式类型，否则 `vue-tsc` 报 TS7006。

### 4.3 修改：`packages/client/src/components/layout/AppSidebar.vue`

改动点（3 处菜单项，全部用 `hasRoute()`）：

| 菜单项 | 原条件 | 新条件 |
|---|---|---|
| petdex（宠物图鉴） | （无 `v-if`） | `v-if="hasRoute('hermes.petdex')"` |
| usage（用量统计） | （无 `v-if`） | `v-if="hasRoute('hermes.usage')"` |
| performance（性能监控） | `v-if="isSuperAdmin"` | `v-if="isSuperAdmin && hasRoute('hermes.performance')"` |

> `versionPreview` 菜单项**无需改动**：官方原代码已带 `hasRoute('hermes.versionPreview') && isSuperAdmin && !isVersionPreview`，路由被 filter 掉后自动隐藏。

### 4.4 修改：`packages/client/src/components/hermes/connections/ConnectionsPanel.vue`

改动点（2 处，用 `isFeatureEnabled('devices')`）：

1. 新增 import `isFeatureEnabled`。
2. devices tab 的两处判断：
   ```diff
   -if (value === 'devices' && isSuperAdmin.value) return value
   +if (value === 'devices' && isSuperAdmin.value && isFeatureEnabled('devices')) return value
   ```
   ```diff
   -<NTabPane v-if="isSuperAdmin" name="devices" ...>
   +<NTabPane v-if="isSuperAdmin && isFeatureEnabled('devices')" name="devices" ...>
   ```

### 4.5 修改：`packages/client/src/components/layout/PageSidebarNav.vue`

改动点（2 处，用 `isFeatureEnabled()`）：

1. 新增 import `isFeatureEnabled`。
2. 「设备互联」按钮（跳转 `hermes.connections`）：
   ```diff
    <button
   +  v-if="isFeatureEnabled('devices')"
      class="page-sidebar-tab"
      :class="{ active: active === 'connections' }"
   ```
3. 「饲料 / API Relay」外链按钮：
   ```diff
   -<button class="page-sidebar-tab" type="button" @click="openApiRelay">
   +<button v-if="isFeatureEnabled('apiRelay')" class="page-sidebar-tab" type="button" @click="openApiRelay">
   ```

   > `openApiRelay()` 跳转到 `https://apikey.fun/register?aff=LIBAPI`。这就是「饲料」功能的真实形态——一个外链按钮，不是路由，所以单独用 `isFeatureEnabled()` 处理。

### 4.6 修改：`Dockerfile`

改动点（1 处，在 `COPY . .` 与 `RUN npm run build` 之间插入构建参数）：

```diff
 COPY . .

+# 构建期特性开关：docker build --build-arg VITE_DISABLED_FEATURES="devices,apiRelay,pet,usage,performance,versionPreview"
+ARG VITE_DISABLED_FEATURES=""
+ENV VITE_DISABLED_FEATURES=${VITE_DISABLED_FEATURES}
+
 RUN npm run build && npm prune --omit=dev
```

> 作用：让 `docker build --build-arg VITE_DISABLED_FEATURES=...` 把这个环境变量传入 `npm run build` 里的 `vite build` 阶段。不传 build-arg 时为空（全部启用）。这是本 fork 改动中**唯一触达镜像构建**的一处——本地 `npm run build` 直接传环境变量即可，无需走 Dockerfile。

---

## 5. feature key 映射表

| key | 中文名 | 实际功能 | 禁用涉及的文件 |
|---|---|---|---|
| `devices` | 设备互联 | PageSidebarNav 入口 + `/hermes/connections` 页面（含 app/mcu/devices 三个 tab）+ `/hermes/devices` 重定向 | `router/index.ts`、`PageSidebarNav.vue`、`ConnectionsPanel.vue` |
| `apiRelay` | 饲料 | 跳转 apikey.fun 的外链按钮 | `PageSidebarNav.vue` |
| `pet` | 宠物 | 桌面宠物 `/desktop-pet` + 宠物图鉴 `/hermes/petdex` | `router/index.ts`、`AppSidebar.vue` |
| `usage` | 用量统计 | `/hermes/usage` | `router/index.ts`、`AppSidebar.vue` |
| `performance` | 性能监控 | `/hermes/performance` | `router/index.ts`、`AppSidebar.vue` |
| `versionPreview` | 版本预览 | `/hermes/version-preview` | `router/index.ts`（菜单项官方已带 `hasRoute`，免改） |

---

## 6. 使用方法与验证

### 6.1 构建时禁用（推荐）

```bash
VITE_DISABLED_FEATURES=devices,apiRelay,pet,usage,performance,versionPreview npm run build
```

- 逗号分隔，key 见第 5 节；不传该环境变量 = 全部启用（与官方一致）。
- key 支持空格与空段（`trim` + `filter(Boolean)`），写 `devices, pet` 也 OK。

### 6.2 局部禁用

只需禁用其中几个，比如只关「宠物」和「用量统计」：

```bash
VITE_DISABLED_FEATURES=pet,usage npm run build
```

### 6.3 构建镜像（Docker）

```bash
docker build \
  --build-arg VITE_DISABLED_FEATURES="devices,apiRelay,pet,usage,performance,versionPreview" \
  -t ekkoye8888/hermes-web-ui:custom-latest .
```

> `VITE_DISABLED_FEATURES` 通过 `--build-arg` 传入（见 4.6），在 `npm run build` 的 `vite build` 阶段生效。
> 不传 `--build-arg` 时镜像与官方一致（全部启用）。

### 6.4 验证

```bash
# 类型检查（必须通过）
./node_modules/.bin/vue-tsc -b

# 构建（默认 + 禁用两种模式都应通过）
./node_modules/.bin/vite build
VITE_DISABLED_FEATURES=devices,apiRelay,pet,usage,performance,versionPreview ./node_modules/.bin/vite build
```

> **本机注意**：当前环境 `NODE_ENV=production`，普通 `npm ci` 会跳过 devDependencies，
> 必须用 `npm ci --ignore-scripts --include=dev` 才能装齐 `vite` / `vue-tsc` 等构建工具。
> 另外 `npx vue-tsc` 会拉取不兼容的独立版本，务必用本地 `./node_modules/.bin/vue-tsc`。

> **Docker 内注意**：`hermes update` 在镜像内被禁用；镜像内 Hermes 版本取决于构建时的
> base `nousresearch/hermes-agent:latest`。升级 Hermes 需重新构建镜像。

---

## 7. 同步官方更新的维护指南

### 7.1 分支结构与 upstream（一次性配置）

本 fork 采用**双分支策略**：

| 分支 | 用途 | 状态 |
|---|---|---|
| `main` | 官方镜像（随时 fast-forward 官方，**不承载本地改动**） | 干净 |
| `custom` | 本地改动（feature flags + Dockerfile） | 承载全部本地改动 |

```bash
# 配置官方 upstream（一次性）
git remote add upstream https://github.com/EKKOLearnAI/hermes-studio.git
git fetch upstream
```

### 7.2 常规同步流程（官方更新后）

```bash
# 1. 拉取官方最新
git fetch upstream

# 2. 让 main 快进到官方最新（main 上无本地改动，必然可 ff）
git checkout main
git merge --ff-only upstream/main
git push origin main            # 可选：保持 origin/main 同步官方

# 3. 把本地改动 rebase 到最新官方之上
git checkout custom
git rebase main

# 4. 解决冲突（如有）后重新验证
./node_modules/.bin/vue-tsc -b
VITE_DISABLED_FEATURES=... ./node_modules/.bin/vite build

# 5. 推送 custom（rebase 后需 force，仅限 custom 分支）
git push --force-with-lease origin custom
```

> `main` 永远保持官方镜像，**绝不在 main 上直接改代码**；本地改动只进 `custom`。
> 新增本地改动时：`git checkout custom` → 改代码 → commit → push。

### 7.3 冲突预判（哪里最容易冲突）

| 文件 | 冲突风险 | 说明 |
|---|---|---|
| `featureFlags.ts` | **零** | 官方没有这个文件，不可能冲突 |
| `router/index.ts` | 低 | 官方加**新路由**：会出现在我们的 `routes` 数组 + `filter` 之间，只要新路由不带 `feature`，filter 自动放行；冲突仅在官方改动我们打标记的那几行时发生 |
| `AppSidebar.vue` | 低 | 只给 3 个菜单项加了 `v-if`，官方改这些菜单项的图标/文案时可能冲突，但极易手工解决 |
| `ConnectionsPanel.vue` | 低 | 只在 devices tab 两处追加了 `&& isFeatureEnabled('devices')` |
| `PageSidebarNav.vue` | 低 | 只给 apiRelay 按钮加了一行 `v-if` |
| `Dockerfile` | 低 | 只在 `npm run build` 前插入了 `ARG`/`ENV` 两行，官方改动该 RUN 行时才可能冲突 |

**核心心智**：所有本地改动都是「追加标记 + 条件」式的正交改动，**没有删除官方任何一行代码**。
merge 冲突时，以「保留官方最新逻辑 + 重新补上 `feature` 标记 / `v-if` / filter」为原则解决。

### 7.4 减少重复冲突的技巧（可选）

```bash
# 启用 rerere，让相同冲突只需手动解决一次
git config rerere.enabled true
```

### 7.5 重新 fork（全新仓库）时复原本地改动

按第 4 节清单，把 6 个文件的改动逐一重新应用即可；其中 `featureFlags.ts` 直接复制 3.1 节全文，
其余 5 个文件按 4.2–4.6 的 diff 逐处补上。

---

## 8. 后续新增「禁用某个功能」的操作清单

当需要再禁用第 N 个功能时，按以下步骤，并在本文档第 4、5 节补充记录：

1. 在 `router/index.ts` 给目标路由加 `meta: { ..., feature: '<key>' }`；
2. 若它是侧边栏菜单项，给菜单项加 `v-if="hasRoute('<routeName>')"`（或并入已有 `v-if`）；
3. 若它是 tab / 按钮等非路由入口，给元素加 `v-if="isFeatureEnabled('<key>')"` 并补 import；
4. 在 `featureFlags.ts` 顶部注释的「特性 key 一览」里补一行；
5. 跑 `vue-tsc -b` + `vite build` 验证；
6. 更新本文档第 4、5 节。

---

## 9. 当前禁用状态

| 功能 | key | 状态 |
|---|---|---|
| 设备互联 | `devices` | 可禁用（默认启用） |
| 饲料 / API Relay | `apiRelay` | 可禁用（默认启用） |
| 宠物（桌面宠物 + 图鉴） | `pet` | 可禁用（默认启用） |
| 用量统计 | `usage` | 可禁用（默认启用） |
| 性能监控 | `performance` | 可禁用（默认启用） |
| 版本预览 | `versionPreview` | 可禁用（默认启用） |

> 默认（不传 `VITE_DISABLED_FEATURES`）时行为与官方完全一致，6 个功能全部显示。
