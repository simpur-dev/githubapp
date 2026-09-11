/**
 * NavTitleBridge —— 自绘 AppBar → NavDestination 原生标题栏（.title/.menus）的桥接单例。
 *
 * 设计（R9 阶段4）：
 *  - 页面在 aboutToAppear 里调用 registerTitle(routeName, config) 上报标题/动作配置；
 *    config 里的动态文案用 titleGetter 闭包随对象携带（读页面 @Trace/@Local 字段），
 *    桥接组件渲染时求值即可获得响应式刷新（如 WebPage 页签标题实时变化）。
 *  - NavDestination 的 .title/.menus builder（AppNavigator 里按路由各一个 @Builder）
 *    渲染 NavTitleView / NavMenusView，按 routeName 从这里取当前配置。
 *  - registerTitle 每次自增 @Trace revision，保证"builder 先建、页面 register 后补"
 *    的时序下标题栏也能刷新（首次渲染可能读到空配置，register 后下一帧补齐）。
 *  - 底栏：registerBottomBar 上报 CommonBottomBar 的装配参数，
 *    NavDestination 的 .toolbarConfiguration builder 渲染 NavBottomBarView，
 *    内部直接复用 CommonBottomBar 组件（common_bottom_bar_item_* / text_* 测试 id 全保留）。
 *
 * 注意：配置只增改不清（页面 pop 时不 unregister，避免返回转场动画期间标题栏闪空）；
 * 同名路由再次 push 时新页面 aboutToAppear 会整体覆盖旧配置。
 */
import { CommonBottomBar, CommonBottomBarItem } from '../components/CommonBottomBar';
import { applySystemBars } from '../../base/utils/SafeAreaInsets';
import { ThemeManager } from '../theme/ThemeManager';
import { GSYColor, GSYFontSize, GSYIconSize, GSYSpacing } from '../style/Theme';

/** 标题栏动作项（原 AppBarAction 等价物），onAction 闭包随对象携带。 */
export interface NavTitleAction {
  /** 矢量 icon 关键字：search/menu/filter/more/done_all 等，与原 AppBar 同一套映射。 */
  iconKey?: string;
  icon?: ResourceStr;
  text?: string;
  onAction?: () => void;
}

/** 标题栏配置（原 AppBar 的 title/subtitle/actions 形参）。 */
export interface NavTitleConfig {
  /** 状态栏底色（颜色跟随页面，经官方窗口属性 setWindowSystemBarProperties 应用）。 */
  statusBarBg?: string;
  /** 状态栏图标是否浅色（深底配白图标）。 */
  statusBarLightIcon?: boolean;
  /** 静态标题；与 titleGetter 同时存在时 getter 优先。 */
  title?: string;
  /** 响应式标题：渲染时求值，读取页面 @Trace 字段可自动刷新。 */
  titleGetter?: () => string;
  subtitle?: string;
  subtitleGetter?: () => string;
  /** 标题 Text 的测试 id，默认 'appbar_title'（如 CodeDetail 的 code_detail_title_text）。 */
  titleId?: string;
  /** 页面级标题栏容器 id（原挂 AppBar 实例上的 .id(...)，如 issue_detail_appbar）。缺省用 'appbar_root'。 */
  barId?: string;
  leftActions?: NavTitleAction[];
  rightActions?: NavTitleAction[];
}

/** 原生工具栏（.toolbarConfiguration）里 CommonBottomBar 的装配配置。 */
export interface NavBottomBarConfig {
  /** 工具栏整体可见性（读页面 @Trace，如 repoDetail 的 fullName 就绪 / issueDetail 的 shouldShowBottomBar）。 */
  visibleGetter?: () => boolean;
  /** 行数据（闭包返回，替换时 CommonBottomBar 内部 @Monitor 强制行重建）。 */
  itemsGetter: () => CommonBottomBarItem[];
  /** 原 CommonBottomBar 形参原样透传。 */
  rootId?: string;
  repoActionStyle?: boolean;
  materialFloatingStyle?: boolean;
  trailingItemId?: string;
  rootHeight?: number;
  rootMarginHorizontal?: number;
  rootMarginBottom?: number;
  rootBorderRadius?: number;
  /** 原挂 CommonBottomBar 实例上的 .id(...)（issue_detail_bottom_bar_wrap），有才应用。 */
  wrapperId?: string;
  /** 受控分支菜单显隐（读页面 @Local branchMenuVisible）。 */
  trailingMenuShowGetter?: () => boolean;
  onTrailingMenuDismiss?: () => void;
  /** 菜单项内容（如 vm.branches）与点击回传。 */
  menuItemsGetter?: () => string[];
  onMenuItemTap?: (item: string) => void;
  /** 菜单测试 id 前缀（repo_branch_menu → *_root / *_item_N / *_item_text_N）。 */
  menuItemIdPrefix?: string;
  menuWidth?: number;
  menuMaxHeight?: number;
  menuRowHeight?: number;
}

const EMPTY_TITLE_CONFIG: NavTitleConfig = { title: '' };
/** 分支菜单分隔线/描边粗细（与原页面 buildBranchMenuContent 一致的发丝线）。 */
const MENU_DIVIDER_WIDTH: number = 0.5;
/** 分支菜单圆角（原页面 buildBranchMenuContent 同值）。 */
const MENU_RADIUS: number = 12;
/** icon 资源动作的图标边长（对齐原 AppBar 内 Image 20x20）。 */
const ACTION_ICON_SIZE: number = GSYIconSize.tab;

@ObservedV2
export class NavTitleBridge {
  private static instance: NavTitleBridge | undefined = undefined;

  static get(): NavTitleBridge {
    if (NavTitleBridge.instance === undefined) {
      NavTitleBridge.instance = new NavTitleBridge();
    }
    return NavTitleBridge.instance;
  }

  /** 每次注册自增；桥接组件渲染时读它建立观测依赖。 */
  @Trace revision: number = 0;
  @Trace private titleConfigs: Map<string, NavTitleConfig> = new Map<string, NavTitleConfig>();
  /** 当前状态栏底色（随可见页面切换）。 */
  @Trace statusBarBg: string = GSYColor.mainBackground;
  /** 当前状态栏图标是否浅色。 */
  @Trace statusBarLightIcon: boolean = false;

  /** 页面直接声明状态栏样式（无标题配置的页面用）。 */
  setStatusBar(bg: string, lightIcon: boolean): void {
    this.statusBarBg = bg;
    this.statusBarLightIcon = lightIcon;
    applySystemBars(bg, lightIcon);
  }

  /** 应用回前台时恢复当前页面的状态栏样式（onBackground 已重置为透明）。 */
  reapplyStatusBar(): void {
    applySystemBars(this.statusBarBg, this.statusBarLightIcon);
  }

  /** NavDestination onShown 时调用：状态栏颜色跟随可见页面（含返回场景）。 */
  onDestinationShown(routeName: string): void {
    const cfg = this.titleFor(routeName);
    if (cfg !== null && cfg !== undefined && cfg.statusBarBg !== undefined) {
      this.setStatusBar(cfg.statusBarBg, cfg.statusBarLightIcon === true);
    } else {
      this.setStatusBar(ThemeManager.current().background, false);
    }
  }

  private titleFor(routeName: string): NavTitleConfig | undefined | null {
    const found: NavTitleConfig | undefined = this.titleConfigs.get(routeName);
    return found !== undefined ? found : null;
  }

  @Trace private bottomBarConfigs: Map<string, NavBottomBarConfig> = new Map<string, NavBottomBarConfig>();

  registerTitle(routeName: string, config: NavTitleConfig): void {
    if (config.statusBarBg !== undefined) {
      this.setStatusBar(config.statusBarBg, config.statusBarLightIcon === true);
    }
    this.titleConfigs.set(routeName, config);
    this.revision++;
  }

  registerBottomBar(routeName: string, config: NavBottomBarConfig): void {
    this.bottomBarConfigs.set(routeName, config);
    this.revision++;
  }

  /** 永不返回 undefined：未注册（或注册晚于首帧）时返回空配置，revision 变化后自动补渲染。 */
  configFor(routeName: string): NavTitleConfig {
    // 读 @Trace revision 建立依赖（registerTitle 会自增触发标题栏刷新）。
    if (this.revision >= 0) {
      const found: NavTitleConfig | undefined = this.titleConfigs.get(routeName);
      if (found !== undefined) {
        return found;
      }
    }
    return EMPTY_TITLE_CONFIG;
  }

  /** 未注册返回 null，NavBottomBarView 据此整条不渲染。 */
  bottomBarFor(routeName: string): NavBottomBarConfig | null {
    if (this.revision >= 0) {
      const found: NavBottomBarConfig | undefined = this.bottomBarConfigs.get(routeName);
      if (found !== undefined) {
        return found;
      }
    }
    return null;
  }
}

/**
 * NavTitleView —— .title(CustomBuilder) 的内容：标题（+可选副标题）。
 * 根容器 id = barId ?? 'appbar_root'，标题 Text id = titleId ?? 'appbar_title'。
 * 文字颜色/字号交给系统默认标题栏样式（最原生），只做省略号截断。
 */
@ComponentV2
export struct NavTitleView {
  @Param routeName: string = '';

  private resolveTitle(): string {
    const cfg: NavTitleConfig = NavTitleBridge.get().configFor(this.routeName);
    if (cfg.titleGetter !== undefined) {
      return cfg.titleGetter();
    }
    return cfg.title !== undefined ? cfg.title : '';
  }

  private hasSubtitle(): boolean {
    const cfg: NavTitleConfig = NavTitleBridge.get().configFor(this.routeName);
    if (cfg.subtitleGetter !== undefined) {
      return cfg.subtitleGetter().length > 0;
    }
    return cfg.subtitle !== undefined && cfg.subtitle.length > 0;
  }

  private resolveSubtitle(): string {
    const cfg: NavTitleConfig = NavTitleBridge.get().configFor(this.routeName);
    if (cfg.subtitleGetter !== undefined) {
      return cfg.subtitleGetter();
    }
    return cfg.subtitle !== undefined ? cfg.subtitle : '';
  }

  private titleId(): string {
    const cfg: NavTitleConfig = NavTitleBridge.get().configFor(this.routeName);
    return cfg.titleId !== undefined && cfg.titleId.length > 0 ? cfg.titleId : 'appbar_title';
  }

  private rootId(): string {
    const cfg: NavTitleConfig = NavTitleBridge.get().configFor(this.routeName);
    return cfg.barId !== undefined && cfg.barId.length > 0 ? cfg.barId : 'appbar_root';
  }

  build(): void {
    Column() {
      Text(this.resolveTitle())
        .id(this.titleId())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      if (this.hasSubtitle()) {
        Text(this.resolveSubtitle())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
    }
    .id(this.rootId())
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center);
  }
}

/**
 * NavMenusView —— .menus(CustomBuilder) 的内容：标题栏动作按钮。
 * 动作 id 与原 AppBar 同规则：appbar_action_{l|r}_{iconKey}（无 iconKey 用下标）。
 * 背景/描边交给系统，按钮只保留命中区域与图标字号 token。
 */
@ComponentV2
export struct NavMenusView {
  @Param routeName: string = '';

  private menuActions(): NavTitleAction[] {
    const cfg: NavTitleConfig = NavTitleBridge.get().configFor(this.routeName);
    const left: NavTitleAction[] = cfg.leftActions !== undefined ? cfg.leftActions : [];
    const right: NavTitleAction[] = cfg.rightActions !== undefined ? cfg.rightActions : [];
    return left.concat(right);
  }

  private leftActionCount(): number {
    const cfg: NavTitleConfig = NavTitleBridge.get().configFor(this.routeName);
    return cfg.leftActions !== undefined ? cfg.leftActions.length : 0;
  }

  private actionId(action: NavTitleAction, side: string, index: number): string {
    if (action.iconKey !== undefined && action.iconKey.length > 0) {
      return 'appbar_action_' + side + '_' + action.iconKey;
    }
    return 'appbar_action_' + side + '_' + index.toString();
  }

  @Builder
  actionIcon(action: NavTitleAction): void {
    if (action.iconKey === 'search') {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(GSYIconSize.appBarAction);
    } else if (action.iconKey === 'menu') {
      SymbolGlyph($r('sys.symbol.line_3_horizontal'))
        .fontSize(GSYIconSize.appBarAction);
    } else if (action.iconKey === 'done_all') {
      SymbolGlyph($r('sys.symbol.checkmark'))
        .fontSize(GSYIconSize.cardIcon);
    } else if (action.iconKey === 'filter') {
      SymbolGlyph($r('sys.symbol.funnel'))
        .fontSize(GSYIconSize.tab);
    } else if (action.iconKey === 'more') {
      SymbolGlyph($r('sys.symbol.more'))
        .fontSize(GSYIconSize.appBarAction);
    } else if (action.icon !== undefined) {
      Image(action.icon)
        .width(ACTION_ICON_SIZE)
        .height(ACTION_ICON_SIZE);
    }
    // 与原 AppBar 一致：未知 iconKey（如 reload）不渲染图标，仅保留可点击命中区。
  }

  @Builder
  actionButton(action: NavTitleAction, side: string, index: number): void {
    Button() {
      Row() {
        this.actionIcon(action);
        if (action.text !== undefined && action.text.length > 0) {
          Text(action.text)
            .fontSize(GSYFontSize.small);
        }
      }
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height('100%');
    }
    .id(this.actionId(action, side, index))
    .type(ButtonType.Normal)
    .backgroundColor(GSYColor.transparent)
    .width(GSYSpacing.hdsActionButtonSize)
    .height(GSYSpacing.hdsActionButtonSize)
    .margin({ left: GSYSpacing.halfEdge, right: GSYSpacing.halfEdge })
    .hitTestBehavior(HitTestMode.Block)
    .onClick((): void => {
      if (action.onAction !== undefined) {
        action.onAction();
      }
    });
  }

  build(): void {
    Row() {
      Repeat<NavTitleAction>(this.menuActions())
        .each((obj: RepeatItem<NavTitleAction>): void => {
          this.actionButton(obj.item, obj.index < this.leftActionCount() ? 'l' : 'r', obj.index);
        })
        .key((action: NavTitleAction, index: number): string =>
          index.toString() + ':' + (action.iconKey !== undefined ? action.iconKey : ''));
    }
    .alignItems(VerticalAlign.Center)
    .hitTestBehavior(HitTestMode.Transparent);
  }
}

/**
 * NavBottomBarView —— .toolbarConfiguration(CustomBuilder) 的内容。
 * 直接复用 CommonBottomBar 组件（common_bottom_bar_item_* / text_* 测试 id、
 * 受控 bindMenu 分支菜单全部保留），菜单内容按配置在组件内渲染。
 */
@ComponentV2
export struct NavBottomBarView {
  @Param routeName: string = '';

  private barConfig(): NavBottomBarConfig | null {
    return NavTitleBridge.get().bottomBarFor(this.routeName);
  }

  private isVisible(): boolean {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    if (cfg === null) {
      return false;
    }
    if (cfg.visibleGetter !== undefined) {
      return cfg.visibleGetter();
    }
    return true;
  }

  private menuShow(): boolean {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    if (cfg === null || cfg.trailingMenuShowGetter === undefined) {
      return false;
    }
    return cfg.trailingMenuShowGetter();
  }

  private menuItems(): string[] {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    if (cfg === null || cfg.menuItemsGetter === undefined) {
      return [];
    }
    const items: string[] = cfg.menuItemsGetter();
    return items !== undefined && items !== null ? items : [];
  }

  @Builder
  trailingMenu(): void {
    Column() {
      Column() {
        Scroll() {
          Column() {
            Repeat<string>(this.menuItems())
              .each((obj: RepeatItem<string>): void => {
                Row() {
                  Text(obj.item)
                    .id(this.menuTextId(obj.index))
                    .fontSize(GSYFontSize.small)
                    .fontColor(GSYColor.primary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1);
                }
                .id(this.menuItemId(obj.index))
                .width('100%')
                .height(this.menuRowHeight())
                .padding({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge })
                .alignItems(VerticalAlign.Center)
                .onClick((): void => {
                  this.tapMenuItem(obj.item);
                });
                if (obj.index < this.menuItems().length - 1) {
                  Divider().color(GSYColor.line).strokeWidth(MENU_DIVIDER_WIDTH);
                }
              })
              .key((branch: string, index: number): string => index.toString() + ':' + branch);
          }
          .width('100%');
        }
        .id(this.menuRootId())
        .width(this.menuWidth())
        .constraintSize({ maxHeight: this.menuMaxHeight() })
        .backgroundColor(GSYColor.hdsMaterialSurface)
        .border({
          width: MENU_DIVIDER_WIDTH,
          color: GSYColor.hdsMaterialBorder,
        })
        .borderRadius(MENU_RADIUS);
      }
      .id(this.menuScrimId());
    }
    .id(this.menuOverlayId());
  }

  private menuPrefix(): string {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.menuItemIdPrefix !== undefined ? cfg.menuItemIdPrefix : 'nav_bottom_bar_menu';
  }

  private menuRootId(): string {
    return this.menuPrefix() + '_root';
  }

  private menuItemId(index: number): string {
    return this.menuPrefix() + '_item_' + index.toString();
  }

  private menuTextId(index: number): string {
    return this.menuPrefix() + '_item_text_' + index.toString();
  }

  private menuScrimId(): string {
    return this.menuPrefix() + '_scrim';
  }

  private menuOverlayId(): string {
    return this.menuPrefix() + '_overlay';
  }

  private menuWidth(): number {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.menuWidth !== undefined ? cfg.menuWidth : 0;
  }

  private menuMaxHeight(): number {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.menuMaxHeight !== undefined ? cfg.menuMaxHeight : 0;
  }

  private menuRowHeight(): number {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.menuRowHeight !== undefined ? cfg.menuRowHeight : 0;
  }

  private tapMenuItem(item: string): void {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    if (cfg !== null && cfg.onMenuItemTap !== undefined) {
      cfg.onMenuItemTap(item);
    }
  }

  private dismissMenu(): void {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    if (cfg !== null && cfg.onTrailingMenuDismiss !== undefined) {
      cfg.onTrailingMenuDismiss();
    }
  }

  build(): void {
    if (this.isVisible()) {
      CommonBottomBar({
        dataList: this.items(),
        rootId: this.rootId(),
        repoActionStyle: this.repoActionStyle(),
        materialFloatingStyle: this.materialFloatingStyle(),
        trailingItemId: this.trailingItemId(),
        rootHeight: this.rootHeight(),
        rootMarginHorizontal: this.rootMarginHorizontal(),
        rootMarginBottom: this.rootMarginBottom(),
        rootBorderRadius: this.rootBorderRadius(),
        trailingMenuShow: this.menuShow(),
        trailingMenuBuilder: (): void => {
          this.trailingMenu();
        },
        onTrailingMenuDismiss: (): void => {
          this.dismissMenu();
        },
      })
        .id(this.wrapperId());
    }
  }

  private items(): CommonBottomBarItem[] {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    if (cfg === null) {
      return [];
    }
    const items: CommonBottomBarItem[] = cfg.itemsGetter();
    return items !== undefined && items !== null ? items : [];
  }

  private rootId(): string {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.rootId !== undefined && cfg.rootId.length > 0 ? cfg.rootId : 'nav_bottom_bar';
  }

  private repoActionStyle(): boolean {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.repoActionStyle === true;
  }

  private materialFloatingStyle(): boolean {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.materialFloatingStyle === true;
  }

  private trailingItemId(): string {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.trailingItemId !== undefined ? cfg.trailingItemId : 'branch';
  }

  private rootHeight(): number {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.rootHeight !== undefined ? cfg.rootHeight : 0;
  }

  private rootMarginHorizontal(): number {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.rootMarginHorizontal !== undefined ? cfg.rootMarginHorizontal : 0;
  }

  private rootMarginBottom(): number {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.rootMarginBottom !== undefined ? cfg.rootMarginBottom : 0;
  }

  private rootBorderRadius(): number {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.rootBorderRadius !== undefined ? cfg.rootBorderRadius : 0;
  }

  private wrapperId(): string {
    const cfg: NavBottomBarConfig | null = this.barConfig();
    return cfg !== null && cfg.wrapperId !== undefined ? cfg.wrapperId : this.rootId();
  }
}
