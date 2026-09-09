import { LoginOutcome } from 'common';
import { OauthService, DEFAULT_OAUTH_SCOPE } from 'common';
import { OAuthRuntimeConfig } from 'common';
import { AuthDeepLinkBus } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { CommonToast } from 'common';
import { LoadingModal } from 'common';
import { I18n } from 'common';
import { AuthStore } from 'common';
import { EventBus, EVENT_USER_LOGGED_IN, EVENT_AUTH_STATE_CHANGED } from 'common';
import { Url } from 'common';
import { KEY_LANGUAGE_SELECT, LANGUAGE_OPTION_SYSTEM } from 'common';
import { SettingPageDeps, SettingPageHelper } from 'common';
import { LoginPageDeps, LoginOauthClient, LoginOauthRouteParams } from './LoginDeps';

const LOGIN_LOGO_PHASE_MS: number = 160;

/**
 * LoginViewModel —— 登录页状态与编排（R9 V2 + MVVM 试点）。
 *
 * @Trace 状态（6 个）：token 输入、语言弹层开关、当前语言、logo 动画相位、
 * 登录 loading、错误文案。双输入校验 / PAT 登录 / OAuth 编排 / 语言切换 /
 * 事件订阅（登录态变化、登录成功、深链回跳）全部收拢在此；
 * LoginPage 仅保留字体注册与 OAuth rawfile 配置读取（需要 UI 上下文）。
 */
@ObservedV2
export class LoginViewModel {
  @Trace token: string = '';
  @Trace showLanguageDialog: boolean = false;
  @Trace currentLanguage: string = LANGUAGE_OPTION_SYSTEM;
  @Trace logoPhase: number = 0;
  @Trace loading: boolean = false;
  @Trace errorMessage: string = '';
  private offLoggedIn: (() => void) | null = null;
  private offDeepLink: (() => void) | null = null;
  private offAuthChanged: (() => void) | null = null;
  private logoTimerId: number = -1;

  /** View aboutToAppear 时调用：加载语言、启动 logo 动画、订阅事件（顺序与原页面一致）。 */
  init(): void {
    this.loadLanguage();
    this.startLogoAnimation();
    // 登录态直读 AuthStore 单例；通过 EVENT_AUTH_STATE_CHANGED 事件驱动 loading / error
    // 刷新（等价旧双向绑定响应）。payload 是发生变化的 AuthStore 实例：测试注入私有
    // store 时同样生效。
    this.offAuthChanged = EventBus.on(EVENT_AUTH_STATE_CHANGED, (payload: ESObject): void => {
      const changed: AuthStore | null = payload !== null && payload !== undefined ? payload as AuthStore : null;
      const source: AuthStore = changed !== null ? changed : LoginPageDeps.getStore();
      this.loading = source.loading;
      this.errorMessage = source.error;
    });
    this.offLoggedIn = EventBus.on(EVENT_USER_LOGGED_IN, (): void => {
      LoadingModal.hide();
      NavigationService.replace(RouteName.Home);
    });
    this.offDeepLink = AuthDeepLinkBus.subscribe((uri: string): void => {
      this.handleDeepLink(uri);
    });
  }

  /** View aboutToDisappear 时调用：退订事件 + 停 logo 动画。 */
  dispose(): void {
    if (this.offLoggedIn !== null) {
      this.offLoggedIn();
      this.offLoggedIn = null;
    }
    if (this.offDeepLink !== null) {
      this.offDeepLink();
      this.offDeepLink = null;
    }
    if (this.offAuthChanged !== null) {
      this.offAuthChanged();
      this.offAuthChanged = null;
    }
    if (this.logoTimerId !== -1) {
      clearInterval(this.logoTimerId);
      this.logoTimerId = -1;
    }
  }

  async handleDeepLink(uri: string): Promise<void> {
    if (!uri || uri.length === 0) {
      return;
    }
    const query: Map<string, string> = Url.parseQuery(uri);
    const code: string | undefined = query.get('code');
    const state: string | undefined = query.get('state');
    if (code === undefined || code.length === 0) {
      return;
    }
    if (state !== undefined && state.length > 0 && !OauthService.validateState(state)) {
      CommonToast.showShort(I18n('LoginFailTip'));
      return;
    }
    LoadingModal.show(I18n('loading'), false);
    const res: LoginOutcome = await OauthService.exchangeOAuthCode(code);
    LoadingModal.hide();
    if (!res.result) {
      CommonToast.showShort(I18n('LoginFailTip'));
    }
  }

  async runTokenLogin(token: string): Promise<void> {
    const trimmed: string = (token ? token : '').trim();
    if (trimmed.length === 0) {
      CommonToast.showShort(I18n('TokenInputTip'));
      return;
    }
    LoadingModal.show(I18n('loading'), false);
    const res: LoginOutcome = await LoginPageDeps.getUseCase().loginWithPersonalAccessToken(trimmed);
    LoadingModal.hide();
    if (!res.result) {
      CommonToast.showShort(I18n('TokenLoginFailTip'));
    }
  }

  async chooseLanguage(option: string): Promise<void> {
    this.currentLanguage = option;
    await SettingPageHelper.applyLanguage(option, SettingPageDeps.getPrefs());
    this.showLanguageDialog = false;
  }

  async loadLanguage(): Promise<void> {
    try {
      this.currentLanguage = await SettingPageDeps.getPrefs()
        .getString(KEY_LANGUAGE_SELECT, LANGUAGE_OPTION_SYSTEM);
    } catch (_e) {
      this.currentLanguage = LANGUAGE_OPTION_SYSTEM;
    }
  }

  startLogoAnimation(): void {
    if (this.logoTimerId !== -1) {
      return;
    }
    this.logoTimerId = setInterval((): void => {
      this.logoPhase = (this.logoPhase + 1) % 12;
    }, LOGIN_LOGO_PHASE_MS);
  }

  /**
   * OAuth 登录编排。rawfile 配置读取（OAuthLocalConfigLoader.load 需要 UI 上下文）
   * 留在 View 层完成后把 OAuthRuntimeConfig 传入，其余校验 / 注入 / 建链 / 跳转在此。
   */
  async openOAuthWeb(cfg: OAuthRuntimeConfig): Promise<void> {
    if (!cfg.isValid()) {
      CommonToast.showShort(I18n('OAuthConfigMissingTip'));
      return;
    }
    LoginPageDeps.getUseCase().setOAuthConfig(cfg.toClientConfig());
    LoginOauthClient.setClientId(cfg.clientId);
    const state: string = OauthService.generateState();
    const authorizeUrl: string = OauthService.buildAuthorizeUrl(
      cfg.clientId,
      cfg.redirectUri,
      DEFAULT_OAUTH_SCOPE,
      state,
    );
    const params: LoginOauthRouteParams = new LoginOauthRouteParams(
      authorizeUrl, state, cfg.redirectUri);
    NavigationService.push(RouteName.LoginWeb, params);
  }
}
