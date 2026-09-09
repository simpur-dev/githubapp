/**
 * 仓库详情域数据实体（R9 V2 + MVVM）。
 * 原 @Observed RepositoryDetailStore 页面级状态类已删除：详情 / readme / issues /
 * activity / files / commits / 分支等 UI 状态平移为 feature_repo 的
 * RepositoryDetailViewModel（含 IssueTabViewModel）@Trace 字段；
 * 本文件只保留数据实体 interface 原地导出（service / ViewModel / 测试共用）。
 */
export interface RepositoryOwner {
  login: string;
  avatar_url: string;
  html_url: string;
}

export interface RepositoryParent {
  full_name: string;
}

export interface RepositoryLicense {
  name: string;
}

export interface RepositoryDetail {
  id: number;
  name: string;
  full_name: string;
  description: string;
  default_branch: string;
  html_url: string;
  language: string;
  stargazers_count: number;
  watchers_count: number;
  forks_count: number;
  open_issues_count: number;
  subscribers_count: number;
  owner: RepositoryOwner;
  size?: number;
  fork?: boolean;
  parent?: RepositoryParent | null;
  topics?: string[];
  license?: RepositoryLicense | null;
  created_at?: string;
  pushed_at?: string;
}

export interface RepositoryEventActor {
  login: string;
  avatar_url: string;
}

export interface RepositoryEventRepo {
  id: number;
  name: string;
}

export interface RepositoryEventItem {
  id: string;
  type: string;
  actor: RepositoryEventActor;
  repo: RepositoryEventRepo;
  created_at: string;
  payload: Record<string, Object>;
}

export interface RepositoryCommitAuthor {
  name: string;
  email: string;
  date: string;
}

export interface RepositoryCommitDetail {
  message: string;
  author: RepositoryCommitAuthor;
  committer: RepositoryCommitAuthor;
}

export interface RepositoryCommitUser {
  login: string;
  avatar_url: string;
}

export interface RepositoryCommitItem {
  sha: string;
  commit: RepositoryCommitDetail;
  author?: RepositoryCommitUser | null;
  committer?: RepositoryCommitUser | null;
}

export interface RepositoryPulseData {
  weekOpenedCount: number;
  weekClosedCount: number;
  description: string;
}

export interface RepositoryIssueUser {
  login: string;
  avatar_url: string;
}

export interface RepositoryIssueItem {
  id: number;
  number: number;
  title: string;
  body: string;
  state: string;
  user: RepositoryIssueUser;
  comments: number;
  created_at: string;
  updated_at: string;
  html_url: string;
}

export interface RepositoryFileItem {
  name: string;
  path: string;
  sha: string;
  size: number;
  type: string;
  download_url: string;
  html_url: string;
}

export const ISSUE_STATE_OPEN: string = 'open';
export const ISSUE_STATE_CLOSED: string = 'closed';
export const ISSUE_STATE_ALL: string = 'all';
