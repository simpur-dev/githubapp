/**
 * SkeletonList —— 列表骨架屏（R12 P2，官方原生姿势：属性动画驱动呼吸效果，
 * 无定时器/无自定义帧循环；替代首屏 LoadingProgress 转圈，感知加载更快）。
 *
 * rows 按宿主页面行高近似值传 3-6；卡片骨架 = 圆头像块 + 两行文字块，深浅色
 * 跟随 palette（surfaceSubtle 块面 / card 卡片底）。
 */
import { GSYFontSize, GSYSpacing } from '../style/Theme';
import { ThemeManager } from '../theme/ThemeManager';

@ComponentV2
export struct SkeletonList {
  /** 骨架行数（近似宿主首屏可视行数）。 */
  @Param rows: number = 4;
  /** 呼吸动画单程时长（ms）。 */
  @Param breatheDuration: number = 900;

  @Local private dim: boolean = false;

  aboutToAppear(): void {
    // 属性动画循环：alpha 两态切换 + 无限 animation，走系统渲染管线（120fps 插补）。
    this.dim = true;
  }

  @Builder
  buildOneRow(index: number): void {
    Row() {
      Column()
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(ThemeManager.current().surfaceSubtle);

      Column() {
        Column()
          .width('62%')
          .height(14)
          .borderRadius(4)
          .backgroundColor(ThemeManager.current().surfaceSubtle);
        Column()
          .width('86%')
          .height(12)
          .borderRadius(4)
          .backgroundColor(ThemeManager.current().surfaceSubtle)
          .margin({ top: 8 });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: GSYSpacing.normalEdge });
    }
    .width('100%')
    .padding({
      left: GSYSpacing.normalEdge,
      right: GSYSpacing.normalEdge,
      top: GSYSpacing.padding12,
      bottom: GSYSpacing.padding12,
    })
    .borderRadius(GSYSpacing.cardRadiusLg)
    .backgroundColor(ThemeManager.current().card)
    .border({ width: 1, color: ThemeManager.current().divider })
    .opacity(this.dim ? 0.55 : 1)
    .animation({
      duration: this.breatheDuration,
      curve: Curve.EaseInOut,
      iterations: -1,
      playMode: PlayMode.Alternate,
      // R12 P4：显式声明满帧区间，系统按声明调度高刷
      expectedFrameRateRange: { min: 60, max: 120, expected: 120 } as ExpectedFrameRateRange,
    });
  }

  build(): void {
    Column() {
      ForEach(Array.from({ length: this.rows }, (_v: undefined, i: number): number => i),
        (i: number): void => {
          this.buildOneRow(i);
        },
        (i: number): string => 'skeleton_row_' + i.toString());
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 8 })
    .alignItems(HorizontalAlign.Start);
  }
}
