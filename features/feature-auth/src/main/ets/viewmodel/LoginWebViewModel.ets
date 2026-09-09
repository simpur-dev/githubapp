import { AuthDeepLinkBus } from 'common';
import { OauthService, DEFAULT_OAUTH_REDIRECT_URI, DEFAULT_OAUTH_SCOPE } from 'common';
import { NavigationService } from 'common';
import { Url } from 'common';

const REDIRECT_URI: string = DEFAULT_OAUTH_REDIRECT_URI;

/**
 * LoginWeb 对外导出的静态 clientId 注入点。
 * R9 V2 + MVVM 试点：从 LoginWebPage.ets 平移到本文件，类名与签名一字未动。
 */
export class LoginWebDeps {
  private static clientId: string = '';

  static setClientId(id: string): void {
    LoginWebDeps.clientId = id;
  }

  static getClientId(): string {
    return LoginWebDeps.clientId;
  }
}

interface LoginWebRouteParams {
  authorizeUrl?: string;
  state?: string;
  redirectUri?: string;
  clientId?: string;
  scope?: string;
}

/**
 * LoginWebViewModel —— OAuth 授权 Web 页状态与拦截编排（R9 V2 + MVVM 试点）。
 *
 * @Trace 状态（3 个）：当前授权页 URL、期望 state、期望 redirect uri。
 * 路由取参建链与重定向深链拦截（校验 code/state 后经 AuthDeepLinkBus 回传给
 * LoginPage 再弹回）全部收拢在此；LoginPage 只保留 WebviewController 与 UI。
 */
@ObservedV2
export class LoginWebViewModel {
  @Trace currentUrl: string = '';
  @Trace expectedState: string = '';
  @Trace expectedRedirect: string = REDIRECT_URI;

  /** View aboutToAppear 把 router.getParams() 原样传入，取参语义与原页面一致。 */
  initFromRoute(params: Object | undefined): void {
    const route: LoginWebRouteParams = (params !== undefined && params !== null
      ? params as LoginWebRouteParams
      : {});
    const redirectUri: string = (route.redirectUri !== undefined && route.redirectUri !== null
      && route.redirectUri.length > 0)
      ? route.redirectUri
      : REDIRECT_URI;
    this.expectedRedirect = redirectUri;
    this.expectedState = (route.state !== undefined && route.state !== null) ? route.state : '';

    if (route.authorizeUrl !== undefined && route.authorizeUrl !== null && route.authorizeUrl.length > 0) {
      this.currentUrl = route.authorizeUrl;
      return;
    }
    const clientId: string = (route.clientId !== undefined && route.clientId !== null && route.clientId.length > 0)
      ? route.clientId
      : LoginWebDeps.getClientId();
    const scope: string = (route.scope !== undefined && route.scope !== null && route.scope.length > 0)
      ? route.scope
      : DEFAULT_OAUTH_SCOPE;
    const fallbackState: string = OauthService.generateState();
    this.expectedState = fallbackState;
    this.currentUrl = OauthService.buildAuthorizeUrl(clientId, redirectUri, scope, fallbackState);
  }

  /** Web onLoadIntercept 转发：命中 redirect 深链则回传 code 并返回 true 拦截。 */
  interceptDeepLink(url: string): boolean {
    if (!url || url.length === 0) {
      return false;
    }
    const target: string = this.expectedRedirect.length > 0 ? this.expectedRedirect : REDIRECT_URI;
    if (url.indexOf(target) !== 0) {
      return false;
    }
    const query: Map<string, string> = Url.parseQuery(url);
    const code: string | undefined = query.get('code');
    const state: string | undefined = query.get('state');
    if (code === undefined || code.length === 0) {
      return false;
    }
    if (this.expectedState.length > 0) {
      if (state === undefined || state.length === 0 || state !== this.expectedState) {
        return false;
      }
    } else if (state !== undefined && state.length > 0 && !OauthService.validateState(state)) {
      return false;
    }
    const deepLinkUri: string = state !== undefined && state.length > 0
      ? `${target}?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state)}`
      : `${target}?code=${encodeURIComponent(code)}`;
    AuthDeepLinkBus.publish(deepLinkUri);
    NavigationService.pop();
    return true;
  }
}
