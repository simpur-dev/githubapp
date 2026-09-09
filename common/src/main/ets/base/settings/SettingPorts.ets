// 设置域端口与助手（R9 阶段1a 从 SettingPage.ets 抽出：DrawerMenu 等 common 组件也要用，不能住在 feature 页面里）
import { Preferences, KEY_LANGUAGE_SELECT, KEY_LANGUAGE_SELECT_NAME, KEY_THEME, KEY_USER_TOKEN, KEY_USER_BASIC, KEY_USER_NAME, KEY_USER_PASSWORD } from '../dao/db/Preferences';
import { RdbStore } from '../dao/db/RdbStore';
import { EventBus, EVENT_LANGUAGE_CHANGED, EVENT_THEME_CHANGED } from '../utils/EventBus';
import { changeLocale, LocaleKey } from '../i18n/I18n';
import { LoginUseCase, DefaultLoginUseCase } from '../../model/auth/LoginUseCase';
import { ThemeManager, ThemeMode, ThemePalette } from '../../ui/theme/ThemeManager';

export const LANGUAGE_OPTION_ZH: string = 'zh-CN';
export const LANGUAGE_OPTION_EN: string = 'en';
export const LANGUAGE_OPTION_SYSTEM: string = 'local';

export const THEME_OPTION_LIGHT: string = 'light';
export const THEME_OPTION_DARK: string = 'dark';
export const THEME_OPTION_SYSTEM: string = 'system';

export const SETTING_CACHE_KEYS: string[] = [
  KEY_LANGUAGE_SELECT,
  KEY_LANGUAGE_SELECT_NAME,
  KEY_THEME,
];

export interface PreferencesPort {
  putString(key: string, value: string): Promise<void>;
  getString(key: string, defValue: string): Promise<string>;
  remove(key: string): Promise<void>;
}

export interface RdbPort {
  clearAll(): Promise<void>;
}

class DefaultPreferencesPort implements PreferencesPort {
  putString(key: string, value: string): Promise<void> {
    return Preferences.putString(key, value);
  }

  getString(key: string, defValue: string): Promise<string> {
    return Preferences.getString(key, defValue);
  }

  remove(key: string): Promise<void> {
    return Preferences.remove(key);
  }
}

class DefaultRdbPort implements RdbPort {
  clearAll(): Promise<void> {
    return RdbStore.clearAll();
  }
}

export class SettingPageDeps {
  private static useCaseImpl: LoginUseCase = DefaultLoginUseCase;
  private static prefsImpl: PreferencesPort = new DefaultPreferencesPort();
  private static rdbImpl: RdbPort = new DefaultRdbPort();

  static setUseCase(useCase: LoginUseCase): void {
    SettingPageDeps.useCaseImpl = useCase;
  }

  static setPrefs(prefs: PreferencesPort): void {
    SettingPageDeps.prefsImpl = prefs;
  }

  static setRdb(rdb: RdbPort): void {
    SettingPageDeps.rdbImpl = rdb;
  }

  static getUseCase(): LoginUseCase {
    return SettingPageDeps.useCaseImpl;
  }

  static getPrefs(): PreferencesPort {
    return SettingPageDeps.prefsImpl;
  }

  static getRdb(): RdbPort {
    return SettingPageDeps.rdbImpl;
  }

  static reset(): void {
    SettingPageDeps.useCaseImpl = DefaultLoginUseCase;
    SettingPageDeps.prefsImpl = new DefaultPreferencesPort();
    SettingPageDeps.rdbImpl = new DefaultRdbPort();
  }
}

export class SettingPageHelper {
  static resolveLocale(option: string): LocaleKey {
    return changeLocale(option);
  }

  static async applyLanguage(option: string, prefs: PreferencesPort): Promise<LocaleKey> {
    const applied: LocaleKey = SettingPageHelper.resolveLocale(option);
    await prefs.putString(KEY_LANGUAGE_SELECT, option);
    await prefs.putString(KEY_LANGUAGE_SELECT_NAME, applied);
    EventBus.emit(EVENT_LANGUAGE_CHANGED, applied);
    return applied;
  }

  static async applyTheme(option: string, prefs: PreferencesPort): Promise<void> {
    await prefs.putString(KEY_THEME, option);
    EventBus.emit(EVENT_THEME_CHANGED, option);
  }

  static async applyThemeMode(option: string): Promise<ThemePalette> {
    const mode: ThemeMode = SettingPageHelper.toThemeMode(option);
    await ThemeManager.setMode(mode);
    return ThemeManager.current();
  }

  static toThemeMode(option: string): ThemeMode {
    if (option === 'dark') {
      return 'dark';
    }
    if (option === 'system') {
      return 'system';
    }
    return 'light';
  }

  static async clearCache(prefs: PreferencesPort, rdb: RdbPort): Promise<void> {
    await rdb.clearAll();
    for (let i: number = 0; i < SETTING_CACHE_KEYS.length; i++) {
      const key: string = SETTING_CACHE_KEYS[i];
      try {
        await prefs.remove(key);
      } catch (_e) {
      }
    }
  }

  static async logout(useCase: LoginUseCase, prefs: PreferencesPort): Promise<void> {
    await useCase.logout();
    const authKeys: string[] = [KEY_USER_TOKEN, KEY_USER_BASIC, KEY_USER_NAME, KEY_USER_PASSWORD];
    for (let i: number = 0; i < authKeys.length; i++) {
      try {
        await prefs.remove(authKeys[i]);
      } catch (_e) {
      }
    }
  }
}
