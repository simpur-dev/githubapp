import mediaquery from '@ohos.mediaquery';
import { Preferences, KEY_THEME } from '../../base/dao/db/Preferences';
import { EventBus, EVENT_THEME_CHANGED } from '../../base/utils/EventBus';
import { GSYColor, GSYDarkColor } from '../style/Theme';

export type ThemeMode = 'light' | 'dark' | 'system';

export interface ThemePalette {
  primary: string;
  primaryDark: string;
  background: string;
  card: string;
  text: string;
  textSecondary: string;
  divider: string;
  danger: string;
  accent: string;
  navBackground: string;
  /** 主页 Tab 内容区背景。 */
  tabBackground: string;
  /** 输入框/芯片等次级表面。 */
  surfaceSubtle: string;
  /** 品牌/深色表面上的文字（深浅色下都接近白）。 */
  onBrandText: string;
}

export const LIGHT_PALETTE: ThemePalette = {
  primary: GSYColor.primary,
  primaryDark: GSYColor.primaryDark,
  background: GSYColor.pageBackground,
  card: GSYColor.white,
  text: GSYColor.primary,
  textSecondary: GSYColor.textSubtle,
  divider: GSYColor.divider,
  danger: GSYColor.dangerRed,
  accent: GSYColor.linkBlue,
  navBackground: GSYColor.primary,
  tabBackground: GSYColor.tabBackground,
  surfaceSubtle: GSYColor.surfaceSubtle,
  onBrandText: GSYColor.white,
};

export const DARK_PALETTE: ThemePalette = {
  primary: GSYDarkColor.darkPagePrimary,
  primaryDark: GSYDarkColor.darkPrimaryDark,
  background: GSYDarkColor.darkBackground,
  card: GSYDarkColor.darkCard,
  text: GSYDarkColor.darkPaletteText,
  textSecondary: GSYDarkColor.darkTextSecondary,
  divider: GSYDarkColor.darkDivider,
  danger: GSYDarkColor.darkDanger,
  accent: GSYDarkColor.darkAccent,
  navBackground: GSYDarkColor.darkPagePrimary,
  tabBackground: GSYDarkColor.darkPagePrimary,
  surfaceSubtle: GSYDarkColor.darkCard,
  onBrandText: GSYDarkColor.darkPaletteText,
};

export interface SystemColorProvider {
  isDark(): boolean;
}

class MediaQuerySystemProvider implements SystemColorProvider {
  private listener: mediaquery.MediaQueryListener | null = null;
  private currentDark: boolean = false;
  private onChange: ((dark: boolean) => void) | null = null;

  start(onChange: (dark: boolean) => void): void {
    this.onChange = onChange;
    try {
      this.listener = mediaquery.matchMediaSync('(prefers-color-scheme: dark)');
      this.currentDark = this.listener.matches;
      const cb: (result: mediaquery.MediaQueryResult) => void = (result: mediaquery.MediaQueryResult): void => {
        this.currentDark = result.matches;
        if (this.onChange !== null) {
          this.onChange(this.currentDark);
        }
      };
      this.listener.on('change', cb);
    } catch (_e) {
    }
  }

  stop(): void {
    try {
      if (this.listener !== null) {
        this.listener.off('change');
      }
    } catch (_e) {
    }
    this.listener = null;
    this.onChange = null;
  }

  isDark(): boolean {
    return this.currentDark;
  }
}

@ObservedV2
export class ThemeManagerImpl {
  private mode: ThemeMode = 'light';
  /** 当前调色板；@Trace 供 V2 组件直接订阅，V1 组件走 EVENT_THEME_CHANGED 事件刷新。 */
  @Trace palette: ThemePalette = LIGHT_PALETTE;
  private systemProvider: SystemColorProvider | null = null;
  private started: boolean = false;

  current(): ThemePalette {
    return this.palette;
  }

  getMode(): ThemeMode {
    return this.mode;
  }

  /** 当前是否深色：light→false / dark→true / system→systemProvider.isDark()。 */
  isDark(): boolean {
    if (this.mode === 'dark') {
      return true;
    }
    if (this.mode === 'light') {
      return false;
    }
    return this.systemProvider !== null ? this.systemProvider.isDark() : false;
  }

  setSystemProvider(provider: SystemColorProvider): void {
    this.systemProvider = provider;
  }

  async setMode(mode: ThemeMode): Promise<void> {
    this.mode = mode;
    try {
      await Preferences.putString(KEY_THEME, mode);
    } catch (_e) {
    }
    this.applyPalette();
  }

  applyPalette(): void {
    this.palette = this.resolvePalette();
    EventBus.emit(EVENT_THEME_CHANGED, this.palette);
  }

  private resolvePalette(): ThemePalette {
    if (this.mode === 'dark') {
      return DARK_PALETTE;
    }
    if (this.mode === 'light') {
      return LIGHT_PALETTE;
    }
    const dark: boolean = this.systemProvider !== null ? this.systemProvider.isDark() : false;
    return dark ? DARK_PALETTE : LIGHT_PALETTE;
  }

  async init(): Promise<void> {
    if (this.systemProvider === null) {
      const provider: MediaQuerySystemProvider = new MediaQuerySystemProvider();
      provider.start((_dark: boolean): void => {
        if (this.mode === 'system') {
          this.applyPalette();
        }
      });
      this.systemProvider = provider;
    }
    let saved: string = '';
    try {
      saved = await Preferences.getString(KEY_THEME, 'light');
    } catch (_e) {
      saved = 'light';
    }
    const normalized: ThemeMode = ThemeManagerImpl.normalizeMode(saved);
    this.mode = normalized;
    this.applyPalette();
    this.started = true;
  }

  isStarted(): boolean {
    return this.started;
  }

  reset(): void {
    this.mode = 'light';
    this.palette = LIGHT_PALETTE;
    this.systemProvider = null;
    this.started = false;
  }

  static normalizeMode(value: string): ThemeMode {
    if (value === 'dark') {
      return 'dark';
    }
    if (value === 'system') {
      return 'system';
    }
    return 'light';
  }
}

export const ThemeManager: ThemeManagerImpl = new ThemeManagerImpl();
