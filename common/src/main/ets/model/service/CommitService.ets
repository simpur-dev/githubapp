import HttpManager from '../../base/net/HttpManager';
import { Address } from '../../base/net/Address';
import { HttpHeaders, HttpResult } from '../../base/net/Result';
import { RepositoryDao } from '../../base/dao/RepositoryDao';
import { ReadResult } from '../../base/dao/DaoBase';

// Commit 实体 interface（原 PushDetailStore.ets，随 store 删除迁入 service 文件）。
export interface CommitAuthorInfo {
  name: string;
  email: string;
  date: string;
}

export interface CommitInner {
  message: string;
  author: CommitAuthorInfo;
  committer: CommitAuthorInfo;
}

export interface CommitUserBrief {
  login: string;
  avatar_url: string;
  html_url: string;
}

export interface CommitFileItem {
  filename: string;
  status: string;
  additions: number;
  deletions: number;
  changes: number;
  blob_url: string;
  raw_url: string;
  patch: string;
  sha: string;
}

export interface CommitStats {
  additions: number;
  deletions: number;
  total: number;
}

export interface CommitDetail {
  sha: string;
  html_url: string;
  commit: CommitInner;
  author: CommitUserBrief | null;
  committer: CommitUserBrief | null;
  files: CommitFileItem[];
  stats: CommitStats;
}

export class CommitOwnerNamePair {
  owner: string;
  name: string;

  constructor(owner: string, name: string) {
    this.owner = owner;
    this.name = name;
  }

  static parse(fullName: string): CommitOwnerNamePair {
    const safe: string = fullName !== null && fullName !== undefined ? fullName : '';
    const idx: number = safe.indexOf('/');
    if (idx < 0) {
      return new CommitOwnerNamePair(safe, '');
    }
    return new CommitOwnerNamePair(safe.substring(0, idx), safe.substring(idx + 1));
  }
}

export class CommitServiceResult<T> {
  result: boolean;
  code: number;
  data: T | null;
  msg: string;
  fromCache: boolean;

  constructor(result: boolean, code: number, data: T | null, msg: string, fromCache: boolean = false) {
    this.result = result;
    this.code = code;
    this.data = data;
    this.msg = msg;
    this.fromCache = fromCache;
  }
}

export const COMMIT_DIFF_ACCEPT: string = 'application/vnd.github.v3.diff';

export interface CommitCacheDao {
  saveCommitInfoDetail(fullName: string, sha: string, jsonString: string): Promise<number>;
  readCommitInfoDetail(fullName: string, sha: string): Promise<ReadResult>;
}

export class CommitService {
  private dao: CommitCacheDao;

  // R9 V2 + MVVM 无状态化：构造函数不再持有 PushDetailStore，
  // 取数结果走返回值（谁调谁更新：调用方 ViewModel 写自己的 UI 状态）。
  constructor(dao?: CommitCacheDao) {
    this.dao = dao !== undefined ? dao : new RepositoryDao();
  }

  async getCommitDetail(fullName: string,
                        sha: string,
                        onCached?: (detail: CommitDetail) => void): Promise<CommitServiceResult<CommitDetail>> {
    const owner: CommitOwnerNamePair = CommitOwnerNamePair.parse(fullName);
    if (owner.owner.length === 0 || owner.name.length === 0 || sha === null || sha.length === 0) {
      const msg: string = 'invalid params';
      return new CommitServiceResult<CommitDetail>(false, 0, null, msg);
    }
    const cached: CommitDetail | null = await this.readCommitCache(fullName, sha);
    if (cached !== null && onCached !== undefined && onCached !== null) {
      onCached(cached);
    }
    const url: string = Address.getCommitDetail(owner.owner, owner.name, sha);
    const httpResult: HttpResult<CommitDetail> = await HttpManager.getFetch<CommitDetail>(url);
    if (httpResult.result && httpResult.data !== null) {
      const data: CommitDetail = httpResult.data as CommitDetail;
      try {
        await this.dao.saveCommitInfoDetail(fullName, sha, JSON.stringify(data));
      } catch (_e) {
      }
      return new CommitServiceResult<CommitDetail>(true, httpResult.code, data, '');
    }
    if (cached !== null) {
      return new CommitServiceResult<CommitDetail>(true, httpResult.code, cached,
        httpResult.msg !== null ? httpResult.msg : '', true);
    }
    const msg: string = httpResult.msg !== null && httpResult.msg.length > 0
      ? httpResult.msg : 'network error';
    return new CommitServiceResult<CommitDetail>(false, httpResult.code, null, msg);
  }

  async getCommitDiff(fullName: string,
                      sha: string): Promise<CommitServiceResult<string>> {
    const owner: CommitOwnerNamePair = CommitOwnerNamePair.parse(fullName);
    if (owner.owner.length === 0 || owner.name.length === 0 || sha === null || sha.length === 0) {
      const msg: string = 'invalid params';
      return new CommitServiceResult<string>(false, 0, null, msg);
    }
    const url: string = Address.getCommitDiff(owner.owner, owner.name, sha);
    const headers: HttpHeaders = {};
    headers['Accept'] = COMMIT_DIFF_ACCEPT;
    const httpResult: HttpResult<string> = await HttpManager.getFetch<string>(url, headers);
    if (httpResult.result && httpResult.data !== null) {
      const text: string = httpResult.data as string;
      return new CommitServiceResult<string>(true, httpResult.code, text, '');
    }
    const msg: string = httpResult.msg !== null && httpResult.msg.length > 0
      ? httpResult.msg : 'network error';
    return new CommitServiceResult<string>(false, httpResult.code, null, msg);
  }

  static extractFiles(detail: CommitDetail | null): CommitFileItem[] {
    if (detail === null || detail.files === null || detail.files === undefined) {
      return [];
    }
    return detail.files.slice();
  }

  private async readCommitCache(fullName: string, sha: string): Promise<CommitDetail | null> {
    try {
      const cache: ReadResult = await this.dao.readCommitInfoDetail(fullName, sha);
      if (!cache.result || cache.data.length === 0) {
        return null;
      }
      const parsed: Object = JSON.parse(cache.data) as Object;
      return parsed as CommitDetail;
    } catch (_e) {
      return null;
    }
  }
}
