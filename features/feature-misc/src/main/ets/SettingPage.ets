import { AppBar } from 'common';
import { CommonToast } from 'common';
import { I18n, changeLocale, LocaleKey } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import {
  Preferences,
  KEY_LANGUAGE_SELECT,
  KEY_LANGUAGE_SELECT_NAME,
  KEY_THEME,
  KEY_USER_TOKEN,
  KEY_USER_BASIC,
  KEY_USER_NAME,
  KEY_USER_PASSWORD,
} from 'common';
import { RdbStore } from 'common';
import {
  EventBus,
  EVENT_LANGUAGE_CHANGED,
  EVENT_THEME_CHANGED,
} from 'common';
import { LoginUseCase, DefaultLoginUseCase } from 'common';
import {
  ThemeManager,
  ThemeMode,
  ThemePalette,
  LIGHT_PALETTE,
} from 'common';
import { GSYColor, GSYFontSize } from 'common';
import {
  LANGUAGE_OPTION_ZH,
  LANGUAGE_OPTION_EN,
  LANGUAGE_OPTION_SYSTEM,
  THEME_OPTION_LIGHT,
  THEME_OPTION_DARK,
  THEME_OPTION_SYSTEM,
  SETTING_CACHE_KEYS,
  SettingPageDeps,
  SettingPageHelper,
} from 'common';

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

@Component
export struct SettingPage {
  @State currentLanguage: string = LANGUAGE_OPTION_SYSTEM;
  @State currentTheme: string = THEME_OPTION_SYSTEM;
  @State okLabel: string = I18n('ok');
  @State cancelLabel: string = I18n('cancel');
  @State languageLabel: string = I18n('language');
  @State clearCacheLabel: string = I18n('clearCache');
  @State logoutLabel: string = I18n('LoginOut');
  @State palette: ThemePalette = LIGHT_PALETTE;
  private offLanguage: (() => void) | null = null;
  private offTheme: (() => void) | null = null;

  aboutToAppear(): void {
    this.offLanguage = EventBus.on(EVENT_LANGUAGE_CHANGED, (): void => {
      this.refreshLabels();
    });
    // V1 组件读 ThemeManager 单例不会自动刷新：订阅显式事件保持响应语义。
    this.offTheme = EventBus.on(EVENT_THEME_CHANGED, (_payload: ESObject): void => {
      this.palette = ThemeManager.current();
    });
    this.palette = ThemeManager.current();
    this.refreshLabels();
  }

  aboutToDisappear(): void {
    if (this.offLanguage !== null) {
      this.offLanguage();
      this.offLanguage = null;
    }
    if (this.offTheme !== null) {
      this.offTheme();
      this.offTheme = null;
    }
  }

  private refreshLabels(): void {
    this.okLabel = I18n('ok');
    this.cancelLabel = I18n('cancel');
    this.languageLabel = I18n('language');
    this.clearCacheLabel = I18n('clearCache');
    this.logoutLabel = I18n('LoginOut');
  }

  private async chooseLanguage(option: string): Promise<void> {
    this.currentLanguage = option;
    await SettingPageHelper.applyLanguage(option, SettingPageDeps.getPrefs());
  }

  private async chooseTheme(option: string): Promise<void> {
    this.currentTheme = option;
    await SettingPageHelper.applyThemeMode(option);
    await SettingPageHelper.applyTheme(option, SettingPageDeps.getPrefs());
    CommonToast.showShort('切换成功');
  }

  private async runClearCache(): Promise<void> {
    try {
      await SettingPageHelper.clearCache(SettingPageDeps.getPrefs(), SettingPageDeps.getRdb());
      CommonToast.showShort(this.okLabel);
    } catch (_e) {
    }
  }

  private async runLogout(): Promise<void> {
    try {
      await SettingPageHelper.logout(SettingPageDeps.getUseCase(), SettingPageDeps.getPrefs());
    } catch (_e) {
    }
    NavigationService.replace(RouteName.Login);
  }

  @Builder
  buildLanguageOption(idValue: string, label: string, option: string): void {
    Button(label)
      .id(idValue)
      .type(ButtonType.Capsule)
      .height(36)
      .fontSize(GSYFontSize.small)
      .fontColor(this.currentLanguage === option ? GSYColor.white : GSYColor.primary)
      .backgroundColor(this.currentLanguage === option ? GSYColor.linkBlue : GSYColor.surfacePill)
      .margin({ right: 8 })
      .onClick((): void => {
        this.chooseLanguage(option);
      });
  }

  @Builder
  buildThemeOption(idValue: string, label: string, option: string): void {
    Button(label)
      .id(idValue)
      .type(ButtonType.Capsule)
      .height(36)
      .fontSize(GSYFontSize.small)
      .fontColor(this.currentTheme === option ? GSYColor.white : GSYColor.primary)
      .backgroundColor(this.currentTheme === option ? GSYColor.linkBlue : GSYColor.surfacePill)
      .margin({ right: 8 })
      .onClick((): void => {
        this.chooseTheme(option);
      });
  }

  build(): void {
    Column() {
      AppBar({
        title: I18n('setting'),
        showBack: true,
        onBack: (): void => {
          NavigationService.pop();
        },
      });
      Scroll() {
        Column() {
          Button(I18n('infoName'))
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

          Text(this.languageLabel)
            .id('setting_language_title')
            .fontSize(GSYFontSize.middleNormal)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.primary)
            .width('100%')
            .padding({ top: 16, bottom: 8, left: 16, right: 16 });
          Row() {
            this.buildLanguageOption('setting_language_zh_btn', I18n('zhLanguage'), LANGUAGE_OPTION_ZH);
            this.buildLanguageOption('setting_language_en_btn', I18n('enLanguage'), LANGUAGE_OPTION_EN);
            this.buildLanguageOption('setting_language_system_btn', I18n('systemLanguage'), LANGUAGE_OPTION_SYSTEM);
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
            this.buildThemeOption('setting_theme_light_btn', 'Light', THEME_OPTION_LIGHT);
            this.buildThemeOption('setting_theme_dark_btn', 'Dark', THEME_OPTION_DARK);
            this.buildThemeOption('setting_theme_system_btn', 'System', THEME_OPTION_SYSTEM);
          }
          .id('setting_theme_row')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 12 })
          .alignItems(VerticalAlign.Center);

          Button(this.clearCacheLabel)
            .id('setting_clear_cache_btn')
            .type(ButtonType.Capsule)
            .width('90%')
            .height(46)
            .fontSize(GSYFontSize.middleNormal)
            .fontColor(GSYColor.white)
            .backgroundColor(GSYColor.warningOrange)
            .margin({ top: 16 })
            .onClick((): void => {
              this.runClearCache();
            });

          Button(this.logoutLabel)
            .id('setting_logout_btn')
            .type(ButtonType.Capsule)
            .width('90%')
            .height(46)
            .fontSize(GSYFontSize.middleNormal)
            .fontColor(GSYColor.white)
            .backgroundColor(GSYColor.dangerRed)
            .margin({ top: 12, bottom: 24 })
            .onClick((): void => {
              this.runLogout();
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
    .backgroundColor(this.palette ? this.palette.background : GSYColor.pageBackground);
  }
}
