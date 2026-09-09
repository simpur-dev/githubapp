import { GSYColor, GSYFontSize } from 'common';

/**
 * HarmonyLogoMark —— 纯展示组件（R9 V2 + MVVM 试点：@ComponentV2 + @Param，无 ViewModel）。
 * 全部入参只读（@Param），phase 变化由父组件（V2 @Param 单向同步）驱动重绘。
 */
@ComponentV2
export struct HarmonyLogoMark {
  @Param phase: number = 0;
  @Param markSize: number = 180;
  @Param rootId: string = 'harmony_logo';
  @Param letterId: string = 'harmony_logo_letter';
  @Param labelId: string = '';
  @Param labelText: string = '';
  @Param darkSurface: boolean = false;
  @Param contained: boolean = false;
  @Param play: boolean = true;
  @Param showPosterBacking: boolean = false;

  private imageHeight(): number {
    return this.markSize * 0.75;
  }

  build(): void {
    Column() {
      Stack() {
        Image($r('app.media.oh_logo_poster'))
          .id(this.letterId + '_poster')
          .width(this.markSize)
          .height(this.imageHeight())
          .objectFit(ImageFit.Contain)
          .visibility((!this.play || this.showPosterBacking) ? Visibility.Visible : Visibility.None);

        Image($r('app.media.oh_logo'))
          .id(this.letterId)
          .width(this.markSize)
          .height(this.imageHeight())
          .objectFit(ImageFit.Contain)
          .visibility(this.play ? Visibility.Visible : Visibility.None);
      }
      .width(this.markSize)
      .height(this.imageHeight());

      if (this.labelText.length > 0) {
        Text(this.labelText)
          .id(this.labelId.length > 0 ? this.labelId : this.rootId + '_label')
          .fontSize(this.markSize > 180 ? GSYFontSize.small : GSYFontSize.min)
          .fontColor(this.darkSurface ? GSYColor.textWhite : GSYColor.textSubtle)
          .margin({ top: 4 });
      }
    }
    .id(this.rootId)
    .width(this.markSize)
    .height(this.imageHeight() + (this.labelText.length > 0 ? 28 : 0))
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.contained ? GSYColor.transparent : GSYColor.transparent);
  }
}
