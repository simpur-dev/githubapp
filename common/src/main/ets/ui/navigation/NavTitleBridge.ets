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
 *
 * 注意：配置只增改不清（页面 pop 时不 unregister，避免返回转场动画期间标题栏闪空）；
 * 同名路由再次 push 时新页面 aboutToAppear 会整体覆盖旧配置。
 */

import { NavigationService } from '../../base/navigation/NavigationService';
import { SafeAreaInsets, setStatusBarStyle } from '../../base/utils/SafeAreaInsets';
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
  /** 状态栏底色（颜色跟随页面）；不声明则用当前默认（白底深图标）。 */
  statusBarBg?: string;
  /** 状态栏图标是否浅色（白图标，配深色底）。 */
  statusBarLightIcon?: boolean;
  /** 是否显示返回按钮（原生标题栏下默认显示；主页等无返回场景声明 false）。 */
  showBack?: boolean;
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

  /** 当前状态栏底色（颜色跟随可见页面）。 */
  @Trace statusBarBg: string = GSYColor.mainBackground;
  /** 当前状态栏图标是否浅色。 */
  @Trace statusBarLightIcon: boolean = false;

  /** 页面直接声明状态栏样式（无标题配置的页面用，如 HomePage）。 */
  setStatusBar(bg: string, lightIcon: boolean): void {
    this.statusBarBg = bg;
    this.statusBarLightIcon = lightIcon;
    setStatusBarStyle(bg, lightIcon);
  }

  private titleFor(routeName: string): NavTitleConfig | undefined | null {
    const found: NavTitleConfig | undefined = this.titleConfigs.get(routeName);
    return found !== undefined ? found : null;
  }

  /** NavDestination onShown 时调用：让状态栏颜色跟随可见页面（含返回场景）。 */
  onDestinationShown(routeName: string): void {
    const cfg: NavTitleConfig | undefined | null = this.titleFor(routeName);
    if (cfg !== undefined && cfg !== null && cfg.statusBarBg !== undefined) {
      this.setStatusBar(cfg.statusBarBg, cfg.statusBarLightIcon === true);
    } else {
      this.setStatusBar(GSYColor.mainBackground, false);
    }
  }

  registerTitle(routeName: string, config: NavTitleConfig): void {
    if (config.statusBarBg !== undefined) {
      this.setStatusBar(config.statusBarBg, config.statusBarLightIcon === true);
    }
    this.titleConfigs.set(routeName, config);
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

  private showBack(): boolean {
    const cfg: NavTitleConfig = NavTitleBridge.get().configFor(this.routeName);
    return cfg.showBack !== false;
  }

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
      if (this.showBack()) {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(GSYIconSize.appBarAction)
            .fontColor([GSYColor.primaryDark]);
        }
        .id('appbar_back')
        .type(ButtonType.Normal)
        .backgroundColor(GSYColor.transparent)
        .width(GSYSpacing.hdsActionButtonSize)
        .height(GSYSpacing.hdsActionButtonSize)
        .margin({ left: GSYSpacing.halfEdge })
        .hitTestBehavior(HitTestMode.Block)
        .onClick((): void => {
          NavigationService.pop();
        });
      }
      Repeat<NavTitleAction>(this.menuActions())
        .each((obj: RepeatItem<NavTitleAction>): void => {
          if (obj.index < this.leftActionCount()) {
            this.actionButton(obj.item, 'l', obj.index);
          }
        })
        .key((action: NavTitleAction, index: number): string =>
          index.toString() + ':' + (action.iconKey !== undefined ? action.iconKey : ''));
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
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .margin({ left: GSYSpacing.halfEdge });
      Repeat<NavTitleAction>(this.menuActions())
        .each((obj: RepeatItem<NavTitleAction>): void => {
          if (obj.index >= this.leftActionCount()) {
            this.actionButton(obj.item, 'r', obj.index - this.leftActionCount());
          }
        })
        .key((action: NavTitleAction, index: number): string =>
          'r' + index.toString() + ':' + (action.iconKey !== undefined ? action.iconKey : ''));
    }
    .id(this.rootId())
    .width('100%')
    .alignItems(VerticalAlign.Center)
    // 窗口全屏沉浸：返回键/标题/动作图标整体避开状态栏，
    // 标题栏背景色（= 页面 NavDestination 背景，即界面本身的颜色）延伸到状态栏后面。
    .padding({ top: SafeAreaInsets.top, left: GSYSpacing.halfEdge, right: GSYSpacing.halfEdge });
  }
}

