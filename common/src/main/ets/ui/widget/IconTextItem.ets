/**
 * IconTextItem —— 严格对齐 RN 端
 * [components/widget/IconTextItem.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/widget/IconTextItem.js)
 * RN L18-L34 render；L20 halfEdge=normalMarginEdge/2；L21-L23 条件 icon；L28-L32 Text+marginLeft；L49-L54 defaults。
 */

import { GSYColor, GSYFontSize, GSYIconSize, GSYSpacing } from '../style/Theme';
import { IconFont } from '../components/IconFont';

@ComponentV2
export struct IconTextItem {
  @Param text: string = '';
  @Param iconChar: string = '';
  @Param iconColor: string = GSYColor.miWhite;
  @Param iconSize: number = GSYIconSize.little;

  @Param textColor: string = GSYColor.miWhite;
  @Param textFontSize: number = GSYFontSize.small;
  @Param textBold: boolean = false;
  @Param textMaxLines: number = 1;
  @Param textLayoutWeight: number = 0;

  @Param rowId: string = '';
  @Param rowWidthFull: boolean = false;
  @Param rowMarginTop: number = 0;
  @Param rowMarginBottom: number = 0;

  private hasIcon(): boolean {
    return this.iconChar.length > 0;
  }

  private resolveHalfEdge(): number {
    return this.hasIcon() ? GSYSpacing.halfEdge : 0;
  }

  build(): void {
    Row() {
      if (this.hasIcon()) {
        IconFont({
          char: this.iconChar,
          glyphSize: this.iconSize,
          glyphColor: this.iconColor,
        });
      }

      if (this.textLayoutWeight > 0) {
        Text(this.text)
          .id(this.rowId.length > 0 ? this.rowId + '_text' : 'icon_text_item_text')
          .fontSize(this.textFontSize)
          .fontColor(this.textColor)
          .fontWeight(this.textBold ? FontWeight.Bold : FontWeight.Normal)
          .margin({ left: this.resolveHalfEdge() })
          .maxLines(this.textMaxLines)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(this.textLayoutWeight);
      } else {
        Text(this.text)
          .id(this.rowId.length > 0 ? this.rowId + '_text' : 'icon_text_item_text')
          .fontSize(this.textFontSize)
          .fontColor(this.textColor)
          .fontWeight(this.textBold ? FontWeight.Bold : FontWeight.Normal)
          .margin({ left: this.resolveHalfEdge() })
          .maxLines(this.textMaxLines)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
    }
    .id(this.rowId.length > 0 ? this.rowId : 'icon_text_item_root')
    .alignItems(VerticalAlign.Center)
    .width(this.rowWidthFull ? '100%' : undefined)
    .margin({ top: this.rowMarginTop, bottom: this.rowMarginBottom });
  }
}
