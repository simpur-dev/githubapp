
import { GSYColor } from 'common';
import { AppBar } from 'common';
import {
  RepositoryService,
  SubRepositoryItem,
  SubListResult,
  RepoOwnerName
} from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { SubListView, SubListMode } from 'common';

interface RepositoryForkRouteParam {
  fullName: string;
}

interface RepositoryDetailRouteParam {
  owner: string;
  name: string;
  fullName: string;
}

const FALLBACK_FULL_NAME: string = '';

/**
 * RepositoryForkPage（V2 薄壳）：forks 子列表；本批不抽 VM，
 * 列表状态以 @Local 受控字段直驱 SubListView（V2 契约）。
 */
@ComponentV2
export struct RepositoryForkPage {
  @Local fullName: string = FALLBACK_FULL_NAME;
  @Local items: SubRepositoryItem[] = [];
  @Local plmRefreshing: boolean = false;
  @Local plmLoadingMore: boolean = false;
  @Local plmNoMore: boolean = false;
  private page: number = 1;
  private hasMore: boolean = true;
  private service: RepositoryService = new RepositoryService();
  private pageSize: number = 30;

  aboutToAppear(): void {
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
    const obj: RepositoryForkRouteParam = param as RepositoryForkRouteParam;
    return obj.fullName !== undefined && obj.fullName !== null ? obj.fullName : FALLBACK_FULL_NAME;
  }

  private async refreshList(): Promise<void> {
    if (this.fullName.length === 0) {
      return;
    }
    this.plmRefreshing = true;
    this.plmLoadingMore = false;
    this.plmNoMore = false;
    const res: SubListResult<SubRepositoryItem> = await this.service.getForks(this.fullName, 1);
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
    const res: SubListResult<SubRepositoryItem> = await this.service.getForks(this.fullName, next);
    if (res.result) {
      const merged: SubRepositoryItem[] = this.items.slice();
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

  private openRepository(item: SubRepositoryItem): void {
    const owner: RepoOwnerName = RepoOwnerName.parse(item.full_name);
    const param: RepositoryDetailRouteParam = {
      'owner': owner.owner.length > 0 ? owner.owner : item.owner_login,
      'name': owner.name.length > 0 ? owner.name : item.name,
      'fullName': item.full_name,
    } as RepositoryDetailRouteParam;
    NavigationService.push(RouteName.RepositoryDetail, param as Object);
  }

  build(): void {
    NavDestination() {
      Column() {
        AppBar({
          title: 'Forks',
          showBack: true,
          onBack: (): void => {
            NavigationService.pop();
          },
        });
        SubListView({
          title: 'Forks',
          mode: SubListMode.REPO,
          users: [],
          repos: this.items,
          refreshing: this.plmRefreshing,
          loadingMore: this.plmLoadingMore,
          noMore: this.plmNoMore,
          idPrefix: 'repo_fork',
          refresh: (): void => {
            this.refreshList();
          },
          loadMore: (): void => {
            this.loadMoreList();
          },
          onRepoClick: (item: SubRepositoryItem): void => {
            this.openRepository(item);
          },
        })
          .id('repo_fork_sub_list')
          .layoutWeight(1);
      }
      .id('repo_fork_root')
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
      const resolved: string = this.resolveFullNameFromCtx(ctx);
      if (resolved.length > 0) {
        this.fullName = resolved;
      }
      this.refreshList();
    });
  }
}
