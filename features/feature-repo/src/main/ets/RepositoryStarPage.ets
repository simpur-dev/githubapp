
import { ThemeManager } from 'common';
import { NavTitleBridge, NavTitleConfig } from 'common';
import {
  RepositoryService,
  SubUserItem,
  SubListResult
} from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { SubListView, SubListMode } from 'common';

interface RepositoryStarRouteParam {
  fullName: string;
}

interface UserDetailRouteParam {
  login: string;
}

const FALLBACK_FULL_NAME: string = '';

/**
 * RepositoryStarPage（V2 薄壳）：stargazers 子列表；本批不抽 VM，
 * 列表状态以 @Local 受控字段直驱 SubListView（V2 契约）。
 */
@ComponentV2
export struct RepositoryStarPage {
  @Local fullName: string = FALLBACK_FULL_NAME;
  @Local items: SubUserItem[] = [];
  @Local plmRefreshing: boolean = false;
  @Local plmLoadingMore: boolean = false;
  @Local plmNoMore: boolean = false;
  private page: number = 1;
  private hasMore: boolean = true;
  private service: RepositoryService = new RepositoryService();
  private pageSize: number = 30;

  aboutToAppear(): void {
    // R9 阶段4：标题栏交给 NavDestination 原生 .title（配置经 NavTitleBridge 上报）。
    NavTitleBridge.get().registerTitle(RouteName.RepositoryStar, {
      titleGetter: (): string => 'Stargazers',
    } as NavTitleConfig);
    this.pageSize = this.service.getPageSize();
  }

  private resolveFullNameFromCtx(ctx: NavDestinationContext): string {
    const info: NavPathInfo | undefined = ctx.pathInfo;
    if (info === undefined || info === null) {
      return FALLBACK_FULL_NAME;
    }
    const param: Object | undefined = info.param as Object | undefined;
    if (param === undefined || param === null) {
      return FALLBACK_FULL_NAME;
    }
    const obj: RepositoryStarRouteParam = param as RepositoryStarRouteParam;
    return obj.fullName !== undefined && obj.fullName !== null ? obj.fullName : FALLBACK_FULL_NAME;
  }

  private async refreshList(): Promise<void> {
    if (this.fullName.length === 0) {
      return;
    }
    this.plmRefreshing = true;
    this.plmLoadingMore = false;
    this.plmNoMore = false;
    const res: SubListResult<SubUserItem> = await this.service.getStars(this.fullName, 1);
    if (res.result) {
      this.items = res.data.slice();
      this.page = 1;
      this.hasMore = res.data.length >= this.pageSize;
    }
    this.plmRefreshing = false;
    this.plmLoadingMore = false;
    this.plmNoMore = !(this.hasMore);
  }

  private async loadMoreList(): Promise<void> {
    if (!this.hasMore) {
      this.plmLoadingMore = false;
      this.plmNoMore = true;
      return;
    }
    const next: number = this.page + 1;
    const res: SubListResult<SubUserItem> = await this.service.getStars(this.fullName, next);
    if (res.result) {
      const merged: SubUserItem[] = this.items.slice();
      for (let i: number = 0; i < res.data.length; i++) {
        merged.push(res.data[i]);
      }
      this.items = merged;
      this.page = next;
      this.hasMore = res.data.length >= this.pageSize;
    }
    this.plmLoadingMore = false;
    this.plmNoMore = !(this.hasMore);
  }

  private openUser(item: SubUserItem): void {
    const param: UserDetailRouteParam = { 'login': item.login } as UserDetailRouteParam;
    NavigationService.push(RouteName.UserDetail, param as Object);
  }

  build(): void {
    NavDestination() {
      Column() {
        SubListView({
          title: 'Stargazers',
          mode: SubListMode.USER,
          users: this.items,
          repos: [],
          refreshing: this.plmRefreshing,
          loadingMore: this.plmLoadingMore,
          noMore: this.plmNoMore,
          idPrefix: 'repo_star',
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
          .id('repo_star_sub_list')
          .layoutWeight(1);
      }
      .id('repo_star_root')
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeManager.current().background);
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      NavigationService.pop();
      return true;
    })
    .onReady((ctx: NavDestinationContext): void => {
      const resolved: string = this.resolveFullNameFromCtx(ctx);
      if (resolved.length > 0) {
        this.fullName = resolved;
      }
      this.refreshList();
    });
  }
}
