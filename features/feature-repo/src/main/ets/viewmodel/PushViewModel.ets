/**
 * PushViewModel —— 提交（commit）详情页状态与编排（R9 V2 + MVVM）。
 *
 * 原 V1 页面级 PushDetailStore（common，已随无状态化删除）的字段语义平移为
 * @Trace UI 状态：提交详情 + 文件列表 + 错误文案；CommitService 已无状态化
 * （cache-first 经 onCached 回调，不写 store），取数结果在这里写回 @Trace 字段。
 */
import {
  CommitService,
  CommitServiceResult,
  CommitDetail,
  CommitFileItem,
  Logger
} from 'common';

const FALLBACK_FULL_NAME: string = '';
const FALLBACK_SHA: string = '';

@ObservedV2
export class PushViewModel {
  /** 目标仓库与 commit sha（View 层从路由 / BOOT 通道解析后调用 setTarget）。 */
  @Trace fullName: string = FALLBACK_FULL_NAME;
  @Trace sha: string = FALLBACK_SHA;
  /** 提交详情与文件列表。 */
  @Trace commit: CommitDetail | null = null;
  @Trace files: CommitFileItem[] = [];
  /** 加载 / 错误态。 */
  @Trace loading: boolean = false;
  @Trace error: string = '';

  private service: CommitService = new CommitService();

  /** 绑定目标 commit（fullName / sha 变化时清旧数据，由 View 在取参后调用）。 */
  setTarget(fullName: string, sha: string): void {
    const nextFullName: string = fullName !== null && fullName !== undefined ? fullName : FALLBACK_FULL_NAME;
    const nextSha: string = sha !== null && sha !== undefined ? sha : FALLBACK_SHA;
    if (nextFullName !== this.fullName || nextSha !== this.sha) {
      this.commit = null;
      this.files = [];
      this.error = '';
    }
    this.fullName = nextFullName;
    this.sha = nextSha;
  }

  /** 文件列表项 key（Repeat virtualScroll 用，sha + 文件名稳定且唯一）。 */
  fileKey(item: CommitFileItem, index: number): string {
    return 'pf_' + index.toString() + '_' + item.sha + '_' + item.filename;
  }

  /** 首屏加载：cache-first（onCached 先渲染缓存）→ 网络刷新。 */
  async loadAll(): Promise<void> {
    if (this.fullName.length === 0 || this.sha.length === 0) {
      Logger.i('boot/ts', `PushViewModel.loadAll skip empty fullName='${this.fullName}' sha='${this.sha}'`);
      return;
    }
    Logger.i('boot/ts', `PushViewModel.loadAll BEGIN fullName='${this.fullName}' sha='${this.sha}'`);
    this.loading = true;
    const res: CommitServiceResult<CommitDetail> = await this.service.getCommitDetail(
      this.fullName, this.sha,
      (cached: CommitDetail): void => {
        this.applyCommit(cached);
      });
    if (res.result && res.data !== null) {
      this.applyCommit(res.data);
    } else if (!res.result && this.commit === null) {
      this.error = res.msg;
    }
    this.loading = false;
    const files: CommitFileItem[] = this.files;
    Logger.i('boot/ts', `PushViewModel.loadAll done result=${res.result} code=${res.code}`
      + ` commit=${this.commit !== null} files=${files.length}`);
  }

  private applyCommit(detail: CommitDetail): void {
    this.commit = detail;
    this.files = CommitService.extractFiles(detail);
    this.loading = false;
    this.error = '';
  }
}
