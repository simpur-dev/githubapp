# R8 硬约束 + 6 步流程 + DoD

> 写代码前必读。任何违反将导致主链状态被回滚，且不能进入下一条。

> **2026-09-01 变更**：仓库主已获得原 RN 上游项目（CarGuo/GSYGithubApp）的完全授权，本仓库不再需要对照 RN 源码开发。RN-FIRST / RN 截图对照相关条款已删除，本文件仅保留 OH 端工程纪律。

---

## 一、硬约束（HARD-LAW）

### HARD-LAW-1 TOKEN-ONLY
ArkTS 文件禁止：
- 字面量颜色（`'#XXXXXX'` `Color.XXX`，除 [Theme.ets](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/style/Theme.ets) 内部）
- 字面量字号（`fontSize(12)`）
- 字面量间距（`padding(10)`）

必须走 [GSYColor / GSYFontSize / GSYIconSize / GSYSpacing / GSYShadow](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/style/Theme.ets)。

### HARD-LAW-2 NO-DEBUG-PROBE
注册到 main_pages.json 的页面禁止 UI 树出现：
- `xxx-count:N` `click:N` `pat-click:N` 等计数 Text
- 构建时间 / 版本哈希 / token 明文 / 仅开发者能理解的 raw 文本

需要诊断 → hilog domain `0x0666`，绝不允许塞进 UI 树（即便 visibility:None）。

### HARD-LAW-3 REGRESSION-EVIDENCE
每个页面真机回归必须产出：
1. OH 截图 → 本次回归报告目录（reports/M6/r8-`<chain>`-`<date>-<hhmm>`/）
2. 变化说明 → 本主链文档 § 3 截图记录 + § 4 变更处理

### HARD-LAW-4 6-STEP
严格 S1..S6（见下方第二节）。todo 粒度必须能映射到具体某一步，禁止"L1 一蹴而就"这种粗粒度。

### HARD-LAW-5 ONE-CHAIN-AT-A-TIME
本主链 DoD 不达标 → **不得宣布完成，不得进入下一条**。

---

## 二、6 步固定流程

| Step | 动作 | 完成标志 |
|---|---|---|
| **S1 Read OH 现状** | 读当前 ArkTS 实现 + 相关 store/service/dao/api | 本主链文档 § 1 现状基准清单（结构树 + token 映射 + 交互序列）写完 |
| **S2 Diff** | 对照读 [known-issues.md](https://github.com/CarGuo/GSYGithubAppOH/blob/main/harness/regression/known-issues.md) + [INDEX.md](https://github.com/CarGuo/GSYGithubAppOH/blob/main/harness/regression/ui-parity/INDEX.md) | 本主链文档 § 2 偏差清单写完，每条偏差 4 字段（现象 / 现状 / 根因 / 影响文件） |
| **S3 Fix Code** | 按偏差清单改 ArkTS（HARD-LAW 全自检） | grep 0 字面量 / 0 调试 Text / 编译通过 |
| **S4 Build** | `hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon` | BUILD SUCCESSFUL |
| **S5 RunOnDevice** | hdc 装机 + scenario-tour.sh 限定该主链跑通 | 截图 md5 唯一 + hilog BEGIN/END marker + assert ≥ 3 [OK] |
| **S6 Record** | 截图归档 + 变化说明写入本主链文档 | 变化 ≤ 5 处登记 § 3，> 5 处回 S3 |

---

## 三、DoD（每条主链必须满足 10 项）

```
☐ 1. 本主链文档三件套齐：§1 现状基准 / §2 偏差 / §3 截图记录+变更处理
☐ 2. ArkTS 文件 grep 字面量颜色/字号/间距 = 0
☐ 3. ArkTS 文件 grep 调试探针 Text = 0
☐ 4. hvigorw assembleHap BUILD SUCCESSFUL
☐ 5. scenario-tour.sh 该主链入口跑通 ok=N fail=0
☐ 6. 截图 md5 唯一（不同场景至少 2 个不同 md5）
☐ 7. hilog 0x0666 有 BEGIN/END marker + assert [OK] ≥ 3
☐ 8. 变更点 ≤ 5 处，每处登记或豁免
☐ 9. INDEX.md 状态更新
☐10. known-issues.md 关联 KI 全部 Closed 或留 P2 + 原因
```

任何一项 ✗ → 不得宣布完成。

---

## 四、报告产物归档约定

```
harness/regression/reports/M6/r8-<chain>-<date>-<hhmm>/
├─ device.txt                # hdc target / build / version
├─ <NN>_<scenario>.png       # 截图
├─ <NN>_<scenario>.json      # dumpLayout
├─ hilog_business.log        # hilog -P PID -x（domain 0x0666）追加
├─ asserts.log               # 断言结果（[OK]/[FAIL]）
├─ md5sums.txt               # 截图 md5 校验
└─ README.md                 # 本次跑分概要 + KI 状态升级
```

工具：[scripts/scenario-tour.sh](https://github.com/CarGuo/GSYGithubAppOH/blob/main/scripts/scenario-tour.sh)。

---

## 五、反作弊纪律

1. **禁止自评 ✅ 而无 OH 真机截图**（违反 HARD-LAW-1 + HARD-LAW-3）
2. **禁止"代码 path 闭环"代替"视觉层闭环"**：S6 必须出 OH 真机截图
3. **禁止跳过 S5 真机跑直接进下一条**：DoD 第 5/6/7/8 项强约束
4. **禁止用 commit 数量代替 KI 关闭数量**：每个 commit 必须挂 KI-XXX 状态升级
5. **禁止 todo 粒度模糊**：todo 必须映射到具体某一步（如 "L1-S5 跑 repoDetail-activity tab"）

违反任意一条 → 立即回滚 + 公开承认违规 + 在 [AGENTS.md](https://github.com/CarGuo/GSYGithubAppOH/blob/main/AGENTS.md) 追加一条。

---

## 六、提交节奏

| 阶段 | commit 数 | 内容 |
|---|---|---|
| L1 完成 | 1 | 代码 + L1 报告 + INDEX 升级 + KI 关闭 |
| L2..L5 各完成 | 1 each = 4 | 同上 |
| L6 6 页各完成 | 1 each = 6 | 同上 |
| L7 完成 | 1 + tag R8 | 总回归 + milestone |

预计 12 commits + 1 tag。
