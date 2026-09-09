# R9 全项目重构 — 单一权威入口

> 2026-09-10 立项。目标：把 GSYGithubAppOH 彻底改造为「鸿蒙原生组件优先 + 官方高质量三层架构 + 状态管理 V2 + 高性能」的工程。
> 本目录是本轮唯一权威文档源。用户已拍板 4 项决策 + 免真机（见 §2）。

---

## 1. 目标（用户原话转述）

1. 尽可能使用鸿蒙原生组件（能不自己画的就不自己画）。
2. 架构严格遵循鸿蒙官方推荐的高质量架构（三层多模块 + MVVM + 单向数据流）。
3. 应用性能尽可能好（细粒度刷新、列表虚拟滚动、路由懒加载）。
4. 状态管理全量迁移 V2（用户拍板）。
5. 今晚长任务，必须全部完成才停；充分调用本机 skills；**不走真机**（用户明示，真机会阻塞工作）。

## 2. 用户拍板记录（2026-09-10）

| 决策点 | 结论 |
|---|---|
| 状态管理 | **V2 全量迁移**（@ComponentV2/@ObservedV2/@Trace/@Local/@Param/@Monitor/@Computed/Repeat；禁 V1/V2 混用） |
| 工程结构 | **完整三层物理拆分**：common(HAR) + features(HAR×5) + entry 产品壳(HAP)，依赖严格单向 |
| AppBar/CommonBottomBar | **纳入改造，放最后一批**（阶段4），scenario-tour.sh id 断言同步迁移 |
| 真机证据 | **不走真机**。验证 = 编译通过 + 逻辑单测（无设备部分）+ 静态检查 + codelinter。真机回归（scenario-tour.sh 全场景 + 截图）留待设备可用时统一补，HARD-LAW-3 的真机证据在本轮以「编译+单测+静态」代偿并在 §7 登记 |

## 3. 目标架构

```
GSYGithubAppOH/
├── common/                       # 公共能力层 HAR（内部按 base/model/ui 分层）
│   └── src/main/ets/
│       ├── base/                 # net/ dao/ utils/ logger/ i18n/ eventbus/ navigation(NavigationService,Routes) / launch(BOOT通道)
│       ├── model/                # GitHub 数据实体 + repository（原 service/ 改造为无状态仓库，只返回数据不写 UI 状态）
│       └── ui/                   # Theme.ets + ThemeManager + 通用组件(PullLoadMoreList/CommonToast/CommonModal/IconFont/HTMLView/markdown原生渲染+cpp) + 跨feature共享widget(UserImage/EventItem/RepositoryItem/UserItem/UserHeadItem/IconTextItem/TimeText/SubListView/CreateIssueDialog)
├── features/
│   ├── feature-auth/             # WelcomePage LoginPage LoginWebPage HarmonyLogoMark
│   ├── feature-main/             # HomePage tabs(Dynamic/Trend/My/MyTabPage) drawer(SearchPage? no) SearchPage NotifyPage ReadHistoryPage TabIcon
│   ├── feature-repo/             # RepositoryDetailPage repo tabs(4) PushDetailPage CodeDetailPage ReleasePage CommonListPage 5个子列表页 RepositoryHeader IssueHead/IssueItem ReleaseItem
│   ├── feature-user/             # UserDetailPage UserFollower/FollowedPage PersonInfoPage OrgItemBar
│   └── feature-misc/             # SettingPage AboutPage HonorPage PhotoPage WebPage CustomPage
└── entry/                        # 产品壳：EntryAbility Index navigation/AppNavigator(routerMap) module.json5 深链 权限 BOOT want 解析
依赖方向：entry → features → common（严格单向，禁止 feature↔feature）
```

打包形态：全部 HAR（单产品单 HAP，无跨 HAP 单例失效问题；后续如需 HSP 再迁）。
native（cpp/md4c）随 common（HAR 支持含 native；如构建失败降级搬去 feature-repo）。

## 4. 必须原样保留的约束（重构红线）

1. **bundleName `cn.gsy.githubapp`、EntryAbility、深链 `gsygithubapp://authed`**（module.json5 skills 留在 entry）。
2. **15 个 boot want 参数名**（bootRepo/bootPush/bootIssue/bootCode/bootUser/bootPhoto/bootWeb/bootCommonList/bootNotifyIssue/bootLogin/bootWelcomeHold/bootLocale/bootTab/bootToken/bootSearchHistory）及其 `|` 分隔格式——机制内部可重写（去 AppStorage），但 `aa start --ps` 对外语义不变。
3. **scenario-tour.sh 控件 id**：约 140 个 `.id()` 字符串在阶段 0-3 一字不动；阶段 4（AppBar/底栏换原生）涉及的 id 同步改脚本。反向断言（不得出现的 id）同样有效。
4. **测试契约**：`entry/src/test/List.test.ets → ohosTest/ets/test/List.test.ets testsuite()` 转发、`LogicOnlyConfig.ets` 的 `export const LOGIC_ONLY` 常量与路径（run-tests.sh 写死）、test_pages.json 宿主页注册。
5. **Theme token 值**：GSYColor/GSYDarkColor 具体 hex 被 ThemeManagerTest 断言（大小写/alpha 锁死），只许搬位置不许改值。HARD-LAW-1 继续有效：页面 0 字面量颜色/字号/间距。
6. **main_pages.json 只注册 pages/Index**；页面全部经 Navigation 路由。
7. **libmd4c.so**：import 名不变，cpp 随模块走，abiFilters arm64-v8a/x86_64 保持。

## 5. 阶段计划与完成标准

| 阶段 | 内容 | 完成标准 |
|---|---|---|
| 0 | 删死代码（17 组件 + PromptDialog/OptionsDialog + HttpRecorder/DebugDumper） | 编译通过 |
| 1 | 搭 common + 5 features HAR 骨架；代码按 §3 搬家；修 import；build-profile/oh-package/hvigorfile 配齐 | 全量编译通过（含 ohosTest 编译） |
| 2A-2E | 逐 feature 做 V2+MVVM 改造（auth→misc→main→user→repo），每 feature：页面抽 ViewModel(@ObservedV2+@Trace)、@ComponentV2、repository 无状态化、去 AppStorage、ForEach→Repeat | 每 feature 编译通过 |
| 2C 附 | 全局状态 V2 化：AuthState/ThemeState/BootChannel/RouteParamStore 单例化，AppStorage 归零 | grep AppStorage 仅剩 AppStorageV2 或 0 |
| 3 | 原生组件替换：Refresh 原生指示器、SideBarContainer 抽屉、bindMenu 分支菜单、原生 Radio 语言选择、bindSheet 输入弹窗（id 全保留） | 编译通过 + id 断言核对 |
| 4 | AppBar/CommonBottomBar → NavDestination 原生标题栏/工具栏 + SymbolGlyph；scenario-tour.sh id 映射同步 | 编译通过 + 脚本 id 全表更新登记 |
| 5 | 性能专项：长列表 Repeat.virtualScroll、routerMap 动态 import、@Computed 派生、codelinter、废弃 API 清理 | codelinter 无 error |
| 6 | 全量编译 + 逻辑单测 + 文档收口（AGENTS.md 架构节、README 项目结构、INDEX、known-issues）+ 完成度审计 | 审计清单全 ☑ |

## 6. 本机工具链（Windows）

- DevEco Studio：`E:\programapp\devcostudio\DevEco Studio`（node v24.14.1 / ohpm 26.0.0 / hvigorw 6.26.4 / jbr）。
- 环境：`source scripts/env-win.sh`（env.sh 是 macOS 版，Windows Git Bash 下 PATH 会被 `E:/` 冒号拆坏，勿直接用）。
- 编译命令：`hvigorw assembleHap --mode module -p product=unsigned -p buildMode=debug --no-daemon`（**unsigned 产品**为本轮新增，无签名纯编译验证；default 产品签名材料仍是占位符，不要动）。
- 无真机：scenario-tour.sh 不跑；`hvigorw test` 需设备也不跑；单测验证以「测试代码可编译 + 纯逻辑部分静态审查」代偿。

## 7. 偏差登记（对既有铁律的豁免）

- HARD-LAW-3（真机截图证据）：用户 2026-09-10 明示本轮不走真机。代偿证据 = 每阶段编译通过记录 + 阶段6 全量编译 + codelinter。真机回归欠账登记在 known-issues.md（R9-REGRESS 条目）。
- HARD-LAW-4（每页 6 步）：本轮是架构重构不是新页建造，按 §5 阶段推进；每 feature 改造仍按「现状→搬迁→V2 改造→编译验证→登记」推进并在 01-status.md 留痕。

## 8. 进度状态

见 [01-status.md](./01-status.md)（每阶段完成即更新，长会话压缩后以此文件续命）。
