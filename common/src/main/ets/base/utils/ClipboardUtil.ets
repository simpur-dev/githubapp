/**
 * ClipboardUtil —— 系统剪贴板（@ohos.pasteboard）轻封装（R12 KI-R12-006）。
 * 长按菜单"复制链接"用；静默失败（剪贴板拒绝不阻塞 UI）。
 */
import pasteboard from '@ohos.pasteboard';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'ClipboardUtil';

export function copyPlainText(text: string): void {
  if (text.length === 0) {
    return;
  }
  try {
    const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data).catch((e: Error): void => {
      hilog.error(0x0666, TAG, 'setData fail %{public}s', e.message);
    });
  } catch (e) {
    hilog.error(0x0666, TAG, 'copyPlainText throw %{public}s', (e as Error).message);
  }
}
