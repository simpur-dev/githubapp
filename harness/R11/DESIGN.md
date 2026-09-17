# R11 设计文档：Bug 修复 + 官方能力深采用

> 调研依据：本地 SDK d.ts（API 23-26 全量枚举）、`@kit.UIDesignKit` HDS 组件库、
> 官方主题框架 `@ohos.arkui.theme`（ThemeControl/WithTheme）、模拟器双主题逐页截图扫描
> （截图：`C:\Users\34928\AppData\Local\Temp\r11\`，dark_*/light_* 共 25 张）。

## 0. 调研结论（本轮改造的官方能力清单）

| 能力 | 来源 | 版本 | 用途 |
|---|---|---|---|
| `ThemeControl.setDefaultTheme(CustomTheme)` | @ohos.arkui.theme | 12（darkColors 20） | 应用级品牌色+深色板，系统组件（弹窗/菜单/Select/加载）自动深浅色 |
| `WithTheme({theme, colorMode})` | with_theme.d.ts | 12 | 子树主题作用域 |
| 弹窗 `systemMaterial` | alert_dialog/action_sheet/custom_dialog_controller | 26 | 系统材质弹窗，自动深浅 |
| `Select.menuSystemMaterial` | select.d.ts | 26 | 选择菜单材质 |
| `HdsSnackBar` | @kit.UIDesignKit | 6.0(20) | 官方 Snackbar（带主题参数），替代自绘 toast |
| `HdsListItem` + `HdsSwipeActionOptions` | @hms.hds.HdsStyle | 6.0(20) | 官方左滑操作（删除/标记已读） |
| `HdsListItemCard` | hdsBaseComponent | — | HDS 卡片列表项 |
| `NavigationTitleOptions.scrollEffectOptions` + `systemMaterial` | navigation.d.ts | 26 | 标题栏滚动渐变模糊（COMMON_BLUR/GRADUAL_BLUR） |
| `Tabs.barFloatingStyle{systemMaterial, maskColor, barBottomMargin, adaptToHandedness}` | tabs.d.ts | 26 | 浮动页签深色适配（HdsTabs 已用 barFloatingStyle，需查材质深浅） |
| `List.backPressBehavior` | list.d.ts | 26 | 返回键收起左滑 |
| `onAreaChange(event, {expectedUpdateInterval})` | common.d.ts | 26 | 区域变化回调节流 |
| `Web.keyboardAppearance(WebKeyboardAppearanceMode)` | web.d.ts | 26 | 网页键盘沉浸 |
| `ReadonlyEnvKey.WINDOW_AVOID_AREA` | common.d.ts (@Env) | 26 | V2 响应式安全区（备用，非全屏模型暂不需要） |

兼容性：compileSdk 6.1.0(23) / targetSdk 26 —— API 20/23 能力可直接用；API 24+ 需运行时判断；
API 26 能力在 Mate 80 Pro (6.1.x) 模拟器上可用，低版本设备需谨慎（本项目最低兼容 23，采用时注意 @since）。

## 1. Bug 清单（模拟器双主题逐页扫描实证）

### A. 显示类

| # | 现象 | 页面 | 复现 | 根因定位方向 |
|---|---|---|---|---|
| A1 | 数据少的列表不顶对齐，卡片悬在页面中部/底部，大片空白 | 动态 Tab、我的 Tab 动态区、用户详情动态区、通知列表 | 双主题 | PullLoadMoreList/列表容器 align 默认 Center（同设置页 527px 空白根因家族） |
| A2 | 浮动 Tab 胶囊与底部遮罩在深色下是浅色，未选中页签对比度低 | 首页 | 深色 | HdsTabs barFloatingStyle 材质/maskColor 未跟深色 |
| A3 | 列表末条内容被浮动 Tab 遮挡、文字被手势区裁切 | 趋势 Tab | 双主题 | 列表 bottom padding 未计入浮动栏高度 |
| A4 | 浅色模式下首页 AppBar 仍是深色，且状态栏色与 AppBar 色不一致（两种深色） | 首页 | 浅色 | 自定义 AppBar 背景未接 ThemeManager palette；EVENT_THEME_CHANGED 只刷状态栏 |
| A5 | 浅色模式下用户详情页头部整块深色 | 用户详情 | 浅色 | 头部背景写死深色 |
| A6 | 列表区域背景与页面背景不一致（灰 vs 白） | 我的/用户详情/动态 | 双主题 | PullLoadMoreList 背景独立于页面背景 |
| A7 | 空/错误态图标渲染成"三条横线"，文案英文未本地化 | 通用列表页等 | 双主题 | EmptyState 图标资源错误 + I18n 缺失 |
| A8 | 深色模式下 WebView 纯白刺眼 | 网页 | 深色 | WebView 未跟随深色（forceDark/算法加深未开） |
| A9 | 抽屉菜单项图标全部缺失（只剩文字） | 首页抽屉 | 双主题 | FA_* 图标字体/资源未渲染 |
| A10 | markdown 列表 bullet 点几乎不可见；链接无链接色、点击无效 | CodeDetail | 双主题 | bullet 颜色未接主题；onLinkClick 未接线（R10 遗留） |
| A11 | 详情页事件列表整片空白（分区控件下方） | 仓库详情 | 双主题 | 数据未加载或渲染失败（待 hilog）→ 也算逻辑类 B3 |

### B. 逻辑类

| # | 现象 | 复现 | 根因定位方向 |
|---|---|---|---|
| B1 | 应用运行中收到 aa start/深链参数不生效（外部链接打开无反应） | 热启动带参数 | onNewWant 已写 BootChannel，但 HomePage/Welcome 只在构建时消费一次，无重新消费通道 |
| B2 | bootCommonList repositories 列表数据未加载（空/错误态） | 双主题 | 查 hilog：参数解析 / API / 响应解析 |
| B3 | 仓库详情"事件"列表空白 | 双主题 | 同上 |
| B4 | 主题/个人信息入口混乱：设置页入口=点头像；抽屉"个人信息"=资料页 | — | UX 设计问题 |

### C. 设计/UX 欠缺

| # | 现象 |
|---|---|
| C1 | 通用列表页标题重复（原生标题栏 + 页内 header 同文案） |
| C2 | 语言切换两个入口（抽屉 + 设置页）功能重叠 |
| C3 | 登录/欢迎页应用图标为华为花瓣（应使用应用自身品牌图） |
| C4 | 仓库详情头部照片直接铺字，视觉噪点大（后置） |
| C5 | Release 页"更多"菜单入口时序（R10 遗留待查，顺带） |

## 2. 阶段计划

### 阶段 1：主题正确性（官方主题框架 + 写死深色清零）
1. `ThemeControl.setDefaultTheme`：把 GSY LIGHT/DARK 调色板映射成官方 `Colors` 语义（brand/compBackground*/font*/compDivider…），EntryAbility 启动时设置一次 → 系统组件自动深浅。
2. CommonModal（AlertDialog/ActionSheet/PromptDialog/OptionsDialog）+ LoadingModal：接 `systemMaterial`（API 26）/官方主题色，深浅自适配，删写死色。
3. 首页 AppBar（A4）、用户详情头部（A5）接 `ThemeManager.current()` 响应式调色板；状态栏色与 AppBar 色统一从同一 token 取。
4. HdsTabs 深色适配（A2）：实测 hdsMaterial 深浅行为，必要时传 maskColor/materialColor 跟主题；顺带 A3 列表底部避让。
5. WebView 深色（A8）：算法加深/前置色注入，深色跟随。
6. 验证：设置页切深/浅，逐页截图对比；重点回归 A1-A8 各点。

### 阶段 2：列表布局与全局显示
1. PullLoadMoreList 顶对齐 + 背景统一（A1/A6，公共组件一处修，全局收益）。
2. EmptyState 图标 + 文案 I18n（A7）。
3. 抽屉图标渲染修复（A9）。
4. markdown bullet 颜色 + 链接色 + onLinkClick 接线（A10）。
5. 趋势/首页列表底部避让完善（A3）。

### 阶段 3：逻辑修复
1. 热启动深链（B1）：onNewWant 后经 EventBus 通知 HomePage 重新消费 boot 通道（保持既有 id/深链契约）。
2. B2/B3：hilog 定位 bootCommonList 与仓库事件列表数据链路，修复。
3. B4/C1/C2：设置入口理顺（抽屉加"设置"项、CommonList 重复标题去掉、语言入口收敛）。

### 阶段 4：官方组件采用
1. HdsSnackBar 替换 CommonToast（保留原调用签名，内部换实现）。
2. 通知列表/浏览历史接 HdsListItem 左滑（标记已读/删除）。
3. 标题栏滚动模糊 scrollEffectOptions（非全屏模型下实测有效再全量推开；无效则记录原因保持现状）。

### 阶段 5：收尾
- 双主题全页截图对比（与 R11 前 evidence 存档对比）+ hilog 无未捕获异常 + scenario-tour 关键链路 + codelinter 0 error。
- 状态文档 `harness/R11/STATUS.md` + known-issues 更新 + 提交推送。

## 3. 不变约束

- bundleName / 深链参数名 / 测试控件 id 契约 / Theme.ets 现有 token 值（ThemeManagerTest 锁定）不变。
- 非全屏官方窗口模型不变（全屏会破坏 .title/.menus 渲染，R10 已实证）。
- 每阶段独立提交；改动过模拟器实测后才算完成。
