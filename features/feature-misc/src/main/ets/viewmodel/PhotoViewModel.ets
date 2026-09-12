/**
 * PhotoViewModel —— 大图预览页状态与编排（R9 V2 + MVVM）。
 *
 * @Trace 状态（3 个）：图片 uri、加载中、加载失败。
 * 路由取参（RouteParamStore → NavPathStack 栈顶参数 → BOOT_PHOTO_KEY 兜底，
 * 测试通道语义原样保留）与“只退出一次”防重入收拢在此；
 * PhotoPage 只做图片展示、手势与 toast。
 */
import { NavigationService } from 'common';
import { RouteParamReader } from 'common';
import { RouteName } from 'common';
import { BOOT_PHOTO_KEY } from 'common';
import { Logger } from 'common';

interface PhotoPageRouteParam {
  uri: string;
}

const FALLBACK_URI: string = '';

@ObservedV2
export class PhotoViewModel {
  @Trace uri: string = '';
  @Trace loading: boolean = true;
  @Trace failed: boolean = false;
  private exit: boolean = false;

  /** View aboutToAppear 时调用：取参 + 启动日志（与原页面一致）。 */
  init(): void {
    this.applyRouterParams();
    Logger.i('boot/ts', `PhotoPage.aboutToAppear t=${Date.now()} uri='${this.uri}'`);
  }

  /** Image onComplete 转发。 */
  markLoaded(): void {
    this.loading = false;
  }

  /** Image onError 转发。 */
  markFailed(): void {
    this.loading = false;
    this.failed = true;
  }

  /** 点击空白退出（防重入，只 pop 一次）。 */
  dismiss(): void {
    if (this.exit) {
      return;
    }
    this.exit = true;
    Logger.i('boot/ts', `PhotoPage.dismiss t=${Date.now()}`);
    NavigationService.pop();
  }

  private resolveUriFromObject(raw: Object | undefined | null): string {
    if (raw === undefined || raw === null) {
      return FALLBACK_URI;
    }
    const obj: PhotoPageRouteParam = raw as PhotoPageRouteParam;
    if (obj.uri !== undefined && obj.uri !== null && obj.uri.length > 0) {
      return obj.uri;
    }
    return FALLBACK_URI;
  }

  private applyRouterParams(): void {
    // 优先级 1：RouteParamStore（NavigationService.push 同步写入，覆盖所有 push 入口）
    const routeRaw: Object | null = RouteParamReader.consumeStoreParam(RouteName.Photo);
    if (routeRaw !== null) {
      const resolvedFromRoute: string = this.resolveUriFromObject(routeRaw);
      if (resolvedFromRoute.length > 0) {
        this.uri = resolvedFromRoute;
        Logger.i('photo/route', `PhotoPage adopted via RouteParamStore uri='${resolvedFromRoute}'`);
        return;
      }
    }
    const stack: NavPathStack | null = NavigationService.getStack();
    if (stack !== null) {
      const raw: Object | null = RouteParamReader.readStackTopParam(stack);
      const resolved: string = this.resolveUriFromObject(raw);
      if (resolved.length > 0) {
        this.uri = resolved;
        return;
      }
    }
    if (this.uri.length === 0) {
      // BOOT 兜底是测试通道（阶段2C 统一处理），语义原样保留。
      const bootPhoto: string = RouteParamReader.readBootString(BOOT_PHOTO_KEY);
      if (bootPhoto.length > 0) {
        this.uri = bootPhoto;
      }
    }
  }
}
