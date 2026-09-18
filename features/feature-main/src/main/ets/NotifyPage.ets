import { I18n } from 'common';
import { NavTitleAction, NavTitleBridge, NavTitleConfig, RouteName } from 'common';
import { NotifyViewModel } from './viewmodel/NotifyViewModel';
import { NotifyContent } from './views/NotifyContent';

/**
 * 通知页（push 路由，R12 P1 起内容抽至 NotifyContent 与通知 Tab 共用）。
 * 深链 bootNotifyIssue / 既有通知测试仍走本页；Tab 入口见 NotificationsTabPage。
 */
@ComponentV2
export struct NotifyPage {
  @Local vm: NotifyViewModel = new NotifyViewModel();
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    // R9 阶段4：标题栏交给 NavDestination 原生 .title/.menus（notify_app_bar id 经 barId 保留）。
    NavTitleBridge.get().registerTitle(RouteName.Notify, {
      titleGetter: (): string => I18n('notify'),
      barId: 'notify_app_bar',
      rightActions: [
        {
          iconKey: 'done_all',
          onAction: (): void => {
            this.vm.markAllRead();
          },
        } as NavTitleAction,
      ],
    } as NavTitleConfig);
    this.vm.init();
  }

  build(): void {
    NavDestination() {
      NotifyContent({ vm: this.vm });
    }
    .onReady((ctx: NavDestinationContext): void => {
      const stack: NavPathStack | undefined = ctx.pathStack;
      if (stack !== undefined && stack !== null) {
        this.pathStack = stack;
      }
    });
  }
}
