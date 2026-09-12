import hilog from '@ohos.hilog';
import { RouteParamReader } from 'common';
import { RouteName } from 'common';
import { BOOT_WEB_KEY } from 'common';
import { CommonToast } from 'common';
import { I18n } from 'common';
import { Logger } from 'common';

const TAG: string = 'WebPage';
const DOMAIN: number = 0x0666;

interface WebPageRouteParam {
  uri: string;
}

/**
 * WebViewModel —— 通用 Web 浏览页状态与编排（R9 V2 + MVVM）。
 *
 * @Trace 状态（3 个）：当前 url、页面标题、页面 host。
 * 路由取参（RouteParamStore → pathInfo.param → BOOT_WEB_KEY 兜底，测试通道语义原样保留）、
 * url 规整 / host 解析 / 标题回填 / gsygithub:// 拦截全部收拢在此；
 * WebPage 只保留 WebviewController、重载动作与 UI 组装。
 */
@ObservedV2
export class WebViewModel {
  @Trace uri: string = '';
  @Trace pageTitle: string = '';
  @Trace pageHost: string = '';

  /** NavDestination onReady 转发：取参优先级与原页面一致。 */
  initFromNavContext(ctx: NavDestinationContext): void {
    // 优先级 1：RouteParamStore（NavigationService.push 同步写入，覆盖所有 push 入口）
    const routeRaw: Object | null = RouteParamReader.consumeStoreParam(RouteName.WebPage);
    if (routeRaw !== null) {
      const routeParam: WebPageRouteParam = routeRaw as WebPageRouteParam;
      if (routeParam.uri !== undefined && routeParam.uri !== null && routeParam.uri.length > 0) {
        Logger.i('web/route', `WebPage adopted via RouteParamStore uri=${routeParam.uri}`);
        this.adoptUri(routeParam.uri);
        return;
      }
    }
    let initial: string = '';
    const ctxParam: Object | null = RouteParamReader.readContextParam(ctx);
    if (ctxParam !== null) {
      const route: WebPageRouteParam = ctxParam as WebPageRouteParam;
      if (route.uri !== undefined && route.uri !== null && route.uri.length > 0) {
        initial = route.uri;
      }
    }
    this.adoptUri(initial);
  }

  private adoptUri(initial: string): void {
    let candidate: string = initial;
    if (candidate.length === 0) {
      // BOOT 兜底是测试通道（阶段2C 统一处理），语义原样保留。
      const fallback: string = RouteParamReader.readBootString(BOOT_WEB_KEY);
      if (fallback.length > 0) {
        candidate = fallback;
        Logger.i('boot/ts', `WebPage adopt BOOT_WEB_KEY fallback uri=${candidate}`);
      }
    }
    this.uri = WebViewModel.resolveUrl(candidate);
    this.pageHost = WebViewModel.parseHost(this.uri);
    hilog.info(DOMAIN, TAG, '[web/page] init uri=%{public}s', this.uri);
  }

  private static resolveUrl(raw: string): string {
    if (raw.length === 0) {
      return '';
    }
    if (/^[a-zA-Z][a-zA-Z0-9+\-.]*:/.test(raw)) {
      return raw;
    }
    return 'http://' + raw;
  }

  private static parseHost(url: string): string {
    if (url.length === 0) {
      return '';
    }
    const schemeEnd: number = url.indexOf('://');
    if (schemeEnd < 0) {
      return url;
    }
    const rest: string = url.substring(schemeEnd + 3);
    const slash: number = rest.indexOf('/');
    return slash < 0 ? rest : rest.substring(0, slash);
  }

  /** AppBar 标题求值（View 在 build 内调用，读 @Trace 字段保持响应）。 */
  displayTitle(): string {
    if (this.pageTitle.length > 0) {
      return this.pageTitle;
    }
    return this.pageHost.length > 0 ? this.pageHost : 'WebPage';
  }

  /** Web onTitleReceive 转发。 */
  onTitleReceived(title: string): void {
    this.pageTitle = title;
  }

  /** Web onPageEnd 转发：刷新 host 展示 + 日志。 */
  onPageFinished(url: string): void {
    this.pageHost = WebViewModel.parseHost(url);
    hilog.info(DOMAIN, TAG, '[web/page] onPageEnd url=%{public}s', url);
  }

  /** Web onLoadIntercept 转发：gsygithub:// 占位提示并拦截，其余放行。 */
  interceptUrl(url: string): boolean {
    if (url.length === 0) {
      return false;
    }
    if (url.indexOf('gsygithub://') === 0) {
      hilog.info(DOMAIN, TAG, '[web/anchor] gsygithub anchor url=%{public}s', url);
      CommonToast.showShort(I18n('webRelativeLinkNeedRepoContext'));
      return true;
    }
    if (url.indexOf('https://github.com/') === 0 || url.indexOf('http://github.com/') === 0) {
      hilog.info(DOMAIN, TAG, '[web/intercept] github candidate url=%{public}s', url);
      return false;
    }
    return false;
  }
}
