/**
 * MyTabViewModel —— "我的"页签状态与编排（R9 V2 + MVVM）。
 *
 * @Trace UI 状态（21 个）：header 用户信息 9 项 + 计数 5 项 + 未读 + 组织列表 +
 * 事件列表 + 刷新中/加载更多中/是否有更多/错误文案。
 * 数据来源：用户信息直读 GlobalAuthStore 单例（refreshMe 内部会写回该单例），
 * 事件流走无状态 DynamicService（返回 FetchReceivedResult 含 page/hasMore）。
 * [MyTabPageDeps] 保持原注入面（ohosTest 经 feature_main 包导入），
 * dynamicService 工厂签名随 DynamicService 无状态化去掉 store 参数。
 */
import { AuthUserInfo, GlobalAuthStore } from 'common';
import { MyStore, GlobalMyStore } from 'common';
import {
  MyService,
  DefaultMyService,
  RefreshMeResult,
  FetchUnReadResult,
  FetchStarredCountResult,
} from 'common';
import { DynamicService, FetchReceivedResult } from 'common';
import { DynamicEvent } from 'common';
import { LoginUseCase, DefaultLoginUseCase } from 'common';
import { I18n } from 'common';
import { TimeUtil } from 'common';

export class MyTabPageDeps {
  private static serviceImpl: MyService = DefaultMyService;
  private static dynamicServiceFactory: (() => DynamicService) | null = null;
  private static storeImpl: MyStore = GlobalMyStore;
  private static loginUseCaseImpl: LoginUseCase = DefaultLoginUseCase;

  static setService(service: MyService): void {
    MyTabPageDeps.serviceImpl = service;
  }

  static setDynamicServiceFactory(factory: (() => DynamicService) | null): void {
    MyTabPageDeps.dynamicServiceFactory = factory;
  }

  static setStore(store: MyStore): void {
    MyTabPageDeps.storeImpl = store;
  }

  static setLoginUseCase(useCase: LoginUseCase): void {
    MyTabPageDeps.loginUseCaseImpl = useCase;
  }

  static getService(): MyService {
    return MyTabPageDeps.serviceImpl;
  }

  static buildDynamicService(): DynamicService {
    if (MyTabPageDeps.dynamicServiceFactory !== null) {
      return MyTabPageDeps.dynamicServiceFactory();
    }
    return new DynamicService();
  }

  static getStore(): MyStore {
    return MyTabPageDeps.storeImpl;
  }

  static getLoginUseCase(): LoginUseCase {
    return MyTabPageDeps.loginUseCaseImpl;
  }

  static reset(): void {
    MyTabPageDeps.serviceImpl = DefaultMyService;
    MyTabPageDeps.dynamicServiceFactory = null;
    MyTabPageDeps.storeImpl = GlobalMyStore;
    MyTabPageDeps.loginUseCaseImpl = DefaultLoginUseCase;
  }
}

@ObservedV2
export class MyTabViewModel {
  // header 用户信息
  @Trace headerDisplayName: string = '';
  @Trace headerLogin: string = '';
  @Trace headerAvatar: string = '';
  @Trace headerCompany: string = '';
  @Trace headerLocation: string = '';
  @Trace headerBlog: string = '';
  @Trace headerDes: string = '';
  @Trace headerJoinedText: string = '';
  @Trace headerType: string = '';
  // 计数
  @Trace beStaredCount: string = '---';
  @Trace starCount: string = '---';
  @Trace reposCount: string = '---';
  @Trace followerCount: string = '---';
  @Trace followedCount: string = '---';
  // 通知 / 组织 / 事件流
  @Trace unRead: boolean = false;
  @Trace orgsList: UserHeadOrgItemLite[] = [];
  @Trace events: DynamicEvent[] = [];
  // 列表状态
  @Trace refreshing: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = true;
  @Trace errorMessage: string = '';
  private eventPage: number = 1;
  private dynamicService: DynamicService = MyTabPageDeps.buildDynamicService();

  setDynamicService(service: DynamicService): void {
    this.dynamicService = service;
  }

  eventKey(item: DynamicEvent, index: number): string {
    return index.toString() + '_' + item.id;
  }

  /**
   * 登录态同步：直读 GlobalAuthStore 单例回填 MyStore，
   * 等价旧版镜像同步方法读 auth.userInfo 镜像的语义。
   */
  private syncAuthUserIntoStore(store: MyStore): void {
    if (GlobalAuthStore.userInfo !== null && GlobalAuthStore.userInfo !== undefined) {
      store.applyRawUserInfo(GlobalAuthStore.userInfo.raw);
    }
  }

  /**
   * 登录用户直读 GlobalAuthStore 单例（原 auth.userInfo 镜像通道已移除）。
   */
  private parseUser(): AuthUserInfo | null {
    if (GlobalAuthStore.userInfo !== null && GlobalAuthStore.userInfo !== undefined) {
      return GlobalAuthStore.userInfo;
    }
    return null;
  }

  resolveLogin(): string {
    const user: AuthUserInfo | null = this.parseUser();
    if (user !== null && user.login.length > 0) {
      return user.login;
    }
    return '';
  }

  private applyUserToHeaderState(): void {
    const user: AuthUserInfo | null = this.parseUser();
    if (user === null) {
      return;
    }
    this.headerDisplayName = user.name.length > 0 ? user.name : user.login;
    this.headerLogin = user.login;
    this.headerAvatar = user.avatarUrl;
    this.headerCompany = user.company;
    this.headerLocation = user.location;
    this.headerBlog = user.blog;
    this.headerType = user.type;
    this.headerDes = user.bio.length > 0 ? user.bio : '';
    this.headerJoinedText = this.buildJoinedText(user);
    this.reposCount = user.publicRepos.toString();
    this.followerCount = user.followers.toString();
    this.followedCount = user.following.toString();
    // star / beStared 由 fetchUserStarredCount 单独写入，
    // 不要在这里用 user.starred 覆盖（GitHub /user 接口本身不返回 starred 字段）。
  }

  private buildJoinedText(user: AuthUserInfo | null): string {
    if (user === null) {
      return '';
    }
    const created: string = user.createdAt.length > 0
      ? TimeUtil.resolveTime(user.createdAt)
      : '';
    if (created.length === 0) {
      return '';
    }
    return I18n('profileJoined').replace('%s', created);
  }

  /** 首屏加载（View aboutToAppear 调用）。 */
  async init(): Promise<void> {
    const store: MyStore = MyTabPageDeps.getStore();
    this.syncAuthUserIntoStore(store);
    this.applyUserToHeaderState();
    await this.refresh();
  }

  async refresh(): Promise<void> {
    let login: string = this.resolveLogin();
    this.refreshing = true;
    this.errorMessage = '';

    // bootToken 注入 / 冷启动场景下，GlobalAuthStore 里还没有 userInfo，login 为空。
    // 先单独拉一次 GET /user 把 GlobalAuthStore.userInfo 填好（refreshMe 内部会写回单例），
    // 拿到 login 之后再启动其它并行请求；否则会直接卡在「---」占位。
    if (login.length === 0) {
      const meFirst: RefreshMeResult = await MyTabPageDeps.getService().refreshMe();
      if (meFirst.result && meFirst.data !== null) {
        login = meFirst.data.login;
      } else if (!meFirst.result && meFirst.msg.length > 0) {
        this.errorMessage = meFirst.msg;
      }
      if (login.length === 0) {
        this.refreshing = false;
        this.hasMore = true;
        return;
      }
    }

    const refreshMe: Promise<RefreshMeResult> = MyTabPageDeps.getService().refreshMe();
    const fetchUnRead: Promise<FetchUnReadResult> = MyTabPageDeps.getService().fetchUnRead();
    const fetchStarred: Promise<FetchStarredCountResult>
      = MyTabPageDeps.getService().fetchUserStarredCount(login);
    const fetchEvents: Promise<FetchReceivedResult>
      = this.dynamicService.fetchUserEvents(login, 1);

    const meRes: RefreshMeResult = await refreshMe;
    const unReadRes: FetchUnReadResult = await fetchUnRead;
    const starredRes: FetchStarredCountResult = await fetchStarred;
    const eventRes: FetchReceivedResult = await fetchEvents;

    this.applyUserToHeaderState();
    if (unReadRes.result) {
      this.unRead = unReadRes.unRead;
    }
    this.orgsList = [];
    if (eventRes.result) {
      this.events = eventRes.data;
      this.eventPage = eventRes.page;
      this.hasMore = eventRes.hasMore;
    } else if (eventRes.data.length > 0) {
      // 401 时携带首页缓存 → 空列表兜底展示（旧 store 缓存可见语义）。
      this.events = eventRes.data;
      this.eventPage = eventRes.page;
      this.hasMore = eventRes.hasMore;
    }
    if (starredRes.result) {
      this.starCount = starredRes.count.toString();
    }
    if (!meRes.result && meRes.msg.length > 0) {
      this.errorMessage = meRes.msg;
    } else if (!eventRes.result && eventRes.msg.length > 0 && eventRes.data.length === 0) {
      this.errorMessage = eventRes.msg;
    } else {
      this.errorMessage = '';
    }
    this.refreshing = false;
  }

  async loadMore(): Promise<void> {
    const login: string = this.resolveLogin();
    if (login.length === 0) {
      this.hasMore = false;
      return;
    }
    if (!this.hasMore) {
      return;
    }
    this.loadingMore = true;
    const next: number = this.eventPage + 1;
    try {
      const res: FetchReceivedResult = await this.dynamicService.fetchUserEvents(login, next);
      if (res.result) {
        this.events = this.events.concat(res.data);
        this.eventPage = res.page;
        this.hasMore = res.hasMore;
      }
    } finally {
      this.loadingMore = false;
    }
  }
}

/** 组织头像条目（VM 对外轻量结构，字段与 UserHeadOrgItem 一致）。 */
export interface UserHeadOrgItemLite {
  login: string;
  avatar_url: string;
}
