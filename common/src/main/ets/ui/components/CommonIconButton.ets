import { GSYColor, GSYFontSize, GSYSpacing } from '../style/Theme';
import { IconFont } from './IconFont';

@ComponentV2
export struct CommonIconButton {
  @Param icon: string = '';
  @Param text: string = '';
  @Param iconColor: string = GSYColor.miWhite;
  @Param textColor: string = GSYColor.miWhite;
  @Param iconSize: number = GSYFontSize.middleWhite;
  @Param textFontSize: number = GSYFontSize.small;
  @Param textId: string = '';
  @Event onPress: () => void = (): void => {};

  @Builder
  buildText(): void {
    if (this.text && this.text.length > 0) {
      if (this.textId.length > 0) {
        Text(this.text)
          .id(this.textId)
          .fontSize(this.textFontSize)
          .fontColor(this.textColor)
          .margin({ left: (this.icon && this.icon.length > 0) ? GSYSpacing.halfEdge : 0 });
      } else {
        Text(this.text)
          .fontSize(this.textFontSize)
          .fontColor(this.textColor)
          .margin({ left: (this.icon && this.icon.length > 0) ? GSYSpacing.halfEdge : 0 });
      }
    }
  }

  build(): void {
    Row() {
      if (this.icon && this.icon.length > 0) {
        IconFont({
          char: this.icon,
          glyphSize: this.iconSize,
          glyphColor: this.iconColor
        });
      }
      this.buildText();
    }
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .padding({
      left: GSYSpacing.normalEdge,
      right: GSYSpacing.normalEdge,
      top: GSYSpacing.halfEdge,
      bottom: GSYSpacing.halfEdge
    })
    .onClick((): void => {
      this.onPress();
    });
  }
}
