/**
 * CodeViewModel —— 代码文件详情页状态与编排（R9 V2 + MVVM）。
 *
 * 原 V1 页面级 CodeDetailStore（common，保留给纯 store 行为测试）的字段语义平移为
 * @Trace UI 状态：路径（fullName / branch / sha / path）+ 文件内容双通道
 * （content：markdown/raw 原文走原生 MarkdownRenderer；htmlContent：高亮 HTML 走 WebView）
 * + 加载 / 错误态。CodeService 已无状态化（双通道结果走返回值，cache-first 经
 * onCached 回调），取数结果在这里写回 @Trace 字段。
 */
import {
  CodeService,
  FetchCodeContentResult,
  Logger
} from 'common';

const FALLBACK_FULL_NAME: string = '';
const FALLBACK_BRANCH: string = 'master';
const FALLBACK_SHA: string = '';
const FALLBACK_PATH: string = '';

@ObservedV2
export class CodeViewModel {
  /** 目标文件路径四元组（View 层从路由 / BOOT 通道解析后调用 setTarget）。 */
  @Trace fullName: string = FALLBACK_FULL_NAME;
  @Trace branch: string = FALLBACK_BRANCH;
  @Trace sha: string = FALLBACK_SHA;
  @Trace path: string = FALLBACK_PATH;
  /** 内容双通道：markdown/raw 原文（MarkdownRenderer）与高亮 HTML（WebView）。 */
  @Trace content: string = '';
  @Trace htmlContent: string = '';
  /** 加载 / 错误态。 */
  @Trace loading: boolean = false;
  @Trace error: string = '';

  private service: CodeService = new CodeService();

  /**
   * 绑定目标文件（任一字段变化即清旧内容，由 View 在取参后调用；
   * 路由命中时 sha 置空的语义与原 tryAdoptRouteStore 一致，由 View 显式传）。
   */
  setTarget(fullName: string, branch: string, sha: string, path: string): void {
    this.fullName = fullName !== null && fullName !== undefined ? fullName : FALLBACK_FULL_NAME;
    this.branch = branch !== null && branch !== undefined && branch.length > 0
      ? branch : FALLBACK_BRANCH;
    this.sha = sha !== null && sha !== undefined ? sha : FALLBACK_SHA;
    this.path = path !== null && path !== undefined ? path : FALLBACK_PATH;
    this.content = '';
    this.htmlContent = '';
    this.error = '';
  }

  /** 首屏加载：sha 通道（commit 文件 patch）优先，否则 branch 通道（raw/HTML 双通道）。 */
  async loadAll(): Promise<void> {
    if (this.fullName.length === 0 || this.path.length === 0) {
      this.error = 'invalid params';
      return;
    }
    Logger.i('CodeDetail',
      `loadAll BEGIN fullName=${this.fullName} branch=${this.branch} sha=${this.sha} path=${this.path}`);
    this.loading = true;
    let res: FetchCodeContentResult;
    if (this.sha.length > 0) {
      res = await this.service.getCommitFile(this.fullName, this.sha, this.path);
    } else {
      res = await this.service.getRawContent(
        this.fullName, this.branch, this.path,
        (cachedContent: string, cachedHtml: string): void => {
          this.content = cachedContent;
          this.htmlContent = cachedHtml;
          this.loading = false;
          this.error = '';
        });
    }
    if (res.result) {
      this.content = res.content;
      this.htmlContent = res.html;
      this.loading = false;
      this.error = '';
    } else if (this.htmlContent.length === 0) {
      this.loading = false;
      this.error = res.msg;
    }
    Logger.i('CodeDetail',
      `loadAll END htmlLen=${this.htmlContent.length} err=${this.error}`);
  }
}
