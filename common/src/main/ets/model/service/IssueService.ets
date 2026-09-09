import HttpManager from '../../base/net/HttpManager';
import { Address } from '../../base/net/Address';
import { HttpResult } from '../../base/net/Result';
import { UNAUTHORIZED, NO_CONTENT } from '../../base/net/NetworkCode';
import { IssueDao } from '../../base/dao/IssueDao';
import { ReadResult } from '../../base/dao/DaoBase';
import {
  IssueDetailModel,
  IssueCommentModel,
  ISSUE_STATE_OPEN,
  ISSUE_STATE_CLOSED
} from '../store/IssueDetailStore';

export class IssueOwnerName {
  owner: string;
  name: string;

  constructor(owner: string, name: string) {
    this.owner = owner;
    this.name = name;
  }

  static parse(fullName: string): IssueOwnerName {
    const safe: string = fullName !== null && fullName !== undefined ? fullName : '';
    const idx: number = safe.indexOf('/');
    if (idx < 0) {
      return new IssueOwnerName(safe, '');
    }
    const owner: string = safe.substring(0, idx);
    const name: string = safe.substring(idx + 1);
    return new IssueOwnerName(owner, name);
  }
}

/**
 * R9 无状态化：结果携带 page / hasMore（列表接口用，详情/布尔类接口恒为 1 / false），
 * 调用方 ViewModel 拿返回值写自己的 UI 状态，service 不再写任何 store。
 */
export class IssueServiceResult<T> {
  result: boolean;
  code: number;
  data: T | null;
  fromCache: boolean;
  msg: string;
  /** 列表接口附带：本次请求对应页码（详情/布尔类接口恒为 1）。 */
  page: number;
  /** 列表接口附带：是否还有下一页（按返回条数 >= pageSize 判定）。 */
  hasMore: boolean;

  constructor(result: boolean, code: number, data: T | null, fromCache: boolean, msg: string,
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

interface IssueStateBody {
  state: string;
}

interface IssueCommentBody {
  body: string;
}

interface IssueEditBody {
  title: string;
  body: string;
}

export class IssueService {
  private dao: IssueDao;
  private pageSize: number;

  // R9 V2 + MVVM 无状态化：构造函数不再持有 IssueDetailStore，
  // 方法只做取数/写入并返回数据（谁调谁更新：调用方 ViewModel 写自己的 UI 状态）。
  constructor(dao?: IssueDao, pageSize?: number) {
    this.dao = dao !== undefined ? dao : new IssueDao();
    this.pageSize = pageSize !== undefined && pageSize > 0
      ? pageSize : Address.getIssuePageSize();
  }

  getPageSize(): number {
    return this.pageSize;
  }

  async getIssue(fullName: string,
                 num: number,
                 onCached?: (issue: IssueDetailModel) => void): Promise<IssueServiceResult<IssueDetailModel>> {
    const owner: IssueOwnerName = IssueOwnerName.parse(fullName);
    if (owner.owner.length === 0 || owner.name.length === 0) {
      const msg: string = 'invalid fullName';
      return new IssueServiceResult<IssueDetailModel>(false, 0, null, false, msg);
    }
    const cachedIssue: IssueDetailModel | null = await this.readIssueCache(fullName, num);
    if (cachedIssue !== null && onCached !== undefined && onCached !== null) {
      onCached(cachedIssue);
    }
    const url: string = Address.getIssue(owner.owner, owner.name, num);
    const httpResult: HttpResult<IssueDetailModel> =
      await HttpManager.getFetch<IssueDetailModel>(url);
    if (httpResult.result && httpResult.data !== null) {
      const detail: IssueDetailModel = httpResult.data as IssueDetailModel;
      try {
        await this.dao.saveIssueDetail(fullName, num, JSON.stringify(detail));
      } catch (_e) {
      }
      return new IssueServiceResult<IssueDetailModel>(true, httpResult.code, detail, false, '');
    }
    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new IssueServiceResult<IssueDetailModel>(false, UNAUTHORIZED, null, false, msg);
    }
    if (cachedIssue !== null) {
      return new IssueServiceResult<IssueDetailModel>(true, httpResult.code, cachedIssue, true,
        httpResult.msg !== null ? httpResult.msg : '');
    }
    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new IssueServiceResult<IssueDetailModel>(false, httpResult.code, null, false, failMsg);
  }

  async getComments(fullName: string,
                    num: number,
                    page: number,
                    onCached?: (comments: IssueCommentModel[]) => void): Promise<IssueServiceResult<IssueCommentModel[]>> {
    const owner: IssueOwnerName = IssueOwnerName.parse(fullName);
    if (owner.owner.length === 0 || owner.name.length === 0) {
      const msg: string = 'invalid fullName';
      return new IssueServiceResult<IssueCommentModel[]>(false, 0, [], false, msg);
    }
    const finalPage: number = page > 0 ? page : 1;
    let cachedComments: IssueCommentModel[] = [];
    if (finalPage === 1) {
      cachedComments = await this.readCommentsCache(fullName, num, finalPage);
      if (cachedComments.length > 0 && onCached !== undefined && onCached !== null) {
        onCached(cachedComments);
      }
    }
    const url: string = Address.getIssueComments(owner.owner, owner.name, num,
      finalPage, this.pageSize);
    const httpResult: HttpResult<IssueCommentModel[]> =
      await HttpManager.getFetch<IssueCommentModel[]>(url);
    if (httpResult.result && httpResult.data !== null) {
      const items: IssueCommentModel[] = httpResult.data as IssueCommentModel[];
      if (finalPage === 1) {
        try {
          await this.dao.saveIssueComment(fullName, num, finalPage, JSON.stringify(items));
        } catch (_e) {
        }
      }
      return new IssueServiceResult<IssueCommentModel[]>(true, httpResult.code, items, false, '',
        finalPage, items.length >= this.pageSize);
    }
    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new IssueServiceResult<IssueCommentModel[]>(false, UNAUTHORIZED, [], false, msg);
    }
    if (finalPage === 1 && cachedComments.length > 0) {
      return new IssueServiceResult<IssueCommentModel[]>(true, httpResult.code, cachedComments, true,
        httpResult.msg !== null ? httpResult.msg : '', 1, cachedComments.length >= this.pageSize);
    }
    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new IssueServiceResult<IssueCommentModel[]>(false, httpResult.code, [], false, failMsg);
  }

  /**
   * 创建评论 —— 无状态化后只返回新建条目，「追加到列表尾部 + 计数 +1」由调用方 ViewModel 处理。
   */
  async createComment(fullName: string,
                      num: number,
                      body: string): Promise<IssueServiceResult<IssueCommentModel>> {
    const owner: IssueOwnerName = IssueOwnerName.parse(fullName);
    if (owner.owner.length === 0 || owner.name.length === 0) {
      return new IssueServiceResult<IssueCommentModel>(false, 0, null, false, 'invalid fullName');
    }
    const safeBody: string = body !== null && body !== undefined ? body : '';
    if (safeBody.length === 0) {
      return new IssueServiceResult<IssueCommentModel>(false, 0, null, false, 'empty body');
    }
    const url: string = Address.createIssueComment(owner.owner, owner.name, num);
    const params: IssueCommentBody = { 'body': safeBody };
    const httpResult: HttpResult<IssueCommentModel> =
      await HttpManager.netFetch<IssueCommentModel>(url, 'POST',
        params as Object as Record<string, Object>, true, null);
    if (httpResult.result && httpResult.data !== null) {
      const comment: IssueCommentModel = httpResult.data as IssueCommentModel;
      return new IssueServiceResult<IssueCommentModel>(true, httpResult.code, comment, false, '');
    }
    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new IssueServiceResult<IssueCommentModel>(false, UNAUTHORIZED, null, false, msg);
    }
    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new IssueServiceResult<IssueCommentModel>(false, httpResult.code, null, false, failMsg);
  }

  async closeIssue(fullName: string,
                   num: number): Promise<IssueServiceResult<IssueDetailModel>> {
    return this.toggleIssueState(fullName, num, ISSUE_STATE_CLOSED);
  }

  async reopenIssue(fullName: string,
                    num: number): Promise<IssueServiceResult<IssueDetailModel>> {
    return this.toggleIssueState(fullName, num, ISSUE_STATE_OPEN);
  }

  private async toggleIssueState(fullName: string,
                                 num: number,
                                 state: string): Promise<IssueServiceResult<IssueDetailModel>> {
    const owner: IssueOwnerName = IssueOwnerName.parse(fullName);
    if (owner.owner.length === 0 || owner.name.length === 0) {
      return new IssueServiceResult<IssueDetailModel>(false, 0, null, false, 'invalid fullName');
    }
    const url: string = Address.setIssueState(owner.owner, owner.name, num);
    const params: IssueStateBody = { 'state': state };
    const httpResult: HttpResult<IssueDetailModel> =
      await HttpManager.netFetch<IssueDetailModel>(url, 'PATCH',
        params as Object as Record<string, Object>, true, null);
    if (httpResult.result && httpResult.data !== null) {
      const detail: IssueDetailModel = httpResult.data as IssueDetailModel;
      try {
        await this.dao.saveIssueDetail(fullName, num, JSON.stringify(detail));
      } catch (_e) {
      }
      return new IssueServiceResult<IssueDetailModel>(true, httpResult.code, detail, false, '');
    }
    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new IssueServiceResult<IssueDetailModel>(false, UNAUTHORIZED, null, false, msg);
    }
    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new IssueServiceResult<IssueDetailModel>(false, httpResult.code, null, false, failMsg);
  }

  async editIssue(fullName: string,
                  num: number,
                  title: string,
                  body: string): Promise<IssueServiceResult<IssueDetailModel>> {
    const owner: IssueOwnerName = IssueOwnerName.parse(fullName);
    if (owner.owner.length === 0 || owner.name.length === 0) {
      return new IssueServiceResult<IssueDetailModel>(false, 0, null, false, 'invalid fullName');
    }
    const safeTitle: string = title !== null && title !== undefined ? title : '';
    if (safeTitle.length === 0) {
      return new IssueServiceResult<IssueDetailModel>(false, 0, null, false, 'empty title');
    }
    const safeBody: string = body !== null && body !== undefined ? body : '';
    const url: string = Address.editIssue(owner.owner, owner.name, num);
    const params: IssueEditBody = { 'title': safeTitle, 'body': safeBody };
    const httpResult: HttpResult<IssueDetailModel> =
      await HttpManager.netFetch<IssueDetailModel>(url, 'PATCH',
        params as Object as Record<string, Object>, true, null);
    if (httpResult.result && httpResult.data !== null) {
      const detail: IssueDetailModel = httpResult.data as IssueDetailModel;
      try {
        await this.dao.saveIssueDetail(fullName, num, JSON.stringify(detail));
      } catch (_e) {
      }
      return new IssueServiceResult<IssueDetailModel>(true, httpResult.code, detail, false, '');
    }
    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new IssueServiceResult<IssueDetailModel>(false, UNAUTHORIZED, null, false, msg);
    }
    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new IssueServiceResult<IssueDetailModel>(false, httpResult.code, null, false, failMsg);
  }

  async toggleIssueLock(fullName: string,
                        num: number,
                        currentLocked: boolean): Promise<IssueServiceResult<boolean>> {
    const owner: IssueOwnerName = IssueOwnerName.parse(fullName);
    if (owner.owner.length === 0 || owner.name.length === 0) {
      return new IssueServiceResult<boolean>(false, 0, null, false, 'invalid fullName');
    }
    const url: string = Address.lockIssue(owner.owner, owner.name, num);
    const method: 'PUT' | 'DELETE' = currentLocked ? 'DELETE' : 'PUT';
    const httpResult: HttpResult<Object> =
      await HttpManager.netFetch<Object>(url, method, null, true, null);
    const ok: boolean = httpResult.result || httpResult.code === NO_CONTENT;
    if (ok) {
      const nextLocked: boolean = !currentLocked;
      // 无状态化：缓存里的 issue 详情就地翻转 locked 后回写（原先经 store.issue 的语义平移）。
      const cached: IssueDetailModel | null = await this.readIssueCache(fullName, num);
      if (cached !== null) {
        cached.locked = nextLocked;
        try {
          await this.dao.saveIssueDetail(fullName, num, JSON.stringify(cached));
        } catch (_e) {
        }
      }
      return new IssueServiceResult<boolean>(true, httpResult.code, nextLocked, false, '');
    }
    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new IssueServiceResult<boolean>(false, UNAUTHORIZED, null, false, msg);
    }
    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new IssueServiceResult<boolean>(false, httpResult.code, null, false, failMsg);
  }

  /**
   * 编辑评论 —— 无状态化后只返回更新条目，「按行替换」由调用方 ViewModel 处理。
   */
  async editComment(fullName: string,
                    num: number,
                    commentId: number,
                    body: string,
                    rowIndex: number): Promise<IssueServiceResult<IssueCommentModel>> {
    const owner: IssueOwnerName = IssueOwnerName.parse(fullName);
    if (owner.owner.length === 0 || owner.name.length === 0) {
      return new IssueServiceResult<IssueCommentModel>(false, 0, null, false, 'invalid fullName');
    }
    const safeBody: string = body !== null && body !== undefined ? body : '';
    if (safeBody.length === 0) {
      return new IssueServiceResult<IssueCommentModel>(false, 0, null, false, 'empty body');
    }
    const url: string = Address.editIssueComment(owner.owner, owner.name, commentId);
    const params: IssueCommentBody = { 'body': safeBody };
    const httpResult: HttpResult<IssueCommentModel> =
      await HttpManager.netFetch<IssueCommentModel>(url, 'PATCH',
        params as Object as Record<string, Object>, true, null);
    if (httpResult.result && httpResult.data !== null) {
      const comment: IssueCommentModel = httpResult.data as IssueCommentModel;
      return new IssueServiceResult<IssueCommentModel>(true, httpResult.code, comment, false, '');
    }
    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new IssueServiceResult<IssueCommentModel>(false, UNAUTHORIZED, null, false, msg);
    }
    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new IssueServiceResult<IssueCommentModel>(false, httpResult.code, null, false, failMsg);
  }

  /**
   * 删除评论 —— 无状态化后只返回成功与否，「按行移除 + 计数 -1」由调用方 ViewModel 处理。
   */
  async deleteComment(fullName: string,
                      num: number,
                      commentId: number,
                      rowIndex: number): Promise<IssueServiceResult<boolean>> {
    const owner: IssueOwnerName = IssueOwnerName.parse(fullName);
    if (owner.owner.length === 0 || owner.name.length === 0) {
      return new IssueServiceResult<boolean>(false, 0, null, false, 'invalid fullName');
    }
    const url: string = Address.editIssueComment(owner.owner, owner.name, commentId);
    const httpResult: HttpResult<Object> =
      await HttpManager.netFetch<Object>(url, 'DELETE', null, true, null);
    const ok: boolean = httpResult.result || httpResult.code === NO_CONTENT;
    if (ok) {
      return new IssueServiceResult<boolean>(true, httpResult.code, true, false, '');
    }
    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new IssueServiceResult<boolean>(false, UNAUTHORIZED, null, false, msg);
    }
    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new IssueServiceResult<boolean>(false, httpResult.code, null, false, failMsg);
  }

  private async readIssueCache(fullName: string, num: number): Promise<IssueDetailModel | null> {
    try {
      const cache: ReadResult = await this.dao.readIssueDetail(fullName, num);
      if (!cache.result || cache.data.length === 0) {
        return null;
      }
      const parsed: Object = JSON.parse(cache.data) as Object;
      return parsed as IssueDetailModel;
    } catch (_e) {
      return null;
    }
  }

  private async readCommentsCache(fullName: string, num: number,
    page: number): Promise<IssueCommentModel[]> {
    try {
      const cache: ReadResult = await this.dao.readIssueComment(fullName, num, page);
      if (!cache.result || cache.data.length === 0) {
        return [];
      }
      const parsed: Object = JSON.parse(cache.data) as Object;
      if (Array.isArray(parsed)) {
        return parsed as IssueCommentModel[];
      }
      return [];
    } catch (_e) {
      return [];
    }
  }
}
