import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { Preferences, KEY_USER_TOKEN, KEY_USER_INFO, PREF_NAME } from 'common';
import { HttpManager } from 'common';
import { GlobalAuthStore, AuthUserInfo } from 'common';
import { DefaultLoginUseCase, LoginOutcome } from 'common';
import { BOOT_LOGIN_KEY, BOOT_WELCOME_HOLD_KEY, BootChannel } from 'common';

const WELCOME_DELAY_MS: number = 1000;
const TAG: string = 'WelcomePage';

/**
 * WelcomeViewModel —— 欢迎页状态与启动路由编排（R9 V2 + MVVM 试点）。
 *
 * - @Trace decided：路由决策是否已完成（完成后不再重复跳转）；
 * - token 检查 / BOOT 兜底（测试通道，原样保留）/ user 信息恢复全部收拢在此，
 *   WelcomePage 仅做字体注册、Preferences 预热与定时器转发。
 */
@ObservedV2
export class WelcomeViewModel {
  @Trace decided: boolean = false;
  private timerId: number = -1;
  private ctx: common.UIAbilityContext | null = null;

  /**
   * 由 View 的 aboutToAppear / onPageShow 转发调用的退出定时编排。
   * aboutToAppear 携带 UIAbilityContext（供 token 缺失时 Preferences 兜底 init 用）；
   * onPageShow 不重复取 context，传 null 即可（ctx 已在首帧注入）。
   */
  scheduleExit(ctx: common.UIAbilityContext | null): void {
    if (ctx !== null) {
      this.ctx = ctx;
    }
    if (this.decided) {
      return;
    }
    if (this.timerId !== -1) {
      return;
    }
    this.timerId = setTimeout((): void => {
      this.startExitTransition();
    }, WELCOME_DELAY_MS);
  }

  cancelTimer(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }

  startExitTransition(): void {
    if (this.decided) {
      return;
    }
    const welcomeHold: string = BootChannel.get(BOOT_WELCOME_HOLD_KEY);
    if (welcomeHold.length > 0) {
      return;
    }
    this.routeByToken();
  }

  async routeByToken(): Promise<void> {
    if (this.decided) {
      return;
    }
    const welcomeHold: string = BootChannel.get(BOOT_WELCOME_HOLD_KEY);
    if (welcomeHold.length > 0) {
      return;
    }
    const bootLogin: string = BootChannel.get(BOOT_LOGIN_KEY);
    if (bootLogin.length > 0) {
      BootChannel.set(BOOT_LOGIN_KEY, '');
      this.decided = true;
      NavigationService.replace(RouteName.Login);
      return;
    }
    // token 直读 GlobalAuthStore 单例（原 auth.token 镜像通道已移除）。
    let token: string = GlobalAuthStore.token ? GlobalAuthStore.token : '';
    if (!token) {
      try {
        if (!Preferences.isReady() && this.ctx !== null) {
          await Preferences.init(this.ctx, PREF_NAME);
        }
        token = await Preferences.getString(KEY_USER_TOKEN, '');
      } catch (_e) {
        token = '';
      }
    }
    if (token && token.length > 0) {
      this.decided = true;
      GlobalAuthStore.token = token;
      HttpManager.setAuthorization(token);
      await this.restoreUserInfo(token);
      NavigationService.replace(RouteName.Home);
      return;
    }
    this.decided = true;
    NavigationService.replace(RouteName.Login);
  }

  /**
   * 冷启 token 路径下补恢复 user 信息（KI-051 修法）：
   * 对齐 RN 端 [user.js initUserInfo](https://github.com/CarGuo/GSYGithubApp/blob/master/app/store/actions/user.js)
   * 把 AsyncStorage[USER_INFO] 解出来后 dispatch USER.USER_INFO 的语义。
   * 读 Preferences[KEY_USER_INFO] → AuthUserInfo.fromJson → GlobalAuthStore.setUser，
   * 让 GlobalAuthStore.userInfo 直接恢复，
   * 修复 IssueDetailPage / 其他 owner 判定页面在冷启 bootToken 路径下 owner=false 的问题。
   */
  private async restoreUserInfo(token: string): Promise<void> {
    try {
      if (GlobalAuthStore.userInfo !== null && GlobalAuthStore.userInfo !== undefined
        && GlobalAuthStore.userInfo.login.length > 0) {
        return;
      }
      if (!Preferences.isReady()) {
        if (this.ctx === null) {
          return;
        }
        try {
          await Preferences.init(this.ctx, PREF_NAME);
        } catch (_e) {
          return;
        }
      }
      const json: string = await Preferences.getString(KEY_USER_INFO, '');
      if (json && json.length > 0) {
        const user: AuthUserInfo | null = AuthUserInfo.fromJson(json);
        if (user !== null && user.login.length > 0) {
          GlobalAuthStore.setUser(token, user);
          hilog.info(0x0000, TAG, 'restoreUserInfo from cache ok login=%{public}s', user.login);
          return;
        }
      }
      // 本地没有 user 缓存（典型场景：bootToken 测试通道首次注入 PAT），
      // 调一次 GET /user 拉回用户信息并写 Preferences；语义对齐 RN 端
      // [login.js doTokenLogin](https://github.com/CarGuo/GSYGithubApp/blob/master/app/store/actions/login.js)。
      const outcome: LoginOutcome = await DefaultLoginUseCase.loginWithPersonalAccessToken(token);
      if (outcome.result && outcome.data !== null) {
        hilog.info(0x0000, TAG, 'restoreUserInfo via /user ok login=%{public}s', outcome.data.login);
      } else {
        hilog.warn(0x0000, TAG, 'restoreUserInfo via /user fail code=%{public}d', outcome.code);
      }
    } catch (e) {
      const err = e as Error;
      hilog.warn(0x0000, TAG, 'restoreUserInfo fail %{public}s', err.message);
    }
  }
}
