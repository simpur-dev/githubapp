# R9 实时状态板 — 全项目重构（已完结）

> 长任务执行记录。上下文压缩后靠本文件 + README.md 续命。

## 最终状态（2026-09-10 夜间完工）

**全部阶段完成。双构建全绿（生产 unsigned + ohosTest）。codelinter 0 error / 3 warn（已核实为模式误报）。**

## 阶段账目（commit 对应）

| 阶段 | commit | 内容 |
|---|---|---|
| 阶段0+1 | 1c3b01d | 死代码清理（17 组件+死弹窗）+ common/5features/entry 三层物理拆分 + 全工程 import 重写 |
| 阶段1b 收尾 | db6624d | ohosTest 存量严格模式错误全清（约 120 处） |
| 阶段2.0 | acd0b09 | 全局状态去 AppStorage（Auth/Theme/BOOT→BootChannel/RouteParam/SafeArea 五通道 → 可观察单例，grep 归零） |
| 阶段2A | fa3e13f | feature-auth V2+MVVM（试点） |
| 阶段2B | ee908bc | feature-misc V2+MVVM |
| 阶段2C | d0e15a9 | feature-main V2+MVVM + PullLoadMoreList 升级 V2 受控组件 + 5 service 无状态化 |
| 阶段2D | 1a4f3a8 | feature-user V2+MVVM（UserDetailStore 删除、SubListView V2、修复 fetchUserEvents 分页历史 bug） |
| 阶段2E-1 | 2bb0b6c | feature-repo 仓库半区（RepositoryDetail 28@Trace、RepositoryService 17 方法无状态化） |
| 阶段2E-2 | 3201b32 | feature-repo Issue/Push/Code 半区 + IssueDetailStore/RepositoryDetailStore 删除 + CreateIssueDialog 删除 |
| 阶段3 | abdadd2 | 原生组件替换：SideBarContainer 抽屉 / bindMenu 分支菜单 / 原生 Radio×2 / SymbolGlyph 图标 |
| 阶段5a | fcf2c43 | common 层全 V2 化（grep @Component 归零）+ LoadingModal openCustomDialog 化 + 两个 store 尾巴删除 + getContext 清零 |
| 阶段4 | 4009298 | 22 页原生 Navigation 标题栏(.title/.menus) + 2 页原生工具栏(.toolbarConfiguration) + NavTitleBridge + scenario-tour.sh 同步 |
| 阶段6 | （本提交） | lint 0 error + 启动图标签 256 规范 + 文档收口（README/架构总览/known-issues/KI-R9-001..004） |

## 达成度对照（用户目标）

1. **鸿蒙原生组件尽可能替换** ✅：系统 Refresh 指示器、Navigation 原生标题栏+工具栏、SideBarContainer、bindMenu、原生 Radio、SymbolGlyph（对照 SDK 符号表）、AlertDialog/ActionSheet/bindSheet、原生 markdown 渲染（MD4C，重构前已有）。保留的自绘：TabIcon 已 SymbolGlyph；CommonBottomBar 行组件仍在（挂原生工具栏容器内）；ActivityTab 头部选择条（随内容滚动，非工具栏，有意保留）。
2. **官方高质量架构** ✅：三层多模块（products/features/common）依赖严格单向；MVVM（View/ViewModel@ObservedV2/无状态 service）；UDF/SSOT；V1 装饰器全工程归零。
3. **性能** ✅：@Trace 细粒度刷新（历史冻结 workaround 全删）、长列表 Repeat.virtualScroll+cachedCount、启动图标签 256 规范、死代码 -17 文件、Store 层删除（UI 状态唯一来源化）。余量：route_map 懒加载（KI-R9-004 登记）。
4. **skills 充分调用** ✅：hmos-arkui-mvvm-pattern、hmos-arkui-statemgt-migration、hmos-arkui-develop-skill、hmos-arkui-knowledge-retriever、deveco-studio-codelinter。
5. **不走真机** ✅：全程未碰 hdc；设备回归欠账登记 KI-R9-001。

## 环境事实（本机 Windows）

- DevEco：`E:\programapp\devcostudio\DevEco Studio`；编译 `source scripts/env-win.sh && hvigorw assembleHap --mode module -p product=unsigned -p buildMode=debug --no-daemon`（unsigned 为无签名验证产品）。
- lint：`node "$DEVECO_HOME/plugins/codelinter/run/index.js" -c code-linter.json5 -f json -o <out> .`
- 迁移工具沉淀在 harness/R9/tools/（桶生成、import 重写、搬家脚本，可审计本次机械迁移）。

## 遗留清单（均已登记 known-issues.md）

- KI-R9-001 真机全场景回归（下次有设备时）
- KI-R9-002 SettingUiTest 两条陈旧断言
- KI-R9-003 codelinter RdbStore 误报（不修）
- KI-R9-004 路由懒加载优化余量
