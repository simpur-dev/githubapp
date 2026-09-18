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

  @Builder
  pressedScrim(): void {
    // 按压蒙层经 .overlay 挂载：overlay 不参与布局、尺寸跟随被覆盖组件本身，
    // 蒙层 height('100%') 只等于卡片内容高（R12 修复：原常驻子节点写法把
    // Stack→Row→ListItem 整条高度链撑成列表全高，短列表下行高虚胀、
    // swipeAction 露出按钮随之错位）。
    Column()
      .width('100%')
      .height('100%')
      .borderRadius(this.cornerRadius)
      .backgroundColor(this.pressScrimColor())
      .opacity(this.isPressed ? 1 : 0)
      .animation({ duration: this.pressDuration, curve: Curve.EaseOut })
      .hitTestBehavior(HitTestMode.None);
  }

  build(): void {
    Stack({ alignContent: Alignment.Top }) {
      this.content();
    }
    .overlay(this.pressedScrim(), { align: Alignment.Top })
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
