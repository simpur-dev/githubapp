import font from '@ohos.font';
import hilog from '@ohos.hilog';
import { OAuthLocalConfigLoader, OAuthRuntimeConfig } from 'common';
import { I18n } from 'common';
import { GSYColor, GSYFontSize, GSYSpacing } from 'common';
import { FA_KEY } from 'common';
import { LANGUAGE_OPTION_ZH, LANGUAGE_OPTION_EN, LANGUAGE_OPTION_SYSTEM } from 'common';
import { HarmonyLogoMark } from './views/HarmonyLogoMark';
import { LoginViewModel } from './viewmodel/LoginViewModel';

const LOGIN_LOGO_MARK_SIZE: number = 180;
const LOGIN_LOGO_IMAGE_HEIGHT: number = LOGIN_LOGO_MARK_SIZE * 0.75;
const LOGIN_LOGO_BOTTOM_MARGIN: number = 24;

/**
 * LoginPage —— 登录页 View 层（R9 V2 + MVVM 试点）。
 *
 * 状态与编排全部在 LoginViewModel（@ObservedV2 + @Trace）；
 * LoginPageDeps / LoginOauthClient / LoginOauthRouteParams 平移至
 * viewmodel/LoginDeps.ets（经 'feature_auth' 桶导出，类名与签名不变）。
 *
 * 语言选择弹层仍是自绘 overlay（login_language_overlay），选项内的假 radio 文本
 * （'●'/'○'）已换为原生 Radio 组件，login_language_* 全部 id 原样保留。
 */
@ComponentV2
export struct LoginPage {
  @Param showLogo: boolean = true;
  @Local vm: LoginViewModel = new LoginViewModel();

  aboutToAppear(): void {
    this.registerIconFonts();
    this.vm.init();
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  private registerIconFonts(): void {
    try {
      font.registerFont({
        familyName: 'FontAwesome',
        familySrc: $rawfile('fonts/FontAwesome.ttf'),
      });
    } catch (e) {
      const err = e as Error;
      hilog.warn(0x0000, 'LoginPage', 'registerFont fail %{public}s', err.message);
    }
  }

  private async openOAuthWeb(): Promise<void> {
    // OAuthLocalConfigLoader.load 需要 UI 上下文读 rawfile，留在 View 层取配置，
    // 校验 / 注入 / 授权页跳转编排交给 LoginViewModel.openOAuthWeb。
    const cfg: OAuthRuntimeConfig = await OAuthLocalConfigLoader.load(this.getUIContext().getHostContext());
    await this.vm.openOAuthWeb(cfg);
  }

  @Builder
  private buildLanguageOption(value: string, label: string): void {
    Row() {
      // 原生 Radio 替代旧 '●'/'○' 文本模拟；同一 group 自动互斥，选中态走原生 checked。
      Radio({ value: value, group: 'loginLanguage' })
        .id('login_language_radio_' + value)
        .checked(this.vm.currentLanguage === value)
        .radioStyle({
          checkedBackgroundColor: GSYColor.linkBlue,
          uncheckedBorderColor: GSYColor.textSubtle,
          indicatorColor: GSYColor.white,
        })
        .width(20)
        .height(20)
        .onChange((isChecked: boolean): void => {
          if (isChecked) {
            this.vm.chooseLanguage(value);
          }
        });

      Text(label)
        .id('login_language_label_' + value)
        .fontSize(GSYFontSize.normal)
        .fontColor(GSYColor.primary)
        .layoutWeight(1)
        .margin({ left: GSYSpacing.halfEdge });
    }
    .id('login_language_option_' + value)
    .width('100%')
    .height(48)
    .padding({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.vm.chooseLanguage(value);
    });
  }

  @Builder
  private buildAnimatedLogo(): void {
    if (this.showLogo) {
      HarmonyLogoMark({
        phase: this.vm.logoPhase,
        markSize: LOGIN_LOGO_MARK_SIZE,
        rootId: 'login_logo',
        letterId: 'login_logo_harmony_letter',
        darkSurface: false,
        contained: false,
      })
        .margin({ bottom: LOGIN_LOGO_BOTTOM_MARGIN });
    } else {
      Blank()
        .id('login_logo_placeholder')
        .width(LOGIN_LOGO_MARK_SIZE)
        .height(LOGIN_LOGO_IMAGE_HEIGHT)
        .margin({ bottom: LOGIN_LOGO_BOTTOM_MARGIN });
    }
  }

  build(): void {
    Stack() {
      Column() {
        this.buildAnimatedLogo();

        Column() {
          Text(I18n('LoginTitle'))
            .id('login_title')
            .fontSize(GSYFontSize.big)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.primary)
            .textAlign(TextAlign.Center);

          Text(I18n('LoginSubtitle'))
            .id('login_subtitle')
            .fontSize(GSYFontSize.middleWhite)
            .fontColor(GSYColor.textSubtle)
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 32 });

          Text(I18n('LoginTokenLabel'))
            .id('login_token_label')
            .fontSize(GSYFontSize.small)
            .fontColor(GSYColor.primary)
            .width('100%')
            .textAlign(TextAlign.Start)
            .margin({ bottom: GSYSpacing.halfEdge });

          Row() {
            Text(FA_KEY)
              .id('login_token_leading_icon')
              .fontFamily('FontAwesome')
              .fontSize(GSYFontSize.middleWhite)
              .fontColor(GSYColor.textSubtle)
              .textAlign(TextAlign.Center)
              .width(40);

            TextInput({ text: this.vm.token, placeholder: I18n('LoginTokenHint') })
              .id('login_token_input')
              .type(InputType.Password)
              .layoutWeight(1)
              .height(48)
              .fontSize(GSYFontSize.small)
              .backgroundColor(GSYColor.transparent)
              .onChange((value: string): void => {
                this.vm.token = value;
              });
          }
            .id('login_token_field')
            .width('100%')
            .height(52)
            .backgroundColor(GSYColor.surfaceSubtle)
            .borderRadius(8)
            .alignItems(VerticalAlign.Center);

          Text(I18n('LoginTokenHelper'))
            .id('login_token_helper')
            .fontSize(GSYFontSize.min)
            .fontColor(GSYColor.textSubtle)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 8, bottom: 24 });

          Row() {
            Button(I18n('LoginButton'))
              .id('login_submit_btn')
              .type(ButtonType.Normal)
              .width('48%')
              .height(50)
              .fontSize(GSYFontSize.middleWhite)
              .fontColor(GSYColor.textWhite)
              .backgroundColor(GSYColor.primary)
              .borderRadius(8)
              .enabled(!this.vm.loading && this.vm.token.trim().length > 0)
              .onClick((): void => {
                this.vm.runTokenLogin(this.vm.token);
              });

            Button(I18n('OAuthLogin'))
              .id('login_oauth_btn')
              .type(ButtonType.Normal)
              .width('48%')
              .height(50)
              .fontSize(GSYFontSize.middleWhite)
              .fontColor(GSYColor.textWhite)
              .backgroundColor(GSYColor.primary)
              .borderRadius(8)
              .enabled(!this.vm.loading)
              .onClick((): void => {
                this.openOAuthWeb();
              });
          }
          .id('login_buttons_row')
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Center);

          Text(I18n('language'))
            .id('login_language_btn')
            .fontSize(GSYFontSize.middleWhite)
            .fontColor(GSYColor.primary)
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ top: 16, bottom: 8 })
            .onClick((): void => {
              this.vm.showLanguageDialog = true;
            });

          if (this.vm.errorMessage.length > 0) {
            Text(this.vm.errorMessage)
              .id('login_error_text')
              .fontSize(GSYFontSize.min)
              .fontColor(GSYColor.primary)
              .margin({ top: GSYSpacing.halfEdge });
          }
        }
        .id('login_form')
        .width('100%')
        .alignItems(HorizontalAlign.Center);
      }
      .id('login_root')
      .width('86%')
      .constraintSize({ minHeight: 520 })
      .padding({
        top: 30,
        bottom: 30,
        left: 30,
        right: 30,
      })
      .backgroundColor(GSYColor.cardBackground)
      .borderRadius(8)
      .alignItems(HorizontalAlign.Center);

      if (this.vm.showLanguageDialog) {
        Column() {
          Column() {
            Text(I18n('language'))
              .id('login_language_title')
              .fontSize(GSYFontSize.middleWhite)
              .fontWeight(FontWeight.Bold)
              .fontColor(GSYColor.darkText)
              .width('100%')
              .textAlign(TextAlign.Start)
              .padding({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge, top: 16, bottom: 12 });

            this.buildLanguageOption(LANGUAGE_OPTION_SYSTEM, I18n('systemLanguage'));
            Divider().color(GSYColor.pillDivider).strokeWidth(0.5);
            this.buildLanguageOption(LANGUAGE_OPTION_ZH, I18n('zhLanguage'));
            Divider().color(GSYColor.pillDivider).strokeWidth(0.5);
            this.buildLanguageOption(LANGUAGE_OPTION_EN, I18n('enLanguage'));
          }
          .id('login_language_dialog')
          .width('86%')
          .backgroundColor(GSYColor.cardBackground)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start);
        }
        .id('login_language_overlay')
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(GSYColor.loadingMaskBg);
      }

      if (this.vm.loading) {
        Column() {
          Column() {
            LoadingProgress()
              .id('login_loading_progress')
              .width(36)
              .height(36)
              .color(GSYColor.white);
          }
          .width(72)
          .height(72)
          .borderRadius(8)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(GSYColor.loadingMaskBg);
        }
        .id('login_loading_overlay')
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(GSYColor.loadingLightMaskBg);
      }
    }
    .id('login_stack_root')
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
    .backgroundColor(GSYColor.primary);
  }
}
