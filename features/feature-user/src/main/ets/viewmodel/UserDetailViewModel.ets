/**
 * UserDetailViewModel —— 用户详情页状态与编排（R9 V2 + MVVM）。
 *
 * @Trace UI 状态：用户资料 / 计数 5 项 / 组织成员列表 / 事件列表 / follow 状态 /
 * 加载与分页（refreshing / loadingMore / hasMore）/ 错误文案。
 * 原 V1 页面级 UserDetailStore + DynamicStore 已删除：
 *   - UserService 已无状态化（不写 store），取数结果在这里写入 @Trace 字段；
 *   - DynamicService 本就无状态，旧页面丢弃 fetchUserEvents 返回值导致
 *     事件列表分页信息（page/hasMore）从未更新 —— 这里按 FetchReceivedResult
 *     语义正确消费（等价旧 applyDynamicResult 的设计意图）。
 * 计数行直接读 5 个 @Trace 计数字段 inline 求值，消除旧 UserCountsRow
 * @ObjectLink store 的 @Builder 值参刷新坑（KI-043/044/048 一类）。
 */
import {
  UserService,
  FetchUserResult,
  FetchFollowResult,
  FetchStarredCountResult,
  FetchSubUserListResult
} from 'common';
import { DynamicService, FetchReceivedResult } from 'common';
import {
  UserDetail,
  emptyUserDetail,
  sanitizeUserDetail
} from 'common';
import { SubUserItem } from 'common';
import { DynamicEvent } from 'common';
import { I18n } from 'common';
import { ReadHistoryService, ReadHistoryAddParam } from 'common';
import { READ_HISTORY_TYPE_USER } from 'common';
import { TimeUtil } from 'common';

/** 安全字符串：把 null/undefined 兜底成 ''（GitHub API 对可选字段常返回 null）。 */
function safeStr(v: string | null | undefined): string {
  return (v === null || v === undefined) ? '' : v;
}

@ObservedV2
export class UserDetailViewModel {
  /** 当前用户 login（AppBar 标题与各处跳转依赖，UI 状态）。 */
  @Trace login: string = '';
  /** 用户资料（始终经 sanitizeUserDetail 归一化，字符串字段不会是 null）。 */
  @Trace user: UserDetail = emptyUserDetail();
  /** 计数 5 项：仓库 / 关注者 / 关注中 / star 数 / 被 star 数。 */
  @Trace reposCount: number = 0;
  @Trace followersCount: number = 0;
  @Trace followingCount: number = 0;
  @Trace starredCount: number = 0;
  @Trace beStaredCount: number = 0;
  /** 组织成员列表（组织账号时作为列表数据源）。 */
  @Trace orgMembers: SubUserItem[] = [];
  /** 用户动态事件列表（个人账号时作为列表数据源）。 */
  @Trace events: DynamicEvent[] = [];
  /** follow 状态（FAB 图标与行为）。 */
  @Trace followed: boolean = false;
  /** 加载 / 分页 / 错误态。 */
  @Trace refreshing: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = true;
  @Trace errorMessage: string = '';

  private orgMemberPage: number = 1;
  private orgMemberHasMore: boolean = true;
  private eventPage: number = 1;
  private eventHasMore: boolean = true;
  private service: UserService = new UserService();
  private dynamicService: DynamicService = new DynamicService();
  private readHistoryService: ReadHistoryService = new ReadHistoryService();

  /** 设置目标用户（View 层从路由参数 / BOOT 通道解析后调用）。 */
  setLogin(login: string): void {
    this.login = login;
  }

  /** 首屏加载（等价旧 loadAll，含缓存渐进渲染与读历史写入）。 */
  async refresh(): Promise<void> {
    if (this.login.length === 0) {
      return;
    }
    this.refreshing = true;
    this.loadingMore = false;
    this.hasMore = true;
    this.errorMessage = '';
    const userRes: FetchUserResult = await this.service.getUser(this.login,
      (cached: UserDetail): void => {
        // 网络返回前先渲染缓存（原 service 直写 store 的渐进渲染语义）。
        this.applyUser(cached);
      });
    if (userRes.result) {
      this.applyUser(userRes.data);
    } else {
      this.errorMessage = userRes.msg;
    }
    if (userRes.result && userRes.fromCache && this.user.starred.length === 0) {
      // Old local user rows may not include the Compose `starred` field yet.
      // Refresh it when we are showing a cache fallback.
      const starredRes: FetchStarredCountResult = await this.service.getUserStarredCount(this.login);
      if (starredRes.result) {
        this.applyStarredCount(starredRes.count);
      }
    }
    const followRes: FetchFollowResult = await this.service.getFollowStatus(this.login);
    if (followRes.result) {
      this.followed = followRes.followed;
    }
    if (userRes.result && this.isOrganizationProfile()) {
      const orgRes: FetchSubUserListResult = await this.service.getOrgMembers(this.login, 1,
        (items: SubUserItem[]): void => {
          this.orgMembers = items.slice();
          this.orgMemberPage = 1;
          this.orgMemberHasMore = items.length >= this.service.getPageSize();
        });
      if (orgRes.result) {
        this.orgMembers = orgRes.data.slice();
        this.orgMemberPage = 1;
        this.orgMemberHasMore = orgRes.data.length >= this.service.getPageSize();
      } else {
        this.orgMembers = [];
        this.orgMemberHasMore = false;
      }
      this.events = [];
      this.hasMore = this.orgMemberHasMore;
    } else {
      this.orgMembers = [];
      const res: FetchReceivedResult = await this.dynamicService.fetchUserEvents(this.login, 1);
      this.applyDynamicResult(res, false);
      this.hasMore = this.eventHasMore;
    }
    await this.writeReadHistory();
    this.refreshing = false;
  }

  /** 加载下一页（组织成员或事件，取决于账号类型）。 */
  async loadMore(): Promise<void> {
    if (this.loadingMore || !this.hasMore || this.login.length === 0) {
      return;
    }
    this.loadingMore = true;
    if (this.isOrganizationProfile()) {
      if (!this.orgMemberHasMore) {
        this.hasMore = false;
        this.loadingMore = false;
        return;
      }
      const next: number = this.orgMemberPage + 1;
      const res: FetchSubUserListResult = await this.service.getOrgMembers(this.login, next);
      if (res.result) {
        const merged: SubUserItem[] = this.orgMembers.slice();
        for (let i: number = 0; i < res.data.length; i++) {
          merged.push(res.data[i]);
        }
        this.orgMembers = merged;
        this.orgMemberPage = next;
        this.orgMemberHasMore = res.data.length >= this.service.getPageSize();
      } else {
        this.orgMemberHasMore = false;
      }
      this.hasMore = this.orgMemberHasMore;
    } else {
      if (!this.eventHasMore) {
        this.hasMore = false;
        this.loadingMore = false;
        return;
      }
      const next: number = this.eventPage + 1;
      const res: FetchReceivedResult = await this.dynamicService.fetchUserEvents(this.login, next);
      this.applyDynamicResult(res, true);
      this.hasMore = this.eventHasMore;
    }
    this.loadingMore = false;
  }

  /** follow / unfollow 切换，成功后回读用户资料刷新计数。 */
  async toggleFollow(): Promise<void> {
    if (this.login.length === 0) {
      return;
    }
    let res: FetchFollowResult;
    if (this.followed) {
      res = await this.service.unfollow(this.login);
    } else {
      res = await this.service.follow(this.login);
    }
    if (res.result) {
      this.followed = res.followed;
      const userRes: FetchUserResult = await this.service.getUser(this.login);
      if (userRes.result) {
        this.applyUser(userRes.data);
      }
    }
  }

  /** 组织账号：列表数据源走组织成员，头部不显示 follow FAB。 */
  isOrganizationProfile(): boolean {
    return safeStr(this.user.type) === 'Organization';
  }

  /** 是否显示 follow FAB（原 shouldShowFollow 语义）。 */
  shouldShowFollow(): boolean {
    if (this.login.length === 0) {
      return false;
    }
    return !this.isOrganizationProfile();
  }

  /** AppBar 标题：优先路由 login，兜底资料 login。 */
  headerTitle(): string {
    const login: string = this.login.length > 0 ? this.login : safeStr(this.user.login);
    return login.length > 0 ? login : '';
  }

  /** 计数跳转用的 login（空资料时可能为 ''）。 */
  currentLogin(): string {
    return this.login.length > 0 ? this.login : safeStr(this.user.login);
  }

  /** 头部展示名：name 优先，兜底 login。 */
  displayName(): string {
    const name: string = safeStr(this.user.name);
    return name.length > 0 ? name : safeStr(this.user.login);
  }

  /** "加入于 xxx" 文案，无 created_at 时返回 ''（头部整行隐藏）。 */
  joinedText(): string {
    const created: string = safeStr(this.user.created_at);
    if (created.length === 0) {
      return '';
    }
    return I18n('userCreate') + TimeUtil.resolveTime(created);
  }

  /** 头部 more 菜单的 html_url（原 resolveHtmlUrl 语义）。 */
  htmlUrl(): string {
    const login: string = this.currentLogin();
    if (login.length === 0) {
      return '';
    }
    return 'https://github.com/' + login;
  }

  private applyUser(user: UserDetail): void {
    this.user = sanitizeUserDetail(user);
    const n: number = Number.parseInt(this.user.starred, 10);
    this.starredCount = Number.isNaN(n) ? 0 : n;
    this.reposCount = this.user.public_repos;
    this.followersCount = this.user.followers;
    this.followingCount = this.user.following;
    this.errorMessage = '';
  }

  private applyStarredCount(count: number): void {
    this.starredCount = count > 0 ? count : 0;
    const next: UserDetail = sanitizeUserDetail(this.user);
    next.starred = this.starredCount.toString();
    this.user = next;
  }

  /**
   * DynamicService 无状态取数结果 → @Trace 事件列表
   * （等价旧页面 applyDynamicResult；失败时携带首页缓存则兜底展示）。
   */
  private applyDynamicResult(res: FetchReceivedResult, append: boolean): void {
    if (res.result) {
      if (append) {
        const merged: DynamicEvent[] = this.events.slice();
        for (let i: number = 0; i < res.data.length; i++) {
          merged.push(res.data[i]);
        }
        this.events = merged;
      } else {
        this.events = res.data.slice();
      }
      this.eventPage = res.page;
      this.eventHasMore = res.hasMore;
    } else if (this.events.length === 0 && res.data.length > 0) {
      this.events = res.data.slice();
      this.eventPage = res.page;
      this.eventHasMore = res.hasMore;
    }
  }

  private async writeReadHistory(): Promise<void> {
    if (this.login.length === 0) {
      return;
    }
    // applyUser 已 sanitize，这里直接取字段写浏览历史。
    const user: UserDetail = this.user;
    const safeName: string = safeStr(user.name);
    const safeBio: string = safeStr(user.bio);
    const title: string = safeName.length > 0 ? safeName : this.login;
    const subtitle: string = safeBio.length > 0 ? safeBio : this.login;
    const avatar: string = safeStr(user.avatar_url);
    const payloadJson: string = JSON.stringify(user);
    const param: ReadHistoryAddParam = {
      'type': READ_HISTORY_TYPE_USER,
      'key': this.login,
      'title': title,
      'subtitle': subtitle,
      'avatar': avatar,
      'payloadJson': payloadJson,
      'time': Date.now(),
    } as ReadHistoryAddParam;
    await this.readHistoryService.add(param);
  }
}
