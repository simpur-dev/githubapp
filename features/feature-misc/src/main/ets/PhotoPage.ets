/**
 * PhotoPage —— L6.4 大图预览
 *
 * RN 基准 [PhotoPage.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/PhotoPage.js)：
 *   - 单图全屏（react-native-image-zoom-viewer）
 *   - backgroundColor=primaryColor
 *   - 点击空白 → Actions.pop()
 *   - 失败显示 default_img.png
 *   - onSaveToCamera 占位
 *
 * OH 端 v1（M-stub）：
 *   - 全屏 Stack + Image objectFit:Contain
 *   - 点击 → NavigationService.pop
 *   - 长按 → CommonToast「长按保存到相册」（i18n photoSaveTip，M-stub 历史占位已去掉）
 *   - 入口参数：{ uri: string }（与 RN 字段对齐）
 *   - boot 通道：want.parameters.bootPhoto=<url>
 *
 * R9 V2 + MVVM：uri/loading/failed 状态与取参（含 BOOT 兜底语义）移入
 * PhotoViewModel（@ObservedV2 + @Trace）；本页仅做展示与手势。
 * 测试 id（photo_*）一字不动。
 */
import { GSYColor, GSYFontSize, GSYIconSize } from 'common';
import { CommonToast, I18n } from 'common';
import { Logger } from 'common';
import { PhotoViewModel } from './viewmodel/PhotoViewModel';
import { NavTitleBridge, NavTitleConfig, RouteName } from 'common';

@ComponentV2
export struct PhotoPage {
  @Local vm: PhotoViewModel = new PhotoViewModel();

  aboutToAppear(): void {
    // 看图页深底：状态栏深底白图标。
    NavTitleBridge.get().registerTitle(RouteName.Photo, {
      statusBarBg: GSYColor.primary,
      statusBarLightIcon: true,
    } as NavTitleConfig);
    this.vm.init();
  }

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      if (this.vm.uri.length > 0 && !this.vm.failed) {
        Image(this.vm.uri)
          .id('photo_image')
          .objectFit(ImageFit.Contain)
          .width('100%')
          .height('100%')
          .onComplete((): void => {
            this.vm.markLoaded();
          })
          .onError((): void => {
            this.vm.markFailed();
          });
      }

      if (this.vm.loading) {
        LoadingProgress()
          .id('photo_loading')
          .width(GSYIconSize.large)
          .height(GSYIconSize.large)
          .color(GSYColor.white);
      }

      if (this.vm.failed) {
        Text(I18n('photoLoadFailed'))
          .id('photo_failed')
          .fontColor(GSYColor.white)
          .fontSize(GSYFontSize.middleNormal);
      }
    }
    .id('photo_page_root')
    .width('100%')
    .height('100%')
    .backgroundColor(GSYColor.primary)
    .onClick((): void => {
      this.vm.dismiss();
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction((): void => {
          Logger.i('boot/ts', `PhotoPage.longPress t=${Date.now()}`);
          CommonToast.showShort(I18n('photoSaveTip'));
        })
    );
  }
}
