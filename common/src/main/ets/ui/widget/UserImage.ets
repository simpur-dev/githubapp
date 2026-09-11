/**
 * UserImage —— 对齐 RN 端
 * [components/widget/UserImage.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/widget/UserImage.js)
 * RN L17-L23：TouchableWithoutFeedback + Image(uri, resizeMethod=scale, style)
 * RN L20-L22 圆形 borderRadius 由调用方 style 传入；OH 端在内部按 size/2 强制圆形。
 * 空 uri 时回退首字母占位（OH 扩展，避免黑块）。
 */

import { GSYColor, GSYFontSize, GSYIconSize } from '../style/Theme';
import { ThemeManager } from '../theme/ThemeManager';

@ComponentV2
export struct UserImage {
  @Param uri: string = '';
  @Param loginUser: string = '';
  @Param imageSize: number = GSYIconSize.small;
  @Param normalIconSize: boolean = false;
  @Param smallIconSize: boolean = false;
  @Param imageId: string = '';

  @Event onAvatarTap: () => void = (): void => {};

  private resolveSize(): number {
    if (this.normalIconSize) {
      return GSYIconSize.normal;
    }
    if (this.smallIconSize) {
      return GSYIconSize.small;
    }
    return this.imageSize;
  }

  private resolveLetter(): string {
    if (this.loginUser.length === 0) {
      return '?';
    }
    return this.loginUser.substring(0, 1).toUpperCase();
  }

  build(): void {
    if (this.uri.length > 0) {
      Image(this.uri)
        .id(this.imageId.length > 0 ? this.imageId : 'user_image')
        .alt($r('app.media.app_icon'))
        .width(this.resolveSize())
        .height(this.resolveSize())
        .borderRadius(this.resolveSize() / 2)
        .objectFit(ImageFit.Cover)
        .backgroundColor(ThemeManager.current().surfaceSubtle)
        .onClick((): void => {
          this.onAvatarTap();
        });
    } else {
      Text(this.resolveLetter())
        .id(this.imageId.length > 0 ? this.imageId : 'user_image_placeholder')
        .width(this.resolveSize())
        .height(this.resolveSize())
        .borderRadius(this.resolveSize() / 2)
        .textAlign(TextAlign.Center)
        .fontSize(this.resolveSize() > GSYIconSize.small ? GSYFontSize.middleWhite : GSYFontSize.small)
        .fontWeight(FontWeight.Bold)
        .fontColor(GSYColor.white)
        .backgroundColor(GSYColor.primary)
        .onClick((): void => {
          this.onAvatarTap();
        });
    }
  }
}
