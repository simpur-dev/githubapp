# 架构总览（ArkUI / HarmonyOS · R9 三层多模块版）

> 2026-09-10 R9 重构后现状。旧单模块结构的说明已归档进 git 历史（6306986 及之前）。

## 1. 模块分层（官方三层结构）

```
┌────────────────────────────────────────────────────────────┐
│ 产品定制层  entry (HAP)                                     │
│   EntryAbility / Index / AppNavigator 路由表 / 深链 / 权限   │
├────────────────────────────────────────────────────────────┤
│ 基础特性层  features/*.har                                   │
│   feature-auth  feature-main  feature-repo  feature-user    │
│   feature-misc    （每模块: pages + viewmodel + views）      │
├────────────────────────────────────────────────────────────┤
│ 公共能力层  common.har                                       │
│   base/(net/dao/utils/logger/i18n/navigation/launch)        │
│   model/(实体 + 无状态 service)                              │
│   ui/(Theme token/通用组件/共享widget/markdown)              │
└────────────────────────────────────────────────────────────┘
依赖方向严格单向：entry → features → common（编译器强制）
```

- **native**：MD4C（C 解析器）+ NAPI 桥随 feature-repo（唯一消费方），产出 libmd4c.so。
- **打包**：全部 HAR + 单 entry HAP（无跨 HAP 单例失效问题；如后续多产品再评估 HSP）。

## 2. MVVM 与状态管理（V2）

- **View**：`@ComponentV2` 页面/组件，只做组装与事件转发；`@Local vm` 持有 ViewModel；子组件 `@Param` + `@Event`。
- **ViewModel**：`@ObservedV2` + `@Trace`（UI 状态）/普通字段（分页游标等非 UI 态）/`@Computed`（派生值）；编排 service 调用并写 @Trace 字段。
- **Model**：service 全部无状态（构造不收 store），只做 HTTP+缓存取数并返回数据（Result 携带 page/hasMore；缓存先行走 onCached 回调）。
- **全局状态**：零 AppStorage。登录态 `GlobalAuthStore`（@ObservedV2 单例）+ EventBus 事件补偿；主题 `ThemeManager`；安全区 `SafeAreaInsets`；路由参数 `RouteParamStore`（Map 单例）；启动参数 `BootChannel`（EntryAbility 写、页面延时消费，键名为 scenario-tour 协议）。
- **渲染控制**：列表统一 Repeat（长列表 `.virtualScroll()` + 容器 `.cachedCount()`）；@Builder 不做响应式值参中转（R-UI-05 沿用）。

## 3. 导航与页面呈现

- 单根 Navigation（AppNavigator 持唯一 NavPathStack）+ NavDestination 页面。
- 标题栏/工具栏：NavDestination 原生 `.title(自定义builder)` + `.menus`；仓库/Issue 底栏为页面内挂载（系统工具栏高度固定 56vp 无法容纳手势条避让）。页面通过 `NavTitleBridge`（@ObservedV2 单例）注册标题/动作配置（titleGetter 支持动态标题，revision 补偿首帧时序）。
- 颜色沉浸（官方模型）：窗口全屏 + 状态栏恒透明，状态栏颜色 = 页面自身颜色延伸（NavTitleView/AppBar 自带状态栏高度内边距，无全局固定色）；窗口 API 仅动态切图标深浅（按页面声明，NavDestination .onShown 驱动）；底部内容铺到屏幕底边、可交互组件经 SafeAreaInsets.bottom 避让手势条。
- 弹层：AlertDialog/ActionSheet（CommonModal 封装）、bindSheet（输入/编辑表单）、bindMenu（分支选择等菜单）、LoadingModal（UIContext.openCustomDialog 句柄式）。V1 CustomDialogController 全工程清零。

## 4. 数据层

- net/HttpManager 门面（401 → LoginExpiredBus）、Address URL 表、NetworkMonitor。
- dao/：relationalStore 24 张离线表 + Preferences（token/语言/搜索历史/用户信息缓存）；查询结果消费方负责 close（DaoBase 范式）。
- service/：14 个领域 service（Repository/Issue/Issue 子操作/Commit/Code/User/Search/Notify/Trend/Dynamic/My/ReadHistory/Contribution/Oauth）。

## 5. 启动流程

1. EntryAbility `onCreate/onNewWant` → 解析 `boot*` want 参数写 BootChannel；OAuth 深链（gsygithubapp://authed）→ AuthDeepLinkBus。
2. `onWindowStageCreate` → loadContent('pages/Index') → AppNavigator（注入 NavigationService.stack、LoadingModal.attach）。
3. WelcomePage（feature-auth）读 token：无 → LoginPage；有 → 恢复用户信息 → HomePage（feature-main，Tabs：动态/趋势/我的 + SideBarContainer 抽屉）。
4. 详情页取参优先级：RouteParamStore.consume → NavDestination ctx.pathInfo → BootChannel 兜底（延时清理时序保留）。

## 6. 关键约束（变更前必读）

- bundleName `cn.gsy.githubapp`、EntryAbility、深链 scheme 不可改（脚本/签名绑定）。
- 控件 id 是 scenario-tour.sh 自动回归的协议（约 140 个），页面重构必须原样保留。
- Theme.ets token 单一事实源（GSYColor/GSYFontSize/GSYIconSize/GSYSpacing/GSYShadow/GSYDarkColor），页面 0 字面量；hex 值被 ThemeManagerTest 锁定。
- `aa start --ps boot*` 15 个启动参数名与格式不变（对回归协议）。

## 7. 构建/测试

```bash
source scripts/env-win.sh            # Windows Git Bash（macOS 用 scripts/env.sh）
hvigorw assembleHap --mode module -p product=unsigned -p buildMode=debug --no-daemon   # 无签名编译验证
hvigorw assembleHap --mode module -p module=entry@ohosTest -p product=unsigned -p buildMode=debug --no-daemon
./harness/regression/run-tests.sh    # 逻辑单测（LOGIC_ONLY）
./scripts/scenario-tour.sh           # 真机全场景回归（需设备）
```
