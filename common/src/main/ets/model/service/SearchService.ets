import HttpManager from '../../base/net/HttpManager';
import { Address } from '../../base/net/Address';
import { HttpResult } from '../../base/net/Result';
import { UNAUTHORIZED } from '../../base/net/NetworkCode';
import { RecommendRepo, RecommendSearchResponse } from '../store/RecommendStore';
import {
  SearchTab,
  SEARCH_TAB_REPO,
  SEARCH_TAB_USER,
  SEARCH_TAB_ISSUE,
  SearchUserItem,
  SearchUserSearchResponse,
  SearchIssueItem,
  SearchIssueSearchResponse,
} from '../store/SearchStore';

/**
 * Search 取数结果（R9 V2 + MVVM 无状态化）：service 不再直写 SearchStore，
 * 分页信息 page / hasMore 随结果返回，由调用方 ViewModel 写入自己的 @Trace 字段。
 */
export class SearchRepoResult {
  result: boolean;
  code: number;
  data: RecommendRepo[];
  msg: string;
  fromCache: boolean;
  page: number;
  hasMore: boolean;

  constructor(result: boolean, code: number, data: RecommendRepo[], msg: string, fromCache: boolean = false,
    page: number = 1, hasMore: boolean = false) {
    this.result = result;
    this.code = code;
    this.data = data;
    this.msg = msg;
    this.fromCache = fromCache;
    this.page = page;
    this.hasMore = hasMore;
  }
}

export class SearchUserResult {
  result: boolean;
  code: number;
  data: SearchUserItem[];
  msg: string;
  fromCache: boolean;
  page: number;
  hasMore: boolean;

  constructor(result: boolean, code: number, data: SearchUserItem[], msg: string, fromCache: boolean = false,
    page: number = 1, hasMore: boolean = false) {
    this.result = result;
    this.code = code;
    this.data = data;
    this.msg = msg;
    this.fromCache = fromCache;
    this.page = page;
    this.hasMore = hasMore;
  }
}

export class SearchIssueResult {
  result: boolean;
  code: number;
  data: SearchIssueItem[];
  msg: string;
  fromCache: boolean;
  page: number;
  hasMore: boolean;

  constructor(result: boolean, code: number, data: SearchIssueItem[], msg: string, fromCache: boolean = false,
    page: number = 1, hasMore: boolean = false) {
    this.result = result;
    this.code = code;
    this.data = data;
    this.msg = msg;
    this.fromCache = fromCache;
    this.page = page;
    this.hasMore = hasMore;
  }
}

export class SearchService {
  private pageSize: number;

  constructor(pageSize?: number) {
    this.pageSize = pageSize !== undefined && pageSize > 0
      ? pageSize
      : Address.getSearchReposPageSize();
  }

  getPageSize(): number {
    return this.pageSize;
  }

  async searchRepo(q: string,
                   sort: string | null,
                   page: number): Promise<SearchRepoResult> {
    const finalPage: number = page > 0 ? page : 1;
    const url: string = Address.getSearchRepos(q, sort, finalPage, this.pageSize);
    const httpResult: HttpResult<RecommendSearchResponse> =
      await HttpManager.getFetch<RecommendSearchResponse>(url);

    if (httpResult.result && httpResult.data !== null) {
      const payload: RecommendSearchResponse = httpResult.data as RecommendSearchResponse;
      const items: RecommendRepo[] = payload.items !== undefined && payload.items !== null
        ? payload.items
        : [];
      return new SearchRepoResult(true, httpResult.code, items, '', false,
        finalPage, items.length >= this.pageSize);
    }

    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new SearchRepoResult(false, UNAUTHORIZED, [], msg, false, finalPage, false);
    }

    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new SearchRepoResult(false, httpResult.code, [], failMsg, false, finalPage, false);
  }

  async searchUser(q: string,
                   sort: string | null,
                   page: number): Promise<SearchUserResult> {
    const finalPage: number = page > 0 ? page : 1;
    const url: string = Address.getSearchUsers(q, sort, finalPage, this.pageSize);
    const httpResult: HttpResult<SearchUserSearchResponse> =
      await HttpManager.getFetch<SearchUserSearchResponse>(url);

    if (httpResult.result && httpResult.data !== null) {
      const payload: SearchUserSearchResponse = httpResult.data as SearchUserSearchResponse;
      const items: SearchUserItem[] = payload.items !== undefined && payload.items !== null
        ? payload.items
        : [];
      return new SearchUserResult(true, httpResult.code, items, '', false,
        finalPage, items.length >= this.pageSize);
    }

    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new SearchUserResult(false, UNAUTHORIZED, [], msg, false, finalPage, false);
    }

    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new SearchUserResult(false, httpResult.code, [], failMsg, false, finalPage, false);
  }

  async searchIssue(q: string,
                    sort: string | null,
                    page: number): Promise<SearchIssueResult> {
    const finalPage: number = page > 0 ? page : 1;
    const url: string = Address.getSearchIssues(q, sort, finalPage, this.pageSize);
    const httpResult: HttpResult<SearchIssueSearchResponse> =
      await HttpManager.getFetch<SearchIssueSearchResponse>(url);

    if (httpResult.result && httpResult.data !== null) {
      const payload: SearchIssueSearchResponse = httpResult.data as SearchIssueSearchResponse;
      const items: SearchIssueItem[] = payload.items !== undefined && payload.items !== null
        ? payload.items
        : [];
      return new SearchIssueResult(true, httpResult.code, items, '', false,
        finalPage, items.length >= this.pageSize);
    }

    if (httpResult.code === UNAUTHORIZED) {
      const msg: string = httpResult.msg !== null ? httpResult.msg : 'unauthorized';
      return new SearchIssueResult(false, UNAUTHORIZED, [], msg, false, finalPage, false);
    }

    const failMsg: string = httpResult.msg !== null ? httpResult.msg : 'network error';
    return new SearchIssueResult(false, httpResult.code, [], failMsg, false, finalPage, false);
  }

  async searchByTab(tab: SearchTab,
                    q: string,
                    sort: string | null,
                    page: number): Promise<boolean> {
    if (tab === SEARCH_TAB_REPO) {
      const r: SearchRepoResult = await this.searchRepo(q, sort, page);
      return r.result;
    }
    if (tab === SEARCH_TAB_USER) {
      const r: SearchUserResult = await this.searchUser(q, sort, page);
      return r.result;
    }
    if (tab === SEARCH_TAB_ISSUE) {
      const r: SearchIssueResult = await this.searchIssue(q, sort, page);
      return r.result;
    }
    return false;
  }
}
