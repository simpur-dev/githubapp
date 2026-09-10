/**
 * DynamicTabPage —— 以 Android Compose DynamicScreen/EventItem 为准。
 * View 只做组装（@ComponentV2），列表状态在 [DynamicTabViewModel]。
 */
import { I18n } from 'common';
import { PullLoadMoreList } from 'common';
import { DynamicEvent } from 'common';
import { EventItem } from 'common';
import { EventActionUtil } from 'common';
import { EventActionDispatcher } from 'common';
import { ExternalUrlUtil } from 'common';
import { GSYColor, GSYFontSize } from 'common';
import { DynamicTabViewModel } from '../viewmodel/DynamicTabViewModel';

@ComponentV2
export struct DynamicTabPage {
  @Local vm: DynamicTabViewModel = new DynamicTabViewModel();

  aboutToAppear(): void {
    this.vm.init();
  }

  private dispatchEventTap(event: DynamicEvent): void {
    EventActionDispatcher.dispatch(event, '', (url: string): boolean => {
      return ExternalUrlUtil.openUrlInBrowser(this.getUIContext().getHostContext(), url, 'DynamicTabPage');
    });
  }

  @Builder
  rowBuilder(item: DynamicEvent, index: number): void {
    EventItem({
      actionTime: item.created_at,
      actionUser: item.actor !== null && item.actor !== undefined
        ? (item.actor.display_login !== undefined && item.actor.display_login !== null && item.actor.display_login.length > 0
          ? item.actor.display_login
          : item.actor.login)
        : '',
      actionUserPic: item.actor !== null && item.actor !== undefined ? item.actor.avatar_url : '',
      actionTarget: EventActionUtil.getComposeActionText(item),
      des: '',
      rowId: 'dynamic_row_' + index.toString(),
      onPressItem: (): void => {
        this.dispatchEventTap(item);
      },
      onPressUser: (): void => {
        const login: string = item.actor !== null && item.actor !== undefined ? item.actor.login : '';
        EventActionDispatcher.dispatchUser(login);
      },
    });
  }

  @Builder
  emptyBuilder(): void {
    Column() {
      Text(I18n('listEmpty'))
        .id('dynamic_empty_text')
        .fontSize(GSYFontSize.middleWhite)
        .fontColor(GSYColor.subText);
    }
    .id('dynamic_empty_root')
    .width('100%')
    .height(240)
    .justifyContent(FlexAlign.Center);
  }

  build(): void {
    Column() {
      PullLoadMoreList({
        dataSource: this.vm.items,
        refreshing: this.vm.refreshing,
        loadingMore: this.vm.loadingMore,
        noMore: !this.vm.hasMore,
        renderRow: (item: Object, index: number): void => this.rowBuilder(item as DynamicEvent, index),
        renderEmpty: (): void => this.emptyBuilder(),
        onRefresh: (): void => {
          this.vm.refresh();
        },
        onLoadMore: (): void => {
          this.vm.loadMore();
        },
        refreshingText: I18n('refreshing'),
        loadingMoreText: I18n('loadMoreing'),
        loadEndText: I18n('loadMoreEnd'),
        emptyText: I18n('listEmpty'),
      })
        .id('dynamic_pull_list')
        .layoutWeight(1);
    }
    .id('tab_page_root_dynamic')
    .width('100%')
    .height('100%')
    .backgroundColor(GSYColor.mainBackground);
  }
}
