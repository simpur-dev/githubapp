import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { AuthDeepLinkBus } from 'common';
import { Url, DeepLinkInfo } from 'common';
import { Preferences, KEY_USER_TOKEN, PREF_NAME } from 'common';
import { RdbStore } from 'common';
import { HttpManager } from 'common';
import { GlobalAuthStore } from 'common';
import { initSystemBars, applySystemBars, GSYColor, NavTitleBridge, ThemeManager } from 'common';
import { Logger } from 'common';
import { changeLocale, LocaleKey } from 'common';
import { KEY_SEARCH_HISTORY, BOOT_TAB_KEY, BOOT_LOGIN_KEY, BOOT_WELCOME_HOLD_KEY, BOOT_REPO_KEY, BOOT_PUSH_KEY, BOOT_ISSUE_KEY, BOOT_CODE_KEY, BOOT_USER_KEY, BOOT_PHOTO_KEY, BOOT_WEB_KEY, BOOT_NOTIFY_ISSUE_KEY, BOOT_COMMON_LIST_KEY, BootChannel } from 'common';

const TAG: string = 'EntryAbility';
const AUTH_SCHEME: string = 'gsygithubapp';
const AUTH_HOST: string = 'authed';
const PARAM_BOOT_TOKEN: string = 'bootToken';
const PARAM_BOOT_LOGIN: string = 'bootLogin';
const PARAM_BOOT_WELCOME_HOLD: string = 'bootWelcomeHold';
const PARAM_BOOT_TAB: string = 'bootTab';
const PARAM_BOOT_REPO: string = 'bootRepo';
const PARAM_BOOT_PUSH: string = 'bootPush';
const PARAM_BOOT_ISSUE: string = 'bootIssue';
const PARAM_BOOT_CODE: string = 'bootCode';
const PARAM_BOOT_USER: string = 'bootUser';
const PARAM_BOOT_PHOTO: string = 'bootPhoto';
const PARAM_BOOT_WEB: string = 'bootWeb';
const PARAM_BOOT_COMMON_LIST: string = 'bootCommonList';
const PARAM_BOOT_LOCALE: string = 'bootLocale';
const PARAM_BOOT_NOTIFY_ISSUE: string = 'bootNotifyIssue';
const PARAM_BOOT_SEARCH_HISTORY: string = 'bootSearchHistory';

/**
 * 表驱动 boot 注入项：onCreate/onNewWant 循环读 want.parameters[param]，
 * 字符串非空则 BootChannel.set(key, value)。行为与原 handleBootXxxInjection 逐一等价：
 * - boolFlag=true：'false'/'0' 视为未注入，注入值固定 '1'（bootLogin / bootWelcomeHold）；
 * - lowerCase=true：值转小写后注入（bootTab / bootLogin / bootWelcomeHold）；
 * - loggerTs=true：保留原 Logger.i('boot/ts', ...) 埋点文本。
 * bootLocale（必须最先注入）/ bootToken（授权副作用）/ bootSearchHistory（写 Preferences，
 * 不走 BootChannel）三个特殊处理保留为显式调用。
 */
interface BootInjectionSpec {
  param: string;
  key: string;
  logTag: string;
  methodName: string;
  lowerCase: boolean;
  boolFlag: boolean;
  loggerTs: boolean;
}

const BOOT_INJECTION_TABLE: BootInjectionSpec[] = [
  { param: PARAM_BOOT_LOGIN, key: BOOT_LOGIN_KEY, logTag: 'bootLogin', methodName: 'handleBootLoginInjection', lowerCase: true, boolFlag: true, loggerTs: false },
  { param: PARAM_BOOT_WELCOME_HOLD, key: BOOT_WELCOME_HOLD_KEY, logTag: 'bootWelcomeHold', methodName: 'handleBootWelcomeHoldInjection', lowerCase: true, boolFlag: true, loggerTs: false },
  { param: PARAM_BOOT_TAB, key: BOOT_TAB_KEY, logTag: 'bootTab', methodName: 'handleBootTabInjection', lowerCase: true, boolFlag: false, loggerTs: false },
  { param: PARAM_BOOT_REPO, key: BOOT_REPO_KEY, logTag: 'bootRepo', methodName: 'handleBootRepoInjection', lowerCase: false, boolFlag: false, loggerTs: true },
  { param: PARAM_BOOT_PUSH, key: BOOT_PUSH_KEY, logTag: 'bootPush', methodName: 'handleBootPushInjection', lowerCase: false, boolFlag: false, loggerTs: true },
  { param: PARAM_BOOT_ISSUE, key: BOOT_ISSUE_KEY, logTag: 'bootIssue', methodName: 'handleBootIssueInjection', lowerCase: false, boolFlag: false, loggerTs: true },
  { param: PARAM_BOOT_CODE, key: BOOT_CODE_KEY, logTag: 'bootCode', methodName: 'handleBootCodeInjection', lowerCase: false, boolFlag: false, loggerTs: true },
  { param: PARAM_BOOT_USER, key: BOOT_USER_KEY, logTag: 'bootUser', methodName: 'handleBootUserInjection', lowerCase: false, boolFlag: false, loggerTs: true },
  { param: PARAM_BOOT_PHOTO, key: BOOT_PHOTO_KEY, logTag: 'bootPhoto', methodName: 'handleBootPhotoInjection', lowerCase: false, boolFlag: false, loggerTs: true },
  { param: PARAM_BOOT_WEB, key: BOOT_WEB_KEY, logTag: 'bootWeb', methodName: 'handleBootWebInjection', lowerCase: false, boolFlag: false, loggerTs: true },
  { param: PARAM_BOOT_COMMON_LIST, key: BOOT_COMMON_LIST_KEY, logTag: 'bootCommonList', methodName: 'handleBootCommonListInjection', lowerCase: false, boolFlag: false, loggerTs: true },
  { param: PARAM_BOOT_NOTIFY_ISSUE, key: BOOT_NOTIFY_ISSUE_KEY, logTag: 'bootNotifyIssue', methodName: 'handleBootNotifyIssueInjection', lowerCase: false, boolFlag: false, loggerTs: true },
];

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'onCreate');
    this.initRdbStore();
    // 偏好存储先行初始化，主题恢复（ThemeManager.init 读 KEY_THEME）才不会静默回退。
    Preferences.init(this.context, PREF_NAME)
      .then((): Promise<void> => ThemeManager.init())
      .catch((e: Error): void => {
        hilog.error(0x0000, TAG, 'prefs/theme init fail %{public}s', e.message);
      });
    this.handleOAuthDeepLink(want);
    // bootLocale 必须最先注入（消费端按注入顺序读取，语义保留）。
    this.handleBootLocaleInjection(want);
    // bootToken 带授权副作用（GlobalAuthStore/HttpManager/Preferences），仅 onCreate 显式处理。
    this.handleBootTokenInjection(want);
    // 其余 boot 参数统一表驱动注入（行为与原 handleBootXxxInjection 逐一等价）。
    this.applyBootInjections(want);
    this.handleBootSearchHistoryInjection(want);
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'onNewWant');
    this.handleOAuthDeepLink(want);
    this.handleBootLocaleInjection(want);
    this.applyBootInjections(want);
    this.handleBootSearchHistoryInjection(want);
  }

  private initRdbStore(): void {
    RdbStore.init(this.context).catch((e: Error): void => {
      hilog.error(0x0000, TAG, 'rdb init fail %{public}s', e.message);
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, 'onWindowStageCreate');
    // 颜色沉浸（官方全屏窗口模型）：窗口全屏，状态栏颜色经 applySystemBars 按页面声明动态跟随
    // （setWindowSystemBarProperties 只在全屏/最大化窗口下生效，非全屏不生效）；
    // 原生 NavDestination 标题栏/返回键自带安全区避让（API 11+ 默认 expandSafeArea）。
    windowStage.getMainWindow((err, win) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'getMainWindow fail %{public}s', JSON.stringify(err));
      } else {
        initSystemBars(win);
      }
    });
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'loadContent fail %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, TAG, 'loadContent ok');
    });
  }

  onBackground(): void {
    // 退后台把状态栏置透明：颜色不残留在系统状态栏上。
    applySystemBars(GSYColor.transparent, false);
  }

  onForeground(): void {
    // 回前台恢复当前页面的状态栏样式（颜色跟随页面）。
    NavTitleBridge.get().reapplyStatusBar();
  }

  onWindowStageRestore(_windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, 'onWindowStageRestore');
  }

  private handleOAuthDeepLink(want: Want): void {
    const uri: string | undefined = want.uri;
    if (!uri || uri.length === 0) {
      return;
    }
    const info: DeepLinkInfo = Url.parseDeepLink(uri);
    if (info.scheme !== AUTH_SCHEME || info.host !== AUTH_HOST) {
      return;
    }
    AuthDeepLinkBus.publish(uri);
  }

  /**
   * 测试通道：want.parameters.bootLocale=en|zh-CN|local，
   * 用于生成 Compose/OH 同语言截图证据，不改变生产默认语言选择。
   */
  private handleBootLocaleInjection(want: Want): void {
    const params: Record<string, Object> | undefined = want.parameters as Record<string, Object> | undefined;
    if (!params) {
      return;
    }
    const raw: Object | undefined = params[PARAM_BOOT_LOCALE];
    if (typeof raw !== 'string') {
      return;
    }
    const value: string = (raw as string).trim();
    if (value.length === 0) {
      return;
    }
    const applied: LocaleKey = changeLocale(value);
    hilog.info(0x0000, TAG, 'bootLocale applied %{public}s', applied);
  }

  /**
   * 测试通道：当 want.parameters.bootToken 存在时，
   * 直接把它写入 Preferences，使 WelcomePage 检测到 token 后跳过 LoginPage。
   * 仅用于真机回归（aa start --PS bootToken xxxx），生产路径不会带该参数。
   */
  private handleBootTokenInjection(want: Want): void {
    const params: Record<string, Object> | undefined = want.parameters as Record<string, Object> | undefined;
    if (!params) {
      return;
    }
    const raw: Object | undefined = params[PARAM_BOOT_TOKEN];
    if (typeof raw !== 'string') {
      return;
    }
    const tokenInput: string = (raw as string).trim();
    if (tokenInput.length === 0) {
      return;
    }
    const authorization: string = tokenInput.toLowerCase().indexOf('token ') === 0
      ? tokenInput
      : `token ${tokenInput}`;
    hilog.info(0x0000, TAG, 'bootToken injected (len=%{public}d)', authorization.length);
    GlobalAuthStore.token = authorization;
    HttpManager.setAuthorization(authorization);
    Preferences.init(this.context, PREF_NAME)
      .then((): Promise<void> => Preferences.putString(KEY_USER_TOKEN, authorization))
      .catch((e: Error): void => {
        hilog.error(0x0000, TAG, 'bootToken persist fail %{public}s', e.message);
      });
  }

  /**
   * 表驱动 boot 注入（原 12 个 handleBootXxxInjection 收敛）：
   * 读 want.parameters[spec.param]，字符串非空按 spec 语义写入 BootChannel。
   * bootLocale / bootToken / bootSearchHistory 三个特殊处理仍为显式调用。
   */
  private applyBootInjections(want: Want): void {
    const params: Record<string, Object> | undefined = want.parameters as Record<string, Object> | undefined;
    if (!params) {
      return;
    }
    for (let i = 0; i < BOOT_INJECTION_TABLE.length; i++) {
      const spec: BootInjectionSpec = BOOT_INJECTION_TABLE[i];
      const raw: Object | undefined = params[spec.param];
      if (typeof raw !== 'string') {
        continue;
      }
      let value: string = (raw as string).trim();
      if (value.length === 0) {
        continue;
      }
      if (spec.lowerCase) {
        value = value.toLowerCase();
      }
      if (spec.boolFlag) {
        if (value === 'false' || value === '0') {
          continue;
        }
        hilog.info(0x0000, TAG, '%{public}s injected', spec.logTag);
        BootChannel.set(spec.key, '1');
        continue;
      }
      hilog.info(0x0000, TAG, '%{public}s injected %{public}s', spec.logTag, value);
      BootChannel.set(spec.key, value);
      if (spec.loggerTs) {
        Logger.i('boot/ts', `EntryAbility.${spec.methodName} done t=${Date.now()} value=${value}`);
      }
    }
  }

  /**
   * 测试通道：want.parameters.bootSearchHistory=react|flutter，
   * 用于 Search 首屏/聚焦态对照截图。生产路径不会带该参数。
   */
  private handleBootSearchHistoryInjection(want: Want): void {
    const params: Record<string, Object> | undefined = want.parameters as Record<string, Object> | undefined;
    if (!params) {
      return;
    }
    const raw: Object | undefined = params[PARAM_BOOT_SEARCH_HISTORY];
    if (typeof raw !== 'string') {
      return;
    }
    const value: string = (raw as string).trim();
    if (value.length === 0) {
      return;
    }
    const parts: string[] = value.split('|');
    const items: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const item: string = parts[i].trim();
      if (item.length > 0) {
        items.push(item);
      }
    }
    if (items.length === 0) {
      return;
    }
    Preferences.init(this.context, PREF_NAME)
      .then((): Promise<void> => Preferences.putString(KEY_SEARCH_HISTORY, JSON.stringify(items)))
      .then((): void => {
        hilog.info(0x0000, TAG, 'bootSearchHistory injected count=%{public}d', items.length);
      })
      .catch((e: Error): void => {
        hilog.error(0x0000, TAG, 'bootSearchHistory persist fail %{public}s', e.message);
      });
  }

}
