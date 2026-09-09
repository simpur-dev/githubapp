/**
 * RepositoryDetailViewModel —— 仓库详情页状态与编排（R9 V2 + MVVM）。
 *
 * 原 V1 页面级 RepositoryDetailStore（common，本批保留给 ohosTest 宿主与下批 Issue 域）
 * 的字段语义在此平移为 @Trace UI 状态：
 *   detail / readme 双通道 / 事件列表 + 分页 / 提交列表 + 分页 / issues 列表 + 分页 /
 *   文件列表 + 目录栈 / 分支列表 + 当前分支 / star / watch / fork 状态 / 错误文案。
 * RepositoryService 已无状态化（不写 store），取数结果在这里写入 @Trace 字段；
 * 缓存先行的渐进渲染语义通过 service 的 onCached 回调保留。
 */
import {
  RepositoryService,
  RepositoryServiceResult,
  FetchReadmeResult,
  FetchStarWatchResult
} from 'common';
import {
  RepositoryDetail,
  RepositoryEventItem,
  RepositoryCommitItem,
  RepositoryFileItem,
  RepositoryIssueItem,
  ISSUE_STATE_ALL
} from 'common';
import { ReadHistoryService, ReadHistoryAddParam } from 'common';
import { READ_HISTORY_TYPE_REPO } from 'common';
import { Logger } from 'common';

const MASTER_BRANCH: string = 'master';

@ObservedV2
export class RepositoryDetailViewModel {
  /** 仓库全名（owner/name），路由 / BOOT 通道解析后由 View 调 setFullName 写入。 */
  @Trace fullName: string = '';
  /** 仓库详情（service 已 sanitize）。 */
  @Trace detail: RepositoryDetail | null = null;
  /** README 双通道：markdown 优先（原生渲染），html 兜底（WebView）。 */
  @Trace readmeHtml: string = '';
  @Trace readmeMarkdown: string = '';
  @Trace readmeLoading: boolean = false;
  @Trace readmeError: string = '';
  /** issues 列表（IssueTab @Prop 数据源）与筛选 / 搜索状态。 */
  @Trace issues: RepositoryIssueItem[] = [];
  @Trace issueState: string = ISSUE_STATE_ALL;
  @Trace issueSearchQuery: string = '';
  /** Activity tab：事件列表（select=0）与提交列表（select=1）。 */
  @Trace activity: RepositoryEventItem[] = [];
  @Trace commits: RepositoryCommitItem[] = [];
  @Trace activitySelect: number = 0;
  /** 文件列表与当前目录（面包屑数据源）。 */
  @Trace files: RepositoryFileItem[] = [];
  @Trace currentFilePath: string = '';
  /** star / watch 状态（底栏图标与文案）。 */
  @Trace starred: boolean = false;
  @Trace watching: boolean = false;
  /** 分支列表与当前分支（底栏 branch 项 + 分支选择 overlay）。 */
  @Trace branches: string[] = [];
  @Trace currentBranch: string = '';
  /** Activity 列表加载 / 分页 / 错误态。 */
  @Trace activityRefreshing: boolean = false;
  @Trace activityLoadingMore: boolean = false;
  @Trace activityNoMore: boolean = false;
  /** Issue 列表加载 / 分页 / 错误态。 */
  @Trace issueRefreshing: boolean = false;
  @Trace issueLoadingMore: boolean = false;
  @Trace issueNoMore: boolean = false;
  /** Files 列表加载 / 分页 / 错误态。 */
  @Trace filesRefreshing: boolean = false;
  @Trace filesLoadingMore: boolean = false;
  @Trace filesNoMore: boolean = false;
  /** 详情域错误文案（首屏 detail 取数失败）。 */
  @Trace errorMessage: string = '';

  private filePathStack: string[] = [];
  private activityPage: number = 1;
  private activityHasMore: boolean = true;
  private commitsPage: number = 1;
  private commitsHasMore: boolean = true;
  private issuePage: number = 1;
  private issueHasMore: boolean = true;
  private branchesLoaded: boolean = false;
  private service: RepositoryService = new RepositoryService();
  private readHistoryService: ReadHistoryService = new ReadHistoryService();

  /** 设置目标仓库（View 层从路由参数 / BOOT 通道解析后调用）。 */
  setFullName(fullName: string): void {
    this.fullName = fullName;
  }

  /** owner 段（fullName 首个 '/' 之前）。 */
  ownerName(): string {
    const idx: number = this.fullName.indexOf('/');
    if (idx <= 0) {
      return '';
    }
    return this.fullName.substring(0, idx);
  }

  /** 仓库段（fullName 首个 '/' 之后）。 */
  repositoryName(): string {
    const idx: number = this.fullName.indexOf('/');
    if (idx < 0 || idx >= this.fullName.length - 1) {
      return '';
    }
    return this.fullName.substring(idx + 1);
  }

  /** 默认分支：detail.default_branch 优先，兜底 master（原 resolveDefaultBranch 语义）。 */
  defaultBranch(): string {
    const d: RepositoryDetail | null = this.detail;
    if (d !== null && d.default_branch !== null && d.default_branch !== undefined
      && d.default_branch.length > 0) {
      return d.default_branch;
    }
    return MASTER_BRANCH;
  }

  /** 当前生效分支：currentBranch 优先，兜底默认分支（原 resolveCurrentBranch 语义）。 */
  currentBranchName(): string {
    return this.currentBranch.length > 0 ? this.currentBranch : this.defaultBranch();
  }

  /** 头部 more 菜单的 html_url。 */
  htmlUrl(): string {
    if (this.fullName.length === 0) {
      return '';
    }
    return 'https://github.com/' + this.fullName;
  }

  /**
   * 首屏加载（原 loadAll 串行编排语义一行不改）：
   * detail → star/watch 状态 → README → 事件 → issues → 文件 → 读历史。
   */
  async loadAll(): Promise<void> {
    if (this.fullName.length === 0) {
      return;
    }
    this.errorMessage = '';
    const infoRes: RepositoryServiceResult<RepositoryDetail> = await this.service.getReposInfo(
      this.fullName,
      (cached: RepositoryDetail): void => {
        this.applyDetail(cached);
      });
    if (infoRes.result && infoRes.data !== null) {
      this.applyDetail(infoRes.data);
    } else {
      this.errorMessage = infoRes.msg;
    }
    const starRes: FetchStarWatchResult = await this.service.getStarStatus(this.fullName);
    if (starRes.result) {
      this.starred = starRes.starred;
      this.watching = starRes.watching;
    }
    await this.fetchReadme(null);
    await this.refreshActivity();
    await this.refreshIssues();
    await this.refreshFiles('');
    await this.writeReadHistory();
  }

  /** README 取数 + @Trace 双通道写回（原 service 写 store 的语义平移）。 */
  private async fetchReadme(branch: string | null): Promise<void> {
    const defaultBranch: string = this.defaultBranch();
    this.readmeLoading = true;
    const res: FetchReadmeResult = await this.service.getReadme(
      this.fullName, branch, defaultBranch,
      (cachedHtml: string): void => {
        this.readmeHtml = cachedHtml;
        this.readmeLoading = false;
        this.readmeError = '';
      });
    if (res.markdown.length > 0) {
      this.readmeMarkdown = res.markdown;
      this.readmeHtml = '';
      this.readmeLoading = false;
      this.readmeError = '';
    } else if (res.html.length > 0) {
      this.readmeHtml = res.html;
      this.readmeLoading = false;
      this.readmeError = '';
    } else if (!res.result) {
      this.readmeLoading = false;
      this.readmeError = res.msg;
    }
  }

  // ── Activity tab（Events / Commits）──────────────────────────────────────────

  private applyActivityPage(events: RepositoryEventItem[], append: boolean, page: number): void {
    if (append) {
      const merged: RepositoryEventItem[] = this.activity.slice();
      for (let i: number = 0; i < events.length; i++) {
        merged.push(events[i]);
      }
      this.activity = merged;
    } else {
      this.activity = events.slice();
    }
    this.activityPage = page;
    this.activityHasMore = events.length >= this.service.getPageSize();
  }

  async refreshActivity(): Promise<void> {
    if (this.fullName.length === 0) {
      return;
    }
    this.activityRefreshing = true;
    this.activityLoadingMore = false;
    this.activityNoMore = false;
    const res: RepositoryServiceResult<RepositoryEventItem[]> = await this.service.getRepositoryEvents(
      this.fullName, 1,
      (cached: RepositoryEventItem[]): void => {
        this.applyActivityPage(cached, false, 1);
      });
    if (res.result && res.data !== null) {
      this.applyActivityPage(res.data, false, res.page);
    }
    this.activityRefreshing = false;
    this.activityLoadingMore = false;
    this.activityNoMore = !(this.activityHasMore);
  }

  async loadMoreActivity(): Promise<void> {
    if (!this.activityHasMore) {
      this.activityLoadingMore = false;
      this.activityNoMore = true;
      return;
    }
    const next: number = this.activityPage + 1;
    const res: RepositoryServiceResult<RepositoryEventItem[]> = await this.service.getRepositoryEvents(
      this.fullName, next);
    if (res.result && res.data !== null) {
      this.applyActivityPage(res.data, true, res.page);
    }
    this.activityLoadingMore = false;
    this.activityNoMore = !(this.activityHasMore);
  }

  private applyCommitsPage(items: RepositoryCommitItem[], append: boolean, page: number): void {
    if (append) {
      const merged: RepositoryCommitItem[] = this.commits.slice();
      for (let i: number = 0; i < items.length; i++) {
        merged.push(items[i]);
      }
      this.commits = merged;
    } else {
      this.commits = items.slice();
    }
    this.commitsPage = page;
    this.commitsHasMore = items.length >= this.service.getPageSize();
  }

  /**
   * ActivityTab 子 tab 切换：Compose 版 Info 仅包含 Events / Commits。
   * （原 handleActivitySelectChange 语义。）
   */
  async handleActivitySelectChange(sel: number): Promise<void> {
    this.activitySelect = sel;
    if (this.fullName.length === 0) {
      return;
    }
    if (sel === 1) {
      this.activityRefreshing = true;
      this.activityLoadingMore = false;
      this.activityNoMore = false;
      const res: RepositoryServiceResult<RepositoryCommitItem[]> =
        await this.service.getRepositoryCommits(
          this.fullName, 1, this.currentBranchName(), this.defaultBranch());
      if (res.result && res.data !== null) {
        this.applyCommitsPage(res.data, false, res.page);
      }
      this.activityRefreshing = false;
      this.activityLoadingMore = false;
      this.activityNoMore = !(this.commitsHasMore);
      return;
    }
  }

  async refreshCurrentActivityTab(): Promise<void> {
    if (this.activitySelect === 1) {
      await this.handleActivitySelectChange(1);
      return;
    }
    await this.refreshActivity();
  }

  async loadMoreCurrentActivityTab(): Promise<void> {
    if (this.activitySelect === 1) {
      if (!this.commitsHasMore) {
        this.activityLoadingMore = false;
        this.activityNoMore = true;
        return;
      }
      const next: number = this.commitsPage + 1;
      const res: RepositoryServiceResult<RepositoryCommitItem[]> =
        await this.service.getRepositoryCommits(
          this.fullName, next, this.currentBranchName(), this.defaultBranch());
      if (res.result && res.data !== null) {
        this.applyCommitsPage(res.data, true, res.page);
      }
      this.activityLoadingMore = false;
      this.activityNoMore = !(this.commitsHasMore);
      return;
    }
    await this.loadMoreActivity();
  }

  // ── Issue tab（本批只做列表读取编排；IssueTab 组件本体留给下批）───────────────

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

  /** 搜索提交（原 handleIssueSearch：重置分页后重拉）。 */
  async handleIssueSearch(): Promise<void> {
    this.issues = [];
    this.issuePage = 1;
    this.issueHasMore = true;
    await this.refreshIssues();
  }

  /**
   * 创建 Issue：无状态 service 只返回新建条目，「插到列表头部」在这里处理
   * （原 service.createIssue 写 store.issues / store.issueList 的语义平移）。
   * 返回 result 供 View 决定 toast 文案。
   */
  async createIssue(title: string, body: string): Promise<RepositoryServiceResult<RepositoryIssueItem | null>> {
    const res: RepositoryServiceResult<RepositoryIssueItem | null> =
      await this.service.createIssue(this.fullName, title, body);
    if (res.result && res.data !== null) {
      const merged: RepositoryIssueItem[] = [res.data];
      for (let i: number = 0; i < this.issues.length; i++) {
        merged.push(this.issues[i]);
      }
      this.issues = merged;
    }
    return res;
  }

  // ── Files tab ────────────────────────────────────────────────────────────────

  private applyFiles(files: RepositoryFileItem[]): void {
    this.files = files.slice();
  }

  async refreshFiles(path: string): Promise<void> {
    if (this.fullName.length === 0) {
      return;
    }
    // 先把 currentFilePath 落到目标路径，避免 PullLoadMoreList 内部
    // refresh 回调把旧路径（root）再带回来覆盖（dir 点进去刷回 root 的根因）。
    this.currentFilePath = path;
    this.filesRefreshing = true;
    this.filesLoadingMore = false;
    this.filesNoMore = false;
    const res: RepositoryServiceResult<RepositoryFileItem[]> = await this.service.getFiles(
      this.fullName, this.currentBranchName(), path, this.defaultBranch(),
      (cached: RepositoryFileItem[]): void => {
        this.applyFiles(cached);
      });
    if (res.result && res.data !== null) {
      this.applyFiles(res.data);
    }
    this.filesRefreshing = false;
    this.filesLoadingMore = false;
    this.filesNoMore = false;
  }

  /** 进入子目录（原 openFile 的 dir 分支：压栈后刷新）。 */
  async openDir(path: string): Promise<void> {
    this.filePathStack.push(this.currentFilePath);
    await this.refreshFiles(path);
  }

  /** 返回上一级目录（原 backFiles：栈空回 root）。 */
  async backFiles(): Promise<void> {
    if (this.filePathStack.length === 0) {
      await this.refreshFiles('');
      return;
    }
    const previous: string = this.filePathStack.pop() as string;
    await this.refreshFiles(previous);
  }

  // ── star / watch / fork / 分支 ───────────────────────────────────────────────

  async toggleStar(): Promise<RepositoryServiceResult<boolean>> {
    let res: RepositoryServiceResult<boolean>;
    if (this.starred) {
      res = await this.service.unstar(this.fullName);
    } else {
      res = await this.service.star(this.fullName);
    }
    if (res.result) {
      this.starred = res.data === true;
      const infoRes: RepositoryServiceResult<RepositoryDetail> =
        await this.service.getReposInfo(this.fullName);
      if (infoRes.result && infoRes.data !== null) {
        this.applyDetail(infoRes.data);
      }
    }
    return res;
  }

  async toggleWatch(): Promise<RepositoryServiceResult<boolean>> {
    let res: RepositoryServiceResult<boolean>;
    if (this.watching) {
      res = await this.service.unwatch(this.fullName);
    } else {
      res = await this.service.watch(this.fullName);
    }
    if (res.result) {
      this.watching = res.data === true;
      const infoRes: RepositoryServiceResult<RepositoryDetail> =
        await this.service.getReposInfo(this.fullName);
      if (infoRes.result && infoRes.data !== null) {
        this.applyDetail(infoRes.data);
      }
    }
    return res;
  }

  async doFork(): Promise<RepositoryServiceResult<boolean>> {
    const res: RepositoryServiceResult<boolean> = await this.service.forkRepository(this.fullName);
    if (res.result) {
      const infoRes: RepositoryServiceResult<RepositoryDetail> =
        await this.service.getReposInfo(this.fullName);
      if (infoRes.result && infoRes.data !== null) {
        this.applyDetail(infoRes.data);
      }
    }
    return res;
  }

  /**
   * 分支列表按需加载（原 openBranchSelector 的加载段）：
   * 返回是否拿到非空列表；写 branches @Trace 供 overlay 渲染。
   */
  async ensureBranchesLoaded(): Promise<boolean> {
    if (!this.branchesLoaded && this.branches.length === 0) {
      const res: RepositoryServiceResult<string[]> = await this.service.getBranches(this.fullName);
      if (res.result && res.data !== null) {
        this.branches = res.data.slice();
        this.branchesLoaded = true;
      }
    }
    return this.branches.length > 0;
  }

  /**
   * 切换分支后重拉 README + files + commits，对齐 Compose selectedBranch LaunchedEffect
   * （原 applyBranchChange 的数据段；toast 由 View 层处理）。
   */
  async applyBranchChange(branch: string): Promise<void> {
    if (branch.length === 0) {
      return;
    }
    this.currentBranch = branch;
    Logger.i('RepositoryDetailPage', `applyBranchChange branch=${branch}`);
    await this.fetchReadme(branch);
    this.currentFilePath = '';
    this.filePathStack = [];
    await this.refreshFilesWithBranch(branch);
    if (this.activitySelect === 1) {
      const res: RepositoryServiceResult<RepositoryCommitItem[]> =
        await this.service.getRepositoryCommits(
          this.fullName, 1, branch, this.defaultBranch());
      if (res.result && res.data !== null) {
        this.applyCommitsPage(res.data, false, res.page);
      }
    }
  }

  /** 指定分支拉文件（切分支路径：currentFilePath/栈已在 applyBranchChange 清空）。 */
  private async refreshFilesWithBranch(branch: string): Promise<void> {
    this.filesRefreshing = true;
    this.filesLoadingMore = false;
    this.filesNoMore = false;
    const res: RepositoryServiceResult<RepositoryFileItem[]> = await this.service.getFiles(
      this.fullName, branch, '', this.defaultBranch());
    if (res.result && res.data !== null) {
      this.applyFiles(res.data);
    }
    this.filesRefreshing = false;
    this.filesLoadingMore = false;
    this.filesNoMore = false;
  }

  // ── 内部 ─────────────────────────────────────────────────────────────────────

  private applyDetail(detail: RepositoryDetail): void {
    this.detail = detail;
    this.errorMessage = '';
  }

  private async writeReadHistory(): Promise<void> {
    if (this.fullName.length === 0) {
      return;
    }
    const d: RepositoryDetail | null = this.detail;
    let title: string = this.fullName;
    let subtitle: string = '';
    let avatar: string = '';
    let payloadJson: string = '';
    if (d !== null) {
      title = d.full_name.length > 0 ? d.full_name : this.fullName;
      subtitle = d.description.length > 0 ? d.description : d.language;
      avatar = d.owner !== null && d.owner !== undefined ? d.owner.avatar_url : '';
      payloadJson = JSON.stringify(d);
    }
    const param: ReadHistoryAddParam = {
      'type': READ_HISTORY_TYPE_REPO,
      'key': this.fullName,
      'title': title,
      'subtitle': subtitle,
      'avatar': avatar,
      'payloadJson': payloadJson,
      'time': Date.now(),
    } as ReadHistoryAddParam;
    await this.readHistoryService.add(param);
  }
}
