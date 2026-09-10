import { I18n } from 'common';
import { NavTitleBridge, NavTitleConfig } from 'common';
import { PullLoadMoreList } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { GSYColor } from 'common';
import { RepositoryItem } from 'common';
import { ReadHistoryItem, READ_HISTORY_TYPE_REPO, READ_HISTORY_TYPE_USER } from 'common';
import { ReadHistoryViewModel } from './viewmodel/ReadHistoryViewModel';

export const READ_HISTORY_TAB_ALL: string = 'all';
export const READ_HISTORY_TAB_REPO: string = 'repo';
export const READ_HISTORY_TAB_USER: string = 'user';

interface ReadHistoryRepoNavParam {
  fullName: string;
  owner: string;
  name: string;
}

interface ReadHistoryUserNavParam {
  login: string;
}

interface ReadHistoryRepoPayloadOwner {
  login?: string;
  avatar_url?: string;
}

interface ReadHistoryRepoPayload {
  full_name?: string;
  name?: string;
  description?: string;
  language?: string;
  stargazers_count?: number;
  watchers_count?: number;
  forks_count?: number;
  owner?: ReadHistoryRepoPayloadOwner | null;
}

@ComponentV2
export struct ReadHistoryPage {
  @Local vm: ReadHistoryViewModel = new ReadHistoryViewModel();
  private pathStack: NavPathStack = new NavPathStack();

  // R9 阶段4：标题栏交给 NavDestination 原生 .title（read_history_appbar id 经 barId 保留）。
  aboutToAppear(): void {
    NavTitleBridge.get().registerTitle(RouteName.ReadHistory, {
      titleGetter: (): string => I18n('history'),
      barId: 'read_history_appbar',
    } as NavTitleConfig);
  }

  private onRowTap(item: ReadHistoryItem): void {
    if (item.type === READ_HISTORY_TYPE_REPO) {
      const idx: number = item.key.indexOf('/');
      const owner: string = idx > 0 ? item.key.substring(0, idx) : '';
      const name: string = idx > 0 ? item.key.substring(idx + 1) : item.key;
      const param: ReadHistoryRepoNavParam = {
        'fullName': item.key,
        'owner': owner,
        'name': name,
      } as ReadHistoryRepoNavParam;
      NavigationService.push(RouteName.RepositoryDetail, param as Object);
    } else if (item.type === READ_HISTORY_TYPE_USER) {
      const param: ReadHistoryUserNavParam = {
        'login': item.key,
      } as ReadHistoryUserNavParam;
      NavigationService.push(RouteName.UserDetail, param as Object);
    }
  }

  private ownerNameOf(item: ReadHistoryItem): string {
    const idx: number = item.key.indexOf('/');
    return idx > 0 ? item.key.substring(0, idx) : '';
  }

  private repoNameOf(item: ReadHistoryItem): string {
    const idx: number = item.key.indexOf('/');
    return idx > 0 ? item.key.substring(idx + 1) : item.key;
  }

  private safeText(value: string | null | undefined): string {
    return value !== null && value !== undefined ? value : '';
  }

  private safeCount(value: number | null | undefined): string {
    return value !== null && value !== undefined ? value.toString() : '0';
  }

  private repoPayloadOf(item: ReadHistoryItem): ReadHistoryRepoPayload | null {
    if (item.payloadJson === null || item.payloadJson === undefined || item.payloadJson.length === 0) {
      return null;
    }
    try {
      return JSON.parse(item.payloadJson) as ReadHistoryRepoPayload;
    } catch (_e) {
      return null;
    }
  }

  private repoFullNameOf(item: ReadHistoryItem): string {
    const payload: ReadHistoryRepoPayload | null = this.repoPayloadOf(item);
    if (payload !== null) {
      const fullName: string = this.safeText((payload as ReadHistoryRepoPayload).full_name);
      if (fullName.length > 0) {
        return fullName;
      }
    }
    return item.key.length > 0 ? item.key : this.repoNameOf(item);
  }

  private repoOwnerNameOf(item: ReadHistoryItem): string {
    const payload: ReadHistoryRepoPayload | null = this.repoPayloadOf(item);
    if (payload !== null) {
      const owner = (payload as ReadHistoryRepoPayload).owner;
      if (owner !== null && owner !== undefined) {
        const login: string = this.safeText((owner as ReadHistoryRepoPayloadOwner).login);
        if (login.length > 0) {
          return login;
        }
      }
    }
    return this.ownerNameOf(item);
  }

  private repoOwnerPicOf(item: ReadHistoryItem): string {
    const payload: ReadHistoryRepoPayload | null = this.repoPayloadOf(item);
    if (payload !== null) {
      const owner = (payload as ReadHistoryRepoPayload).owner;
      if (owner !== null && owner !== undefined) {
        const avatar: string = this.safeText((owner as ReadHistoryRepoPayloadOwner).avatar_url);
        if (avatar.length > 0) {
          return avatar;
        }
      }
    }
    return item.avatar;
  }

  private repoDescriptionOf(item: ReadHistoryItem): string {
    const payload: ReadHistoryRepoPayload | null = this.repoPayloadOf(item);
    if (payload !== null) {
      const des: string = this.safeText((payload as ReadHistoryRepoPayload).description);
      if (des.length > 0) {
        return des;
      }
    }
    return item.subtitle.length > 0 ? item.subtitle : item.key;
  }

  private repoLanguageOf(item: ReadHistoryItem): string {
    const payload: ReadHistoryRepoPayload | null = this.repoPayloadOf(item);
    if (payload !== null) {
      const lang: string = this.safeText((payload as ReadHistoryRepoPayload).language);
      if (lang.length > 0) {
        return lang;
      }
    }
    return '---';
  }

  private repoStarOf(item: ReadHistoryItem): string {
    const payload: ReadHistoryRepoPayload | null = this.repoPayloadOf(item);
    return payload !== null ? this.safeCount((payload as ReadHistoryRepoPayload).stargazers_count) : '0';
  }

  private repoForkOf(item: ReadHistoryItem): string {
    const payload: ReadHistoryRepoPayload | null = this.repoPayloadOf(item);
    return payload !== null ? this.safeCount((payload as ReadHistoryRepoPayload).forks_count) : '0';
  }

  private repoWatchOf(item: ReadHistoryItem): string {
    const payload: ReadHistoryRepoPayload | null = this.repoPayloadOf(item);
    return payload !== null ? this.safeCount((payload as ReadHistoryRepoPayload).watchers_count) : '0';
  }

  @Builder
  rowBuilder(item: ReadHistoryItem, index: number): void {
    RepositoryItem({
      ownerName: this.repoOwnerNameOf(item),
      ownerPic: this.repoOwnerPicOf(item),
      repositoryName: this.repoFullNameOf(item),
      repositoryStar: this.repoStarOf(item),
      repositoryFork: this.repoForkOf(item),
      repositoryWatch: this.repoWatchOf(item),
      repositoryType: this.repoLanguageOf(item),
      repositoryDes: this.repoDescriptionOf(item),
      rowId: 'read_history_row_' + index.toString(),
      onPressItem: (): void => {
        this.onRowTap(item);
      },
    });
  }

  @Builder
  emptyBuilder(): void {
    Column()
    .id('read_history_empty_root')
    .width('100%')
    .height(1);
  }

  build(): void {
    NavDestination() {
      Column() {
        PullLoadMoreList({
          dataSource: this.vm.items,
          refreshing: this.vm.refreshing,
          loadingMore: this.vm.loadingMore,
          noMore: !this.vm.hasMore,
          renderRow: (item: Object, index: number): void =>
            this.rowBuilder(item as ReadHistoryItem, index),
          renderEmpty: (): void => this.emptyBuilder(),
          onRefresh: (): void => {
            this.vm.refresh();
          },
          onLoadMore: (): void => {
            this.vm.loadMore();
          },
        })
          .id('read_history_pull_list')
          .layoutWeight(1);
      }
      .id('read_history_root')
      .width('100%')
      .height('100%')
      .backgroundColor(GSYColor.white);
    }
    .onReady((ctx: NavDestinationContext): void => {
      const stack: NavPathStack | undefined = ctx.pathStack;
      if (stack !== undefined && stack !== null) {
        this.pathStack = stack;
      }
      this.vm.refresh();
    });
  }
}
