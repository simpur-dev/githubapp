import { I18n } from 'common';
import { GSYFontSize } from 'common';
import { ThemeManager } from 'common';
import { NotifyViewModel } from '../viewmodel/NotifyViewModel';
import { NotifyContent } from '../views/NotifyContent';

/**
 * NotificationsTabPage —— 首页五 Tab 之"通知"（R12 P1 新增，对齐官方 App 通知一级入口）。
 * 与推送页 NotifyPage 共用 NotifyContent 组件与 NotifyViewModel 逻辑；
 * Tab 形态补一个轻量头部（标题 + 全部已读按钮，对应官方 App Inbox 头部操作）。
 */
@ComponentV2
export struct NotificationsTabPage {
  @Local vm: NotifyViewModel = new NotifyViewModel();

  aboutToAppear(): void {
    this.vm.init();
  }

  build(): void {
    Column() {
      Row() {
        Text(I18n('tabNotifications'))
          .id('notifications_tab_title')
          .fontSize(GSYFontSize.normal)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeManager.current().text)
          .layoutWeight(1);

        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(22)
          .fontColor([ThemeManager.current().accent])
          .onClick((): void => {
            this.vm.markAllRead();
          });
      }
      .id('notifications_tab_header')
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .backgroundColor(ThemeManager.current().tabBackground)
      .alignItems(VerticalAlign.Center);

      NotifyContent({ vm: this.vm })
    }
    .id('notifications_tab_root')
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeManager.current().background);
  }
}
