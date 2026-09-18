/**
 * MyTabPage —— 以 Android Compose ProfileScreen/ProfileHeader 为准。
 *
 * Compose ProfileHeader 头像不可点击；通知铃铛进入 Notification。
 * Compose ProfileScreen 在 ProfileContent 下方保留 Logout 按钮；OH My 页同样保留
 * 该登出入口。调试探针（refresh-count/logout-click/entry-click）已移除。
 * View 只做组装（@ComponentV2），状态在 [MyTabViewModel]（viewmodel/MyTabViewModel.ets）。
 */

import { I18n, GSYColor } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { DynamicEvent } from 'common';
import { PullLoadMoreList } from 'common';
import { EventItem } from 'common';
import { EventActionUtil } from 'common';
import { EventActionDispatcher, EventMenuItem, copyPlainText, CommonToast } from 'common';
import { ExternalUrlUtil } from 'common';
import { GSYFontSize, GSYSpacing } from 'common';
import { ThemeManager } from 'common';
import { UserHeadItem } from '../views/UserHeadItem';
import { MyTabViewModel, MyTabPageDeps } from '../viewmodel/MyTabViewModel';

@ComponentV2
export struct MyTabPage {
  @Local vm: MyTabViewModel = new MyTabViewModel();

  aboutToAppear(): void {
    this.vm.init();
  }

  private dispatchEventTap(event: DynamicEvent): void {
    EventActionDispatcher.dispatch(event, '', (url: string): boolean => {
      return ExternalUrlUtil.openUrlInBrowser(this.getUIContext().getHostContext(), url, 'MyTabPage');
    });
  }

  private handleNotifyTap(): void {
    NavigationService.push(RouteName.Notify);
  }

  private async handleLogoutTap(): Promise<void> {
    try {
      await MyTabPageDeps.getLoginUseCase().logout();
    } catch (_e) {
    }
    NavigationService.replace(RouteName.Login);
  }

  private resolveLoginForNav(): string {
    return this.vm.resolveLogin();
  }

  private handleCounterTap(key: string): void {
    const login: string = this.resolveLoginForNav();
    if (login.length === 0) {
      return;
    }
    // RN [UserHeadItem.js#L156-L254](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/widget/UserHeadItem.js#L156-L254)
    // 5 个 NameValueItem 全部走 Actions.ListPage(dataType, showType, currentUser, title, [localData])
    let dataType: string = '';
    let showType: string = '';
    let title: string = login;
    if (key === 'repos') {
      dataType = 'user_repos';
      showType = 'repository';
      title = login + ' - ' + I18n('repositoryText');
    } else if (key === 'follower') {
      dataType = 'follower';
      showType = 'user';
      title = login + ' - ' + I18n('FollowersText');
    } else if (key === 'followed') {
      dataType = 'followed';
      showType = 'user';
      title = login + ' - ' + I18n('FollowedText');
    } else if (key === 'star') {
      dataType = 'user_star';
      showType = 'repository';
      title = login + ' - ' + I18n('staredText');
    } else {
      return;
    }
    const param: Record<string, Object> = {
      'dataType': dataType,
      'showType': showType,
      'currentUser': login,
      'title': title,
    };
    NavigationService.push(RouteName.CommonList, param);
  }

  @Builder
  buildHeader(): void {
    UserHeadItem({
      userDisplayName: this.vm.headerDisplayName,
      userName: this.vm.headerLogin,
      userPic: this.vm.headerAvatar,
      groupName: this.vm.headerCompany,
      location: this.vm.headerLocation,
      link: this.vm.headerBlog,
      des: this.vm.headerDes,
      joinedText: this.vm.headerJoinedText,
      star: this.vm.starCount,
      follower: this.vm.followerCount,
      followed: this.vm.followedCount,
      repos: this.vm.reposCount,
      beStared: this.vm.beStaredCount,
      setting: true,
      settingNeed: false,
      unRead: this.vm.unRead,
      isOrganizations: this.vm.headerType === 'Organization',
      needFollow: false,
      hadFollowed: false,
      userType: this.vm.headerType,
      orgsList: this.vm.orgsList,
      onNotifyTap: (): void => {
        this.handleNotifyTap();
      },
      onAvatarTap: (): void => {
        NavigationService.push(RouteName.Setting);
      },
      onFollowTap: (): void => {},
      onCounterTap: (key: string): void => {
        this.handleCounterTap(key);
      },
    });
  }

  @Builder
  rowBuilder(item: DynamicEvent, index: number): void {
    EventItem({
      actionTime: item.created_at,
      actionUser: item.actor !== null && item.actor !== undefined
        ? (item.actor.display_login !== undefined && item.actor.display_login !== null
            && item.actor.display_login.length > 0
          ? item.actor.display_login
          : item.actor.login)
        : '',
      actionUserPic: item.actor !== null && item.actor !== undefined
        ? item.actor.avatar_url : '',
      actionTarget: EventActionUtil.getComposeActionText(item),
      des: '',
      rowId: 'my_event_row_' + index.toString(),
      onPressItem: (): void => {
        this.dispatchEventTap(item);
      },
      onPressUser: (): void => {
        const login: string = item.actor !== null && item.actor !== undefined ? item.actor.login : '';
        EventActionDispatcher.dispatchUser(login);
      },
      // R12 KI-R12-006：长按快捷菜单
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
        .id('my_empty_text')
        .fontSize(GSYFontSize.middleWhite)
        .fontColor(ThemeManager.current().textSecondary);
    }
    .id('my_empty_root')
    .width('100%')
    .height(240)
    .justifyContent(FlexAlign.Center);
  }

  build(): void {
    Column() {
      if (this.vm.errorMessage.length > 0) {
        Text(this.vm.errorMessage)
          .id('my_error_text')
          .width('100%')
          .fontSize(GSYFontSize.small)
          .fontColor(GSYColor.actionBlue)
          .padding({
            left: GSYSpacing.normalEdge,
            right: GSYSpacing.normalEdge,
            top: GSYSpacing.halfEdge,
            bottom: GSYSpacing.halfEdge,
          });
      }
      PullLoadMoreList({
      // R12 P2：头像/图片行较重，加大预缓存避免快滑白块
      cachedCountParam: 8,
      // R11 A3：尾部避让浮动页签（barOverlap 悬浮于内容上，末行不再被遮挡/裁切）
      tailPadding: GSYSpacing.tabBarHeight + GSYSpacing.hdsFloatingTabBottomMargin * 2,
        dataSource: this.vm.events,
        refreshing: this.vm.refreshing,
        loadingMore: this.vm.loadingMore,
        noMore: !this.vm.hasMore,
        renderHeader: (): void => this.buildHeader(),
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
        .id('my_pull_list')
        .layoutWeight(1);
    }
    .id('tab_page_root_my')
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeManager.current().background);
  }
}
