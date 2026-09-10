import { ThemePalette, LIGHT_PALETTE, ThemeManager } from '../theme/ThemeManager';
import { SafeAreaInsets } from '../../base/utils/SafeAreaInsets';
import { EventBus, EVENT_THEME_CHANGED, EVENT_SAFE_AREA_CHANGED } from '../../base/utils/EventBus';
import { GSYColor, GSYFontSize, GSYIconSize, GSYSpacing } from '../style/Theme';

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
  @Local safeAreaTop: number = 0;
  private offTheme: (() => void) | null = null;
  private offSafeArea: (() => void) | null = null;

  aboutToAppear(): void {
    this.palette = ThemeManager.current();
    this.safeAreaTop = SafeAreaInsets.top;
    // V2 @Local 读单例字段不会自动刷新：订阅显式事件保持等价的响应语义。
    this.offTheme = EventBus.on(EVENT_THEME_CHANGED, (_payload: ESObject): void => {
      this.palette = ThemeManager.current();
    });
    this.offSafeArea = EventBus.on(EVENT_SAFE_AREA_CHANGED, (_payload: ESObject): void => {
      this.safeAreaTop = SafeAreaInsets.top;
    });
  }

  aboutToDisappear(): void {
    if (this.offTheme !== null) {
      this.offTheme();
      this.offTheme = null;
    }
    if (this.offSafeArea !== null) {
      this.offSafeArea();
      this.offSafeArea = null;
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
      return GSYColor.white;
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
      return GSYColor.white;
    }
    return this.actionColor;
  }

  private resolveActionMaterialBackground(): ResourceColor {
    return this.useTheme ? GSYColor.hdsMaterialSurfaceDark : GSYColor.transparent;
  }

  @Builder
  buildAction(action: AppBarAction, side: string, idx: number): void {
    Button() {
      Row() {
        // 手绘矢量（Circle/Line）统一换成系统 SymbolGlyph；
        // 只使用系统符号表中确定存在的资源名，避免运行时空白。
        if (action.iconKey === 'search') {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(GSYIconSize.appBarAction)
            .fontColor([this.resolveActionColor()]);
        } else if (action.iconKey === 'menu') {
          SymbolGlyph($r('sys.symbol.line_3_horizontal'))
            .fontSize(GSYIconSize.appBarAction)
            .fontColor([this.resolveActionColor()]);
        } else if (action.iconKey === 'done_all') {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(GSYIconSize.cardIcon)
            .fontColor([this.resolveActionColor()]);
        } else if (action.iconKey === 'filter') {
          SymbolGlyph($r('sys.symbol.funnel'))
            .fontSize(GSYIconSize.tab)
            .fontColor([this.resolveActionColor()]);
        } else if (action.iconKey === 'more') {
          SymbolGlyph($r('sys.symbol.more'))
            .fontSize(GSYIconSize.appBarAction)
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
      if (this.immersive && this.safeAreaTop > 0) {
        Row()
          .id('appbar_status_spacer')
          .width('100%')
          .height(this.safeAreaTop)
          .backgroundColor(this.resolveBackground());
      }
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
