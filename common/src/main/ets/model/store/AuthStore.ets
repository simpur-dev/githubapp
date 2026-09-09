/**
 * AuthStore —— 全局登录态容器，对齐 RN 端 Redux
 * [store/actions/login.js](../../../../../../../reactnative/GSYGithubApp/app/store/actions/login.js)
 * 与 [store/actions/user.js](../../../../../../../reactnative/GSYGithubApp/app/store/actions/user.js) 的语义：
 *
 * - 字段：authed / loading / error / userInfo / token，对应 RN 端
 *   `LOGIN.IN | LOGIN.CLEAR` + `USER.USER_INFO` 派发后的最终视图模型。
 * - 通过 `@ObservedV2 + @Trace` 提供类级可观察性（V2 组件可直接订阅字段）；
 *   V1 组件通过 `GlobalAuthStore` 单例直读字段，配合 `EVENT_AUTH_STATE_CHANGED`
 *   事件驱动刷新（等价 RN 端 `connect(state => ({state}))`）。
 * - 仅承载状态与状态迁移，不直接发起网络请求；具体登录流程在
 *   [LoginUseCase.ets](../auth/LoginUseCase.ets) 中编排。
 */

import { EventBus, EVENT_AUTH_STATE_CHANGED } from '../../base/utils/EventBus';

export class AuthUserInfo {
  login: string;
  name: string;
  avatarUrl: string;
  htmlUrl: string;
  raw: string;
  bio: string;
  followers: number;
  following: number;
  publicRepos: number;
  company: string;
  location: string;
  blog: string;
  createdAt: string;
  type: string;
  starred: string;

  constructor(login: string = '',
              name: string = '',
              avatarUrl: string = '',
              htmlUrl: string = '',
              raw: string = '',
              bio: string = '',
              followers: number = 0,
              following: number = 0,
              publicRepos: number = 0,
              company: string = '',
              location: string = '',
              blog: string = '',
              createdAt: string = '',
              type: string = '',
              starred: string = '') {
    this.login = login;
    this.name = name;
    this.avatarUrl = avatarUrl;
    this.htmlUrl = htmlUrl;
    this.raw = raw;
    this.bio = bio;
    this.followers = followers;
    this.following = following;
    this.publicRepos = publicRepos;
    this.company = company;
    this.location = location;
    this.blog = blog;
    this.createdAt = createdAt;
    this.type = type;
    this.starred = starred;
  }

  static fromJson(jsonString: string): AuthUserInfo | null {
    if (!jsonString || jsonString.length === 0) {
      return null;
    }
    let parsed: Record<string, Object> | null = null;
    try {
      parsed = JSON.parse(jsonString) as Record<string, Object>;
    } catch (_e) {
      return null;
    }
    if (!parsed) {
      return null;
    }
    const login: string = AuthUserInfo.readString(parsed, 'login');
    const name: string = AuthUserInfo.readString(parsed, 'name');
    const avatarUrl: string = AuthUserInfo.readString(parsed, 'avatar_url');
    const htmlUrl: string = AuthUserInfo.readString(parsed, 'html_url');
    const bio: string = AuthUserInfo.readString(parsed, 'bio');
    const followers: number = AuthUserInfo.readNumber(parsed, 'followers');
    const following: number = AuthUserInfo.readNumber(parsed, 'following');
    const publicRepos: number = AuthUserInfo.readNumber(parsed, 'public_repos');
    const company: string = AuthUserInfo.readString(parsed, 'company');
    const location: string = AuthUserInfo.readString(parsed, 'location');
    const blog: string = AuthUserInfo.readString(parsed, 'blog');
    const createdAt: string = AuthUserInfo.readString(parsed, 'created_at');
    const type: string = AuthUserInfo.readString(parsed, 'type');
    const starred: string = AuthUserInfo.readString(parsed, 'starred');
    return new AuthUserInfo(login, name, avatarUrl, htmlUrl, jsonString,
      bio, followers, following, publicRepos,
      company, location, blog, createdAt, type, starred);
  }

  private static readString(obj: Record<string, Object>, key: string): string {
    const v: Object | undefined = obj[key];
    if (typeof v === 'string') {
      return v as string;
    }
    if (v === null || v === undefined) {
      return '';
    }
    return String(v);
  }

  private static readNumber(obj: Record<string, Object>, key: string): number {
    const v: Object | undefined = obj[key];
    if (typeof v === 'number') {
      return v as number;
    }
    if (typeof v === 'string') {
      const n: number = Number.parseInt(v as string, 10);
      return Number.isNaN(n) ? 0 : n;
    }
    return 0;
  }
}

@ObservedV2
export class AuthStore {
  @Trace authed: boolean = false;
  @Trace loading: boolean = false;
  @Trace error: string = '';
  @Trace userInfo: AuthUserInfo | null = null;
  @Trace token: string = '';

  setLoading(loading: boolean): void {
    this.loading = loading;
    if (loading) {
      this.error = '';
    }
    this.notifyChanged();
  }

  setError(message: string): void {
    this.error = message ? message : '';
    this.loading = false;
    this.notifyChanged();
  }

  setUser(token: string, user: AuthUserInfo | null): void {
    const trimToken: string = token ? token : '';
    this.token = trimToken;
    this.userInfo = user;
    this.authed = trimToken.length > 0 && user !== null;
    this.loading = false;
    this.error = '';
    this.notifyChanged();
  }

  clear(): void {
    this.authed = false;
    this.loading = false;
    this.error = '';
    this.userInfo = null;
    this.token = '';
    this.notifyChanged();
  }

  /**
   * 任一状态字段变化后广播 EVENT_AUTH_STATE_CHANGED，payload 为本实例。
   * V1 组件（LoginPage / DrawerHeader 等）订阅该事件后回读单例字段刷新 UI，
   * 语义等价旧版镜像键 + 自动同步的响应机制。
   */
  private notifyChanged(): void {
    EventBus.emit(EVENT_AUTH_STATE_CHANGED, this);
  }
}

export const GlobalAuthStore: AuthStore = new AuthStore();
