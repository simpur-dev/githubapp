/**
 * 系统状态栏样式 —— 官方非全屏窗口模型：
 * 窗口默认避让状态栏/手势条（系统画返回键、标题栏，组件天然不与安全区冲突）；
 * 状态栏底色/图标深浅按页面声明，经 setStatusBarStyle 调官方窗口属性实现颜色跟随。
 */
import window from '@ohos.window';
import hilog from '@ohos.hilog';
import { GSYColor } from '../../ui/style/Theme';

const TAG: string = 'SafeAreaInsets';

let mainWindow: window.Window | null = null;

/**
 * 由 EntryAbility.onWindowStageCreate 调用一次：缓存主窗口 + 设置初始状态栏样式。
 */
export function initSystemBars(win: window.Window): void {
  mainWindow = win;
  applySystemBars(GSYColor.mainBackground, false);
}

/**
 * 状态栏颜色跟随页面（官方 setWindowSystemBarProperties）：
 * bg 为状态栏底色（GSYColor token hex 字符串），contentLight 表示图标是否白色。
 * 应用退后台时由 EntryAbility.onBackground 重置为默认色，避免颜色残留在系统状态栏上。
 */
export function applySystemBars(bg: string, contentLight: boolean): void {
  if (mainWindow === null) {
    return;
  }
  mainWindow.setWindowSystemBarProperties({
    statusBarColor: bg,
    isStatusBarLightIcon: contentLight,
    statusBarContentColor: contentLight ? GSYColor.white : GSYColor.primaryDark,
    navigationBarColor: GSYColor.transparent,
  }).catch((e: Error): void => {
    hilog.error(0x0000, TAG, 'applySystemBars fail %{public}s', e.message);
  });
}
