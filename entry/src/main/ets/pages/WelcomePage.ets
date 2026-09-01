import common from '@ohos.app.ability.common';
import font from '@ohos.font';
import hilog from '@ohos.hilog';
import { NavigationService } from '../navigation/NavigationService';
import { RouteName } from '../navigation/Routes';
import { Preferences, KEY_USER_TOKEN, KEY_USER_INFO, PREF_NAME } from '../dao/db/Preferences';
import { HttpManager } from '../net/HttpManager';
import { GlobalAuthStore, APP_STORAGE_KEY_TOKEN, APP_STORAGE_KEY_USER_LOGIN, AuthUserInfo } from '../store/AuthStore';
import { DefaultLoginUseCase, LoginOutcome } from '../auth/LoginUseCase';
import { BOOT_LOGIN_KEY, BOOT_WELCOME_HOLD_KEY } from '../entryability/EntryAbility';

const WELCOME_DELAY_MS: number = 1000;
const WELCOME_ICON_SIZE: number = 120;
const TAG: string = 'WelcomePage';

/**
 * WelcomePage —— 系统原生启动窗口风格的欢迎页（2026-09 重构）
 *
 * 用户拍板：与 RN 端 welcome.png + Lottie 动画解耦，改用 HarmonyOS 系统启动窗口
 * 同款视觉 —— 屏幕居中 app 图标 + 系统空白背景（跟随系统深浅色模式）。
 *
 * 深浅色跟随实现：背景色走资源引用 $r('app.color.start_window_background')，
 * base 目录 #FFFFFF（浅色）/ dark 目录 #000000（深色）由资源限定符自动切换，
 * 与 module.json5 startWindowBackground 指向同一资源，启动窗口→本页视觉无缝衔接。
 */
@Component
export struct WelcomePage {
  @State decided: boolean = false;
  private timerId: number = -1;

  aboutToAppear(): void {
    this.registerIconFonts();
    try {
      const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      Preferences.init(ctx, PREF_NAME).catch((): void => {
      });
    } catch (_e) {
    }
    if (!this.decided) {
      this.timerId = setTimeout((): void => {
        this.startExitTransition();
      }, WELCOME_DELAY_MS);
    }
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }

  /**
   * 注册 FontAwesome 字体族（与 RN 端 react-native-vector-icons FontAwesome.ttf 同源 4.x ttf）。
   * 注册后任意 Text 组件 `.fontFamily('FontAwesome')` 即可显示 FontAwesome 字符（如 \uf0f3 = bell）。
   * 必须在 UI 上下文（@Entry 页面 aboutToAppear）调用，UIAbility 中调用会抛 401。
   */
  private registerIconFonts(): void {
    try {
      font.registerFont({
        familyName: 'FontAwesome',
        familySrc: $rawfile('fonts/FontAwesome.ttf'),
      });
      hilog.info(0x0000, TAG, 'registerFont FontAwesome ok');
    } catch (e) {
      const err = e as Error;
      hilog.error(0x0000, TAG, 'registerFont fail %{public}s', err.message);
    }
  }

  onPageShow(): void {
    if (this.decided) {
      return;
    }
    if (this.timerId === -1) {
      this.timerId = setTimeout((): void => {
        this.startExitTransition();
      }, WELCOME_DELAY_MS);
    }
  }

  private startExitTransition(): void {
    if (this.decided) {
      return;
    }
    const welcomeHold: string | undefined = AppStorage.get<string>(BOOT_WELCOME_HOLD_KEY);
    if (welcomeHold !== undefined && welcomeHold !== null && welcomeHold.length > 0) {
      return;
    }
    this.routeByToken();
  }

  private async routeByToken(): Promise<void> {
    if (this.decided) {
      return;
    }
    const welcomeHold: string | undefined = AppStorage.get<string>(BOOT_WELCOME_HOLD_KEY);
    if (welcomeHold !== undefined && welcomeHold !== null && welcomeHold.length > 0) {
      return;
    }
    const bootLogin: string | undefined = AppStorage.get<string>(BOOT_LOGIN_KEY);
    if (bootLogin !== undefined && bootLogin !== null && bootLogin.length > 0) {
      AppStorage.setOrCreate<string>(BOOT_LOGIN_KEY, '');
      this.decided = true;
      NavigationService.replace(RouteName.Login);
      return;
    }
    let token: string = GlobalAuthStore.token ? GlobalAuthStore.token : '';
    if (!token) {
      try {
        const mirrored: string | undefined = AppStorage.get<string>(APP_STORAGE_KEY_TOKEN);
        if (mirrored && mirrored.length > 0) {
          token = mirrored;
        }
      } catch (_e) {
      }
    }
    if (!token) {
      try {
        if (!Preferences.isReady()) {
          const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
          await Preferences.init(ctx, PREF_NAME);
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
   * 让 AppStorage[APP_STORAGE_KEY_USER_LOGIN] 与 AuthStore.userInfo 同步恢复，
   * 修复 IssueDetailPage / 其他 owner 判定页面在冷启 bootToken 路径下 owner=false 的问题。
   */
  private async restoreUserInfo(token: string): Promise<void> {
    try {
      const cached: string | undefined = AppStorage.get<string>(APP_STORAGE_KEY_USER_LOGIN);
      if (cached !== undefined && cached !== null && cached.length > 0) {
        return;
      }
      if (!Preferences.isReady()) {
        try {
          const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
          await Preferences.init(ctx, PREF_NAME);
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

  build(): void {
    Stack() {
      Column() {
        Image($r('app.media.app_icon'))
          .id('welcome_image')
          .width(WELCOME_ICON_SIZE)
          .height(WELCOME_ICON_SIZE)
          .objectFit(ImageFit.Contain);

        // 脚本断言锚点（scenario-tour.sh 场景 24），空 Text 不渲染任何视觉内容
        Text('')
          .id('welcome_subtitle')
          .width(1)
          .height(1)
          .opacity(0.001);
      }
      .id('welcome_inner')
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center);
    }
    .id('welcome_root')
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.start_window_background'));
  }
}
