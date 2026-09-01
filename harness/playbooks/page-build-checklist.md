# Page Build Checklist（每页 6 步建造流程）

每个 ArkTS 页面/可见组件必须按此 6 步流水建造，**不得跳步**。

> **2026-09-01 变更**：仓库主已获得原 RN 上游项目（CarGuo/GSYGithubApp）的完全授权，本仓库不再需要对照 RN 源码开发。原 Step 1"打开 RN 源"已删除，建造流程改为从 OH 现状出发。

---

## Step 1 — 抽布局骨架
逐层列出：根容器 → 一级子容器 → 二级 → 控件。
使用纯文本树形：
```
Column(mainBox)
├─ AppBar
└─ PullLoadMoreList
   ├─ Header(UserHeadItem)
   │  ├─ Stack(primaryColor 卡片)
   │  └─ Row → CountsCell × 5
   └─ Row → EventItem
```

## Step 2 — 抽样式 token
列出本页用到的 token 集合（颜色、字号、间距、圆角、阴影），全部映射到
[entry/src/main/ets/style/Theme.ets](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/style/Theme.ets)。
如本页需求超出既有 token → 在 Theme.ets 登记新增 token（带注释说明用途）。

页面文件**禁止**出现 `#xxx` / `12vp` / `30fp` 这类硬编码（除非是 Theme 内部）。

## Step 3 — 抽交互序列
按事件 → 数据 → 路由的顺序，列时序：
```
点击 GitHub 登录按钮
  → OauthService.buildAuthorizeUrl(...)
  → NavigationService.push(LoginWeb, params)
  → AuthDeepLinkBus 回调
  → LoginUseCase 换 token
  → NavigationService.replace(Home)
```

## Step 4 — ArkTS 落地
- 按骨架逐节点对应 ArkUI 组件
- 颜色/字号/间距引用 Theme，不允许内联硬编码
- 调试输出走 hilog domain `0x0666`，**禁止**写到 UI
- **R-UI-04 自检**（KI-048 守则）：依赖响应式字段（@State/@Prop/@ObjectLink/@StorageLink/@Provide/@Consume/@Link）渲染的子节点必须 inline 求值；
  本页 grep 扫描 `rg -n '@Builder' -A 1 entry/src/main/ets/<your-page>.ets | rg -E '\((string|number|boolean)\)|: (string|number|boolean)[,)]'`
  命中 → 对照 [R-UI-04 豁免清单](https://github.com/CarGuo/GSYGithubAppOH/blob/main/harness/rules/ui-parity-with-rn.md)（路由分发/静态文案/天然 immutable），不在豁免内必须重构

## Step 5 — 真机截图记录
1. `bash scripts/device-smoke.sh` 抓 `oh-<PageName>.png`
2. 归档到 `harness/regression/ui-parity/<PageName>.md` 第 3 节"截图记录"

## Step 6 — 写入 ui-parity 报告
模板：
```markdown
# <PageName> Page Report

## 1. 现状基准清单
- 源：[<PageName>.ets](../../entry/src/main/ets/pages/<PageName>.ets)
- 顶层容器：...
- 核心结构：...
- 样式 token：...
- 交互序列：...

## 2. ArkUI 落地
- 偏差点：...

## 3. 截图记录
| 版本 | OH 截图 |
|---|---|
| vN | ![oh](screenshots/<PageName>/oh_<PageName>_<vN>.png) |

## 4. 变更处理
- 已修齐：...
- OH 增强：...
- 平台豁免：...
```

---

完成 Step 1-6 后，在 INDEX.md 更新该行状态；任一步缺失置为 `🚧 partial`。
