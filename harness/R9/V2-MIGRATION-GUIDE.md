# R9 V2 + MVVM 迁移指南（feature 改造执行手册）

> 每个负责改造一个 feature 的执行者在动手前必须通读本文。改造完一个页面立即编译，一个 feature 全绿才算完成。

## 0. 环境与验证

```bash
cd /e/githubapp && source scripts/env-win.sh
# 生产构建（约 15-40s）
hvigorw assembleHap --mode module -p product=unsigned -p buildMode=debug --no-daemon 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "Error Message|BUILD" | sort -u | head -30
# 测试目标构建
hvigorw assembleHap --mode module -p module=entry@ohosTest -p product=unsigned -p buildMode=debug --no-daemon 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E "BUILD" | head -3
```
两个都要 BUILD SUCCESSFUL。

## 1. 硬规则（违反即返工）

1. **V1/V2 不混用**：一个 struct 内只能有一套。V1 套件 `@Component + @State/@Prop/@Link/@ObjectLink/@Watch/@Provide/@Consume/@StorageLink/@StorageProp`；V2 套件 `@ComponentV2 + @Local/@Param/@Event/@Monitor/@Computed/@Provider/@Consumer`。类观测：V1 `@Observed` → V2 `@ObservedV2 + @Trace`。
2. **整棵组件树迁 V2**：改一个页面时，它 build 里引用的**本项目**子组件也一并迁 V2（@ComponentV2 + @Param）。跨层级一次改完，不留中间态。第三方/系统组件不受影响。
3. **@Param 只读**：子组件里改入参 = 编译错。需要回传改父状态 → `@Event` 回调或直接调 ViewModel 方法。
4. **@Local 不接受外部初始化**：页面持有的 VM 用 `@Local vm: XxxViewModel = new XxxViewModel();`。子组件接收 VM 用 `@Param vm: XxxViewModel`（对象引用传递，@Trace 字段变化自动刷新）。
5. ** ArkTS 严格模式**：无 any/unknown；箭头函数参数显式标类型；泛型调用显式给类型参数；Map/Set 显式类型；对象字面量必须对应声明的 interface/class；回调参数类型与被调方签名逐字一致。
6. **HARD-LAW-1**：颜色/字号/间距一律 Theme.ets token（`import { GSYColor, GSYFontSize, GSYSpacing, GSYIconSize, GSYShadow } from 'common'`）。新 token 只许加进 Theme.ets。
7. **测试 id 一字不动**：所有 `.id('...')` 字符串保持原样（scenario-tour.sh 断言依赖）。新增交互控件可加新 id，但旧 id 不得改名/删除。
8. **不塞调试 Text 进 UI 树**（HARD-LAW-2）。日志走 `Logger`（common 包）。
9. **无真机**：不做任何 hdc/模拟器操作。

## 2. MVVM 目标形态（每页面三件套）

```
features/feature-X/src/main/ets/
├── XxxPage.ets              # View：@ComponentV2，只做组装 + 手势/点击转发
└── viewmodel/XxxViewModel.ets  # ViewModel：@ObservedV2，持有 @Trace UI 状态 + 编排
common/src/main/ets/model/service/XxxService.ets  # Model：无状态仓库，只取数据返回
```

### ViewModel 模板

```typescript
import { @ObservedV2 需要装饰器 } from ...;  // 实际写法：装饰器直接标在类声明上
import { XxxService, XxxItem } from 'common';

@ObservedV2
export class XxxViewModel {
  @Trace items: XxxItem[] = [];
  @Trace refreshing: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = true;
  @Trace errorMessage: string = '';
  private page: number = 1;              // 非UI状态不用 @Trace
  private service: XxxService = new XxxService();

  async refresh(keyword: string): Promise<void> {
    this.refreshing = true;
    this.errorMessage = '';
    this.page = 1;
    try {
      const res: XxxItem[] = await this.service.fetch(keyword, 1);  // 纯数据返回
      this.items = res;                 // 整体替换数组
      this.hasMore = res.length >= PAGE_SIZE;
    } catch (e) {
      this.errorMessage = (e as Error).message;
    } finally {
      this.refreshing = false;
    }
  }

  async loadMore(keyword: string): Promise<void> {
    if (this.loadingMore || !this.hasMore) { return; }
    this.loadingMore = true;
    this.page++;
    try {
      const res: XxxItem[] = await this.service.fetch(keyword, this.page);
      this.items = this.items.concat(res);
      this.hasMore = res.length >= PAGE_SIZE;
    } finally {
      this.loadingMore = false;
    }
  }
}
```

### View 模板

```typescript
@ComponentV2
export struct XxxPage {
  @Local vm: XxxViewModel = new XxxViewModel();

  aboutToAppear(): void {
    this.vm.refresh('');   // 参数来自路由参数消费逻辑（保留原有 aboutToAppear 里的取参代码，搬进 ViewModel 或留 View 层取参后调 vm）
  }

  build() {
    Column() {
      // 下拉刷新 + 列表（见 §4）
      Refresh({ refreshing: this.refreshProxy() }) { ... }
    }
  }
}
```

### 子组件

```typescript
@ComponentV2
struct XxxRow {
  @Param item: XxxItem = new XxxItem();   // 或 @Require @Param
  @Event press: (item: XxxItem) => void = (_i: XxxItem) => {};
  build() { ... this.press(this.item) ... }
}
```

## 3. Repository 无状态化

现 service 构造函数注入 store、方法里 `this.store.applyXxx()` 写状态。改造：
1. 构造函数删掉 store 参数（改为无参或只收配置）。
2. 方法只做 HTTP/缓存取数并 `return 数据`（已有 `Result<T>` 封装则返回 Result，没有就返回数组/对象，抛错走 throw）。
3. 谁调谁更新：ViewModel 拿返回值写自己的 @Trace 字段。
4. **注意**：同文件里的 Model interface（数据实体）保留原处不动。跨 service 重复定义的实体（如 `FetchStarredCountResult` 同时在 MyService/UserService）统一收敛到一处，另一处 import。
5. 改 service 签名时全工程搜调用点（含 ohosTest 的 *ServiceTest）一起改。**测试文件里的 service mock/注入路径要跟着签名走，但断言语义不许变。**

## 4. 列表：ForEach → Repeat + PullLoadMoreList V2 接口契约

### PullLoadMoreList 已升级为 V2（common/ui/components/PullLoadMoreList.ets）

V1 的 `PullLoadMoreController` 状态机已删除。新接口（受控式，状态归 ViewModel）：

```typescript
PullLoadMoreList({
  dataSource: this.vm.items,            // @Param Object[]（必须）
  refreshing: this.vm.refreshing,       // @Param boolean
  noMore: !this.vm.hasMore,             // @Param boolean（footer 显示"没有更多"）
  loadingMore: this.vm.loadingMore,     // @Param boolean
  showEmpty: this.vm.showEmpty,         // @Param boolean（空态）
  emptyText: '',                        // @Param string
  onRefresh: (): void => { this.vm.refresh() },        // @Event
  onLoadMore: (): void => { this.vm.loadMore() },      // @Event
  renderRow: (item: Object, index: number): void => this.rowBuilder(item, index),  // 行渲染（沿用闭包模式）
  renderHeader: ...,                    // 可选，同旧
  renderEmpty: ...,                     // 可选，同旧
})
  .id('xxx_pull_list')                  // 调用方 id 原样保留
```

ViewModel 侧负责在 refresh/loadMore 完成后把 `refreshing/loadingMore` 置回 false（指示器随之收起）。
**调用方迁移要点**：删掉 `new PullLoadMoreController()`、`@Link controller`、`refreshComplete/loadMoreComplete/setFooterState/showRefreshState` 全部调用；`dataSource` 替换旧的 `dataSource` 传法一致；行渲染闭包写法保持。ohosTest 宿主页同样迁移。

### Repeat 写法

V2 组件里一律用 Repeat（长列表必须 virtualScroll）：

```typescript
List() {
  Repeat<XxxItem>(this.vm.items, (item: XxxItem, idx: number) => this.vm.itemKey(item, idx))
    .each((obj: RepeatItem<XxxItem>) => {
      ListItem() {
        XxxRow({ item: obj.item, press: (i: XxxItem): void => this.openDetail(i) })
      }
    })
    .key((item: XxxItem) => this.vm.itemKey(item, -1))
}
.cachedCount(5)          // cachedCount 放滚动容器上，不放 Repeat 上
```

长列表（动态/搜索结果/Issue评论/文件树 ≥ 30 项量级）加 `.virtualScroll()`；`.each` 里用 `obj.index`。短列表（设置项等 <20 项）Repeat 不加 virtualScroll。
注意：virtualScroll 模式下数组必须整体替换或 splice 更新（@Trace 数组），并保证 key 稳定（业务 id，不用 index）。

## 5. 弹窗与菜单（V2 页面禁用 CustomDialogController）

- **V1 的 @CustomDialog + CustomDialogController 在 @ComponentV2 里不可用。** 替代：
  1. 首选 `bindSheet`（原生半模态，性能好、手势友好）：`Column(){...}.bindSheet(SheetSize/MODE, this.mySheetBuilder(), {title...})`，内容放在 @Builder（V2 @Builder 可用）或子 @ComponentV2。
  2. 居中确认类：`CommonModal.confirm`（原生 AlertDialog 包装，已是全局 API，V2 可直接用）。
  3. 选项列表：`CommonModal.options`（原生 ActionSheet 包装）。
- 现存 V1 @CustomDialog struct（IssueEditDialog / CreateIssueDialog / PersonInfoEditDialog 等）改造时：内容抽成 @ComponentV2 struct + bindSheet 呈现；**内部 TextInput 的 .id() 原样保留**（脚本按 id 点击输入）。
- 简单 prompt（单行输入确认）→ 用 bindSheet 内容里放 TextInput + 确定按钮。

## 6. 全局状态读取（feature 内禁止 AppStorage）

- 登录态：`import { GlobalAuthStore } from 'common'` → `GlobalAuthStore.get()`（或既有的单例访问器），字段是 @ObservedV2/@Trace 或普通字段。**禁止** `@StorageLink('auth.*')` / `AppStorage.get`。
- 主题：`ThemeManager`（common/ui/theme）。安全区：`SafeAreaInsets`。
- 路由：`NavigationService` + `RouteName`（common）。取参优先 `RouteParamStore.consume(name)` / `ctx.pathInfo.param`，boot 兜底走 `BootKeys` + AppStorage（**这部分是测试通道，阶段2C 统一处理，本轮 feature 改造遇到 BOOT_ 键读取的代码原样保留不动**）。
- 事件：EventBus（common）。

## 7. @Builder 陷阱（R-UI-05 沿用）

依赖响应式字段的文案/样式必须在 build 主体 inline 求值，或抽 @ComponentV2 + @Param；**禁止** `@Builder fn(value: string)` 值参中转响应式数据。@Builder 多参数不刷新；按引用传参用 `$$` 形参 + interface。

## 8. 每个页面改造的自检清单

```
☐ @ComponentV2 全套（页面 + 本项目子组件）
☐ 状态进 ViewModel：@Trace 只标 UI 状态；派生值用 @Computed 或 getter
☐ View 不 import service/model 实体类型（列表项用 ViewModel/实体经 @Param 传入可以，但页面不得直接调 service）
☐ service 无 store 依赖，返回数据
☐ ForEach → Repeat（长列表 virtualScroll + cachedCount）
☐ AppStorage/@StorageLink 清零（BOOT 通道除外）
☐ CustomDialogController 清零（换 bindSheet/CommonModal）
☐ 所有 .id() 原样保留
☐ 无字面量颜色/字号/间距（对照 Theme token；缺 token 加 token）
☐ 两个构建全绿
```

## 9. 已知全局符号位置（改造时 import 速查）

| 符号 | 包 |
|---|---|
| HttpManager/Address/Result/NetworkCode/NetworkMonitor | common |
| 各 XxxService（RepositoryService/IssueService/...） | common |
| 各实体 interface（RepositoryDetail/IssueItem/...） | common（多随 service 文件导出） |
| 各 XxxStore（RepositoryDetailStore/AuthStore/...） | common |
| BootKeys 12 个键 | common |
| NavigationService/RouteName/ROUTE_NAMES/isKnownRoute/RouteParamStore | common |
| I18n/changeLocale/LocaleKey | common |
| Logger/EventBus(EVENT_*)/Preferences(KEY_*)/RdbStore/SafeAreaInsets/enableImmersive | common |
| SettingPorts（SettingPageDeps/SettingPageHelper/LANGUAGE_OPTION_*/THEME_OPTION_*/PreferencesPort/RdbPort） | common |
| ThemeManager/ThemeMode/ThemePalette/LIGHT_PALETTE/DARK_PALETTE/THEME_PALETTE_KEY | common |
| Theme tokens（GSYColor/GSYFontSize/GSYSpacing/GSYIconSize/GSYShadow/GSYDarkColor） | common |
| AppBar/CommonBottomBar/CommonToast/CommonModal/LoadingModal/IconFont/HTMLView/MarkdownText/PullLoadMoreList(PullLoadMoreController/PullLoadMoreFooterState)/SubListView/UserImage/EventItem/RepositoryItem/UserItem/IconTextItem/TimeText/CreateIssueDialog(EventItem...)/SettingPorts | common |
| 页面 struct | feature_auth / feature_main / feature_repo / feature_user / feature_misc |
| 私有组件（DrawerHeader/DrawerMenu/TabIcon/UserHeadItem→feature_main；RepositoryHeader/ReleaseItem→feature_repo；HarmonyLogoMark→feature_auth；markdown(MarkdownNative/MarkdownRenderer)→feature_repo） | 对应 feature 包 |
