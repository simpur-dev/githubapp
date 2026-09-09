import { AppBar } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { GSYColor, GSYFontSize } from 'common';
import { SettingViewModel, SettingOptionItem } from './viewmodel/SettingViewModel';

// 设置域端口/助手已抽到 common/base/settings/SettingPorts（R9 阶段1a），
// 这里 import 使用 + 再导出兼容测试引用。
export {
  LANGUAGE_OPTION_ZH,
  LANGUAGE_OPTION_EN,
  LANGUAGE_OPTION_SYSTEM,
  THEME_OPTION_LIGHT,
  THEME_OPTION_DARK,
  THEME_OPTION_SYSTEM,
  SETTING_CACHE_KEYS,
  PreferencesPort,
  RdbPort,
  SettingPageDeps,
  SettingPageHelper,
} from 'common';

/**
 * SettingPage —— 设置页 View 层（R9 V2 + MVVM）。
 *
 * 状态与编排（语言/主题/清理缓存/退出登录）在 SettingViewModel（@ObservedV2 + @Trace）；
 * 语言/主题选项行由 Repeat 渲染，选中态与文案 inline 求值保持响应。
 * 所有测试 id（setting_*）一字不动。
 */
@ComponentV2
export struct SettingPage {
  @Local vm: SettingViewModel = new SettingViewModel();

  aboutToAppear(): void {
    this.vm.init();
  }

  aboutToDisappear(): void {
    this.vm.dispose();
  }

  build(): void {
    Column() {
      AppBar({
        title: this.vm.settingTitle,
        showBack: true,
        onBack: (): void => {
          NavigationService.pop();
        },
      });
      Scroll() {
        Column() {
          Button(this.vm.personInfoLabel)
            .id('setting_person_info_btn')
            .type(ButtonType.Capsule)
            .width('90%')
            .height(46)
            .fontSize(GSYFontSize.middleWhite)
            .fontColor(GSYColor.white)
            .backgroundColor(GSYColor.linkBlue)
            .margin({ top: 16 })
            .onClick((): void => {
              NavigationService.push(RouteName.PersonInfo);
            });

          Text(this.vm.languageLabel)
            .id('setting_language_title')
            .fontSize(GSYFontSize.middleNormal)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.primary)
            .width('100%')
            .padding({ top: 16, bottom: 8, left: 16, right: 16 });
          Row() {
            Repeat(this.vm.languageOptions)
              .each((obj: RepeatItem<SettingOptionItem>) => {
                Button(obj.item.label)
                  .id(obj.item.idValue)
                  .type(ButtonType.Capsule)
                  .height(36)
                  .fontSize(GSYFontSize.small)
                  .fontColor(obj.item.option === this.vm.currentLanguage ? GSYColor.white : GSYColor.primary)
                  .backgroundColor(obj.item.option === this.vm.currentLanguage ? GSYColor.linkBlue : GSYColor.surfacePill)
                  .margin({ right: 8 })
                  .onClick((): void => {
                    this.vm.chooseLanguage(obj.item.option);
                  });
              })
              .key((item: SettingOptionItem): string => item.idValue)
          }
          .id('setting_language_row')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 })
          .alignItems(VerticalAlign.Center);

          Text('Theme')
            .id('setting_theme_title')
            .fontSize(GSYFontSize.middleNormal)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.primary)
            .width('100%')
            .padding({ top: 16, bottom: 8, left: 16, right: 16 });
          Row() {
            Repeat(this.vm.themeOptions)
              .each((obj: RepeatItem<SettingOptionItem>) => {
                Button(obj.item.label)
                  .id(obj.item.idValue)
                  .type(ButtonType.Capsule)
                  .height(36)
                  .fontSize(GSYFontSize.small)
                  .fontColor(obj.item.option === this.vm.currentTheme ? GSYColor.white : GSYColor.primary)
                  .backgroundColor(obj.item.option === this.vm.currentTheme ? GSYColor.linkBlue : GSYColor.surfacePill)
                  .margin({ right: 8 })
                  .onClick((): void => {
                    this.vm.chooseTheme(obj.item.option);
                  });
              })
              .key((item: SettingOptionItem): string => item.idValue)
          }
          .id('setting_theme_row')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 })
          .alignItems(VerticalAlign.Center);

          Button(this.vm.clearCacheLabel)
            .id('setting_clear_cache_btn')
            .type(ButtonType.Capsule)
            .width('90%')
            .height(46)
            .fontSize(GSYFontSize.middleNormal)
            .fontColor(GSYColor.white)
            .backgroundColor(GSYColor.warningOrange)
            .margin({ top: 16 })
            .onClick((): void => {
              this.vm.runClearCache();
            });

          Button(this.vm.logoutLabel)
            .id('setting_logout_btn')
            .type(ButtonType.Capsule)
            .width('90%')
            .height(46)
            .fontSize(GSYFontSize.middleNormal)
            .fontColor(GSYColor.white)
            .backgroundColor(GSYColor.dangerRed)
            .margin({ top: 12, bottom: 24 })
            .onClick((): void => {
              this.vm.runLogout();
            });
        }
        .id('setting_content')
        .width('100%')
        .alignItems(HorizontalAlign.Center);
      }
      .id('setting_scroll')
      .layoutWeight(1)
      .width('100%');
    }
    .id('setting_root')
    .width('100%')
    .height('100%')
    .backgroundColor(this.vm.palette ? this.vm.palette.background : GSYColor.pageBackground);
  }
}
