/**
 * Issue 域数据实体（R9 V2 + MVVM）。
 * 原 @Observed IssueDetailStore 页面级状态类已删除：issue 详情 / 评论列表等 UI 状态
 * 平移为 feature_repo 的 IssueDetailViewModel @Trace 字段；本文件只保留数据实体
 * interface 原地导出（IssueService / ViewModel / 测试共用）。
 */
export interface IssueUser {
  login: string;
  avatar_url: string;
  html_url: string;
}

export interface IssueDetailModel {
  id: number;
  number: number;
  title: string;
  body: string;
  body_html: string;
  state: string;
  locked: boolean;
  comments: number;
  user: IssueUser;
  created_at: string;
  updated_at: string;
  closed_at: string;
  html_url: string;
}

export interface IssueCommentModel {
  id: number;
  body: string;
  body_html: string;
  user: IssueUser;
  created_at: string;
  updated_at: string;
  html_url: string;
}

export const ISSUE_STATE_OPEN: string = 'open';
export const ISSUE_STATE_CLOSED: string = 'closed';
