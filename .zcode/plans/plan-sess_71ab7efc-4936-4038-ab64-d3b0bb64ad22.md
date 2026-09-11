# R10 全面优化计划：原生质感 + 全面深色 + 高性能 + 结构清理

基于三份调研（SDK API 24/26 能力清单、代码欠账清查、UI 盘点）+ 你的三项拍板（系统材质风、全面深色、全部优化项纳入）。全程调用 skills：hmos-arkui-knowledge-retriever（API 查证）、deveco-studio-codelinter、hmos-arkts-deprecated-interface-checker、hmos-arkui-develop-skill 约束、模拟器+hilog 实测验证。**不碰真机**，验证=双构建+codelinter+模拟器像素实测。

## 阶段 1：全屏沉浸 + 原生标题栏（系统画返回键/标题/菜单）

刚做的实验已验证关键事实：全屏窗口下，原生 NavDestination 标题栏**自动避开状态栏**（系统返回键 y=137，状态栏下方），标题栏背景自动延伸到状态栏后面。所以可以放心回到全屏，并把自绘的标题内容全部还给系统：

1. EntryAbility/initSystemBars 恢复 `setWindowLayoutFullScreen(true)` + 状态栏/导航条透明。
2. 26 个路由分支改用官方 `NavigationTitleOptions`：`.title(标题或builder, { systemMaterial: ImmersiveMaterial(REGULAR), scrollEffectOptions: { GRADUAL_BLUR }, backgroundColor 按页面 })`——长列表页获得滚动模糊，深浅色自动适配。
3. 删除自绘 NavTitleView/NavMenusView 标题内容与返回键（`.menus` 改原生 ToolbarItem + SymbolGlyphModifier 图标，appbar_action_* id 规则保留）。
4. 每分支 `NavDestination.systemBarStyle({ statusBarContentColor })` 声明图标深浅（官方页面级 API，全屏下生效）；window API 仅保留 onBackground 置透明 / onForeground 恢复（防后台残留，已有机制）。
5. 底部避让恢复（全屏下手势条悬浮于内容上）：安全区改用官方 @26 通道 `ReadonlyEnvKey.WINDOW_AVOID_AREA`（V2 @Env 响应式）或恢复 avoidAreaChange 发布；CommonBottomBar rootMarginBottom、主页悬浮 Tab barBottomMargin、PullLoadMoreList tailPadding 默认值接上。
6. 模拟器像素验证：标题栏材质延伸到状态栏下、返回键/标题/菜单在状态栏下方、底栏项避让手势线、无崩溃。

## 阶段 2：全面深色支持（本轮最大项）

1. ThemeManager.init() 接入 EntryAbility 启动：恢复持久化主题（现在重启丢失）+ system 跟随。
2. DARK_PALETTE 语义补全（background/cardBackground/mainText/subText/divider/navBackground/tabBackground/surfaceSubtle 等核心语义色），提供 V2 响应式 palette 访问。
3. UI 扫描替换（调研清单定位的写死点）：页面 root 背景（49 处 white/cardBackground、9 处 mainBackground）、主/次文字色、分割线（#42464b 近黑线）→ palette 驱动；重点文件：NotifyPage、SearchPage、IssueTab、UserDetailPage、CommonListPage、DynamicTab/MyTab/TrendTab、ReadHistoryPage。
4. 深色内容适配：MarkdownRenderer 文字色接 palette、ReadmeTab HTML 内联 pre 底色、HtmlUtil body、代码高亮主题深色分支。
5. bindSheet/弹窗移除写死白底（API 26 系统材质接管，自动深浅色）；主页内容区/抽屉/TabIcon 接 palette。
6. 验证：设置切 Dark/System 逐页截图对比 + 重启后主题保持 + 模拟器系统深色联动。

## 阶段 3：UI 美化（三件套 + 热力图 + Notify 重构）

1. **按压反馈**：common 新增按压态封装（stateStyles pressed 背景/scale），应用到全部列表行组件（RepositoryItem/EventItem/UserItem/Notify 行/IssueTab 行等）。
2. **空态/错误态组件**：EmptyState（图标+双行文案+重试按钮，I18n）替换"一行字"空态；PullLoadMoreList 增加 error 状态参数；footer 文案 I18n 化（现硬编码英文且 10 个页面没传文案）。
3. **Issue 状态徽章**：列表行加 open/closed 色 pill（token 已有），详情页状态文字升级 pill。
4. **贡献热力图**：新建组件（heatmapLevel0-4 token + ContributionStore 数据已就绪）落到 HonorPage/我的页。
5. **NotifyPage 重构**：分段控件材质化、未读行视觉（unreadBg token）、阴影 bug 修复（NotifyPage/ReleaseItem 两处纯黑阴影 → cardShadowAlpha）。
6. 卡片规格统一（radius/边框/间距 token 化）、SearchPage 分割线与搜索框美化、FilesTab 分隔线。

## 阶段 4：性能

1. `Navigation.configuration({ stackSizeLimit })`（API 26）防深层浏览栈膨胀。
2. Repeat `memoryOptimizationStrategy`（API 26）+ 长列表 cachedCount 校准。
3. MarkdownRenderer 最后一处 ForEach→Repeat + onLinkClick 接线（现在链接点击无效）。
4. RdbStore/DaoBase/ReadHistoryDao/ReadHistoryService 结果集 try-finally 关闭（消除 3 条 lint 警告 + 异常路径泄漏）。
5. NotifyViewModel 缺失 catch、7 处 Image 补 alt/占位、MarkdownRenderer 图片行高度约束。
6. 路由系统路由表/懒加载：评估后列入 backlog（本次保留手动 routerMap，不做高风险迁移——如你要求可加做）。

## 阶段 5：结构清理 + 样板收敛

1. 删 5 个无生产入口的近克隆子列表页（~740 行）+ 5 路由 + 对应 title builders + SubListHostPage/SubListServiceTest 同步。
2. 删 NavBottomBar 残骸（~250 行）、约 80 个死导出、28 个死 FA 常量、Constant.ets 遗留层。
3. EntryAbility 14 个 boot 注入方法 → 表驱动（净减约 300 行）；"三层取参"样板 → RouteParamReader 公共化（8 个页面）。
4. SymbolGlyph 映射表合一（AppBar/NavTitleBridge 两份重复）；字符串常量归位（'stargazers' 裸字符串、UserDetailPage 本地复制常量）。
5. I18n 收口：'Theme'/'License'/'Custom'/'Following'/'图片加载失败'/HONOR_LIST 等写死文案。
6. 超长 build 拆分（RepositoryDetailPage 204 行、LoginPage 196 行、EventActionUtil 159 行表驱动）。

## 阶段 6：收口

- codelinter 0 error 0 warn；废弃 API 检查（hmos-arkts-deprecated-interface-checker）。
- 双构建全绿 + 模拟器全链手测（冷启/深链/各页面/深浅色切换/前后台切换/无崩溃）。
- 文档：R10 状态文档 + 架构总览更新 + known-issues 更新。

## 纪律与不变约束

- 不变：bundleName、深链、测试控件 id、Theme token 现有值（ThemeManagerTest 锁定）、scenario-tour 启动参数契约。
- 每阶段：双构建全绿 + 模拟器像素实测 + 独立提交。
- 深色改造采用"语义色渐进"策略：核心语义色（背景/卡片/文字/分割线）先行，装饰色（issue 绿/紫等）保持，避免半深半浅中间态——每阶段结束必须是无破相的完整状态。