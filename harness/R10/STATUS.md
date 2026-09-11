# R10 全面优化 — 状态与验证记录

> 2026-09-12 执行。前置：R9 三层模块 + V2 + MVVM 重构已完成。
> 用户拍板：系统材质风 UI + 全面深色支持 + 全部优化项纳入；模拟器验证（不碰真机）。

## 已完成阶段

| 阶段 | 内容 | 提交 |
|---|---|---|
| 阶段1 | 全屏沉浸 + 系统原生标题栏（实验证实：全屏窗口下 NavDestination 默认避让状态栏，系统返回键 y=137 自动在状态栏下方；标题栏背景自动延伸）+ NavigationTitleOptions（滚动模糊 GRADUAL_BLUR）+ 每分支 systemBarStyle | 293446e |
| 阶段2 | 全面深色支持：ThemePalette 语义位补全（tabBackground/surfaceSubtle/onBrandText）+ ThemeManager.init 启动恢复 + 51 文件 450+ 处语义色下沉（palette 驱动）+ Markdown/WebView 深色双套样式 | 21f11fe |
| 阶段2收口 | 主题持久化修复：根因 Preferences.init 时序（ThemeManager.init 读 KEY_THEME 早于偏好就绪 → 静默回退浅色）→ onCreate 先 Preferences.init 再 ThemeManager.init。实测重启深色保持（状态栏/头部 13,16,21、内容 33,38,44） | cf08d0a |
| 阶段3 | UI 美化：PressableCard 按压反馈（蒙层+缩放动画）应用全部列表行；EmptyState 统一空态/错误态（SymbolGlyph+重试）；Issue open/closed 状态 pill（列表+详情）；ContributionHeatmap 53x7 热力图落 HonorPage；NotifyPage 分段条材质化+未读圆点；Theme.ets 新增 14 token | 73c9f1d |
| 阶段4+5 | 性能：Navigation stackSizeLimit=30、Repeat 内存优化策略、ResultSet try-finally（4 处）、6 处 Image alt、MarkdownRenderer 图片防撑跳、NotifyViewModel catch。结构：删 5 个无入口子列表页（~740 行）+ 5 路由、删约 80 个死导出（IconFont 28 FA_*/Constant.ets 整文件等）、EntryAbility boot 注入表驱动（488→280 行）、AppSymbol 白名单合一、EventActionUtil 模板表驱动（159 行 if-else 链） | ba68159 |
| 收口 | codelinter await-thenable 4 error 清零（init 去 async 返回共享 Promise）；全页面双主题扫描验证 | 7d694bd |

## 全页面状态栏区域扫描（用户重点验收项）

方法：每页 force-stop → boot 参数直达 → 截图取色（状态栏 10,15 / 标题栏 640,160 / 内容 640,800 / 底部 640,2820）+ dump 结构 + pid 存活检查。深浅色各一轮 × 13 页。

### 深色（全部通过，无崩溃）
| 页面 | 状态栏 | 标题栏区 | 底边 | 判定 |
|---|---|---|---|---|
| home / trend / my / search / issueDetail / pushDetail / codeDetail / commonList | 13,16,21 | 13,16,21 | 224,226,225 | ✅ 深色沉浸一致 |
| repoDetail / userDetail / notify | 22,27,33 | 22,27,33 | 22,27,33 | ✅（修复前 236 浅灰不一致，已通过标题栏 backgroundColor 主题化修复） |
| webPage | 22,27,33 | 22,27,33 | 255（Web 白内容） | ✅ 跟随内容 |
| photoPage | 13,16,21 | 36,41,47 | 36,41,47 | ✅ 深色看图页 |

### 浅色（全部通过）
| 页面 | 状态栏 | 标题栏区 | 底边 |
|---|---|---|---|
| home 系 / search / issue / push / code / commonList | 36,41,47（深头部） | 36,41,47 | 246 |
| repoDetail / userDetail / notify / webPage | 246,247,251（浅） | 246,247,251 | 238-255 |
| photoPage | 36,41,47（深看图页） | 36,41,47 | — |

### 系统返回键
全屏下自动避开状态栏（y=137-168，状态栏底 ~117px）✅；边缘右滑返回手势系统默认保留 ✅。

## codelinter
最终 0 error / 4 warn：2 处 datashare-query（RdbStore.query/querySql "结果集要关闭"——消费方 DaoBase 已 close，跨文件误报，见 known-issues KI-R9-003）+ 行号漂移；1 处 bad-deep-clone（IssueDetailViewModel JSON 深拷贝——structuredClone 在本 SDK 不存在，无法按建议改，误报登记）。

## 遗留（backlog）
- 路由系统路由表/懒加载（KI-R9-004）
- RouteParamReader 三层取参收敛（涉及与 UI 美化批次的文件冲突，移入 backlog）
- ReadmeTab WebView 深色切主题需重进页面刷新
- UserHeadItem 📍/🏢 emoji 保留（SDK symbol 白名单外）
