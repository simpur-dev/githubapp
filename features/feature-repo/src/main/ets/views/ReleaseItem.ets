/**
 * ReleaseItem —— Release / Tag 列表行（V2）。
 * 严格对齐 RN [components/widget/ReleaseItem.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/widget/ReleaseItem.js)
 *
 * 结构（自上而下）：
 *  shadowCard（marginVertical=halfEdge, marginH=normalEdge, padding=normalEdge, radius=4）
 *  ├─ Row: actionTitle(small bold, layoutWeight=1) + TimeText(subSmall, marginTop=-20)
 *  └─ body: actionTargetHtml 真 → HTMLView(actionTarget, subSmall) ; 否 → Text(actionTargetHtml, subSmall)
 *
 * R9 V2：@ComponentV2 + @Param/@Event（TimeText / HTMLView 保持 common 既有组件）。
 */

import { GSYColor, GSYFontSize, GSYSpacing } from 'common';
import { TimeText } from 'common';
import { HTMLView } from 'common';

@ComponentV2
export struct ReleaseItem {
  @Param actionTime: string = '';
  @Param actionTitle: string = '';
  @Param actionTarget: string = '';
  @Param actionTargetHtml: string = '';
  @Param rowId: string = '';
  @Event onPressItem: () => void = (): void => {};
  @Event onLongPressItem: () => void = (): void => {};

  build(): void {
    Column() {
      Row() {
        Text(this.actionTitle)
          .id(this.rowId.length > 0 ? this.rowId + '_title' : 'release_item_title')
          .fontSize(GSYFontSize.small)
          .fontWeight(FontWeight.Bold)
          .fontColor(GSYColor.mainText)
          .layoutWeight(1)
          .margin({ left: GSYSpacing.halfEdge })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        TimeText({
          time: this.actionTime,
          marginTopValue: -20,
          textId: this.rowId.length > 0 ? this.rowId + '_time' : 'release_item_time',
        });
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      if (this.actionTargetHtml && this.actionTargetHtml.length > 0) {
        HTMLView({
          html: this.actionTarget,
          rootId: this.rowId.length > 0 ? this.rowId + '_body' : 'release_item_body',
        })
          .margin({ top: GSYSpacing.halfEdge });
      } else {
        Text(this.actionTargetHtml)
          .id(this.rowId.length > 0 ? this.rowId + '_body' : 'release_item_body')
          .fontSize(GSYFontSize.small)
          .fontColor(GSYColor.subText)
          .width('100%')
          .margin({ top: GSYSpacing.halfEdge });
      }
    }
    .id(this.rowId.length > 0 ? this.rowId : 'release_item_root')
    .width('100%')
    .padding(GSYSpacing.normalEdge)
    .margin({
      left: GSYSpacing.normalEdge,
      right: GSYSpacing.normalEdge,
      top: GSYSpacing.halfEdge,
      bottom: GSYSpacing.halfEdge,
    })
    .borderRadius(4)
    .backgroundColor(GSYColor.cardBackground)
    .shadow({
      radius: 4,
      color: GSYColor.cardShadow,
      offsetX: 1,
      offsetY: 1,
    })
    .alignItems(HorizontalAlign.Start)
    .onClick((): void => {
      this.onPressItem();
    })
    .gesture(
      LongPressGesture()
        .onAction((): void => {
          this.onLongPressItem();
        })
    );
  }
}
