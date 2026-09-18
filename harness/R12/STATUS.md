# R12 状态：官方体验对齐 + 120fps + 秒开加载

> 设计与执行记录：[docs/01-重构总方案.md](./docs/01-重构总方案.md)（含交付文档索引 02-06）。
> 代码即"可运行的重构核心代码框架"（交付标准第 7 项）：分层架构（entry + common HAR + 5 feature HAR，
> MVVM + V2 状态管理）、原生动画调用（expectedFrameRateRange/属性动画）、懒加载预加载实现
> （Repeat virtualScroll + cachedCount 分级 + SkeletonList + RDB 缓存优先）全部在仓库内，
> 索引入口：[../../common/Index.ets](../../common/Index.ets)。

## 提交记录

| 提交 | 内容 |
|---|---|
| bbec8f1 | P1 五 Tab 信息架构 + P3 通知左滑已读 + overlay 原生姿势修复 |
| 6be8a23 | P2 预缓存分级 + 骨架屏 + P4 动画满帧声明 |
| 本提交 | P6 交付文档（02 问题报告 / 03 120帧专项 / 04 懒加载预加载 / 05 技术选型 / 06 交互对齐）+ known-issues 登记 |

## 实测结论（模拟器 Mate 80 Pro, HarmonyOS 6.1.x）

- 五 Tab 切换/图标/文案全通；旧 bootTab 契约（dynamic/trend/my）+ 新增 code/notifications 全验证。
- 左滑"标记已读"与行对齐（overlay 修复后行高链恢复正常，行中心 y:1659→757）。
- 趋势页 8 连快滑（120ms/次）无白块无崩溃（cachedCount=8 生效）。
- 热启动深链 3s 内直出通知页数据（B1 重投通道）。
- codelinter 0 error / 4 warn（R10 存量，R12 零新增）。

## R12+ 补齐轮（本会话第二批，提交见 git log）

- **List 行过渡动效**：PullLoadMoreList 数据行挂原生 TransitionEffect（淡入+上移 250ms，满帧声明），全应用列表一处生效。
- **多设备断点适配**：WindowSize 单例（官方 sm/md/lg 口径）+ PullLoadMoreList md/lg 下内容 720vp 限宽居中（@Computed 响应）；sm 路径截图无回归，md/lg 宽屏视觉登记 KI-R12-010（真机批次）。
- **长按菜单验证限制**：模拟器 uitest 无法合成 500ms 长按 → KI-R12-009（真机/人工验证）。
- **技术结论补充**：SharedElementTransition 不采用依据（05 §3.1）；setBadgeNumber @26 deprecated、角标依赖通知发布通道（05 §3.2）。

## 遗留（登记）

- 真机项：120fps 帧率采集（SP_da）、冷启动 TTI ≤1.2s 实测（模拟器欢迎页停留干扰计时）。
- 功能项：列表行长按快捷菜单；HdsListItem 官方左滑形态替换（R13 候选）。
- 标题栏滚动模糊 scrollEffectOptions（非全屏模型下逐页实测后推广）。
- 共享元素转场（头像/仓库头图 geometry 标注）。
