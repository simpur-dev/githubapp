/**
 * DynamicTabPage —— 以 Android Compose DynamicScreen/EventItem 为准。
 * View 只做组装（@ComponentV2），列表状态在 [DynamicTabViewModel]。
 */
import { I18n } from 'common';
import { GSYSpacing, PullLoadMoreList } from 'common';
import { DynamicEvent } from 'common';
import { EventItem } from 'common';
import { EventActionUtil } from 'common';
import { EventActionDispatcher, EventMenuItem, copyPlainText, CommonToast } from 'common';
import { ExternalUrlUtil } from 'common';
import { GSYFontSize } from 'common';
import { ThemeManager } from 'common';
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
      // R12 KI-R12-006：长按快捷菜单（打开仓库/复制链接/打开用户）
      menuItems: this.buildRowMenu(item),
    });
  }

  /** R12 KI-R12-006：长按菜单项（打开仓库/复制链接/打开用户主页）。 */
  private buildRowMenu(item: DynamicEvent): EventMenuItem[] {
    const items: EventMenuItem[] = [];
    const repoName: string = item.repo !== null && item.repo !== undefined ? item.repo.name : '';
    if (repoName.length > 0) {
      items.push({
        label: I18n('menuViewRepo'),
        onPick: (): void => {
          EventActionDispatcher.dispatch(item, '');
        },
      });
      items.push({
        label: I18n('menuCopyLink'),
        onPick: (): void => {
          copyPlainText('https://github.com/' + repoName);
          CommonToast.showShort(I18n('copyDone'));
        },
      });
    }
    const login: string = item.actor !== null && item.actor !== undefined ? item.actor.login : '';
    if (login.length > 0) {
      items.push({
        label: I18n('menuOpenUser'),
        onPick: (): void => {
          EventActionDispatcher.dispatchUser(login);
        },
      });
    }
    return items;
  }

  @Builder
  emptyBuilder(): void {
    Column() {
      Text(I18n('listEmpty'))
        .id('dynamic_empty_text')
        .fontSize(GSYFontSize.middleWhite)
        .fontColor(ThemeManager.current().textSecondary);
    }
    .id('dynamic_empty_root')
    .width('100%')
    .height(240)
    .justifyContent(FlexAlign.Center);
  }

  build(): void {
    Column() {
      PullLoadMoreList({
      // R12 P2：头像/图片行较重，加大预缓存避免快滑白块
      cachedCountParam: 8,
      // R11 A3：尾部避让浮动页签（barOverlap 悬浮于内容上，末行不再被遮挡/裁切）
      tailPadding: GSYSpacing.tabBarHeight + GSYSpacing.hdsFloatingTabBottomMargin * 2,
        dataSource: this.vm.items,
        refreshing: this.vm.refreshing,
        loadingMore: this.vm.loadingMore,
        noMore: !this.vm.hasMore,
        // R10 阶段3：错误态接入（有数据时不打断列表，空数据时显示统一错误空态）。
        error: this.vm.errorMessage.length > 0,
        errorText: this.vm.errorMessage,
        renderRow: (item: Object, index: number): void => this.rowBuilder(item as DynamicEvent, index),
        renderEmpty: (): void => this.emptyBuilder(),
        onRefresh: (): void => {
          this.vm.refresh();
        },
        onLoadMore: (): void => {
          this.vm.loadMore();
        },
        retryError: (): void => {
          this.vm.refresh();
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
    .backgroundColor(ThemeManager.current().background);
  }
}
