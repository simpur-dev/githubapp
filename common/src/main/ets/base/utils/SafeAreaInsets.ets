/**
 * 系统状态栏样式 —— 官方全屏窗口模型：
 * 窗口全屏（setWindowLayoutFullScreen(true)），状态栏颜色经 setWindowSystemBarProperties
 * 按页面声明动态跟随（该接口只在全屏/最大化窗口下生效，非全屏不生效）；
 * 原生 NavDestination 标题栏/返回键自带安全区避让（API 11+ 默认 expandSafeArea）。
 */
import window from '@ohos.window';
import display from '@ohos.display';
import hilog from '@ohos.hilog';
import { GSYColor } from '../../ui/style/Theme';

const TAG: string = 'SafeAreaInsets';

let mainWindow: window.Window | null = null;

/**
 * 手势条/状态栏避让高度（vp，全屏沉浸窗口下供底部交互组件避让用）。
 */
@ObservedV2
export class SystemInsets {
  @Trace top: number = 0;
  @Trace bottom: number = 0;
}

export const systemInsets: SystemInsets = new SystemInsets();

/**
 * 由 EntryAbility.onWindowStageCreate 调用一次：缓存主窗口 + 设置初始状态栏样式。
 */
export function initSystemBars(win: window.Window): void {
  mainWindow = win;
  // 全屏窗口：setWindowSystemBarProperties 的 statusBarColor 才生效（非全屏下官方明确不生效）。
  win.setWindowLayoutFullScreen(true).catch((e: Error): void => {
    hilog.error(0x0000, TAG, 'layoutFullScreen fail %{public}s', e.message);
  });
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
