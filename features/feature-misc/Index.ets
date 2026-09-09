// features/feature-misc 统一出口（R9 阶段1b 生成，模块间只允许从这里导入）
// R9 V2 + MVVM：ViewModel 三件套与设置域端口一并从桶导出
// （SettingUiTest / ThemeUiTest / LoginUiTest 经此引用 SettingPageDeps / PreferencesPort / RdbPort）

export { APP_AUTHOR, APP_LICENSE, APP_PROJECT_URL, APP_VERSION, AboutPage } from './src/main/ets/AboutPage';
export { CustomPage, CustomScriptItem, buildCustomPlaceholderList } from './src/main/ets/CustomPage';
export { HONOR_LIST, HonorEntry, HonorPage } from './src/main/ets/HonorPage';
export { PhotoPage } from './src/main/ets/PhotoPage';
export { PhotoViewModel } from './src/main/ets/viewmodel/PhotoViewModel';
export {
  LANGUAGE_OPTION_EN,
  LANGUAGE_OPTION_SYSTEM,
  LANGUAGE_OPTION_ZH,
  SETTING_CACHE_KEYS,
  THEME_OPTION_DARK,
  THEME_OPTION_LIGHT,
  THEME_OPTION_SYSTEM,
  PreferencesPort,
  RdbPort,
  SettingPage,
  SettingPageDeps,
  SettingPageHelper,
} from './src/main/ets/SettingPage';
export { SettingOptionItem, SettingViewModel } from './src/main/ets/viewmodel/SettingViewModel';
export { WebPage } from './src/main/ets/WebPage';
export { WebViewModel } from './src/main/ets/viewmodel/WebViewModel';
