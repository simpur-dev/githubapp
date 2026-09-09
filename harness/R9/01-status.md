# R9 实时状态板

> 每完成一个阶段立即更新。长会话上下文被压缩后，靠本文件 + README.md 续命。

更新时间：2026-09-10（夜里）

## 环境事实（本机 Windows）

- DevEco：`E:\programapp\devcostudio\DevEco Studio`，node v24.14.1 / ohpm 26.0.0 / hvigorw 6.26.4。
- 编译命令：`source scripts/env-win.sh && hvigorw assembleHap --mode module -p product=unsigned -p buildMode=debug --no-daemon`（无签名产物，纯编译验证）。
- 基线：BUILD SUCCESSFUL in 39s（33 任务，2026-09-10）。存量 WARN：CodeDetailPage 等 `getContext` deprecated + 若干 "Function may throw exceptions"（阶段5清）。
- 坑：env.sh 是 macOS 版不能在 Git Bash 用（`E:/` 冒号拆坏 PATH）；必须用 scripts/env-win.sh；换过 SDK 环境先 `hvigorw --stop-daemon`。

## 阶段进度

| 阶段 | 状态 | 备注 |
|---|---|---|
| 指挥文档 R9 | ✅ | README.md 建好 |
| 工具链 + 基线编译 | ✅ | unsigned 产品已加进根 build-profile（additive，default 未动） |
| 阶段0 删死代码 | 🔄 | 逐个 grep 核实后删（两份探索报告对 CommonRowItem/OrgItemBar/IssueHead/PromptDialog 是否死代码有矛盾，以实测为准） |
| 阶段1 三层骨架 | ⏳ | |
| 阶段2A feature-auth | ⏳ | |
| 阶段2B feature-misc | ⏳ | |
| 阶段2C feature-main + 全局状态V2化 | ⏳ | |
| 阶段2D feature-user | ⏳ | |
| 阶段2E feature-repo | ⏳ | |
| 阶段3 原生组件替换 | ⏳ | |
| 阶段4 AppBar/底栏→原生 + 脚本id迁移 | ⏳ | |
| 阶段5 性能+静态检查 | ⏳ | |
| 阶段6 收口+审计 | ⏳ | |

## 关键决策追加记录

- （追加于此，避免只留在对话里）

## 模块搬家映射（阶段1执行时逐项打勾）

见 README.md §3。搬家顺序建议：common 先行（base→model→ui），再 features（auth→misc→main→user→repo），entry 收壳。
