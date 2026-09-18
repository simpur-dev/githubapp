/**
 * HapticUtil —— 轻触觉反馈（R12 体验优化）。
 *
 * 关键动作（长按菜单弹出 / 左滑标记已读 / 下拉刷新触发）给 10ms 'touch' 短振动，
 * 提升操作确认感；需要 ohos.permission.VIBRATE（normal 级，静默授予）。
 * 模拟器/不支持设备上静默失败，不影响功能。
 */
import vibrator from '@ohos.vibrator';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'HapticUtil';

export function hapticTick(): void {
  try {
    vibrator.startVibration(
      { type: 'time', duration: 10 },
      { usage: 'touch' }
    ).catch((e: Error): void => {
      hilog.debug(0x0666, TAG, 'startVibration fail %{public}s', e.message);
    });
  } catch (e) {
    hilog.debug(0x0666, TAG, 'hapticTick throw %{public}s', (e as Error).message);
  }
}
