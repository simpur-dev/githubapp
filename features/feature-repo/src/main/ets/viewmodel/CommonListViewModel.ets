/**
 * CommonListViewModel —— 通用列表页（follower / followed / user_repos / user_star /
 * stargazers / watchers / forks / user_orgs / topics / user_be_stared）状态与 dataType 分发
 * （R9 V2 + MVVM）。原页面级 @State 字段与 refreshList/loadMoreList 的分支调度在此平移。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { I18n } from 'common';
import {
  RepositoryService,
  SubListResult,
  SubUserItem,
  SubRepositoryItem
} from 'common';
import {
  UserService,
  FetchSubUserListResult,
  FetchUserReposResult
} from 'common';
import { UserRepoItem } from 'common';
import { SubListMode } from 'common';

export const COMMON_LIST_DATA_TYPE_FOLLOWER: string = 'follower';
export const COMMON_LIST_DATA_TYPE_FOLLOWED: string = 'followed';
export const COMMON_LIST_DATA_TYPE_FOLLOWING: string = 'following';
export const COMMON_LIST_DATA_TYPE_REPOSITORIES: string = 'repositories';
export const COMMON_LIST_DATA_TYPE_STARGAZERS: string = 'stargazers';
export const COMMON_LIST_DATA_TYPE_REPO_STAR: string = 'repo_star';
export const COMMON_LIST_DATA_TYPE_WATCHERS: string = 'watchers';
export const COMMON_LIST_DATA_TYPE_REPO_WATCHER: string = 'repo_watcher';
export const COMMON_LIST_DATA_TYPE_FORKS: string = 'forks';
export const COMMON_LIST_DATA_TYPE_REPO_FORK: string = 'repo_fork';
export const COMMON_LIST_DATA_TYPE_USER_REPOS: string = 'user_repos';
export const COMMON_LIST_DATA_TYPE_USER_STAR: string = 'user_star';
export const COMMON_LIST_DATA_TYPE_USER_BE_STARED: string = 'user_be_stared';
export const COMMON_LIST_DATA_TYPE_USER_ORGS: string = 'user_orgs';
export const COMMON_LIST_DATA_TYPE_TOPICS: string = 'topics';

export const COMMON_LIST_SHOW_TYPE_USER: string = 'user';
export const COMMON_LIST_SHOW_TYPE_REPOSITORY: string = 'repository';

/** UserRepoItem 的 owner 兼容形态（缓存老数据可能缺 owner 对象）。 */
interface UserRepoOwnerLikeOwner {
  login?: string;
  avatar_url?: string;
}

interface UserRepoOwnerLike {
  owner?: UserRepoOwnerLikeOwner;
}

@ObservedV2
export class CommonListViewModel {
  /** 路由参数（View 层解析后经 init 写入）。 */
  @Trace dataType: string = COMMON_LIST_DATA_TYPE_USER_REPOS;
  @Trace showType: string = COMMON_LIST_SHOW_TYPE_REPOSITORY;
  @Trace currentUser: string = '';
  @Trace repoName: string = '';
  @Trace title: string = '';
  /** 列表数据源（showType=user 走 users，repository 走 repos）。 */
  @Trace users: SubUserItem[] = [];
  @Trace repos: SubRepositoryItem[] = [];
  /** 列表加载 / 分页 / 错误态（PullLoadMoreList V2 受控契约）。 */
  @Trace refreshing: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace noMore: boolean = false;
  @Trace errorMessage: string = '';

  private page: number = 1;
  private hasMore: boolean = true;
  private localData: SubRepositoryItem[] = [];
  private userService: UserService = new UserService();
  private repoService: RepositoryService = new RepositoryService();

  /** 设置目标列表（View 层从路由参数 / localData 解析后调用）。 */
  init(dataType: string, showType: string, currentUser: string, repoName: string,
       title: string, localData: SubRepositoryItem[]): void {
    if (dataType.length > 0) {
      this.dataType = dataType;
    }
    if (showType.length > 0) {
      this.showType = showType;
    }
    this.currentUser = currentUser;
    if (repoName.length > 0) {
      this.repoName = repoName;
    }
    if (title.length > 0) {
      this.title = title;
    }
    this.localData = localData.slice();
  }

  // ── 派生值（原页面私有 helper 语义平移）─────────────────────────────────────

  private normalizedDataType(): string {
    if (this.dataType === COMMON_LIST_DATA_TYPE_REPOSITORIES) {
      return COMMON_LIST_DATA_TYPE_USER_REPOS;
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_FOLLOWING) {
      return COMMON_LIST_DATA_TYPE_FOLLOWED;
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_REPO_STAR) {
      return COMMON_LIST_DATA_TYPE_STARGAZERS;
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_REPO_WATCHER) {
      return COMMON_LIST_DATA_TYPE_WATCHERS;
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_REPO_FORK) {
      return COMMON_LIST_DATA_TYPE_FORKS;
    }
    return this.dataType;
  }

  /** 仓库域列表的 fullName：currentUser 可能直接是 owner/name。 */
  repoFullName(): string {
    if (this.currentUser.indexOf('/') > 0 && this.repoName.length === 0) {
      return this.currentUser;
    }
    if (this.currentUser.length === 0 || this.repoName.length === 0) {
      return '';
    }
    return this.currentUser + '/' + this.repoName;
  }

  private titleRepoName(): string {
    if (this.repoName.length > 0) {
      return this.repoName;
    }
    const slash: number = this.currentUser.indexOf('/');
    if (slash >= 0 && slash < this.currentUser.length - 1) {
      return this.currentUser.substring(slash + 1);
    }
    return this.currentUser;
  }

  resolveTitle(): string {
    if (this.dataType === COMMON_LIST_DATA_TYPE_REPOSITORIES) {
      return this.formatListTitle(I18n('listRepositories'), this.currentUser);
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_FOLLOWER) {
      return this.formatListTitle(I18n('listFollowers'), this.currentUser);
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_FOLLOWING
      || this.dataType === COMMON_LIST_DATA_TYPE_FOLLOWED) {
      return this.formatListTitle(I18n('listFollowing'), this.currentUser);
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_USER_REPOS) {
      return this.formatListTitle(I18n('listRepos'), this.currentUser);
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_STARGAZERS
      || this.dataType === COMMON_LIST_DATA_TYPE_REPO_STAR) {
      return this.formatListTitle(I18n('listStargazers'), this.titleRepoName());
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_USER_STAR) {
      return this.formatListTitle(I18n('listStar'), this.currentUser);
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_USER_ORGS) {
      return this.formatListTitle(I18n('listOrgs'), this.currentUser);
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_WATCHERS
      || this.dataType === COMMON_LIST_DATA_TYPE_REPO_WATCHER) {
      return this.formatListTitle(I18n('listWatchers'), this.titleRepoName());
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_FORKS
      || this.dataType === COMMON_LIST_DATA_TYPE_REPO_FORK) {
      return this.formatListTitle(I18n('listForks'), this.titleRepoName());
    }
    if (this.dataType === COMMON_LIST_DATA_TYPE_TOPICS) {
      return this.formatListTitle(I18n('listTopics'), this.currentUser);
    }
    return this.title.length > 0 ? this.title : this.currentUser;
  }

  resolveSubListMode(): SubListMode {
    const type: string = this.normalizedDataType();
    // R11 B2：user_repos（含 repositories 别名）的数据装载固定写 this.repos，
    // 渲染分支必须同为 REPO；否则 showType=user 时会出现"数据到了但列表空"的错位。
    if (type === COMMON_LIST_DATA_TYPE_USER_REPOS) {
      return SubListMode.REPO;
    }
    if (type === COMMON_LIST_DATA_TYPE_STARGAZERS || type === COMMON_LIST_DATA_TYPE_WATCHERS
      || type === COMMON_LIST_DATA_TYPE_USER_ORGS) {
      return SubListMode.USER;
    }
    if (type === COMMON_LIST_DATA_TYPE_FORKS || type === COMMON_LIST_DATA_TYPE_TOPICS) {
      return SubListMode.REPO;
    }
    return this.showType === COMMON_LIST_SHOW_TYPE_USER ? SubListMode.USER : SubListMode.REPO;
  }

  resolveIdPrefix(): string {
    return 'common_list_' + this.dataType;
  }

  private formatListTitle(template: string, value: string): string {
    return template.replace('%s', value);
  }

  // ── 数据编排 ────────────────────────────────────────────────────────────────

  private mapUserRepoToSub(item: UserRepoItem): SubRepositoryItem {
    const raw: UserRepoOwnerLike = item as UserRepoOwnerLike;
    let avatar: string = '';
    let ownerLogin: string = '';
    if (raw.owner !== undefined && raw.owner !== null) {
      const a: string | null | undefined = raw.owner.avatar_url;
      if (a !== undefined && a !== null) {
        avatar = a;
      }
      const l: string | null | undefined = raw.owner.login;
      if (l !== undefined && l !== null) {
        ownerLogin = l;
      }
    }
    if (ownerLogin.length === 0 && item.owner_login !== undefined && item.owner_login !== null) {
      ownerLogin = item.owner_login;
    }
    if (ownerLogin.length === 0 && item.full_name !== undefined && item.full_name !== null) {
      const slash: number = item.full_name.indexOf('/');
      if (slash > 0) {
        ownerLogin = item.full_name.substring(0, slash);
      }
    }
    const safeName: string = item.name !== undefined && item.name !== null ? item.name : '';
    return {
      id: item.id !== undefined && item.id !== null ? item.id : 0,
      name: safeName,
      full_name: item.full_name !== undefined && item.full_name !== null ? item.full_name : '',
      description: item.description !== undefined && item.description !== null ? item.description : '',
      language: item.language !== undefined && item.language !== null ? item.language : '',
      stargazers_count: item.stargazers_count !== undefined && item.stargazers_count !== null ? item.stargazers_count : 0,
      forks_count: item.forks_count !== undefined && item.forks_count !== null ? item.forks_count : 0,
      watchers_count: item.watchers_count !== undefined && item.watchers_count !== null ? item.watchers_count : 0,
      owner_login: ownerLogin,
      owner_avatar_url: avatar,
    } as SubRepositoryItem;
  }

  private mapUserRepoList(list: UserRepoItem[]): SubRepositoryItem[] {
    const out: SubRepositoryItem[] = [];
    for (let i: number = 0; i < list.length; i++) {
      out.push(this.mapUserRepoToSub(list[i]));
    }
    return out;
  }

  async refreshList(): Promise<void> {
    const type: string = this.normalizedDataType();
    hilog.info(0x6666, 'CommonList', 'refresh dataType=%{public}s showType=%{public}s user=%{public}s title=%{public}s local=%{public}d',
      this.dataType, this.showType, this.currentUser, this.title, this.localData.length);
    if (type === COMMON_LIST_DATA_TYPE_USER_BE_STARED) {
      // RN 那边把 100 仓库列表（用于荣耀汇总）通过 localData 透传过来；OH 暂未缓存，
      // localData 为空时 fallback 到 GET /users/:login/repos?sort=pushed&per_page=100，
      // 与 RN [getUserRepository100StatusDao](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/widget/UserHeadItem.js#L240) 同源
      if (this.localData.length > 0) {
        this.repos = this.localData.slice();
        this.page = 1;
        this.hasMore = false;
        this.errorMessage = '';
        this.refreshing = false;
        this.loadingMore = false;
        this.noMore = true;
        return;
      }
      if (this.currentUser.length === 0) {
        this.refreshing = false;
        this.loadingMore = false;
        this.noMore = true;
        return;
      }
      this.refreshing = true;
      this.loadingMore = false;
      this.noMore = false;
      const res: FetchUserReposResult = await this.userService.getUserRepos(this.currentUser, 1);
      hilog.info(0x6666, 'CommonList', 'user_be_stared fallback res ok=%{public}s code=%{public}d size=%{public}d msg=%{public}s',
        String(res.result), res.code, res.data.length, res.msg);
      this.applyUserReposResult(res, true);
      return;
    }
    if (this.currentUser.length === 0) {
      this.refreshing = false;
      this.loadingMore = false;
      this.noMore = true;
      return;
    }
    this.refreshing = true;
    this.loadingMore = false;
    this.noMore = false;

    if (type === COMMON_LIST_DATA_TYPE_FOLLOWER) {
      const res: FetchSubUserListResult = await this.userService.getUserFollowers(this.currentUser, 1);
      hilog.info(0x6666, 'CommonList', 'follower res ok=%{public}s code=%{public}d size=%{public}d msg=%{public}s',
        String(res.result), res.code, res.data.length, res.msg);
      this.applyUserResult(res, true);
    } else if (type === COMMON_LIST_DATA_TYPE_FOLLOWED) {
      const res: FetchSubUserListResult = await this.userService.getUserFollowed(this.currentUser, 1);
      hilog.info(0x6666, 'CommonList', 'followed res ok=%{public}s code=%{public}d size=%{public}d msg=%{public}s',
        String(res.result), res.code, res.data.length, res.msg);
      this.applyUserResult(res, true);
    } else if (type === COMMON_LIST_DATA_TYPE_USER_REPOS) {
      const res: FetchUserReposResult = await this.userService.getUserRepos(this.currentUser, 1);
      hilog.info(0x6666, 'CommonList', 'user_repos res ok=%{public}s code=%{public}d size=%{public}d msg=%{public}s',
        String(res.result), res.code, res.data.length, res.msg);
      this.applyUserReposResult(res, true);
    } else if (type === COMMON_LIST_DATA_TYPE_USER_STAR) {
      const res: SubListResult<SubRepositoryItem> = await this.repoService.getUserStarredRepos(this.currentUser, 1);
      hilog.info(0x6666, 'CommonList', 'user_star res ok=%{public}s code=%{public}d size=%{public}d msg=%{public}s',
        String(res.result), res.code, res.data.length, res.msg);
      this.applySubRepoResult(res, true);
    } else if (type === COMMON_LIST_DATA_TYPE_USER_ORGS) {
      const res: FetchSubUserListResult = await this.userService.getUserOrgs(this.currentUser, 1);
      hilog.info(0x6666, 'CommonList', 'user_orgs res ok=%{public}s code=%{public}d size=%{public}d msg=%{public}s',
        String(res.result), res.code, res.data.length, res.msg);
      this.applyUserResult(res, true);
    } else if (type === COMMON_LIST_DATA_TYPE_STARGAZERS) {
      const res: SubListResult<SubUserItem> = await this.repoService.getStars(this.repoFullName(), 1);
      hilog.info(0x6666, 'CommonList', 'stargazers res ok=%{public}s code=%{public}d size=%{public}d msg=%{public}s',
        String(res.result), res.code, res.data.length, res.msg);
      this.applyUserResult(res, true);
    } else if (type === COMMON_LIST_DATA_TYPE_WATCHERS) {
      const res: SubListResult<SubUserItem> = await this.repoService.getWatchers(this.repoFullName(), 1);
      hilog.info(0x6666, 'CommonList', 'watchers res ok=%{public}s code=%{public}d size=%{public}d msg=%{public}s',
        String(res.result), res.code, res.data.length, res.msg);
      this.applyUserResult(res, true);
    } else if (type === COMMON_LIST_DATA_TYPE_FORKS) {
      const res: SubListResult<SubRepositoryItem> = await this.repoService.getForks(this.repoFullName(), 1);
      hilog.info(0x6666, 'CommonList', 'forks res ok=%{public}s code=%{public}d size=%{public}d msg=%{public}s',
        String(res.result), res.code, res.data.length, res.msg);
      this.applySubRepoResult(res, true);
    } else if (type === COMMON_LIST_DATA_TYPE_TOPICS) {
      const res: SubListResult<SubRepositoryItem> = await this.repoService.searchTopicRepos(this.currentUser, 1);
      hilog.info(0x6666, 'CommonList', 'topics res ok=%{public}s code=%{public}d size=%{public}d msg=%{public}s',
        String(res.result), res.code, res.data.length, res.msg);
      this.applySubRepoResult(res, true);
    } else {
      hilog.warn(0x6666, 'CommonList', 'unknown dataType=%{public}s', this.dataType);
      this.refreshing = false;
      this.loadingMore = false;
      this.noMore = true;
    }
  }

  async loadMoreList(): Promise<void> {
    const type: string = this.normalizedDataType();
    if (!this.hasMore) {
      this.loadingMore = false;
      this.noMore = true;
      return;
    }
    if (type === COMMON_LIST_DATA_TYPE_USER_BE_STARED) {
      this.loadingMore = false;
      this.noMore = true;
      return;
    }
    if (this.currentUser.length === 0) {
      this.loadingMore = false;
      this.noMore = true;
      return;
    }
    const next: number = this.page + 1;

    if (type === COMMON_LIST_DATA_TYPE_FOLLOWER) {
      const res: FetchSubUserListResult = await this.userService.getUserFollowers(this.currentUser, next);
      this.applyUserResult(res, false, next);
    } else if (type === COMMON_LIST_DATA_TYPE_FOLLOWED) {
      const res: FetchSubUserListResult = await this.userService.getUserFollowed(this.currentUser, next);
      this.applyUserResult(res, false, next);
    } else if (type === COMMON_LIST_DATA_TYPE_USER_REPOS) {
      const res: FetchUserReposResult = await this.userService.getUserRepos(this.currentUser, next);
      this.applyUserReposResult(res, false, next);
    } else if (type === COMMON_LIST_DATA_TYPE_USER_STAR) {
      const res: SubListResult<SubRepositoryItem> = await this.repoService.getUserStarredRepos(this.currentUser, next);
      this.applySubRepoResult(res, false, next);
    } else if (type === COMMON_LIST_DATA_TYPE_USER_ORGS) {
      const res: FetchSubUserListResult = await this.userService.getUserOrgs(this.currentUser, next);
      this.applyUserResult(res, false, next);
    } else if (type === COMMON_LIST_DATA_TYPE_STARGAZERS) {
      const res: SubListResult<SubUserItem> = await this.repoService.getStars(this.repoFullName(), next);
      this.applyUserResult(res, false, next);
    } else if (type === COMMON_LIST_DATA_TYPE_WATCHERS) {
      const res: SubListResult<SubUserItem> = await this.repoService.getWatchers(this.repoFullName(), next);
      this.applyUserResult(res, false, next);
    } else if (type === COMMON_LIST_DATA_TYPE_FORKS) {
      const res: SubListResult<SubRepositoryItem> = await this.repoService.getForks(this.repoFullName(), next);
      this.applySubRepoResult(res, false, next);
    } else if (type === COMMON_LIST_DATA_TYPE_TOPICS) {
      const res: SubListResult<SubRepositoryItem> = await this.repoService.searchTopicRepos(this.currentUser, next);
      this.applySubRepoResult(res, false, next);
    } else {
      this.loadingMore = false;
      this.noMore = true;
    }
  }

  private applyUserResult(res: FetchSubUserListResult, isRefresh: boolean, nextPage: number = 1): void {
    if (res.result) {
      if (isRefresh) {
        this.users = res.data.slice();
        this.page = 1;
      } else {
        const merged: SubUserItem[] = this.users.slice();
        for (let i: number = 0; i < res.data.length; i++) {
          merged.push(res.data[i]);
        }
        this.users = merged;
        this.page = nextPage;
      }
      this.hasMore = res.data.length >= this.userService.getPageSize();
      this.errorMessage = '';
    } else {
      this.errorMessage = res.msg;
    }
    this.refreshing = false;
    this.loadingMore = false;
    this.noMore = !(this.hasMore);
  }

  private applySubRepoResult(res: SubListResult<SubRepositoryItem>, isRefresh: boolean, nextPage: number = 1): void {
    if (res.result) {
      if (isRefresh) {
        this.repos = res.data.slice();
        this.page = 1;
      } else {
        const merged: SubRepositoryItem[] = this.repos.slice();
        for (let i: number = 0; i < res.data.length; i++) {
          merged.push(res.data[i]);
        }
        this.repos = merged;
        this.page = nextPage;
      }
      this.hasMore = res.data.length >= this.userService.getPageSize();
      this.errorMessage = '';
    } else {
      this.errorMessage = res.msg;
    }
    this.refreshing = false;
    this.loadingMore = false;
    this.noMore = !(this.hasMore);
  }

  private applyUserReposResult(res: FetchUserReposResult, isRefresh: boolean, nextPage: number = 1): void {
    if (res.result) {
      const mapped: SubRepositoryItem[] = this.mapUserRepoList(res.data);
      if (isRefresh) {
        this.repos = mapped;
        this.page = 1;
      } else {
        const merged: SubRepositoryItem[] = this.repos.slice();
        for (let i: number = 0; i < mapped.length; i++) {
          merged.push(mapped[i]);
        }
        this.repos = merged;
        this.page = nextPage;
      }
      this.hasMore = res.data.length >= this.userService.getPageSize();
      this.errorMessage = '';
    } else {
      this.errorMessage = res.msg;
    }
    this.refreshing = false;
    this.loadingMore = false;
    this.noMore = !(this.hasMore);
  }
}
