import { I18n } from 'common';
import {
  EventBus,
  EVENT_LANGUAGE_CHANGED,
  EVENT_THEME_CHANGED,
} from 'common';
import { NavigationService, RouteName } from 'common';
import { CommonToast } from 'common';
import {
  ThemeManager,
  ThemePalette,
  LIGHT_PALETTE,
} from 'common';
import {
  LANGUAGE_OPTION_ZH,
  LANGUAGE_OPTION_EN,
  LANGUAGE_OPTION_SYSTEM,
  THEME_OPTION_LIGHT,
  THEME_OPTION_DARK,
  THEME_OPTION_SYSTEM,
  SettingPageDeps,
  SettingPageHelper,
} from 'common';

/**
 * SettingOptionItem —— 语言/主题选项按钮的展示数据行（Repeat 数据源）。
 * idValue 是测试脚本依赖的组件 id（scenario-tour.sh 断言清单），一字不动。
 */
@ObservedV2
export class SettingOptionItem {
  readonly idValue: string;
  readonly option: string;
  @Trace label: string;

  constructor(idValue: string, label: string, option: string) {
    this.idValue = idValue;
    this.label = label;
    this.option = option;
  }
}

/**
 * SettingViewModel —— 设置页状态与编排（R9 V2 + MVVM）。
 *
 * @Trace 状态（12 个）：当前语言、当前主题、主题色板、页面标题、个人信息按钮文案、
 * ok/取消/语言/清理缓存/退出登录 5 条 I18n 文案、语言选项行、主题选项行。
 * 语言切换 / 主题切换 / 清理缓存 / 退出登录编排全部调用 common 的
 * SettingPageDeps / SettingPageHelper（helper 本体不改）；事件订阅
 * （语言变化、主题变化）也收拢在此，SettingPage 只做 UI 组装。
 */
@ObservedV2
export class SettingViewModel {
  @Trace currentLanguage: string = LANGUAGE_OPTION_SYSTEM;
  @Trace currentTheme: string = THEME_OPTION_SYSTEM;
  @Trace palette: ThemePalette = LIGHT_PALETTE;
  @Trace settingTitle: string = I18n('setting');
  @Trace personInfoLabel: string = I18n('infoName');
  @Trace okLabel: string = I18n('ok');
  @Trace cancelLabel: string = I18n('cancel');
  @Trace languageLabel: string = I18n('language');
  @Trace clearCacheLabel: string = I18n('clearCache');
  @Trace logoutLabel: string = I18n('LoginOut');
  @Trace languageOptions: SettingOptionItem[] = [
    new SettingOptionItem('setting_language_zh_btn', I18n('zhLanguage'), LANGUAGE_OPTION_ZH),
    new SettingOptionItem('setting_language_en_btn', I18n('enLanguage'), LANGUAGE_OPTION_EN),
    new SettingOptionItem('setting_language_system_btn', I18n('systemLanguage'), LANGUAGE_OPTION_SYSTEM),
  ];
  @Trace themeOptions: SettingOptionItem[] = [
    new SettingOptionItem('setting_theme_light_btn', 'Light', THEME_OPTION_LIGHT),
    new SettingOptionItem('setting_theme_dark_btn', 'Dark', THEME_OPTION_DARK),
    new SettingOptionItem('setting_theme_system_btn', 'System', THEME_OPTION_SYSTEM),
  ];
  private offLanguage: (() => void) | null = null;
  private offTheme: (() => void) | null = null;

  /** View aboutToAppear 时调用：订阅事件 + 同步当前主题与文案（顺序与原页面一致）。 */
  init(): void {
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

  /** View aboutToDisappear 时调用：退订事件。 */
  dispose(): void {
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
    this.settingTitle = I18n('setting');
    this.personInfoLabel = I18n('infoName');
    this.okLabel = I18n('ok');
    this.cancelLabel = I18n('cancel');
    this.languageLabel = I18n('language');
    this.clearCacheLabel = I18n('clearCache');
    this.logoutLabel = I18n('LoginOut');
    this.languageOptions[0].label = I18n('zhLanguage');
    this.languageOptions[1].label = I18n('enLanguage');
    this.languageOptions[2].label = I18n('systemLanguage');
  }

  async chooseLanguage(option: string): Promise<void> {
    this.currentLanguage = option;
    await SettingPageHelper.applyLanguage(option, SettingPageDeps.getPrefs());
  }

  async chooseTheme(option: string): Promise<void> {
    this.currentTheme = option;
    await SettingPageHelper.applyThemeMode(option);
    await SettingPageHelper.applyTheme(option, SettingPageDeps.getPrefs());
    CommonToast.showShort('切换成功');
  }

  async runClearCache(): Promise<void> {
    try {
      await SettingPageHelper.clearCache(SettingPageDeps.getPrefs(), SettingPageDeps.getRdb());
      CommonToast.showShort(this.okLabel);
    } catch (_e) {
    }
  }

  async runLogout(): Promise<void> {
    try {
      await SettingPageHelper.logout(SettingPageDeps.getUseCase(), SettingPageDeps.getPrefs());
    } catch (_e) {
    }
    NavigationService.replace(RouteName.Login);
  }
}
