/**
 * SafeAreaInsets —— 沉浸式布局下读取系统安全区（状态栏 / 底部手势条），
 * 以 @ObservedV2 单例形式暴露给各页面直读：
 *   SafeAreaInsets.top      // 状态栏高度（vp）
 *   SafeAreaInsets.bottom   // 底部手势条高度（vp）
 *
 * 数据单位：vp（已转换，可直接用作 padding/height）
 *
 * V1 组件读单例字段不会自动刷新，配合 EVENT_SAFE_AREA_CHANGED 事件订阅即可；
 * V2 组件可直接订阅 @Trace 字段。
 *
 * 沉浸式开关在 [EntryAbility.onWindowStageCreate](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/entryability/EntryAbility.ets) 调
 * `enableImmersive(windowStage)` 即可。
 */
import window from '@ohos.window';
import display from '@ohos.display';
import hilog from '@ohos.hilog';
import { GSYColor } from '../../ui/style/Theme';
import { EventBus, EVENT_SAFE_AREA_CHANGED } from './EventBus';

const TAG: string = 'SafeAreaInsets';

@ObservedV2
export class SafeAreaInsetsImpl {
  /** 状态栏避让高度（vp） */
  @Trace top: number = 0;
  /** 底部手势条避让高度（vp） */
  @Trace bottom: number = 0;
}

/**
 * 安全区单例：enableImmersive / avoidAreaChange 回调更新 top/bottom。
 */
export const SafeAreaInsets: SafeAreaInsetsImpl = new SafeAreaInsetsImpl();

/**
 * 沉浸式 + 安全区初始化（HarmonyOS 6.x 光感 UI）。
 * - setWindowLayoutFullScreen(true)：内容延伸到 statusBar / navIndicator 区域
 * - setWindowSystemBarProperties：
 *   - statusBar 透明 + LightIcon=true（白字图标）—— AppBar 是深色 GitHub primary，需要白图标
 *   - navigationBar 透明 + LightIcon=false（深字图标）—— TabBar 是白底，需要黑图标
 * - 监听 avoidArea 变化，把 top / bottom 推给 SafeAreaInsets 单例（vp）并广播事件
 */
export async function enableImmersive(windowStage: window.WindowStage): Promise<void> {
  try {
    const win: window.Window = await windowStage.getMainWindow();
    await win.setWindowLayoutFullScreen(true);

    const sysBarProps: window.SystemBarProperties = {
      statusBarColor: GSYColor.transparent,
      navigationBarColor: GSYColor.transparent,
      isStatusBarLightIcon: true,
      isNavigationBarLightIcon: false,
      statusBarContentColor: GSYColor.white,
      navigationBarContentColor: GSYColor.primary,
    };
    await win.setWindowSystemBarProperties(sysBarProps);

    publishInsets(win);

    win.on('avoidAreaChange', (data: window.AvoidAreaOptions): void => {
      if (data.type === window.AvoidAreaType.TYPE_SYSTEM
        || data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
        publishInsets(win);
      }
    });
  } catch (e) {
    hilog.error(0x0000, TAG, 'enableImmersive fail %{public}s', (e as Error).message);
  }
}

function publishInsets(win: window.Window): void {
  try {
    const sysArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const navArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);

    const topPx: number = sysArea.topRect.height;
    const bottomPx: number = navArea.bottomRect.height;

    const dpInfo: display.Display = display.getDefaultDisplaySync();
    const density: number = dpInfo.densityPixels > 0 ? dpInfo.densityPixels : 1;

    const topVp: number = Math.round(topPx / density);
    const bottomVp: number = Math.round(bottomPx / density);

    SafeAreaInsets.top = topVp;
    SafeAreaInsets.bottom = bottomVp;
    EventBus.emit(EVENT_SAFE_AREA_CHANGED, SafeAreaInsets);

    hilog.info(0x0000, TAG, 'insets top=%{public}dvp bottom=%{public}dvp', topVp, bottomVp);
  } catch (e) {
    hilog.error(0x0000, TAG, 'publishInsets fail %{public}s', (e as Error).message);
  }
}
