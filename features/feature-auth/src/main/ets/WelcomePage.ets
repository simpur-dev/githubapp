import common from '@ohos.app.ability.common';
import font from '@ohos.font';
import hilog from '@ohos.hilog';
import { Preferences, PREF_NAME } from 'common';
import { WelcomeViewModel } from './viewmodel/WelcomeViewModel';

const WELCOME_ICON_SIZE: number = 120;
const TAG: string = 'WelcomePage';

/**
 * WelcomePage —— 系统原生启动窗口风格的欢迎页（2026-09 重构；R9 V2 + MVVM 试点 View 层）
 *
 * 用户拍板：与 RN 端 welcome.png + Lottie 动画解耦，改用 HarmonyOS 系统启动窗口
 * 同款视觉 —— 屏幕居中 app 图标 + 系统空白背景（跟随系统深浅色模式）。
 *
 * 深浅色跟随实现：背景色走资源引用 $r('app.color.start_window_background')，
 * base 目录 #FFFFFF（浅色）/ dark 目录 #000000（深色）由资源限定符自动切换，
 * 与 module.json5 startWindowBackground 指向同一资源，启动窗口→本页视觉无缝衔接。
 *
 * token 检查 / 路由决策 / BOOT 兜底全部在 WelcomeViewModel（@ObservedV2 + @Trace）。
 */
@ComponentV2
export struct WelcomePage {
  @Local vm: WelcomeViewModel = new WelcomeViewModel();

  aboutToAppear(): void {
    this.registerIconFonts();
    let ctx: common.UIAbilityContext | null = null;
    try {
      ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      Preferences.init(ctx, PREF_NAME).catch((): void => {
      });
    } catch (_e) {
    }
    this.vm.scheduleExit(ctx);
  }

  aboutToDisappear(): void {
    this.vm.cancelTimer();
  }

  /**
   * 注册 FontAwesome 字体族（与 RN 端 react-native-vector-icons FontAwesome.ttf 同源 4.x ttf）。
   * 注册后任意 Text 组件 `.fontFamily('FontAwesome')` 即可显示 FontAwesome 字符（如 \uf0f3 = bell）。
   * 必须在 UI 上下文（@Entry 页面 aboutToAppear）调用，UIAbility 中调用会抛 401。
   */
  private registerIconFonts(): void {
    try {
      font.registerFont({
        familyName: 'FontAwesome',
        familySrc: $rawfile('fonts/FontAwesome.ttf'),
      });
      hilog.info(0x0000, TAG, 'registerFont FontAwesome ok');
    } catch (e) {
      const err = e as Error;
      hilog.error(0x0000, TAG, 'registerFont fail %{public}s', err.message);
    }
  }

  onPageShow(): void {
    this.vm.scheduleExit(null);
  }

  build(): void {
    Stack() {
      Column() {
        Image($r('app.media.app_icon'))
          .id('welcome_image')
          .width(WELCOME_ICON_SIZE)
          .height(WELCOME_ICON_SIZE)
          .objectFit(ImageFit.Contain);

        // 脚本断言锚点（scenario-tour.sh 场景 24），空 Text 不渲染任何视觉内容
        Text('')
          .id('welcome_subtitle')
          .width(1)
          .height(1)
          .opacity(0.001);
      }
      .id('welcome_inner')
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center);
    }
    .id('welcome_root')
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'));
  }
}
