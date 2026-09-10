
import { SubUserItem } from 'common';
import { GSYColor } from 'common';
import { NavTitleBridge, NavTitleConfig } from 'common';
import {
  UserService,
  FetchSubUserListResult
} from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { SubListView, SubListMode } from 'common';

interface UserFollowedRouteParam {
  login: string;
}

interface UserDetailRouteParam {
  login: string;
}

const FALLBACK_LOGIN: string = '';

/**
 * Following 列表薄壳页（R9 V2）：@ComponentV2 + @Local 受控状态，
 * 列表渲染/分页交互全部在 common 的 SubListView（V2 受控组件）。
 */
@ComponentV2
export struct UserFollowedPage {
  @Local login: string = FALLBACK_LOGIN;
  @Local items: SubUserItem[] = [];
  @Local page: number = 1;
  @Local hasMore: boolean = true;
  @Local error: string = '';
  @Local refreshing: boolean = false;
  @Local loadingMore: boolean = false;
  private service: UserService = new UserService();
  private pageSize: number = 30;

  aboutToAppear(): void {
    // R9 阶段4：标题栏交给 NavDestination 原生 .title（配置经 NavTitleBridge 上报）。
    NavTitleBridge.get().registerTitle(RouteName.UserFollowed, {
      titleGetter: (): string => 'Following',
    } as NavTitleConfig);
    this.pageSize = this.service.getPageSize();
  }

  private resolveLoginFromCtx(ctx: NavDestinationContext): string {
    const info: NavPathInfo | undefined = ctx.pathInfo;
    if (info === undefined || info === null) {
      return FALLBACK_LOGIN;
    }
    const param: Object | undefined = info.param as Object | undefined;
    if (param === undefined || param === null) {
      return FALLBACK_LOGIN;
    }
    const obj: UserFollowedRouteParam = param as UserFollowedRouteParam;
    return obj.login !== undefined && obj.login !== null ? obj.login : FALLBACK_LOGIN;
  }

  private async refreshList(): Promise<void> {
    if (this.login.length === 0) {
      return;
    }
    this.refreshing = true;
    this.loadingMore = false;
    this.hasMore = true;
    const res: FetchSubUserListResult = await this.service.getUserFollowed(this.login, 1);
    if (res.result) {
      this.items = res.data.slice();
      this.page = 1;
      this.hasMore = res.data.length >= this.pageSize;
      this.error = '';
    } else {
      this.error = res.msg;
    }
    this.refreshing = false;
    this.loadingMore = false;
  }

  private async loadMoreList(): Promise<void> {
    if (!this.hasMore || this.loadingMore) {
      return;
    }
    this.loadingMore = true;
    const next: number = this.page + 1;
    const res: FetchSubUserListResult = await this.service.getUserFollowed(this.login, next);
    if (res.result) {
      const merged: SubUserItem[] = this.items.slice();
      for (let i: number = 0; i < res.data.length; i++) {
        merged.push(res.data[i]);
      }
      this.items = merged;
      this.page = next;
      this.hasMore = res.data.length >= this.pageSize;
    }
    this.loadingMore = false;
  }

  private openUser(item: SubUserItem): void {
    const param: UserDetailRouteParam = { 'login': item.login } as UserDetailRouteParam;
    NavigationService.push(RouteName.UserDetail, param as Object);
  }

  build(): void {
    NavDestination() {
      Column() {
        SubListView({
          title: 'Following',
          mode: SubListMode.USER,
          users: this.items,
          repos: [],
          refreshing: this.refreshing,
          loadingMore: this.loadingMore,
          noMore: !this.hasMore,
          idPrefix: 'user_followed',
          refresh: (): void => {
            this.refreshList();
          },
          loadMore: (): void => {
            this.loadMoreList();
          },
          onUserClick: (item: SubUserItem): void => {
            this.openUser(item);
          },
        })
          .id('user_followed_sub_list')
          .layoutWeight(1);
      }
      .id('user_followed_root')
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
      const resolved: string = this.resolveLoginFromCtx(ctx);
      if (resolved.length > 0) {
        this.login = resolved;
      }
      this.refreshList();
    });
  }
}
