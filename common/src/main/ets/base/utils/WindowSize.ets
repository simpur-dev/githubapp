/**
 * WindowSize —— 窗口尺寸/断点单例（R12 多设备适配，官方"一多"姿势）。
 *
 * EntryAbility.initSystemBars 时调 attach(window) 挂 windowSizeChange 监听；
 * UI 侧读 breakpoint() 得到 'sm' | 'md' | 'lg'（官方断点口径：
 * sm < 600vp、md 600-840vp、lg > 840vp，取窗口宽度），列表内容区据此限宽居中。
 *
 * V2 组件直接订阅 @Trace 字段；非响应场景可直读属性。
 */
import window from '@ohos.window';
import display from '@ohos.display';
import hilog from '@ohos.hilog';

const TAG: string = 'WindowSize';

export type WindowBreakpoint = 'sm' | 'md' | 'lg';

/** 官方断点口径（vp）：md 下限 600 / lg 下限 840。 */
const MD_MIN_VP: number = 600;
const LG_MIN_VP: number = 840;

/** 宽屏下列表内容区最大宽度（vp）：折叠展开/平板上防止单列拉满全宽。 */
export const CONTENT_MAX_WIDTH_VP: number = 720;

@ObservedV2
export class WindowSizeImpl {
  /** 窗口宽度（vp）。 */
  @Trace widthVp: number = 0;
  /** 窗口高度（vp）。 */
  @Trace heightVp: number = 0;
  /** 当前断点。 */
  @Trace breakpoint: WindowBreakpoint = 'sm';

  attach(win: window.Window): void {
    try {
      this.refresh();
      win.on('windowSizeChange', (): void => {
        this.refresh();
      });
    } catch (e) {
      hilog.error(0x0000, TAG, 'attach fail %{public}s', (e as Error).message);
    }
  }

  refresh(): void {
    try {
      const info: display.Display = display.getDefaultDisplaySync();
      const density: number = info.densityPixels > 0 ? info.densityPixels : 1;
      this.widthVp = Math.round(info.width / density);
      this.heightVp = Math.round(info.height / density);
      if (this.widthVp >= LG_MIN_VP) {
        this.breakpoint = 'lg';
      } else if (this.widthVp >= MD_MIN_VP) {
        this.breakpoint = 'md';
      } else {
        this.breakpoint = 'sm';
      }
    } catch (e) {
      hilog.error(0x0000, TAG, 'refresh fail %{public}s', (e as Error).message);
    }
  }
}

export const WindowSize: WindowSizeImpl = new WindowSizeImpl();
