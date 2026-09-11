import { I18n } from 'common';
import { TimeUtil } from 'common';
import { PullLoadMoreList } from 'common';
import { NavTitleAction, NavTitleBridge, NavTitleConfig, RouteName } from 'common';
import { GSYFontSize, GSYShadow, GSYSpacing } from 'common';
import { ThemeManager } from 'common';
import { NotifyThread } from 'common';
import { NotifyViewModel, NotifyTabItem } from './viewmodel/NotifyViewModel';

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

  private buildStatusText(item: NotifyThread): string {
    const status: string = item.unread ? I18n('notifyStatusUnread') : I18n('notifyStatusRead');
    return I18n('notifyType') + ': ' + item.subject.type + ', '
      + I18n('notifyStatus') + ': ' + status;
  }

  @Builder
  buildTabBar(): void {
    Row() {
      Repeat<NotifyTabItem>(this.vm.tabs)
        .each((obj: RepeatItem<NotifyTabItem>): void => {
          Button(obj.item.label)
            .id('notify_tab_' + obj.index.toString())
            .type(ButtonType.Normal)
            .height(56)
            .layoutWeight(1)
            .backgroundColor(this.vm.currentTabIndex === obj.index
              ? ThemeManager.current().navBackground : ThemeManager.current().card)
            .fontColor(this.vm.currentTabIndex === obj.index
              ? ThemeManager.current().onBrandText : ThemeManager.current().textSecondary)
            .fontSize(GSYFontSize.normal)
            .borderRadius(obj.index === 0 || obj.index === this.vm.tabs.length - 1 ? 8 : 0)
            .border({ width: 1, color: ThemeManager.current().navBackground })
            .onClick((): void => {
              this.vm.onTabChanged(obj.index);
            });
        })
        .key((tab: NotifyTabItem): string => 'notify_tab_key_' + tab.filter)
    }
    .id('notify_tab_bar')
    .width('100%')
    .height(72)
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(ThemeManager.current().tabBackground);
  }

  @Builder
  rowBuilder(item: NotifyThread, index: number): void {
    Row() {
      Column() {
        Row() {
          Text(item.repository.full_name)
            .id('notify_row_repo_' + index.toString())
            .fontSize(GSYFontSize.small)
            .fontColor(ThemeManager.current().text)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          Text(TimeUtil.resolveTime(item.updated_at))
            .id('notify_row_time_' + index.toString())
            .fontSize(GSYFontSize.small)
            .fontColor(ThemeManager.current().textSecondary)
            .margin({ left: GSYSpacing.halfEdge });
        }
        .id('notify_row_meta_' + index.toString())
        .width('100%')
        .alignItems(VerticalAlign.Center);

        Text(item.subject.title)
          .id('notify_row_title_' + index.toString())
          .fontSize(GSYFontSize.middleWhite)
          .fontColor(ThemeManager.current().text)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: GSYSpacing.halfEdge });

        Text(this.buildStatusText(item))
          .id('notify_row_status_' + index.toString())
          .fontSize(GSYFontSize.small)
          .fontColor(ThemeManager.current().textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: GSYSpacing.halfEdge });
      }
      .id('notify_row_card_' + index.toString())
      .width('100%')
      .padding({ left: 10, right: 10, top: 10, bottom: 10 })
      .borderRadius(8)
      .border({ width: 1, color: ThemeManager.current().divider })
      .backgroundColor(ThemeManager.current().card)
      .shadow({
        radius: GSYShadow.radius,
        color: GSYShadow.cardShadowAlpha,
        offsetX: 1,
        offsetY: 1,
      })
      .alignItems(HorizontalAlign.Start);
    }
    .id('notify_row_' + index.toString())
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .onClick((): void => {
      this.vm.onThreadClick(item);
    });
  }

  @Builder
  emptyBuilder(): void {
    Column() {
      Text(I18n('notifyEmpty'))
        .id('notify_empty_text')
        .fontSize(GSYFontSize.middleNormal)
        .fontColor(ThemeManager.current().textSecondary);
    }
    .id('notify_empty_root')
    .width('100%')
    .height(240)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  buildInitialLoading(): void {
    Column() {
      LoadingProgress()
        .id('notify_initial_loading_indicator')
        .width(36)
        .height(36)
        .color(ThemeManager.current().text);
    }
    .id('notify_initial_loading')
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  buildInitialError(): void {
    Column() {
      Text(this.vm.error.length > 0 ? this.vm.error : I18n('unknown'))
        .id('notify_initial_error_text')
        .fontSize(GSYFontSize.middleWhite)
        .fontColor(ThemeManager.current().textSecondary)
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 });
    }
    .id('notify_initial_error')
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  buildNotifyContent(): void {
    this.buildTabBar();

    PullLoadMoreList({
      dataSource: this.vm.items,
      refreshing: this.vm.refreshing,
      loadingMore: this.vm.loadingMore,
      noMore: !this.vm.hasMore,
      renderRow: (item: Object, index: number): void => this.rowBuilder(item as NotifyThread, index),
      renderEmpty: (): void => this.emptyBuilder(),
      onRefresh: (): void => {
        this.vm.refresh();
      },
      onLoadMore: (): void => {
        this.vm.loadMore();
      },
    })
      .id('notify_pull_list')
      .layoutWeight(1);
  }

  build(): void {
    NavDestination() {
      Column() {
        if (this.vm.initialPageLoading && this.vm.items.length === 0) {
          this.buildInitialLoading();
        } else if (this.vm.error.length > 0 && this.vm.items.length === 0) {
          this.buildInitialError();
        } else {
          this.buildNotifyContent();
        }
      }
      .id('notify_root')
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeManager.current().background);
    }
    .onReady((ctx: NavDestinationContext): void => {
      const stack: NavPathStack | undefined = ctx.pathStack;
      if (stack !== undefined && stack !== null) {
        this.pathStack = stack;
      }
    });
  }
}
