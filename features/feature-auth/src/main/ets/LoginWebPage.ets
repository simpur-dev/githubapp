import webview from '@ohos.web.webview';
import router from '@ohos.router';
import { NavTitleBridge, NavTitleConfig, RouteName } from 'common';
import { HOST_WEB } from 'common';
import { GSYColor } from 'common';
import { I18n } from 'common';
import { LoginWebViewModel } from './viewmodel/LoginWebViewModel';

/**
 * LoginWebPage —— OAuth 授权 Web 页 View 层（R9 V2 + MVVM 试点）。
 *
 * 取参建链 / 深链拦截在 LoginWebViewModel（@ObservedV2 + @Trace）；
 * LoginWebDeps 平移至 viewmodel/LoginWebViewModel.ets（经 'feature_auth' 桶导出）。
 * R9 阶段4：标题栏交给 NavDestination 原生 .title（login_web_appbar id 经 barId 保留）。
 */
@ComponentV2
export struct LoginWebPage {
  @Local vm: LoginWebViewModel = new LoginWebViewModel();
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    NavTitleBridge.get().registerTitle(RouteName.LoginWeb, {
      titleGetter: (): string => I18n('GithubAuthorization'),
      barId: 'login_web_appbar',
    } as NavTitleConfig);
    this.vm.initFromRoute(router.getParams() as Object | undefined);
  }

  build(): void {
    Column() {
      if (this.vm.currentUrl.length > 0) {
        Web({ src: this.vm.currentUrl, controller: this.controller })
          .id('login_web_view')
          .domStorageAccess(true)
          .javaScriptAccess(true)
          .mixedMode(MixedMode.All)
          .layoutWeight(1)
          .onLoadIntercept((event: OnLoadInterceptEvent): boolean => {
            const request: WebResourceRequest = event.data;
            const url: string = request.getRequestUrl();
            return this.vm.interceptDeepLink(url);
          });
      }
    }
    .id('login_web_root')
    .width('100%')
    .height('100%')
    .backgroundColor(GSYColor.white);
  }
}

export { HOST_WEB };
