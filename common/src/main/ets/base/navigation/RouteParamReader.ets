/**
 * RouteParamReader —— 详情页「三层取参」统一读入口（R10 收敛）。
 *
 * 背景：RouteParamStore.consume → NavDestination ctx.pathInfo/stack → BootChannel 兜底
 *      的三层取参样板此前在约 8 个页面各自复制（每处 ~40 行），且各页 try/catch /
 *      栈顶取参写法略有漂移；本类把「从哪里读」收敛为单一入口，「字段语义拆分」
 *      （对象哪个字段是 owner、整串哪个位置是 branch）仍留在各页面/VM——各页参数
 *      形状不同（对象字段 vs '|' 分隔整串），强行统一会改语义。
 *
 * 三层来源（优先级由各页面按原顺序自行编排）：
 *   层 1  [consumeStoreParam] —— RouteParamStore.consume（NavigationService.push 同步
 *         写入的进程内槽，读到即清，一次性）；参数为原始 Object（各页自定义形状）。
 *   层 2  [readContextParam] / [readStackTopParam] —— NavDestinationContext.pathInfo.param
 *         与 NavPathStack 栈顶 param，原始 Object；onReady 早期接口可能未挂载
 *         （KI-029 "undefined is not callable"），必须 try/catch 包裹（本类已包）。
 *   层 3  [readBootString] —— BootChannel 直读 want.parameters 注入的测试通道整串
 *         （'owner/name|branch|path' 之类 '|' 分隔）。这里只 get 不清：
 *         600ms/1500ms 延迟清 key 时序由 EventActionDispatcher 保持；
 *         「读到即清」（UserDetail.tryAdoptBoot*）与「读到不合法不清、成功才清」
 *         （CodeDetail.tryAdoptBootCode）语义由调用方用 [consumeBootString] /
 *         [clearBootString] 按原样表达。
 *
 * 与 [RouteParamStore]/[BootChannel] 的关系：本类不引入新存储，只是读入口的
 * 统一门面；清 key 的时机判断（合法/不合法、立刻/延迟）全部不属于本类。
 */
import { RouteName } from './Routes';
import { RouteParamStore } from './RouteParamStore';
import { BootChannel } from '../launch/BootChannel';

export class RouteParamReader {
  /** 层 1：RouteParamStore 一次性消费（原始 Object 原样返回，读到即清；无参返回 null）。 */
  static consumeStoreParam(routeName: RouteName | string): Object | null {
    return RouteParamStore.consume(routeName);
  }

  /**
   * 层 2：NavDestinationContext.pathInfo.param（原始 Object；无参或接口未就绪返回 null）。
   * try/catch 包裹与各页原实现一致（onReady 早期 pathInfo 可能未挂载）。
   */
  static readContextParam(ctx: NavDestinationContext): Object | null {
    try {
      const info: NavPathInfo | undefined = ctx.pathInfo;
      if (info !== undefined && info !== null && info.param !== undefined && info.param !== null) {
        return info.param as Object;
      }
    } catch (_e) {
      return null;
    }
    return null;
  }

  /**
   * 层 2 兜底：NavPathStack 栈顶 param（原始 Object；栈空/无参/接口未就绪返回 null）。
   * getAllPathName + getParamByIndex(最后一项)，try/catch 包裹与各页原实现一致。
   */
  static readStackTopParam(stack: NavPathStack): Object | null {
    try {
      const all: string[] = stack.getAllPathName();
      if (all === undefined || all === null || all.length === 0) {
        return null;
      }
      const param: Object | undefined = stack.getParamByIndex(all.length - 1) as Object | undefined;
      if (param === undefined || param === null) {
        return null;
      }
      return param as Object;
    } catch (_e) {
      return null;
    }
  }

  /** 层 3：BootChannel 整串直读（get 不清；缺失返回 ''，清 key 时序由调用方保持）。 */
  static readBootString(bootKey: string): string {
    return BootChannel.get(bootKey);
  }

  /** 层 3 变体：读并立即清（仅原实现「读到即清」的调用方使用，如 tryAdoptBoot*）。 */
  static consumeBootString(bootKey: string): string {
    return BootChannel.consume(bootKey);
  }

  /** 层 3 写空（「读到不合法不清、成功才清」的调用方在解析成功后调用）。 */
  static clearBootString(bootKey: string): void {
    BootChannel.set(bootKey, '');
  }

  /**
   * '|' 分割整串：保序、不 trim、不做 URL/语义解码；空段保留为 ''（由调用方判空）。
   * 供层 3 整串（'owner/name|branch|path' 之类）的页面侧字段拆分使用；
   * 位置→语义的映射（哪个位置是 owner、哪个是 branch）仍留在各页面。
   */
  static splitFields(raw: string): string[] {
    if (raw === null || raw === undefined || raw.length === 0) {
      return [];
    }
    return raw.split('|');
  }
}
