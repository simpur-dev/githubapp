/**
 * 系统状态栏样式 —— 官方非全屏窗口模型（最终定稿）：
 * 窗口非全屏（系统避让状态栏/手势条，原生标题栏/返回键/菜单正常渲染且不进入安全区）；
 * 状态栏底色/图标深浅经 setWindowSystemBarProperties 按页面声明动态跟随，
 * 应用退后台由 EntryAbility.onBackground 重置，防颜色残留。
 * 实测：全屏窗口下 .title()/.menus() 自定义 builder 不渲染（标题栏整条消失），勿开全屏。
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
