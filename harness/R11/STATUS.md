# R11 状态：Bug 修复 + 官方能力深采用

> 设计与执行记录：[DESIGN.md](./DESIGN.md)（Bug 清单 A1-A11/B1-B4/C1-C5、官方能力清单、逐项验证结论）。
> 证据截图（模拟器 Mate 80 Pro）：`C:\Users\34928\AppData\Local\Temp\r11\`（dark_*/light_* 扫描 + v1_/v2_/v3_ 修复验证）。

## 轮次概览

| 阶段 | 内容 | 提交 |
|---|---|---|
| 调研 | SDK API 24-26 全量枚举；HDS 组件库（@kit.UIDesignKit）；官方主题框架 @ohos.arkui.theme；WithTheme/ThemeControl 官方文档核对 | — |
| 扫描 | 双主题 25 张逐页截图 + 布局转储，实证 Bug 清单（见 DESIGN.md §1） | — |
| 阶段1 | 官方主题框架接入（SystemThemeBridge→ThemeControl.setDefaultTheme）、弹窗 systemMaterial、HdsTabs 深色、WebView 深色 | 631c0e8 |
| 阶段2+3 | A1 短列表悬空、A7 空态 I18n、A9 抽屉图标、A10 markdown 解析/链接、B1 热启动深链、B2 数据错位 | 741ae29 |
| 阶段4 | A3 尾部避让、B4 抽屉设置入口、设计文档补记 | 本提交 |

## 关键修复（均模拟器实测）

1. **官方主题框架**：`ThemeControl.setDefaultTheme({colors, darkColors})` —— 系统组件（AlertDialog/ActionSheet/菜单）按品牌浅色板+深色板自动切换；实测"发现新版本"弹窗在深色下为半透明系统材质卡。
2. **浮动页签深色适配**：`gradientMask.maskColor/lightColor` 接调色板（原写死 #E6FFFFFF 白带）；实测深色下为深色胶囊。
3. **热启动深链**：onNewWant → EVENT_BOOT_REDELIVERED → HomePage 重新消费 BootChannel；实测应用运行中 aa start 带 bootRepo 直接打开仓库详情。
4. **短列表悬空（全局）**：PressableCard 的 Stack 改 Top 对齐，一行修复全部列表页。
5. **markdown**：li 内嵌 p 不拆行（圆点与内容合一）；链接色 + onLinkClick 接线（ReadmeTab 复用 interceptUrl 路由）。

## 质量门

- hvigor 构建：BUILD SUCCESSFUL（每个阶段独立验证）。
- codelinter：**Errors 0 / Warns 4**（4 条均为 R10 已记录存量：IssueDetailViewModel deep-clone ×1、RdbStore 结果集关闭 ×3），本轮零新增。
- 设备验证：深色弹窗材质、浮动页签深浅色、网页深色、趋势页尾部避让、抽屉图标+设置入口、热启动深链、通用列表中文空态 —— 逐项截图确认。

## 遗留与延后（详见 DESIGN.md §4）

- HdsListItem 左滑（通知标记已读 / 历史删除）→ R12 功能增强。
- 标题栏滚动模糊 scrollEffectOptions → 需非全屏模型下逐页实测后推广。
- Release 页"更多"菜单时序（R10 遗留）→ 未复现未修，保持登记。
- C3 登录/欢迎页华为花瓣图标 → 品牌资源问题，待替换应用图标资源。
