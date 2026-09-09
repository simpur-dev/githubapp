import HttpManager from '../../base/net/HttpManager';
import { Address } from '../../base/net/Address';
import { HttpResult } from '../../base/net/Result';
import { UNAUTHORIZED } from '../../base/net/NetworkCode';
import { DynamicDao } from '../../base/dao/DynamicDao';
import { ReadResult } from '../../base/dao/DaoBase';
import { DynamicEvent } from '../store/DynamicStore';

/**
 * FetchReceivedResult —— 无状态取数结果（R9 V2 + MVVM）。
 *
 * service 不再直写 DynamicStore（UI 状态），分页信息 page / hasMore 随结果返回，
 * 由调用方 ViewModel 写入自己的 @Trace 字段：
 *   - 刷新成功：page=finalPage（首页为 1）、hasMore = data.length >= pageSize；
 *   - 追加成功：page=finalPage、hasMore = data.length >= pageSize；
 *   - 网络失败但首页有缓存：result=true、fromCache=true、hasMore=false（等价旧 applyCachedFallback）；
 *   - 401（首页有缓存时 data=cached，供 ViewModel 维持"缓存仍可见"）。
 */
export class FetchReceivedResult {
  result: boolean;
  code: number;
  data: DynamicEvent[];
  fromCache: boolean;
  msg: string;
  page: number;
  hasMore: boolean;

  constructor(result: boolean, code: number, data: DynamicEvent[], fromCache: boolean, msg: string,
    page: number = 1, hasMore: boolean = false) {
    this.result = result;
    this.code = code;
    this.data = data;
    this.fromCache = fromCache;
    this.msg = msg;
    this.page = page;
    this.hasMore = hasMore;
  }
}

export class DynamicService {
  private dao: DynamicDao;
  private pageSize: number;

  constructor(dao?: DynamicDao, pageSize?: number) {
    this.dao = dao !== undefined ? dao : new DynamicDao();
    this.pageSize = pageSize !== undefined && pageSize > 0 ? pageSize : Address.getReceivedEventPageSize();
  }

  getPageSize(): number {
    return this.pageSize;
  }

  /** 首页缓存预读（供 ViewModel 做"先展示缓存再刷新"的渐进渲染）。 */
  async peekReceivedCache(user: string): Promise<DynamicEvent[]> {
    return this.readCache(user);
  }

  /** 用户事件首页缓存预读。 */
  async peekUserEventCache(user: string): Promise<DynamicEvent[]> {
    return this.readUserEventCache(user);
  }

  async fetchReceivedEvents(user: string, page: number): Promise<FetchReceivedResult> {
    if (!user || user.length === 0) {
      const empty: FetchReceivedResult = new FetchReceivedResult(false, 0, [], false, 'empty user');
      return empty;
    }

    const finalPage: number = page > 0 ? page : 1;
    let cached: DynamicEvent[] = [];
    if (finalPage === 1) {
      cached = await this.readCache(user);
    }

    const url: string = Address.getReceivedEvent(user, finalPage, this.pageSize);
    const httpResult: HttpResult<DynamicEvent[]> = await HttpManager.getFetch<DynamicEvent[]>(url);

    if (httpResult.result && httpResult.data !== null) {
      const events: DynamicEvent[] = httpResult.data as DynamicEvent[];
      if (finalPage === 1) {
        try {
          await this.dao.saveReceivedEvent(user, JSON.stringify(events));
        } catch (_e) {
        }
      }
      return new FetchReceivedResult(true, httpResult.code, events, false, '',
        finalPage, events.length >= this.pageSize);
    }

    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new FetchReceivedResult(false, UNAUTHORIZED, finalPage === 1 ? cached : [], false, msg,
        finalPage, false);
    }

    if (finalPage === 1 && cached.length > 0) {
      return new FetchReceivedResult(true, httpResult.code, cached, true,
        httpResult.msg !== null ? httpResult.msg : '', 1, false);
    }

    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new FetchReceivedResult(false, httpResult.code, [], false, failMsg, finalPage, false);
  }

  /**
   * 拉取指定用户自身行为事件，对齐 RN 端
   * [store/actions/event.js](../../../../../../../reactnative/GSYGithubApp/app/store/actions/event.js)
   * `getEvent(page, login)` 走 `GET /users/:login/events`，被 MyTab / UserDetail 使用。
   * 无状态：只取数返回，UI 状态归 ViewModel。
   */
  async fetchUserEvents(user: string, page: number): Promise<FetchReceivedResult> {
    if (!user || user.length === 0) {
      const empty: FetchReceivedResult = new FetchReceivedResult(false, 0, [], false, 'empty user');
      return empty;
    }

    const finalPage: number = page > 0 ? page : 1;
    let cached: DynamicEvent[] = [];
    if (finalPage === 1) {
      cached = await this.readUserEventCache(user);
    }

    const url: string = Address.getUserEvent(user, finalPage, this.pageSize);
    const httpResult: HttpResult<DynamicEvent[]> = await HttpManager.getFetch<DynamicEvent[]>(url);

    if (httpResult.result && httpResult.data !== null) {
      const events: DynamicEvent[] = httpResult.data as DynamicEvent[];
      if (finalPage === 1) {
        try {
          await this.dao.saveUserEvent(user, JSON.stringify(events));
        } catch (_e) {
        }
      }
      return new FetchReceivedResult(true, httpResult.code, events, false, '',
        finalPage, events.length >= this.pageSize);
    }

    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new FetchReceivedResult(false, UNAUTHORIZED, finalPage === 1 ? cached : [], false, msg,
        finalPage, false);
    }

    if (finalPage === 1 && cached.length > 0) {
      return new FetchReceivedResult(true, httpResult.code, cached, true,
        httpResult.msg !== null ? httpResult.msg : '', 1, false);
    }

    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new FetchReceivedResult(false, httpResult.code, [], false, failMsg, finalPage, false);
  }

  private async readUserEventCache(user: string): Promise<DynamicEvent[]> {
    try {
      const cache: ReadResult = await this.dao.readUserEvent(user);
      if (!cache.result || cache.data.length === 0) {
        return [];
      }
      const parsed: Object = JSON.parse(cache.data) as Object;
      if (Array.isArray(parsed)) {
        return parsed as DynamicEvent[];
      }
      return [];
    } catch (_e) {
      return [];
    }
  }

  private async readCache(user: string): Promise<DynamicEvent[]> {
    try {
      const cache: ReadResult = await this.dao.readReceivedEvent(user);
      if (!cache.result || cache.data.length === 0) {
        return [];
      }
      const parsed: Object = JSON.parse(cache.data) as Object;
      if (Array.isArray(parsed)) {
        return parsed as DynamicEvent[];
      }
      return [];
    } catch (_e) {
      return [];
    }
  }
}
