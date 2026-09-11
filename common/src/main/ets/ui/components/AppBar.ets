/**
 * AppBar —— 自绘标题栏（V2）。
 *
 * R9 阶段4 后唯一业务调用方是 HomePage（Navigation 首内容，不走 NavDestination 原生标题栏，
 * home_appbar / appbar_title / appbar_action_l_menu / appbar_action_r_search 等 id 不变）。
 * 其余页面的标题栏已迁至 NavDestination 原生 .title/.menus（见
 * common/src/main/ets/ui/navigation/NavTitleBridge.ets + entry AppNavigator routerMap）。
 * entry 的 ohosTest 宿主页（HomePageHost / CommonComponentsPage）仍引用本组件做测试宿主。
 */
import { ThemePalette, LIGHT_PALETTE, ThemeManager } from '../theme/ThemeManager';
import { EventBus, EVENT_THEME_CHANGED } from '../../base/utils/EventBus';
import { GSYColor, GSYFontSize, GSYIconSize, GSYSpacing } from '../style/Theme';
import { AppSymbolSpec, appSymbolSpecFor } from './AppSymbol';

const APP_BAR_SIDE_WIDTH: number = 64;
const APP_BAR_TITLE_LINE_HEIGHT: number = 28;
const APP_BAR_SUBTITLE_LINE_HEIGHT: number = 18;

export interface AppBarAction {
  text?: string;
  icon?: ResourceStr;
  /** 矢量 icon 关键字：search/menu/filter/more/done_all 等。优先于 icon。 */
  iconKey?: string;
  onAction?: () => void;
}

@ComponentV2
export struct AppBar {
  @Param title: string = '';
  @Param titleId: string = 'appbar_title';
  @Param subtitle: string = '';
  @Param showBack: boolean = true;
  @Param backgroundColorValue: ResourceColor = GSYColor.primary;
  @Param titleColor: ResourceColor = GSYColor.white;
  @Param subtitleColor: ResourceColor = GSYColor.subLightText;
  @Param actionColor: ResourceColor = GSYColor.white;
  @Param barHeight: number = 64;
  @Param useTheme: boolean = true;
  @Param titleStart: boolean = true;
  /** 是否让 AppBar 背景延伸到状态栏区域并自动让出 statusBar 高度（沉浸式） */
  @Param immersive: boolean = true;
  @Event onBack: () => void = (): void => {};
  /** 数组随对象携带 onAction 回调（interface 字段），保持原对象字面量传法。 */
  @Param leftActions: AppBarAction[] = [];
  @Param rightActions: AppBarAction[] = [];

  @Local palette: ThemePalette = LIGHT_PALETTE;
  private offTheme: (() => void) | null = null;

  aboutToAppear(): void {
    this.palette = ThemeManager.current();
    // V2 @Local 读单例字段不会自动刷新：订阅显式事件保持等价的响应语义。
    this.offTheme = EventBus.on(EVENT_THEME_CHANGED, (_payload: ESObject): void => {
      this.palette = ThemeManager.current();
    });
  }

  aboutToDisappear(): void {
    if (this.offTheme !== null) {
      this.offTheme();
      this.offTheme = null;
    }
  }

  private resolveBackground(): ResourceColor {
    if (this.useTheme && this.palette) {
      return this.palette.navBackground;
    }
    return this.backgroundColorValue;
  }

  private resolveTitleColor(): ResourceColor {
    if (this.useTheme && this.palette) {
      // 品牌头部上的文字：深浅色下都接近白，走 palette.onBrandText。
      return this.palette.onBrandText;
    }
    return this.titleColor;
  }

  private resolveSubtitleColor(): ResourceColor {
    if (this.useTheme && this.palette) {
      return this.palette.textSecondary;
    }
    return this.subtitleColor;
  }

  private resolveActionColor(): ResourceColor {
    if (this.useTheme && this.palette) {
      // 品牌头部上的文字/图标：深浅色下都接近白，走 palette.onBrandText。
      return this.palette.onBrandText;
    }
    return this.actionColor;
  }

  private resolveActionMaterialBackground(): ResourceColor {
    return this.useTheme ? GSYColor.hdsMaterialSurfaceDark : GSYColor.transparent;
  }

  /** 动作图标规格（AppSymbol 统一白名单）：未知 iconKey 返回 undefined，回落 Image。 */
  private actionGlyphSpec(action: AppBarAction): AppSymbolSpec | undefined {
    if (action.iconKey === undefined || action.iconKey === null || action.iconKey.length === 0) {
      return undefined;
    }
    return appSymbolSpecFor(action.iconKey);
  }

  @Builder
  buildAction(action: AppBarAction, side: string, idx: number): void {
    Button() {
      Row() {
        // 手绘矢量（Circle/Line）统一换成系统 SymbolGlyph；
        // iconKey → 资源/字号映射收敛到 AppSymbol.appSymbolSpecFor（与 NavMenusView 共用）。
        if (this.actionGlyphSpec(action) !== undefined) {
          SymbolGlyph((this.actionGlyphSpec(action) as AppSymbolSpec).resource)
            .fontSize((this.actionGlyphSpec(action) as AppSymbolSpec).fontSize)
            .fontColor([this.resolveActionColor()]);
        } else if (action.icon) {
          Image(action.icon)
            .width(20)
            .height(20)
            .fillColor(this.resolveActionColor());
        }
        if (action.text && action.text.length > 0) {
          Text(action.text)
            .fontSize(GSYFontSize.small)
            .fontColor(this.resolveActionColor())
            .margin({ left: (action.icon || action.iconKey) ? 4 : 0 });
        }
      }
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height('100%');
    }
    .id(action.iconKey && action.iconKey.length > 0
      ? 'appbar_action_' + side + '_' + action.iconKey
      : 'appbar_action_' + side + '_' + idx.toString())
    .type(ButtonType.Normal)
    .backgroundColor(this.resolveActionMaterialBackground())
    .border({
      width: 0.5,
      color: GSYColor.hdsMaterialBorder,
    })
    .borderRadius(GSYSpacing.hdsActionButtonRadius)
    .padding({ left: 8, right: 8 })
    .width(GSYSpacing.hdsActionButtonSize)
    .height(GSYSpacing.hdsActionButtonSize)
    .margin({
      top: (this.barHeight - GSYSpacing.hdsActionButtonSize) / 2,
      bottom: (this.barHeight - GSYSpacing.hdsActionButtonSize) / 2,
      left: 4,
      right: 4,
    })
    // 显式 hit area 与拦截：避免 SideBarContainer 主内容层把点击吞掉
    .hitTestBehavior(HitTestMode.Block)
    .onClick((): void => {
      if (action.onAction) {
        action.onAction();
      }
    });
  }

  @Builder
  buildBack(): void {
    Button() {
      Text('<')
        .fontSize(GSYIconSize.minIcon)
        .fontWeight(FontWeight.Bold)
        .lineHeight(APP_BAR_TITLE_LINE_HEIGHT)
        .fontColor(this.resolveActionColor());
    }
    .type(ButtonType.Normal)
    .backgroundColor(this.resolveActionMaterialBackground())
    .border({
      width: 0.5,
      color: GSYColor.hdsMaterialBorder,
    })
    .borderRadius(GSYSpacing.hdsActionButtonRadius)
    .padding({ left: 12, right: 8 })
    .width(GSYSpacing.hdsActionButtonSize)
    .height(GSYSpacing.hdsActionButtonSize)
    .margin({
      top: (this.barHeight - GSYSpacing.hdsActionButtonSize) / 2,
      bottom: (this.barHeight - GSYSpacing.hdsActionButtonSize) / 2,
      left: 4,
      right: 4,
    })
    .hitTestBehavior(HitTestMode.Block)
    .onClick((): void => {
      this.onBack();
    });
  }

  build(): void {
    Column() {
      Row() {
        if (this.titleStart) {
          Row() {
            if (this.showBack) {
              this.buildBack();
            }
            Repeat<AppBarAction>(this.leftActions)
              .each((obj: RepeatItem<AppBarAction>): void => {
                this.buildAction(obj.item, 'l', obj.index);
              })
              .key((action: AppBarAction, idx: number): string => 'l_' + idx.toString());
          }
          .alignItems(VerticalAlign.Center);

          Column() {
            Text(this.title)
              .id(this.titleId)
              .fontSize(GSYFontSize.normal)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.resolveTitleColor())
              .lineHeight(APP_BAR_TITLE_LINE_HEIGHT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            if (this.subtitle.length > 0) {
              Text(this.subtitle)
                .fontSize(GSYFontSize.min)
                .fontColor(this.resolveSubtitleColor())
                .lineHeight(APP_BAR_SUBTITLE_LINE_HEIGHT)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 2 });
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Center);

          Row() {
            Repeat<AppBarAction>(this.rightActions)
              .each((obj: RepeatItem<AppBarAction>): void => {
                this.buildAction(obj.item, 'r', obj.index);
              })
              .key((action: AppBarAction, idx: number): string => 'r_' + idx.toString());
          }
          .padding({ right: 8 })
          .justifyContent(FlexAlign.End)
          .alignItems(VerticalAlign.Center)
          .hitTestBehavior(HitTestMode.Transparent);
        } else {
          Row() {
            if (this.showBack) {
              this.buildBack();
            }
            Repeat<AppBarAction>(this.leftActions)
              .each((obj: RepeatItem<AppBarAction>): void => {
                this.buildAction(obj.item, 'l', obj.index);
              })
              .key((action: AppBarAction, idx: number): string => 'l_' + idx.toString());
          }
          .width(APP_BAR_SIDE_WIDTH)
          .alignItems(VerticalAlign.Center);

          Column() {
            Text(this.title)
              .id(this.titleId)
              .fontSize(GSYFontSize.normal)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.resolveTitleColor())
              .lineHeight(APP_BAR_TITLE_LINE_HEIGHT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            if (this.subtitle.length > 0) {
              Text(this.subtitle)
                .fontSize(GSYFontSize.min)
                .fontColor(this.resolveSubtitleColor())
                .lineHeight(APP_BAR_SUBTITLE_LINE_HEIGHT)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 2 });
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center);

          Row() {
            Repeat<AppBarAction>(this.rightActions)
              .each((obj: RepeatItem<AppBarAction>): void => {
                this.buildAction(obj.item, 'r', obj.index);
              })
              .key((action: AppBarAction, idx: number): string => 'r_' + idx.toString());
          }
          .width(APP_BAR_SIDE_WIDTH)
          .padding({ right: 8 })
          .justifyContent(FlexAlign.End)
          .alignItems(VerticalAlign.Center)
          .hitTestBehavior(HitTestMode.Transparent);
        }
      }
      .id('appbar_main_row')
      .width('100%')
      .height(this.barHeight)
      .alignItems(VerticalAlign.Center);
    }
    .id('appbar_root')
    .width('100%')
    .backgroundColor(this.resolveBackground());
  }
}
