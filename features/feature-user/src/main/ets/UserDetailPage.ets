import { I18n } from 'common';
import pasteboard from '@ohos.pasteboard';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { PullLoadMoreList } from 'common';
import { GSYColor, GSYFontSize, GSYIconSize, GSYSpacing, GSYShadow } from 'common';
import { NavTitleAction, NavTitleBridge, NavTitleConfig } from 'common';
import { CommonModal, CommonOptionItem } from 'common';
import { CommonToast } from 'common';
import { Logger } from 'common';
import { UserRepoItem } from 'common';
import { SubUserItem } from 'common';
import { DynamicEvent } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { RouteParamStore } from 'common';
import { BOOT_USER_KEY, BootChannel } from 'common';
import { IconTextItem } from 'common';
import { EventItem } from 'common';
import { IconFont, FA_CHECK, FA_GROUP, FA_MAP_MARKER, FA_USER_PLUS } from 'common';
import { EventActionUtil } from 'common';
import { EventActionDispatcher } from 'common';
import { UserDetailViewModel } from './viewmodel/UserDetailViewModel';

interface UserDetailRouteParam {
  login: string;
}

interface RepositoryDetailRouteParam {
  owner: string;
  name: string;
  fullName: string;
}

interface UserCountJumpParam {
  dataType: string;
  showType: string;
  currentUser: string;
  title: string;
}

const FALLBACK_LOGIN: string = '';
const COMMON_LIST_DATA_TYPE_REPOSITORIES: string = 'repositories';
const COMMON_LIST_DATA_TYPE_FOLLOWER: string = 'follower';
const COMMON_LIST_DATA_TYPE_FOLLOWING: string = 'following';
const COMMON_LIST_DATA_TYPE_USER_STAR: string = 'user_star';
const COMMON_LIST_SHOW_TYPE_USER: string = 'user';
const COMMON_LIST_SHOW_TYPE_REPOSITORY: string = 'repository';

@ComponentV2
export struct UserDetailPage {
  @Local vm: UserDetailViewModel = new UserDetailViewModel();
  private pathStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    // R9 阶段4：标题栏交给 NavDestination 原生 .title/.menus（headerTitle 是 @Trace 组合，getter 闭包随对象携带）。
    NavTitleBridge.get().registerTitle(RouteName.UserDetail, {
      titleGetter: (): string => this.vm.headerTitle(),
      rightActions: this.buildRightActions(),
    } as NavTitleConfig);
    this.tryAdoptRouteParam();
    if (this.vm.login.length === 0) {
      this.tryAdoptBootUser();
    }
  }

  /**
   * 优先从 RouteParamStore 拿（NavigationService.push 时同步写入），
   * 覆盖所有走 NavigationService.push(UserDetail, param) 的入口（CommonList / SearchPage / DrawerHeader / etc）。
   */
  private tryAdoptRouteParam(): void {
    const raw: Object | null = RouteParamStore.consume(RouteName.UserDetail);
    if (raw === null) {
      return;
    }
    const obj: UserDetailRouteParam = raw as UserDetailRouteParam;
    const login: string = obj.login !== undefined && obj.login !== null ? obj.login : '';
    if (login.length > 0) {
      this.vm.setLogin(login);
      Logger.i('user/route', `UserDetailPage.tryAdoptRouteParam adopted login=${login} t=${Date.now()}`);
    }
  }

  /**
   * KI-042 同款：直读 BOOT_USER_KEY 兜底解析 login，立即清空，避免 NavPathStack push 时序竞争。
   * 与 [CodeDetailPage.tryAdoptBootCode] / [PushDetailPage.tryAdoptBootPush] 同款做法。
   */
  private tryAdoptBootUser(): void {
    const value: string = BootChannel.get(BOOT_USER_KEY);
    const raw: string = (value || '').trim();
    if (raw.length === 0) {
      return;
    }
    this.vm.setLogin(raw);
    BootChannel.set(BOOT_USER_KEY, '');
    Logger.i('user/boot', `UserDetailPage.tryAdoptBootUser adopted login=${raw} t=${Date.now()}`);
  }

  private resolveLoginFromParam(rawParam: Object | null | undefined): string {
    if (rawParam === undefined || rawParam === null) {
      return FALLBACK_LOGIN;
    }
    const obj: UserDetailRouteParam = rawParam as UserDetailRouteParam;
    return obj.login !== undefined && obj.login !== null ? obj.login : FALLBACK_LOGIN;
  }

  private resolveLoginFromStack(stack: NavPathStack): string {
    // 关键：NavDestinationContext.pathStack 在 onReady 早期阶段，
    // getAllPathName / getParamByIndex 可能尚未挂载（"undefined is not callable"），
    // 必须 try/catch 包裹，与 RepositoryDetailPage.resolveFullNameFromStack 保持一致。
    try {
      const all: string[] = stack.getAllPathName();
      if (all === undefined || all === null || all.length === 0) {
        return FALLBACK_LOGIN;
      }
      const param: Object | undefined = stack.getParamByIndex(all.length - 1) as Object | undefined;
      return this.resolveLoginFromParam(param === undefined ? null : param);
    } catch (_e) {
      return FALLBACK_LOGIN;
    }
  }

  private openRepository(item: UserRepoItem): void {
    const ownerLogin: string = item.owner_login;
    const param: RepositoryDetailRouteParam = {
      'owner': ownerLogin.length > 0 ? ownerLogin : this.vm.login,
      'name': item.name,
      'fullName': item.full_name,
    } as RepositoryDetailRouteParam;
    NavigationService.push(RouteName.RepositoryDetail, param as Object);
  }

  @Builder
  buildHeader(): void {
    Column() {
      // ── Row 1：头像 + 名字/login + group/location 三行 ─────────────────────
      Row() {
        Image(this.vm.user.avatar_url)
          .id('user_detail_avatar')
          .width(GSYIconSize.large)
          .height(GSYIconSize.large)
          .borderRadius(GSYIconSize.large / 2)
          .objectFit(ImageFit.Cover)
          .margin({ top: GSYSpacing.halfEdge });

        Column() {
          Text(this.vm.displayName())
            .id('user_detail_name')
            .fontSize(GSYFontSize.large)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.white);

          Text(this.vm.user.login)
            .id('user_detail_login')
            .fontSize(GSYFontSize.small)
            .fontColor(GSYColor.subLightText)
            .margin({ top: GSYSpacing.halfEdge });

          if (this.vm.user.company.length > 0) {
            IconTextItem({
              text: this.vm.user.company,
              iconChar: FA_GROUP,
              iconColor: GSYColor.miWhite,
              textColor: GSYColor.miWhite,
              textFontSize: GSYFontSize.small,
              rowId: 'user_detail_company',
              rowMarginTop: GSYSpacing.halfEdge,
            });
          }

          if (this.vm.user.location.length > 0) {
            IconTextItem({
              text: this.vm.user.location,
              iconChar: FA_MAP_MARKER,
              iconColor: GSYColor.miWhite,
              textColor: GSYColor.miWhite,
              textFontSize: GSYFontSize.small,
              rowId: 'user_detail_location',
              rowMarginTop: GSYSpacing.halfEdge,
            });
          }
        }
        .id('user_detail_head_meta_col')
        .margin({ left: GSYSpacing.normalEdge })
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .id('user_detail_head_row')
      .width('100%')
      .alignItems(VerticalAlign.Top);

      if (this.vm.user.bio.length > 0) {
        Text(this.vm.user.bio)
          .id('user_detail_bio')
          .fontSize(GSYFontSize.small)
          .fontColor(GSYColor.subLightText)
          .margin({ top: GSYSpacing.normalEdge });
      }

      if (this.vm.joinedText().length > 0) {
        Text(this.vm.joinedText())
          .id('user_detail_joined')
          .fontSize(GSYFontSize.small)
          .fontColor(GSYColor.subLightText)
          .margin({ top: GSYSpacing.halfEdge, bottom: GSYSpacing.normalEdge });
      }

      // ── 计数行：直接读 ViewModel @Trace 计数字段 inline 求值 ───────────────
      // 旧 UserCountsRow（@ObjectLink store + @Builder 值参）已删除，
      // 消除 KI-043/044/048 一类的 @Builder 值参不刷新坑；测试 id 全部原样保留。
      Row() {
        Column() {
          Text(this.fmtCount(this.vm.reposCount))
            .id('user_detail_repos_count')
            .fontSize(GSYFontSize.middleWhite)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.white);
          Text(I18n('repositoryText'))
            .id('user_detail_repos_label')
            .fontSize(GSYFontSize.min)
            .fontColor(GSYColor.miWhite)
            .margin({ top: GSYSpacing.halfEdge / 2 });
        }
        .id('user_detail_repos_block')
        .layoutWeight(1)
        .padding({ top: GSYSpacing.halfEdge, bottom: GSYSpacing.halfEdge })
        .alignItems(HorizontalAlign.Center)
        .onClick((): void => {
          Logger.i('user/count/click', 'idPrefix=user_detail_repos dataType=' + COMMON_LIST_DATA_TYPE_REPOSITORIES + ' login=' + this.vm.login);
          if (this.vm.login.length === 0) {
            return;
          }
          this.openCommonList(COMMON_LIST_DATA_TYPE_REPOSITORIES, COMMON_LIST_SHOW_TYPE_REPOSITORY, I18n('repositoryText'));
        });

        Column() {
          Text(this.fmtCount(this.vm.followersCount))
            .id('user_detail_followers_count')
            .fontSize(GSYFontSize.middleWhite)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.white);
          Text(I18n('FollowersText'))
            .id('user_detail_followers_label')
            .fontSize(GSYFontSize.min)
            .fontColor(GSYColor.miWhite)
            .margin({ top: GSYSpacing.halfEdge / 2 });
        }
        .id('user_detail_followers_block')
        .layoutWeight(1)
        .padding({ top: GSYSpacing.halfEdge, bottom: GSYSpacing.halfEdge })
        .alignItems(HorizontalAlign.Center)
        .border({ width: { left: 1 }, color: { left: GSYColor.primaryLight } })
        .onClick((): void => {
          Logger.i('user/count/click', 'idPrefix=user_detail_followers dataType=' + COMMON_LIST_DATA_TYPE_FOLLOWER + ' login=' + this.vm.login);
          if (this.vm.login.length === 0) {
            return;
          }
          this.openCommonList(COMMON_LIST_DATA_TYPE_FOLLOWER, COMMON_LIST_SHOW_TYPE_USER, I18n('FollowersText'));
        });

        Column() {
          Text(this.fmtCount(this.vm.followingCount))
            .id('user_detail_following_count')
            .fontSize(GSYFontSize.middleWhite)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.white);
          Text(I18n('FollowedText'))
            .id('user_detail_following_label')
            .fontSize(GSYFontSize.min)
            .fontColor(GSYColor.miWhite)
            .margin({ top: GSYSpacing.halfEdge / 2 });
        }
        .id('user_detail_following_block')
        .layoutWeight(1)
        .padding({ top: GSYSpacing.halfEdge, bottom: GSYSpacing.halfEdge })
        .alignItems(HorizontalAlign.Center)
        .border({ width: { left: 1 }, color: { left: GSYColor.primaryLight } })
        .onClick((): void => {
          Logger.i('user/count/click', 'idPrefix=user_detail_following dataType=' + COMMON_LIST_DATA_TYPE_FOLLOWING + ' login=' + this.vm.login);
          if (this.vm.login.length === 0) {
            return;
          }
          this.openCommonList(COMMON_LIST_DATA_TYPE_FOLLOWING, COMMON_LIST_SHOW_TYPE_USER, I18n('FollowedText'));
        });

        Column() {
          Text(this.fmtCount(this.vm.starredCount))
            .id('user_detail_stared_count')
            .fontSize(GSYFontSize.middleWhite)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.white);
          Text(I18n('staredText'))
            .id('user_detail_stared_label')
            .fontSize(GSYFontSize.min)
            .fontColor(GSYColor.miWhite)
            .margin({ top: GSYSpacing.halfEdge / 2 });
        }
        .id('user_detail_stared_block')
        .layoutWeight(1)
        .padding({ top: GSYSpacing.halfEdge, bottom: GSYSpacing.halfEdge })
        .alignItems(HorizontalAlign.Center)
        .border({ width: { left: 1 }, color: { left: GSYColor.primaryLight } })
        .onClick((): void => {
          Logger.i('user/count/click', 'idPrefix=user_detail_stared dataType=' + COMMON_LIST_DATA_TYPE_USER_STAR + ' login=' + this.vm.login);
          if (this.vm.login.length === 0) {
            return;
          }
          this.openCommonList(COMMON_LIST_DATA_TYPE_USER_STAR, COMMON_LIST_SHOW_TYPE_REPOSITORY, I18n('staredText'));
        });
      }
      .id('user_detail_counts_row')
      .width('100%')
      .border({
        width: { top: 1 },
        color: { top: GSYColor.primaryLight },
      });

      Row() {
        Text(I18n('personDynamic'))
          .id('user_detail_dynamic_title')
          .fontSize(GSYFontSize.small)
          .fontWeight(FontWeight.Medium)
          .fontColor(GSYColor.miWhite);
      }
      .id('user_detail_dynamic_title_bar')
      .width('100%')
      .padding({ top: GSYSpacing.halfEdge, bottom: GSYSpacing.halfEdge });
    }
    .width('100%')
    .padding({
      left: GSYSpacing.normalEdge,
      right: GSYSpacing.normalEdge,
      top: 2 * GSYSpacing.normalEdge,
    })
    .alignItems(HorizontalAlign.Start)
    .id('user_detail_header_stack')
    .backgroundColor(GSYColor.primary)
    .borderRadius({ bottomLeft: GSYShadow.radius, bottomRight: GSYShadow.radius })
    .shadow({
      radius: GSYShadow.radius,
      color: GSYShadow.cardShadowAlpha,
      offsetX: 1,
      offsetY: 2,
    });
  }

  @Builder
  buildFollowFab(): void {
    Row() {
      IconFont({
        char: this.vm.followed ? FA_CHECK : FA_USER_PLUS,
        glyphSize: GSYFontSize.middleWhite,
        glyphColor: GSYColor.miWhite,
      })
        .id(this.vm.followed ? 'user_detail_follow_fab_icon_following' : 'user_detail_follow_fab_icon_add');
    }
    .id('user_detail_follow_fab')
    .width(GSYSpacing.tabBarHeight)
    .height(GSYSpacing.tabBarHeight)
    .borderRadius(GSYSpacing.tabBarHeight / 2)
    .backgroundColor(GSYColor.primary)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .margin({
      right: GSYSpacing.normalEdge,
      bottom: GSYSpacing.normalEdge,
    })
    .onClick((): void => {
      this.vm.toggleFollow();
    });
  }

  private fmtCount(n: number): string {
    return n >= 0 ? n.toString() : '---';
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
      rowId: 'user_detail_event_row_' + index.toString(),
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
  orgMemberRowBuilder(item: SubUserItem, index: number): void {
    Row() {
      Image(item.avatar_url)
        .id('user_detail_org_member_avatar_' + index.toString())
        .width(GSYIconSize.normal)
        .height(GSYIconSize.normal)
        .borderRadius(GSYIconSize.normal / 2)
        .objectFit(ImageFit.Cover);
      Text(item.login)
        .id('user_detail_org_member_login_' + index.toString())
        .fontSize(GSYFontSize.middleNormal)
        .fontColor(GSYColor.primary)
        .margin({ left: GSYSpacing.normalEdge })
        .layoutWeight(1);
    }
    .id('user_detail_org_member_row_' + index.toString())
    .width('100%')
    .padding({
      left: GSYSpacing.normalEdge + GSYSpacing.halfEdge,
      right: GSYSpacing.normalEdge + GSYSpacing.halfEdge,
      top: GSYSpacing.normalEdge,
      bottom: GSYSpacing.normalEdge,
    })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      const param: UserDetailRouteParam = { login: item.login };
      NavigationService.push(RouteName.UserDetail, param as Object);
    });
  }

  /**
   * 事件点击：统一走 EventActionDispatcher，覆盖 RN ActionUtils 全 5 分支。
   */
  private dispatchEventTap(item: DynamicEvent): void {
    EventActionDispatcher.dispatch(item, '', (url: string): boolean => {
      return this.openUrlInBrowser(url);
    });
  }

  @Builder
  emptyBuilder(): void {
    Column() {
      Text(I18n('listEmpty'))
        .id('user_detail_empty_text')
        .fontSize(GSYFontSize.middleWhite)
        .fontColor(GSYColor.subText);
    }
    .id('user_detail_empty_root')
    .width('100%')
    .padding({ top: GSYSpacing.normalEdge * GSYSpacing.normalNumberOfLine })
    .justifyContent(FlexAlign.Center);
  }

  private openCommonList(dataType: string, showType: string, title: string): void {
    const login: string = this.vm.currentLogin();
    if (login.length === 0) {
      return;
    }
    const param: UserCountJumpParam = {
      dataType: dataType,
      showType: showType,
      currentUser: login,
      title: title,
    };
    Logger.i('user/count/click', 'CommonList dataType=' + dataType + ' showType=' + showType + ' login=' + login);
    NavigationService.push(RouteName.CommonList, param as Object);
  }

  private copyToPasteboard(text: string): void {
    if (text.length === 0) {
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const board: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      board.setData(data);
      CommonToast.showShort(I18n('hadCopy'));
    } catch (_e) {
      CommonToast.showShort(I18n('hadCopy'));
    }
  }

  private showMoreMenu(): void {
    const htmlUrl: string = this.vm.htmlUrl();
    Logger.i('UserDetailPage', 'headerRight more tapped, login=' + this.vm.login + ' url=' + htmlUrl);
    const items: CommonOptionItem[] = [
      { itemName: I18n('browserOpen') } as CommonOptionItem,
      { itemName: I18n('copy') } as CommonOptionItem,
      { itemName: I18n('share') } as CommonOptionItem,
    ];
    CommonModal.options(
      { title: this.vm.login, items: items },
      (index: number, _item: CommonOptionItem): void => {
        if (htmlUrl.length === 0) {
          Logger.w('UserDetailPage', 'more menu skipped, html_url empty');
          return;
        }
        if (index === 0) {
          Logger.i('UserDetailPage', 'more menu browserOpen url=' + htmlUrl);
          this.openUrlInBrowser(htmlUrl);
        } else if (index === 1) {
          this.copyToPasteboard(htmlUrl);
        } else if (index === 2) {
          Logger.i('UserDetailPage', 'more menu share url=' + htmlUrl);
          this.openUrlInBrowser(htmlUrl);
        }
      }
    );
  }

  private openUrlInBrowser(url: string): boolean {
    if (url.length === 0) {
      return false;
    }
    try {
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: url,
      };
      ctx.startAbility(want)
        .then((): void => {
          Logger.i('UserDetailPage', 'startAbility viewData ok url=' + url);
        })
        .catch((err: Error): void => {
          Logger.w('UserDetailPage', 'startAbility viewData fail msg=' + err.message);
          CommonToast.showShort(I18n('browserOpen'));
        });
      return true;
    } catch (e) {
      const err = e as Error;
      Logger.w('UserDetailPage', 'startAbility viewData throw msg=' + err.message);
      CommonToast.showShort(I18n('browserOpen'));
      return false;
    }
  }

  private buildRightActions(): NavTitleAction[] {
    const list: NavTitleAction[] = [];
    list.push({
      iconKey: 'more',
      onAction: (): void => {
        this.showMoreMenu();
      },
    } as NavTitleAction);
    return list;
  }

  build(): void {
    NavDestination() {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          PullLoadMoreList({
            dataSource: this.vm.isOrganizationProfile()
              ? this.vm.orgMembers as Object[]
              : this.vm.events as Object[],
            refreshing: this.vm.refreshing,
            loadingMore: this.vm.loadingMore,
            noMore: !this.vm.hasMore,
            renderRow: (item: Object, index: number): void => {
              if (this.vm.isOrganizationProfile()) {
                this.orgMemberRowBuilder(item as SubUserItem, index);
              } else {
                this.rowBuilder(item as DynamicEvent, index);
              }
            },
            renderHeader: (): void => this.buildHeader(),
            renderEmpty: (): void => this.emptyBuilder(),
            onRefresh: (): void => {
              this.vm.refresh();
            },
            onLoadMore: (): void => {
              this.vm.loadMore();
            },
          })
            .id('user_detail_pull_list')
            .layoutWeight(1);
        }
        .width('100%')
        .height('100%');

        if (this.vm.shouldShowFollow()) {
          this.buildFollowFab();
        }
      }
      .id('user_detail_root')
      .width('100%')
      .height('100%')
      .backgroundColor(GSYColor.white);
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      NavigationService.pop();
      return true;
    })
    .onReady((ctx: NavDestinationContext): void => {
      const stack: NavPathStack | undefined = ctx.pathStack;
      if (stack !== undefined && stack !== null) {
        this.pathStack = stack;
      }
      // 优先从 ctx.pathInfo 拿参数（最稳，不依赖 stack 接口可用性）
      let resolved: string = FALLBACK_LOGIN;
      try {
        const info: NavPathInfo | undefined = ctx.pathInfo;
        if (info !== undefined && info !== null) {
          resolved = this.resolveLoginFromParam(info.param as Object | null | undefined);
        }
      } catch (_e) {
        resolved = FALLBACK_LOGIN;
      }
      // 兜底：再尝试通过 stack
      if (resolved.length === 0 && stack !== undefined && stack !== null) {
        resolved = this.resolveLoginFromStack(stack);
      }
      // 终兜底：BOOT_USER_KEY 旁路（KI-045 同款，dispatcher 在 push 前注入 BootChannel）
      if (resolved.length === 0) {
        const boot: string = BootChannel.get(BOOT_USER_KEY);
        const bootLogin: string = (boot || '').trim();
        if (bootLogin.length > 0) {
          resolved = bootLogin;
        }
      }
      if (resolved.length > 0 && resolved !== this.vm.login) {
        this.vm.setLogin(resolved);
        this.vm.refresh();
      } else if (this.vm.login.length > 0) {
        this.vm.refresh();
      }
    });
  }
}
