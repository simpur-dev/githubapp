/**
 * AppSymbol —— 标题栏动作 iconKey → 系统符号（SymbolGlyph）的统一白名单映射。
 *
 * 背景（R10 阶段5）：AppBar.buildAction 与 NavTitleBridge.NavMenusView.actionIcon
 * 原各维护一份 iconKey → sys.symbol 资源 + 字号的 if/else 映射，重复且易漂移；
 * 收敛到本模块单一映射源：
 *  - appSymbolSpecFor(iconKey)：白名单查找（资源 + 字号 token），供组件内
 *    SymbolGlyph 内联渲染使用（渲染逻辑保持不变，含各自的颜色/命中区差异）；
 *  - symbolModifierFor(iconKey, accessibilityText?)：同一白名单的
 *    SymbolGlyphModifier 形态（API 12+，attributeModifier / 菜单符号等
 *    modifier 消费方使用），fontSize 随白名单带入，可选无障碍文本。
 *
 * 未知 iconKey（如 reload）两套查找都返回 undefined：调用方按各自原语义处理
 * （AppBar 回落 Image 图标 / NavMenusView 不渲染图标仅保留命中区）。
 */
import { SymbolGlyphModifier } from '@ohos.arkui.modifier';
import { GSYIconSize } from '../style/Theme';

/** 单个 iconKey 的符号渲染规格（资源 + 字号 token）。 */
export interface AppSymbolSpec {
  resource: Resource;
  fontSize: number;
}

const APP_SYMBOL_WHITELIST: Map<string, AppSymbolSpec> = new Map<string, AppSymbolSpec>();
APP_SYMBOL_WHITELIST.set('search', {
  resource: $r('sys.symbol.magnifyingglass'),
  fontSize: GSYIconSize.appBarAction,
});
APP_SYMBOL_WHITELIST.set('menu', {
  resource: $r('sys.symbol.line_3_horizontal'),
  fontSize: GSYIconSize.appBarAction,
});
APP_SYMBOL_WHITELIST.set('done_all', {
  resource: $r('sys.symbol.checkmark'),
  fontSize: GSYIconSize.cardIcon,
});
APP_SYMBOL_WHITELIST.set('filter', {
  resource: $r('sys.symbol.funnel'),
  fontSize: GSYIconSize.tab,
});
APP_SYMBOL_WHITELIST.set('more', {
  resource: $r('sys.symbol.more'),
  fontSize: GSYIconSize.appBarAction,
});

/** 白名单查找：未知 iconKey 返回 undefined（调用方按原语义回落）。 */
export function appSymbolSpecFor(iconKey: string): AppSymbolSpec | undefined {
  return APP_SYMBOL_WHITELIST.get(iconKey);
}

/**
 * 白名单查找的 SymbolGlyphModifier 形态（API 12+）。
 * accessibilityText 可选：非空时经 CommonMethod.accessibilityText 挂无障碍文案。
 */
export function symbolModifierFor(iconKey: string, accessibilityText?: string): SymbolGlyphModifier | undefined {
  const spec: AppSymbolSpec | undefined = appSymbolSpecFor(iconKey);
  if (spec === undefined) {
    return undefined;
  }
  const modifier: SymbolGlyphModifier = new SymbolGlyphModifier(spec.resource);
  modifier.fontSize(spec.fontSize);
  if (accessibilityText !== undefined && accessibilityText.length > 0) {
    modifier.accessibilityText(accessibilityText);
  }
  return modifier;
}
