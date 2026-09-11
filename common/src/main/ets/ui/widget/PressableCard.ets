/**
 * PressableCard —— 通用按压反馈容器（R10 阶段3）。
 *
 * 一行包裹即可让任意列表行 / 卡片获得按压反馈，被包裹内容的 .id 与 .onClick
 * 全部保持原样（触摸事件沿命中链冒泡，蒙层 hitTestBehavior=None 不拦截点击）：
 *
 *   PressableCard({ cornerRadius: GSYSpacing.cardRadiusLg }) {
 *     Column() { ...原卡片内容... }
 *       .id('xxx_row_0')
 *       .onClick(...)
 *   }
 *
 * 实现：onTouch 跟踪按压态 → 按压时顶层叠加 8% 低透明蒙层
 * （浅色 8% 黑 / 深色 8% 白，经 ThemeManager.isDark() 选择 token，非 palette 直读位），
 * 并对整个容器做 0.98 缩放 + 120ms 隐式属性动画；蒙层透明度同样走 120ms 过渡。
 * 圆角默认与统一卡片大圆角一致，可与被包裹卡片圆角对齐做到贴合。
 */
import { GSYColor, GSYSpacing } from '../style/Theme';
import { ThemeManager } from '../theme/ThemeManager';

const PRESS_SCALE: number = 0.98;

@ComponentV2
export struct PressableCard {
  /** 被包裹内容（插槽）：保留原行 / 卡片的 .id 与 .onClick。 */
  @BuilderParam content: () => void = this.defaultContent;
  /** 按压蒙层圆角，与被包裹卡片圆角保持一致。 */
  @Param cornerRadius: number = GSYSpacing.cardRadiusLg;
  /** 是否启用按压缩放反馈。 */
  @Param scaleOnPress: boolean = true;
  /** 按压过渡时长（ms）。 */
  @Param pressDuration: number = 120;
  @Local isPressed: boolean = false;

  private pressScrimColor(): string {
    return ThemeManager.isDark() ? GSYColor.pressScrimDark : GSYColor.pressScrimLight;
  }

  @Builder
  defaultContent(): void {
  }

  build(): void {
    Stack({ alignContent: Alignment.Center }) {
      this.content();

      // 按压蒙层：常驻节点 + 透明度过渡，避免条件渲染导致动画丢失。
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(this.cornerRadius)
        .backgroundColor(this.pressScrimColor())
        .opacity(this.isPressed ? 1 : 0)
        .animation({ duration: this.pressDuration, curve: Curve.EaseOut })
        .hitTestBehavior(HitTestMode.None);
    }
    .scale({
      x: this.scaleOnPress && this.isPressed ? PRESS_SCALE : 1,
      y: this.scaleOnPress && this.isPressed ? PRESS_SCALE : 1,
    })
    .animation({ duration: this.pressDuration, curve: Curve.EaseOut })
    .onTouch((event: TouchEvent): void => {
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    });
  }
}
