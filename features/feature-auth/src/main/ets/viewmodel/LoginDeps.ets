import { LoginUseCase, DefaultLoginUseCase } from 'common';
import { AuthStore, GlobalAuthStore } from 'common';

/**
 * LoginPage 对外导出的路由参数 / OAuth 客户端 / 用例注入点。
 * R9 V2 + MVVM 试点：从 LoginPage.ets 平移到本文件（View 与 VM 解耦，避免循环 import），
 * 类名与签名一字未动，LoginUiTest 等经 'feature_auth' 桶导出的引用不受影响。
 */

export class LoginOauthRouteParams {
  authorizeUrl: string;
  state: string;
  redirectUri: string;

  constructor(authorizeUrl: string, state: string, redirectUri: string) {
    this.authorizeUrl = authorizeUrl;
    this.state = state;
    this.redirectUri = redirectUri;
  }
}

export class LoginOauthClient {
  private static clientIdImpl: string = '';

  static setClientId(id: string): void {
    LoginOauthClient.clientIdImpl = id ? id : '';
  }

  static getClientId(): string {
    return LoginOauthClient.clientIdImpl;
  }
}

export class LoginPageDeps {
  private static useCaseImpl: LoginUseCase = DefaultLoginUseCase;
  private static storeImpl: AuthStore = GlobalAuthStore;

  static setUseCase(useCase: LoginUseCase): void {
    LoginPageDeps.useCaseImpl = useCase;
  }

  static setStore(store: AuthStore): void {
    LoginPageDeps.storeImpl = store;
  }

  static getUseCase(): LoginUseCase {
    return LoginPageDeps.useCaseImpl;
  }

  static getStore(): AuthStore {
    return LoginPageDeps.storeImpl;
  }

  static reset(): void {
    LoginPageDeps.useCaseImpl = DefaultLoginUseCase;
    LoginPageDeps.storeImpl = GlobalAuthStore;
  }
}
