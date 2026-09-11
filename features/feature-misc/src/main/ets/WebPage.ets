/**
 * WebPage —— L6.5 通用 Web 浏览页（github 站外链兜底 + gsygithub:// 业务深链回归）
 *
 * RN 基准 [WebPage.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/WebPage.js)：
 *   - 顶部地址栏 Row（chevron-back + URL TextInput + search-circle，primaryColor 背景）
 *   - WebView 主体（javaScriptEnabled / domStorageEnabled / mixedContentMode='always'）
 *   - resolveUrl 兜底加 'http://'
 *   - BackHandler 拦截硬件返回（webview.canGoBack ? webview.goBack() : Actions.pop()）
 *   - 入口：[htmlUtils.launchUrl#L380-L399](https://github.com/CarGuo/GSYGithubApp/blob/master/app/utils/htmlUtils.js#L380-L399)
 *           + [CustomWebComponent#L69](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/widget/CustomWebComponent.js#L69)
 *
 * OH 端 v1（OH 增强：地址栏 → AppBar）：
 *   - 顶部 AppBar（title=webController.getTitle 或 host fallback，rightActions=reload）
 *   - Web 组件主体（layoutWeight(1)）
 *   - onLoadIntercept：gsygithub:// 占位 hilog [web/anchor]；其他链接 return false 让 Web 自处理
 *   - 入口参数：{ uri: string }（与 RN 字段对齐）
 *   - boot 通道：want.parameters.bootWeb=<url>（KI-042 / KI-045 同款 BOOT_*_KEY 范式）
 *
 * R9 V2 + MVVM：uri/标题/host 状态、取参（含 BOOT 兜底语义）与拦截编排
 * 移入 WebViewModel（@ObservedV2 + @Trace）；本页仅保留 WebviewController、
 * 重载动作与 UI 组装。测试 id（web_page_*）一字不动。
 *
 * HARD-LAW 自检：
 *   - LAW-1 RN-FIRST：抽源 ui-parity/WebPage.md §1
 *   - LAW-2 token-only：颜色/字号/间距全走 GSYColor / GSYFontSize / GSYSpacing
 *   - LAW-3 NO-DEBUG-PROBE：UI 树仅 AppBar + Web；3 个 hilog tag [web/page]/[web/anchor]/[web/intercept]
 */
import webview from '@ohos.web.webview';
import hilog from '@ohos.hilog';
import { NavTitleAction, NavTitleBridge, NavTitleConfig, RouteName } from 'common';
import { ThemeManager } from 'common';
import { WebViewModel } from './viewmodel/WebViewModel';

const DOMAIN: number = 0x0666;
const TAG: string = 'WebPage';

@ComponentV2
export struct WebPage {
  @Local vm: WebViewModel = new WebViewModel();
  private controller: webview.WebviewController = new webview.WebviewController();

  // R9 阶段4：标题栏交给 NavDestination 原生 .title/.menus（配置经 NavTitleBridge 上报）。
  // displayTitle() 走 getter 闭包，页面标题（onTitleReceive）变化可实时反映到标题栏。
  aboutToAppear(): void {
    NavTitleBridge.get().registerTitle(RouteName.WebPage, {
      titleGetter: (): string => this.vm.displayTitle(),
      barId: 'web_page_appbar',
      rightActions: [
        {
          iconKey: 'reload',
          onAction: (): void => {
            this.onReload();
          },
        } as NavTitleAction,
      ],
    } as NavTitleConfig);
  }

  private onReload(): void {
    hilog.info(DOMAIN, TAG, '[web/page] reload');
    try {
      this.controller.refresh();
    } catch (e) {
      const err: Error = e as Error;
      hilog.warn(DOMAIN, TAG, '[web/page] reload fail %{public}s', err.message);
    }
  }

  build(): void {
    NavDestination() {
      Column() {
        if (this.vm.uri.length > 0) {
          Web({ src: this.vm.uri, controller: this.controller })
            .id('web_page_view')
            .domStorageAccess(true)
            .javaScriptAccess(true)
            .mixedMode(MixedMode.All)
            .zoomAccess(true)
            .layoutWeight(1)
            .onTitleReceive((event: OnTitleReceiveEvent): void => {
              this.vm.onTitleReceived(event.title);
            })
            .onPageEnd((event: OnPageEndEvent): void => {
              this.vm.onPageFinished(event.url);
            })
            .onLoadIntercept((event: OnLoadInterceptEvent): boolean => {
              const request: WebResourceRequest = event.data;
              const url: string = request.getRequestUrl();
              return this.vm.interceptUrl(url);
            });
        }
      }
      .id('web_page_root')
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeManager.current().background);
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext): void => {
      this.vm.initFromNavContext(ctx);
    });
  }
}
