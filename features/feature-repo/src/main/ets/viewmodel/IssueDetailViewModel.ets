/**
 * IssueDetailViewModel —— Issue 详情页状态与编排（R9 V2 + MVVM）。
 *
 * 原 V1 页面级 IssueDetailStore（common，本批已删除）的字段语义平移为 @Trace UI 状态：
 *   issue 详情 / 评论列表 + 分页 / 错误文案；权限组合判定（canReply / canEditIssue /
 *   canOpenClose / canLockUnlock，底层 IssuePermissionUtil 保留）从页面移入；
 *   三组编辑弹层（回复 / 编辑 issue / 编辑评论）的开关与草稿状态也在 VM；
 *   评论增删改 / 锁 / 开关 issue 编排调 IssueService（已无状态化，只返回数据）。
 * 登录态直读 GlobalAuthStore 单例。
 */
import {
  IssueService,
  IssueServiceResult,
  IssueDetailModel,
  IssueCommentModel,
  ISSUE_STATE_OPEN,
  IssuePermissionUtil,
  GlobalAuthStore,
  Logger
} from 'common';

const FALLBACK_FULL_NAME: string = '';
const FALLBACK_NUMBER: number = 0;

@ObservedV2
export class IssueDetailViewModel {
  /** issue 详情（cache-first 渐进渲染：先 onCached 回调，后网络结果）。 */
  @Trace issue: IssueDetailModel | null = null;
  /** 评论列表与分页 / 加载态。 */
  @Trace comments: IssueCommentModel[] = [];
  @Trace commentRefreshing: boolean = false;
  @Trace commentLoadingMore: boolean = false;
  @Trace commentNoMore: boolean = false;
  /** 详情域错误 / 加载文案（issue 为 null 时头部展示）。 */
  @Trace errorMessage: string = '';

  /** 权限判定结果（issue 数据或登录态变化时重算，底层 IssuePermissionUtil 保留）。 */
  @Trace canReply: boolean = false;
  @Trace canEditIssue: boolean = false;
  @Trace canOpenCloseIssue: boolean = false;
  @Trace canLockUnlockIssue: boolean = false;

  /** 操作 busy 态（关/开、锁、评论增删改进行中，防重复触发）。 */
  @Trace actionBusy: boolean = false;

  /** 回复弹层（issue_reply_dialog_*）开关与草稿。 */
  @Trace replySheetOpen: boolean = false;
  @Trace replyDraft: string = '';
  /** 编辑 issue 弹层（issue_edit_dialog_*）开关与草稿。 */
  @Trace editIssueSheetOpen: boolean = false;
  @Trace editIssueTitleDraft: string = '';
  @Trace editIssueBodyDraft: string = '';
  /** 编辑评论弹层（issue_comment_edit_dialog_*）开关与草稿。 */
  @Trace editCommentSheetOpen: boolean = false;
  @Trace editCommentDraft: string = '';

  private fullName: string = FALLBACK_FULL_NAME;
  private issueNumber: number = FALLBACK_NUMBER;
  private commentPage: number = 1;
  private commentHasMore: boolean = true;
  /** 长按选中的评论（编辑 / 删除目标）。 */
  private pendingCommentId: number = 0;
  private pendingCommentRowIndex: number = -1;
  /** 仓库主人标记（fullName owner 与当前登录一致的缓存）。 */
  private repoOwner: boolean = false;
  private service: IssueService = new IssueService();

  /** 绑定目标 issue（View 层从路由 / BOOT 通道解析后调用）。 */
  setTarget(fullName: string, number: number): void {
    this.fullName = fullName !== null && fullName !== undefined ? fullName : FALLBACK_FULL_NAME;
    this.issueNumber = number !== null && number !== undefined ? number : FALLBACK_NUMBER;
    this.repoOwner = IssuePermissionUtil.isRepoOwner(this.fullName, this.currentLogin());
  }

  targetFullName(): string {
    return this.fullName;
  }

  targetNumber(): number {
    return this.issueNumber;
  }

  /** AppBar 标题数据：'#编号 标题'（issue 未到时为 '#编号' 或空串）。 */
  appBarTitle(): string {
    const issue: IssueDetailModel | null = this.issue;
    const prefix: string = this.issueNumber > 0 ? '#' + this.issueNumber.toString() : '';
    if (issue !== null && issue.title !== null && issue.title !== undefined && issue.title.length > 0) {
      return prefix + ' ' + issue.title;
    }
    return prefix;
  }

  /** issue 是否处于 open 态（底栏关/开文案与开关动作共用）。 */
  isIssueOpen(): boolean {
    const issue: IssueDetailModel | null = this.issue;
    if (issue === null) {
      return true;
    }
    return issue.state === ISSUE_STATE_OPEN;
  }

  /** 当前 issue 是否锁定。 */
  isIssueLocked(): boolean {
    const issue: IssueDetailModel | null = this.issue;
    return issue !== null ? issue.locked : false;
  }

  /** 当前登录名（GlobalAuthStore 单例直读）。 */
  currentLogin(): string {
    if (GlobalAuthStore.userInfo !== null && GlobalAuthStore.userInfo !== undefined) {
      return GlobalAuthStore.userInfo.login;
    }
    return '';
  }

  /** 评论是否可管理（仓库主人或评论作者本人）。 */
  canManageComment(item: IssueCommentModel): boolean {
    if (this.repoOwner) {
      return true;
    }
    const login: string = this.currentLogin();
    if (login.length === 0) {
      return false;
    }
    return item.user.login === login;
  }

  /** 底栏是否可见（四个权限任一成立）。 */
  shouldShowBottomBar(): boolean {
    return this.canReply || this.canEditIssue || this.canOpenCloseIssue || this.canLockUnlockIssue;
  }

  // ── 取数 ─────────────────────────────────────────────────────────────────────

  /** 首屏加载（原 loadAll 串行编排语义一行不改）：issue 详情 → 评论第一页。 */
  async loadAll(): Promise<void> {
    if (this.fullName.length === 0 || this.issueNumber <= 0) {
      return;
    }
    await this.fetchIssue();
    await this.refreshComments();
  }

  private async fetchIssue(): Promise<void> {
    const res: IssueServiceResult<IssueDetailModel> = await this.service.getIssue(
      this.fullName, this.issueNumber,
      (cached: IssueDetailModel): void => {
        this.applyIssue(cached);
      });
    if (res.result && res.data !== null) {
      this.applyIssue(res.data);
    } else if (!res.result && this.issue === null) {
      this.errorMessage = res.msg;
    }
  }

  private applyIssue(issue: IssueDetailModel): void {
    this.issue = issue;
    this.errorMessage = '';
    this.recomputePermissions();
  }

  /** 权限组合判定（原页面 isIssueOwner/isRepoOwner/canXxx 系列语义平移）。 */
  private recomputePermissions(): void {
    const issue: IssueDetailModel | null = this.issue;
    if (issue === null) {
      this.canReply = false;
      this.canEditIssue = false;
      this.canOpenCloseIssue = false;
      this.canLockUnlockIssue = false;
      return;
    }
    const isIssueOwner: boolean = issue.user.login === this.currentLogin()
      && this.currentLogin().length > 0;
    const locked: boolean = issue.locked;
    this.canReply = IssuePermissionUtil.canReply(this.repoOwner, isIssueOwner, locked);
    this.canEditIssue = IssuePermissionUtil.canEdit(this.repoOwner, isIssueOwner, locked);
    this.canOpenCloseIssue = IssuePermissionUtil.canOpenClose(this.repoOwner, isIssueOwner);
    this.canLockUnlockIssue = IssuePermissionUtil.canLockUnlock(this.repoOwner);
  }

  // ── 评论列表分页 ─────────────────────────────────────────────────────────────

  private applyCommentsPage(items: IssueCommentModel[], append: boolean, page: number,
                            hasMore: boolean): void {
    if (append) {
      const merged: IssueCommentModel[] = this.comments.slice();
      for (let i: number = 0; i < items.length; i++) {
        merged.push(items[i]);
      }
      this.comments = merged;
    } else {
      this.comments = items.slice();
    }
    this.commentPage = page;
    this.commentHasMore = hasMore;
  }

  async refreshComments(): Promise<void> {
    if (this.fullName.length === 0 || this.issueNumber <= 0) {
      return;
    }
    this.commentRefreshing = true;
    this.commentLoadingMore = false;
    this.commentNoMore = false;
    const res: IssueServiceResult<IssueCommentModel[]> = await this.service.getComments(
      this.fullName, this.issueNumber, 1,
      (cached: IssueCommentModel[]): void => {
        this.applyCommentsPage(cached, false, 1, cached.length >= this.service.getPageSize());
      });
    if (res.result && res.data !== null) {
      this.applyCommentsPage(res.data, false, res.page, res.hasMore);
    }
    this.commentRefreshing = false;
    this.commentLoadingMore = false;
    this.commentNoMore = !(this.commentHasMore);
  }

  async loadMoreComments(): Promise<void> {
    if (!this.commentHasMore) {
      this.commentLoadingMore = false;
      this.commentNoMore = true;
      return;
    }
    const next: number = this.commentPage + 1;
    const res: IssueServiceResult<IssueCommentModel[]> = await this.service.getComments(
      this.fullName, this.issueNumber, next);
    if (res.result && res.data !== null) {
      this.applyCommentsPage(res.data, true, res.page, res.hasMore);
    }
    this.commentLoadingMore = false;
    this.commentNoMore = !(this.commentHasMore);
  }

  // ── 弹层开关与草稿 ───────────────────────────────────────────────────────────

  /** 长按/点按评论选中（编辑 / 删除目标 + 编辑草稿）。 */
  selectComment(item: IssueCommentModel, index: number): void {
    this.pendingCommentId = item.id;
    this.pendingCommentRowIndex = index;
    this.editCommentDraft = item.body !== null && item.body !== undefined ? item.body : '';
  }

  openReplySheet(): void {
    this.replyDraft = '';
    this.replySheetOpen = true;
  }

  closeReplySheet(): void {
    this.replySheetOpen = false;
  }

  /** 打开编辑 issue 弹层（用当前详情回填草稿）。 */
  openEditIssueSheet(): void {
    const issue: IssueDetailModel | null = this.issue;
    if (issue === null) {
      return;
    }
    this.editIssueTitleDraft = issue.title !== null && issue.title !== undefined ? issue.title : '';
    this.editIssueBodyDraft = issue.body !== null && issue.body !== undefined ? issue.body : '';
    this.editIssueSheetOpen = true;
  }

  closeEditIssueSheet(): void {
    this.editIssueSheetOpen = false;
  }

  /** 打开编辑评论弹层（草稿已在 selectComment 回填）。 */
  openEditCommentSheet(): void {
    if (this.pendingCommentId <= 0 || this.pendingCommentRowIndex < 0) {
      return;
    }
    this.editCommentSheetOpen = true;
  }

  closeEditCommentSheet(): void {
    this.editCommentSheetOpen = false;
  }

  // ── 写操作编排（service 已无状态，列表/计数的维护都在这里） ────────────────────

  /** 回复（创建评论）：成功后追加到列表尾部 + issue.comments +1。 */
  async submitReply(): Promise<IssueServiceResult<IssueCommentModel>> {
    const safe: string = this.replyDraft !== null && this.replyDraft !== undefined
      ? this.replyDraft.trim() : '';
    const fail: IssueServiceResult<IssueCommentModel> =
      new IssueServiceResult<IssueCommentModel>(false, 0, null, false, 'empty body');
    if (safe.length === 0 || this.fullName.length === 0 || this.issueNumber <= 0) {
      return fail;
    }
    this.actionBusy = true;
    const res: IssueServiceResult<IssueCommentModel> =
      await this.service.createComment(this.fullName, this.issueNumber, safe);
    this.actionBusy = false;
    Logger.i('issue/comment', `create result=${res.result} code=${res.code}`);
    if (res.result && res.data !== null) {
      const merged: IssueCommentModel[] = this.comments.slice();
      merged.push(res.data);
      this.comments = merged;
      this.replaceIssue((draft: IssueDetailModel): void => {
        draft.comments = draft.comments + 1;
      });
    }
    return res;
  }

  /** 编辑 issue：成功后用返回详情整体替换。 */
  async submitEditIssue(): Promise<IssueServiceResult<IssueDetailModel>> {
    const safeTitle: string = this.editIssueTitleDraft !== null && this.editIssueTitleDraft !== undefined
      ? this.editIssueTitleDraft.trim() : '';
    const fail: IssueServiceResult<IssueDetailModel> =
      new IssueServiceResult<IssueDetailModel>(false, 0, null, false, 'empty title');
    if (safeTitle.length === 0 || this.fullName.length === 0 || this.issueNumber <= 0) {
      return fail;
    }
    this.actionBusy = true;
    const res: IssueServiceResult<IssueDetailModel> = await this.service.editIssue(
      this.fullName, this.issueNumber, safeTitle, this.editIssueBodyDraft);
    this.actionBusy = false;
    Logger.i('issue/edit', `result=${res.result} code=${res.code}`);
    if (res.result && res.data !== null) {
      this.applyIssue(res.data);
    }
    return res;
  }

  /** 编辑评论：成功后按选中行替换。 */
  async submitEditComment(): Promise<IssueServiceResult<IssueCommentModel>> {
    const safe: string = this.editCommentDraft !== null && this.editCommentDraft !== undefined
      ? this.editCommentDraft.trim() : '';
    const fail: IssueServiceResult<IssueCommentModel> =
      new IssueServiceResult<IssueCommentModel>(false, 0, null, false, 'empty body');
    if (safe.length === 0 || this.pendingCommentRowIndex < 0 || this.pendingCommentId <= 0) {
      return fail;
    }
    this.actionBusy = true;
    const res: IssueServiceResult<IssueCommentModel> = await this.service.editComment(
      this.fullName, this.issueNumber, this.pendingCommentId, safe, this.pendingCommentRowIndex);
    this.actionBusy = false;
    Logger.i('comment/edit', `result=${res.result} code=${res.code} cid=${this.pendingCommentId}`);
    if (res.result && res.data !== null) {
      this.replaceCommentAt(this.pendingCommentRowIndex, res.data);
    }
    return res;
  }

  /** 删除选中的评论（selectComment 已登记目标）：成功后按行移除 + issue.comments -1。 */
  async deleteSelectedComment(): Promise<IssueServiceResult<boolean>> {
    const commentId: number = this.pendingCommentId;
    const rowIndex: number = this.pendingCommentRowIndex;
    const fail: IssueServiceResult<boolean> =
      new IssueServiceResult<boolean>(false, 0, null, false, 'no comment selected');
    if (commentId <= 0 || rowIndex < 0) {
      return fail;
    }
    return this.deleteComment(commentId, rowIndex);
  }

  /** 删除评论：成功后按行移除 + issue.comments -1（不小于 0）。 */
  async deleteComment(commentId: number, rowIndex: number): Promise<IssueServiceResult<boolean>> {
    const res: IssueServiceResult<boolean> =
      await this.service.deleteComment(this.fullName, this.issueNumber, commentId, rowIndex);
    Logger.i('comment/delete', `result=${res.result} code=${res.code} cid=${commentId} row=${rowIndex}`);
    if (res.result && res.data === true) {
      const merged: IssueCommentModel[] = this.comments.slice();
      if (rowIndex >= 0 && rowIndex < merged.length) {
        merged.splice(rowIndex, 1);
        this.comments = merged;
        this.replaceIssue((draft: IssueDetailModel): void => {
          const next: number = draft.comments - 1;
          draft.comments = next > 0 ? next : 0;
        });
      }
    }
    return res;
  }

  /** 关/开 issue（View 层 CommonModal.confirm 确认后调用；isOpen 为确认前的状态）。 */
  async runToggleIssueState(isOpen: boolean): Promise<IssueServiceResult<IssueDetailModel>> {
    if (this.fullName.length === 0 || this.issueNumber <= 0) {
      return new IssueServiceResult<IssueDetailModel>(false, 0, null, false, 'invalid params');
    }
    this.actionBusy = true;
    let res: IssueServiceResult<IssueDetailModel>;
    if (isOpen) {
      res = await this.service.closeIssue(this.fullName, this.issueNumber);
    } else {
      res = await this.service.reopenIssue(this.fullName, this.issueNumber);
    }
    this.actionBusy = false;
    Logger.i('issue/state', `result=${res.result} code=${res.code} wasOpen=${isOpen}`);
    if (res.result && res.data !== null) {
      this.applyIssue(res.data);
    }
    return res;
  }

  /** 锁/解锁 issue（View 层 CommonModal.confirm 确认后调用；currentLocked 为确认前状态）。 */
  async runToggleIssueLock(currentLocked: boolean): Promise<IssueServiceResult<boolean>> {
    if (this.fullName.length === 0 || this.issueNumber <= 0) {
      return new IssueServiceResult<boolean>(false, 0, null, false, 'invalid params');
    }
    this.actionBusy = true;
    const res: IssueServiceResult<boolean> =
      await this.service.toggleIssueLock(this.fullName, this.issueNumber, currentLocked);
    this.actionBusy = false;
    Logger.i('issue/lock', `result=${res.result} code=${res.code} wasLocked=${currentLocked}`);
    if (res.result && res.data === true) {
      const nextLocked: boolean = !currentLocked;
      this.replaceIssue((draft: IssueDetailModel): void => {
        draft.locked = nextLocked;
      });
      this.recomputePermissions();
    }
    return res;
  }

  /**
   * issue 是 interface（无观测能力），任何字段变更都要整体替换引用才会触发 @Trace。
   * 这里 JSON 深拷贝出草稿，由 mutator 改字段后重新赋值。
   */
  private replaceIssue(mutator: (draft: IssueDetailModel) => void): void {
    const current: IssueDetailModel | null = this.issue;
    if (current === null) {
      return;
    }
    const draft: IssueDetailModel = JSON.parse(JSON.stringify(current)) as IssueDetailModel;
    mutator(draft);
    this.applyIssue(draft);
  }

  private replaceCommentAt(index: number, item: IssueCommentModel): void {
    if (index < 0 || index >= this.comments.length) {
      return;
    }
    const merged: IssueCommentModel[] = this.comments.slice();
    merged.splice(index, 1, item);
    this.comments = merged;
  }
}
