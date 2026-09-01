# AGENTS.md — LLM 协作硬约束（最高优先级）

> **本文件是任何 AI 编码代理（Claude / GPT / Gemini / Cursor / Trae / 其他）进入本仓库后的第一行规则。**
> 任何会话、任何模型、任何 IDE，都必须在第一次写代码或调用工具之前完整读完这份文件。
> 如果你违反这里的任何一条，请立即承认违规并回滚——这不是建议，这是仓库主指定的工作纪律。

> **2026-09-01 变更**：仓库主已获得原 RN 上游项目（CarGuo/GSYGithubApp）的完全授权，本仓库不再需要对照 RN 源码开发。所有强制"先读 RN 源 / 对齐 RN 视觉 / 出 RN 对照截图"的规则已删除，本文件仅保留通用工程纪律。

---

## 1. 不可妥协的硬约束（HARD-LAW）

### HARD-LAW-1 | THEME-TOKEN-ONLY（违反即驳回）

ArkTS 文件中**禁止**出现：
- 字面量颜色 `'#XXXXXX'` 或 `Color.XXX`（除 Theme.ets 内部）
- 字面量字号 `fontSize(12)` `fontSize(14)`（除 Theme.ets 内部）
- 字面量间距 `padding(10)` `margin(8)`（除 Theme.ets 内部）

必须使用 [GSYColor / GSYFontSize / GSYIconSize / GSYSpacing / GSYShadow](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/style/Theme.ets) 统一暴露的颜色/字号/间距 token。

### HARD-LAW-2 | NO-DEBUG-PROBE-IN-PROD（违反即驳回）

main_pages.json 中注册的任何页面，禁止以下控件出现在 `Visibility.Visible` 或 `Visibility.None`：
- `xxx-count:N` `click:N` `pat-click:N` 等计数 Text
- 构建时间 / 版本哈希 / token 明文
- 仅开发者能理解的 raw 文本

需要调试断言 → 走 hilog domain `0x0666` 或 hypium 单元测试，**绝不允许**塞进 UI 树（即便隐藏）。

### HARD-LAW-3 | REGRESSION-EVIDENCE（违反即驳回）

每个页面的真机回归必须产出完整证据，缺一不可：

1. **OH 端真机截图** → `harness/regression/ui-parity/screenshots/<Page>/oh_<Page>_<vN>.png`（md5 必须与上一版不同）
2. **变化说明** → `harness/regression/ui-parity/<Page>.md` 第 3 节"截图记录"+ 第 4 节"变更处理"

### HARD-LAW-4 | PAGE-BUILD-CHECKLIST（违反即驳回）

严格执行 [page-build-checklist.md](https://github.com/CarGuo/GSYGithubAppOH/blob/main/harness/playbooks/page-build-checklist.md) 的 6 步：

| Step | 动作 | 完成标志 |
|---|---|---|
| 1 | 抽布局骨架 | `<Page>.md` § 核心结构（树状） |
| 2 | 抽样式 token | `<Page>.md` § token 映射表 |
| 3 | 抽交互序列 | `<Page>.md` § 交互序列伪代码 |
| 4 | ArkTS 落地 | Edit/Write 文件 + 编译通过 |
| 5 | 真机截图记录 | 截图齐全 + md5 不同 |
| 6 | 写入报告 | INDEX.md 状态更新 + 变更点登记 |

todo 粒度必须细到能映射到 6 步之一，**禁止**用"重构某页面 + 真机回归"这种粗粒度 todo 一蹴而就。

---

## 2. 跨会话续会 SOP

新会话起手第一动作（在 `TodoWrite` 之前）必须是：

```
1. Read ./AGENTS.md           ← 你正在读的这份
2. Read ./harness/R8/README.md  ← R8 主链单一入口（取代旧 HANDOFF-*）
3. Read ./harness/R8/00-rules.md
4. Read ./harness/R8/01-status.md
5. Read 当前 in-progress 主链对应的 L<n>-*.md
6. Read ./harness/regression/known-issues.md
```

读完后才允许：
- 创建 todo 列表
- 调用 Edit/Write
- 调用 RunCommand 执行 hvigorw / hdc

**禁止**直接基于会话上下文压缩 summary 就开干，summary 不是规则的事实源。

---

## 3. 自检清单（每次 commit 前）

```
☐ 我的 ArkTS 文件没有任何字面量颜色/字号/间距吗？（HARD-LAW-1）
☐ 我没有在 UI 树里塞调试 Text 吗？（HARD-LAW-2）
☐ 我有 OH 截图 + 变更说明吗？（HARD-LAW-3）
☐ 我的 todo 是按 6 步建造流程拆分的吗？（HARD-LAW-4）
☐ 我已经在 INDEX.md 登记了状态变化吗？（HARD-LAW-4 + step 6）
```

任何一项打 ✗ → 立即回滚提交，公开承认违规，重做。

---

## 4. 沟通风格硬约束（NO-JARGON）

**用户在 2026-05-27 拍板：以后回复必须用大白话，不允许用业内黑话。**

### 什么叫"业内黑话"（禁止）

下面这些表达，回复给用户看时**一律禁用**（写在代码注释、md 文档内部仍可保留，仅约束面向用户的对话回复）：

1. **状态术语黑话**：`Code-Ready`、`闭环`、`收口`、`落地`、`抽证`、`抽源`、`兜底`、`链路`、`接通`、`基线`、`绿`、`红`、`P0/P1/P2/P3`、`DoD`、`scope=A/B/C`、`ok=N fail=N`、`md5=xxxxxx…`
2. **流程术语黑话**：`HARD-LAW-N`、`R-UI-0N`、`KI-XXX`、`L6.5-S4`、`7-step`、`三件套`、`@Builder 值参冻结`、`R-UI-05 守则`、`token-only`、`token 化`、`token 清零`、`grep 自检`、`GetDiagnostics=[]`、`ONE-CHAIN`
3. **架构术语黑话直堆**：`BOOT_*_KEY 第 N 套`、`scheduleBoot* 同款时序`、`onLoadIntercept 3 分支`、`pathInfo.param 优先 / AppStorage 兜底`
4. **凑字进度感**：`严格按 X-step 推完`、`一次过`、`无错误 / 无返工`、`HARD-LAW-1..6 全 ☑`、`本主链 / 本轮 / 本期`

### 大白话替换原则

| 黑话 | 大白话 |
|---|---|
| Code-Ready | 代码写完了，等真机测试 |
| 闭环 | 这件事做完了 |
| 抽源 / 抽证 | 看了现在代码这边什么样 |
| 兜底 | 没传值的时候用什么默认值 |
| 链路接通 | 从入口到目标页能正常跳过去 |
| token-only | 颜色字号间距全走 Theme.ets，没写死 |
| HARD-LAW-N 全 ☑ | 仓库的几条铁律我都对照检查过 |
| GetDiagnostics=[] | 编辑器没报错 |
| KI-049 候选 | 顺手发现一个新问题，记下来等以后修 |
| L6.5-S4 ArkTS 落地 | L6.5 这个任务的第 4 步：把代码写出来 |

### 具体执行规则

1. **优先讲做了什么、现在长什么样、下一步还要做什么**，三件事讲清楚就够了
2. **不要堆术语和编号**：必要时只在第一次出现时用括号注明（例如"KI-049（一个待修的小问题）"），后面就直接用"这个待修问题"
3. **不要凑成就感**：避免"严格按 / 一次过 / 全部 ☑ / 全闭环"这类话
4. **md 文档里照旧**：本规则只约束**对话回复**，写进 `harness/R8/01-status.md`、`harness/regression/ui-parity/*.md`、`known-issues.md` 的内部记录仍可用术语（避免重写历史成本）
5. **代码注释照旧**：英文 API 名、装饰器、HARD-LAW-N、KI-XXX 在代码注释里保留（方便检索）

### 违反怎么办

用户随时可以指出哪句话是黑话；指出后立即用大白话改写，**不允许辩解**（理由是"约定俗成"也不行）。

---

## 5. 开源安全约定

- 不提交 `oauth.local.json`、`local.properties`、Personal Access Token、client secret、签名私钥、账号 Cookie 或真实登录截图。
- OAuth 本地配置只允许放在 `entry/src/main/resources/rawfile/oauth.local.json`，仓库只提交 `oauth.local.example.json` 占位模板。
- DevEco 生成的 `.p12 / .csr / .cer / .p7b` 签名材料不得入库。
- 真机录屏、hilog 原始日志、临时回归报告默认不提交，因为里面可能有用户信息、请求参数或本机路径。
- README、报告和提交日志里只能写脱敏配置示例；自查时至少扫描 `ghp_`、`github_pat_`、真实 `CLIENT_SECRET`、`Authorization: token <真实值>`。

---

## 6. 与本仓库其他规则文档的关系

```
AGENTS.md（本文件，最高优先级）
  └─ 引用 → harness/playbooks/page-build-checklist.md（页面建造流程）
  └─ 引用 → harness/HANDOFF-*.md（当前未结清状态）
  └─ 引用 → harness/regression/known-issues.md（问题登记）
  └─ 引用 → harness/regression/ui-parity/INDEX.md（页面状态矩阵）
```

如有冲突，以 AGENTS.md 为准。
