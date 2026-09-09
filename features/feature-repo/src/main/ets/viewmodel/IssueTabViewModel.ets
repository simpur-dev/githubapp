/**
 * IssueTabViewModel —— 仓库详情 Issue 列表 tab（列表 + 分页 + 筛选 + 搜索）状态与编排
 * （R9 V2 + MVVM）。
 *
 * 原先散在 RepositoryDetailViewModel / IssueTab（V1 @Prop）里的 issues 列表、
 * open/closed/all 筛选、搜索关键字与分页状态在此收敛为 @Trace UI 状态；
 * RepositoryService 已无状态化（不写 store），取数结果在这里写回 @Trace 字段。
 * 创建 Issue 的编排（service 只返回新建条目，「插到列表头部」）也在这里处理。
 */
import {
  RepositoryService,
  RepositoryServiceResult,
  RepositoryIssueItem,
  ISSUE_STATE_ALL
} from 'common';
import { Logger } from 'common';

@ObservedV2
export class IssueTabViewModel {
  /** 目标仓库全名（owner/name），View 层从路由 / BOOT 通道解析后调用 loadAll 绑定。 */
  @Trace fullName: string = '';
  /** issues 列表数据源。 */
  @Trace issues: RepositoryIssueItem[] = [];
  /** open / closed / all 筛选态。 */
  @Trace issueState: string = ISSUE_STATE_ALL;
  /** 搜索框输入（未提交）。 */
  @Trace issueSearchQuery: string = '';
  /** 加载 / 分页 / 错误态。 */
  @Trace issueRefreshing: boolean = false;
  @Trace issueLoadingMore: boolean = false;
  @Trace issueNoMore: boolean = false;
  @Trace errorMessage: string = '';

  private issuePage: number = 1;
  private issueHasMore: boolean = true;
  private service: RepositoryService = new RepositoryService();

  /** 绑定目标仓库（fullName 变化时重置列表与筛选，由 View 在取参后调用）。 */
  async loadAll(fullName: string): Promise<void> {
    if (fullName === null || fullName === undefined || fullName.length === 0) {
      return;
    }
    if (this.fullName !== fullName) {
      this.fullName = fullName;
      this.issues = [];
      this.issueState = ISSUE_STATE_ALL;
      this.issueSearchQuery = '';
      this.issuePage = 1;
      this.issueHasMore = true;
    }
    await this.refreshIssues();
  }

  /** 列表项 key（virtualScroll 用业务 id，保证 splice 后行复用稳定）。 */
  issueKey(item: RepositoryIssueItem, index: number): string {
    return 'issue_' + item.id.toString() + '_' + item.number.toString() + '_' + index.toString();
  }

  private applyIssuesPage(items: RepositoryIssueItem[], append: boolean, page: number): void {
    if (append) {
      const merged: RepositoryIssueItem[] = this.issues.slice();
      for (let i: number = 0; i < items.length; i++) {
        merged.push(items[i]);
      }
      this.issues = merged;
    } else {
      this.issues = items.slice();
    }
    this.issuePage = page;
    this.issueHasMore = items.length >= this.service.getPageSize();
  }

  async refreshIssues(): Promise<void> {
    if (this.fullName.length === 0) {
      return;
    }
    this.issueRefreshing = true;
    this.issueLoadingMore = false;
    this.issueNoMore = false;
    const res: RepositoryServiceResult<RepositoryIssueItem[]> = await this.service.getIssues(
      this.fullName, this.issueState, 1, this.issueSearchQuery,
      (cached: RepositoryIssueItem[]): void => {
        this.applyIssuesPage(cached, false, 1);
      });
    if (res.result && res.data !== null) {
      this.applyIssuesPage(res.data, false, res.page);
      this.errorMessage = '';
    } else if (!res.result && this.issues.length === 0) {
      this.errorMessage = res.msg;
    }
    this.issueRefreshing = false;
    this.issueLoadingMore = false;
    this.issueNoMore = !(this.issueHasMore);
  }

  async loadMoreIssues(): Promise<void> {
    if (!this.issueHasMore) {
      this.issueLoadingMore = false;
      this.issueNoMore = true;
      return;
    }
    const next: number = this.issuePage + 1;
    const res: RepositoryServiceResult<RepositoryIssueItem[]> = await this.service.getIssues(
      this.fullName, this.issueState, next, this.issueSearchQuery);
    if (res.result && res.data !== null) {
      this.applyIssuesPage(res.data, true, res.page);
    }
    this.issueLoadingMore = false;
    this.issueNoMore = !(this.issueHasMore);
  }

  /** 切换 open / closed / all 筛选（原 handleIssueStateChange：重置分页后重拉）。 */
  async handleIssueStateChange(state: string): Promise<void> {
    if (state === this.issueState) {
      return;
    }
    this.issueState = state;
    this.issues = [];
    this.issuePage = 1;
    this.issueHasMore = true;
    await this.refreshIssues();
  }

  /** 搜索框输入回写（原 handleIssueSearchQueryChange）。 */
  setIssueSearchQuery(query: string): void {
    this.issueSearchQuery = query !== null && query !== undefined ? query : '';
  }

  /** 搜索提交 / 清空后重搜（原 handleIssueSearch：重置分页后重拉）。 */
  async handleIssueSearch(): Promise<void> {
    if (this.fullName.length === 0) {
      return;
    }
    this.issues = [];
    this.issuePage = 1;
    this.issueHasMore = true;
    await this.refreshIssues();
  }

  /**
   * 创建 Issue：无状态 service 只返回新建条目，「插到列表头部」在这里处理
   * （原 RepositoryDetailViewModel.createIssue 的列表插入语义平移）。
   * 返回 result 供 View 决定 toast 文案。
   */
  async createIssue(title: string, body: string): Promise<RepositoryServiceResult<RepositoryIssueItem | null>> {
    const res: RepositoryServiceResult<RepositoryIssueItem | null> =
      await this.service.createIssue(this.fullName, title, body);
    if (res.result && res.data !== null) {
      Logger.i('IssueTabViewModel', `createIssue ok number=${res.data.number}`);
      const merged: RepositoryIssueItem[] = [res.data];
      for (let i: number = 0; i < this.issues.length; i++) {
        merged.push(this.issues[i]);
      }
      this.issues = merged;
    }
    return res;
  }
}
