import { NavTitleBridge, NavTitleConfig, RouteName } from 'common';
import { I18n } from 'common';
import { GSYColor, GSYFontSize } from 'common';
import { ThemeManager } from 'common';

export class CustomScriptItem {
  name: string;
  hint: string;

  constructor(name: string, hint: string) {
    this.name = name;
    this.hint = hint;
  }
}

export function buildCustomPlaceholderList(): CustomScriptItem[] {
  return [
    new CustomScriptItem(I18n('customScriptItem1'), I18n('customScriptHint1')),
    new CustomScriptItem(I18n('customScriptItem2'), I18n('customScriptHint2')),
    new CustomScriptItem(I18n('customScriptItem3'), I18n('customScriptHint3')),
  ];
}

/**
 * CustomPage —— 自定义脚本页 View 层（R9 V2 + MVVM）。
 * 纯静态占位列表展示，无异步编排/业务状态，不强抽 ViewModel，仅做 @ComponentV2 化；
 * 列表 ForEach → Repeat（短列表，不用 virtualScroll），测试 id（custom_*）一字不动。
 */
@ComponentV2
export struct CustomPage {
  @Local items: CustomScriptItem[] = buildCustomPlaceholderList();

  @Builder
  buildItem(item: CustomScriptItem, index: number): void {
    Column() {
      Text(item.name)
        .id('custom_item_name_' + index.toString())
        .fontSize(GSYFontSize.middleNormal)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeManager.current().text);
      Text(item.hint)
        .id('custom_item_hint_' + index.toString())
        .fontSize(GSYFontSize.min)
        .fontColor(ThemeManager.current().textSecondary)
        .margin({ top: 4 });
    }
    .id('custom_item_' + index.toString())
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 12, bottom: 12, left: 16, right: 16 })
    .backgroundColor(ThemeManager.current().card)
    .border({ width: { bottom: 0.5 }, color: ThemeManager.current().divider });
  }

  // R9 阶段4：标题栏交给 NavDestination 原生 .title（配置经 NavTitleBridge 上报）。
  aboutToAppear(): void {
    NavTitleBridge.get().registerTitle(RouteName.Custom, {
      titleGetter: (): string => I18n('custom'),
    } as NavTitleConfig);
  }

  build(): void {
    Column() {
      Column() {
        Text(I18n('customHeaderTitle'))
          .id('custom_header_title')
          .fontSize(GSYFontSize.middleWhite)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeManager.current().text);
        Text(I18n('feedback'))
          .id('custom_header_subtitle')
          .fontSize(GSYFontSize.min)
          .fontColor(ThemeManager.current().textSecondary)
          .margin({ top: 4 });
      }
      .id('custom_header')
      .width('100%')
      .padding({ top: 24, bottom: 16, left: 16, right: 16 })
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(ThemeManager.current().card);

      List() {
        Repeat(this.items)
          .each((obj: RepeatItem<CustomScriptItem>) => {
            ListItem() {
              this.buildItem(obj.item, obj.index);
            }
            .id('custom_list_item_' + obj.index.toString());
          })
          .key((item: CustomScriptItem): string => item.name)
      }
      .id('custom_list')
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0, color: GSYColor.transparent });

      Button(I18n('customComingSoon'))
        .id('custom_placeholder_btn')
        .type(ButtonType.Capsule)
        .width('80%')
        .height(44)
        .fontSize(GSYFontSize.small)
        .fontColor(GSYColor.white)
        .backgroundColor(GSYColor.subText)
        .margin({ top: 12, bottom: 12 })
        .onClick((): void => {
        });
    }
    .id('custom_root')
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeManager.current().background);
  }
}
