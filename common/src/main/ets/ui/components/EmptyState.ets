/**
 * EmptyState —— 统一空态 / 错误态组件（R10 阶段3）。
 *
 * 结构（垂直居中）：SymbolGlyph 图标（textSecondary）+ 标题（text）+
 * 可选副标题（textSecondary）+ 可选重试胶囊按钮（accent 底 onBrandText 字）。
 *
 * iconText 只接受本工程系统符号表中确定存在的资源名（AppBar / TabIcon 已在用，
 * 避免 $r 动态值运行空白），未匹配时回退 line_3_horizontal。
 *
 * rootId / titleId 允许调用方透传测试 id（历史空态节点替换为本组件时保持 id 不变）；
 * 不传时使用默认 id。
 */
import { GSYFontSize, GSYIconSize, GSYSpacing } from '../style/Theme';
import { ThemeManager } from '../theme/ThemeManager';

@ComponentV2
export struct EmptyState {
  /** SymbolGlyph 符号名（白名单内），默认空列表横线形。 */
  @Param iconText: string = 'line_3_horizontal';
  /** 主标题。 */
  @Param title: string = 'No content yet';
  /** 副标题（可选）。 */
  @Param subtitle: string = '';
  /** 重试按钮文案（可选；不传则不渲染重试按钮）。 */
  @Param retryText: string = '';
  /** 可选测试 id：容器 / 标题（替换历史空态节点时保 id 用）。 */
  @Param rootId: string = '';
  @Param titleId: string = '';
  @Event retry: () => void = (): void => {};

  private resolveIconResource(): Resource {
    // 仅使用工程内已确认存在的 sys.symbol 资源名（编译期字面量，规避动态资源名空白风险）。
    if (this.iconText === 'magnifyingglass') {
      return $r('sys.symbol.magnifyingglass');
    }
    if (this.iconText === 'line_3_horizontal') {
      return $r('sys.symbol.line_3_horizontal');
    }
    if (this.iconText === 'checkmark') {
      return $r('sys.symbol.checkmark');
    }
    if (this.iconText === 'funnel') {
      return $r('sys.symbol.funnel');
    }
    if (this.iconText === 'more') {
      return $r('sys.symbol.more');
    }
    if (this.iconText === 'clock') {
      return $r('sys.symbol.clock');
    }
    if (this.iconText === 'flame') {
      return $r('sys.symbol.flame');
    }
    if (this.iconText === 'person') {
      return $r('sys.symbol.person');
    }
    return $r('sys.symbol.line_3_horizontal');
  }

  build(): void {
    Column() {
      SymbolGlyph(this.resolveIconResource())
        .fontSize(GSYIconSize.big)
        .fontColor([ThemeManager.current().textSecondary]);

      Text(this.title)
        .id(this.titleId.length > 0 ? this.titleId : 'empty_state_title')
        .fontSize(GSYFontSize.middleNormal)
        .fontColor(ThemeManager.current().text)
        .textAlign(TextAlign.Center)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: GSYSpacing.padding12 });

      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(GSYFontSize.small)
          .fontColor(ThemeManager.current().textSecondary)
          .textAlign(TextAlign.Center)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: GSYSpacing.halfEdge });
      }

      if (this.retryText.length > 0) {
        Button(this.retryText)
          .id('empty_state_retry_btn')
          .type(ButtonType.Capsule)
          .height(GSYSpacing.pillButtonHeight)
          .backgroundColor(ThemeManager.current().accent)
          .fontColor(ThemeManager.current().onBrandText)
          .fontSize(GSYFontSize.small)
          .padding({ left: GSYSpacing.padding12, right: GSYSpacing.padding12 })
          .margin({ top: GSYSpacing.padding12 })
          .onClick((): void => {
            this.retry();
          });
      }
    }
    .id(this.rootId.length > 0 ? this.rootId : 'empty_state_root')
    .width('100%')
    .height(GSYSpacing.emptyStateHeight)
    .padding({ left: GSYSpacing.padding12 * 2, right: GSYSpacing.padding12 * 2 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }
}
