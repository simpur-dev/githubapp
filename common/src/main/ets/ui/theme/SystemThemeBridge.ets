/**
 * SystemThemeBridge —— 把 GSY 调色板同步给官方应用主题框架（@ohos.arkui.theme）。
 *
 * ThemeControl.setDefaultTheme(CustomTheme) 设置全局默认主题后，
 * 系统组件（AlertDialog / ActionSheet / 菜单 / Select / LoadingProgress 等）
 * 会按 colors + darkColors 自动深浅色，不再出现"深色模式下弹窗白底"这类问题。
 * 应用自身的界面色仍以 ThemeManager 为准；本桥接只负责系统默认样式。
 *
 * 注意：CustomColors = Partial<Colors> 是映射类型，ArkTS 不接受其对象字面量
 * （arkts-no-untyped-obj-literals），因此这里直接构造完整的 Colors。
 */
import { Colors, CustomTheme, ThemeControl } from '@ohos.arkui.theme';
import { ThemePalette } from './ThemeManager';

function toSystemColors(p: ThemePalette): Colors {
  const colors: Colors = {
    brand: p.primary,
    primary: p.accent,
    onPrimary: p.onBrandText,
    container: p.surfaceSubtle,
    warning: p.danger,
    alert: p.danger,
    confirm: p.accent,
    fontPrimary: p.text,
    fontSecondary: p.textSecondary,
    fontTertiary: p.textSecondary,
    fontFourth: p.textSecondary,
    fontEmphasize: p.accent,
    fontOnPrimary: p.onBrandText,
    fontOnSecondary: p.onBrandText,
    fontOnTertiary: p.onBrandText,
    fontOnFourth: p.onBrandText,
    iconPrimary: p.text,
    iconSecondary: p.textSecondary,
    iconTertiary: p.textSecondary,
    iconFourth: p.textSecondary,
    iconEmphasize: p.accent,
    iconSubEmphasize: p.accent,
    iconOnPrimary: p.onBrandText,
    iconOnSecondary: p.onBrandText,
    iconOnTertiary: p.onBrandText,
    iconOnFourth: p.onBrandText,
    backgroundPrimary: p.background,
    backgroundSecondary: p.surfaceSubtle,
    backgroundTertiary: p.surfaceSubtle,
    backgroundFourth: p.surfaceSubtle,
    backgroundEmphasize: p.primary,
    compForegroundPrimary: p.card,
    compBackgroundPrimary: p.card,
    compBackgroundPrimaryTran: p.card,
    compBackgroundPrimaryContrary: p.text,
    compBackgroundGray: p.surfaceSubtle,
    compBackgroundSecondary: p.surfaceSubtle,
    compBackgroundTertiary: p.surfaceSubtle,
    compBackgroundEmphasize: p.accent,
    compBackgroundNeutral: p.surfaceSubtle,
    compEmphasizeSecondary: p.accent,
    compEmphasizeTertiary: p.accent,
    compDivider: p.divider,
    compCommonContrary: p.card,
    compBackgroundFocus: p.surfaceSubtle,
    compFocusedPrimary: p.accent,
    compFocusedSecondary: p.accent,
    compFocusedTertiary: p.accent,
    interactiveHover: p.surfaceSubtle,
    interactivePressed: p.surfaceSubtle,
    interactiveFocus: p.surfaceSubtle,
    interactiveActive: p.surfaceSubtle,
    interactiveSelect: p.accent,
    interactiveClick: p.surfaceSubtle,
  };
  return colors;
}

/**
 * 由 ThemeManager.applyPalette 调用：浅色板 + 深色板一次性交给系统框架，
 * 深浅切换由系统按当前 colorMode 自行选择对应变体。
 */
export function syncSystemTheme(light: ThemePalette, dark: ThemePalette): void {
  try {
    const theme: CustomTheme = {
      colors: toSystemColors(light),
      darkColors: toSystemColors(dark),
    };
    ThemeControl.setDefaultTheme(theme);
  } catch (_e) {
    // 低版本或异常时静默：系统组件退回系统默认色，不影响自绘界面
  }
}
