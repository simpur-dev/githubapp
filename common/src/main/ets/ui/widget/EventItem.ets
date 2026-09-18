/**
 * EventItem —— 对齐 Android Compose core/ui/components/EventItem.kt。
 *
 * 结构：卡片内横排头像和内容列；内容列依次是用户名、动作描述、相对时间。
 * Issue/Push 的详情文本不在列表卡片中展开，点击仍由 EventActionDispatcher 处理。
 */

import { GSYFontSize, GSYSpacing, GSYShadow } from '../style/Theme';
import { ThemeManager } from '../theme/ThemeManager';
import { TimeUtil } from '../../base/utils/TimeUtil';
import { UserImage } from './UserImage';
import { PressableCard } from './PressableCard';

/** R12 KI-R12-006：长按菜单项模型（label 系统菜单渲染，onPick 回调调用方业务）。 */
export interface EventMenuItem {
  label: string;
  onPick: () => void;
}

@ComponentV2
export struct EventItem {
  @Param actionTime: string = '';
  @Param actionUser: string = '';
  @Param actionUserPic: string = '';
  @Param actionTarget: string = '';
  @Param des: string = '';
  @Param rowId: string = '';
  /** R12 KI-R12-006：长按快捷菜单项（对齐官方 App 长按交互；label + 回调由调用方给）。 */
  @Param menuItems: EventMenuItem[] = [];
  /** R12 KI-R12-006：受控菜单开关（长按置 true，bindMenu 跳变弹出）。 */
  @Local showMenu: boolean = false;
  @Event onPressItem: () => void = (): void => {};
  @Event onPressUser: () => void = (): void => {};

  /** R12 KI-R12-006：菜单内容（MenuElement[] 数据直给）。 */
  private rowMenuContent(): MenuElement[] {
    return this.menuItems.map((item: EventMenuItem): MenuElement => {
      const element: MenuElement = { value: item.label, action: item.onPick };
      return element;
    });
  }

  build(): void {
    // R10 阶段3：整卡按压反馈（蒙层 + 0.98 缩放），行内 .id / onClick 原样保留。
    PressableCard({ cornerRadius: GSYSpacing.cardRadiusLg }) {
      Column() {
      Row() {
        UserImage({
          uri: this.actionUserPic,
          loginUser: this.actionUser,
          imageSize: 40,
          imageId: this.rowId.length > 0 ? this.rowId + '_avatar' : 'event_item_avatar',
          onAvatarTap: (): void => {
            this.onPressUser();
          },
        })
          .margin({ right: GSYSpacing.normalEdge });

        Column() {
          Text(this.actionUser)
            .id(this.rowId.length > 0 ? this.rowId + '_user' : 'event_item_user')
            .fontSize(GSYFontSize.small)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeManager.current().text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          Text(this.actionTarget)
            .id(this.rowId.length > 0 ? this.rowId + '_target' : 'event_item_target')
            .fontSize(GSYFontSize.middleWhite)
            .fontColor(ThemeManager.current().textSecondary)
            .margin({ top: 4 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          Text(TimeUtil.resolveTime(this.actionTime))
            .id(this.rowId.length > 0 ? this.rowId + '_time' : 'event_item_time')
            .fontSize(GSYFontSize.small)
            .fontColor(ThemeManager.current().textSecondary)
            .margin({ top: 4 });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .alignItems(VerticalAlign.Top);
    }
    // R12 KI-R12-006：长按快捷菜单（系统 bindContextMenu，LongPress 触发）
    // R12 KI-R12-006：长按快捷菜单（LongPressGesture 捕获 + bindMenu(isShow) 受控弹出）
    .gesture(LongPressGesture({ repeat: false, duration: 500 })
      .onAction((): void => {
        this.showMenu = false;
        setTimeout((): void => {
          this.showMenu = true;
        }, 60);
      }))
    .bindMenu(this.showMenu, this.rowMenuContent())
    .id(this.rowId.length > 0 ? this.rowId : 'event_item_root')
    .width('auto')
    .padding({
      left: 16,
      right: 16,
      top: 12,
      bottom: 12,
    })
    .borderRadius(GSYSpacing.cardRadiusLg)
    .backgroundColor(ThemeManager.current().card)
    .border({
      width: 1,
      color: ThemeManager.current().divider,
    })
    .shadow({
      radius: 6,
      color: GSYShadow.cardShadowAlpha,
      offsetX: 0,
      offsetY: 2,
    })
    .alignItems(HorizontalAlign.Start)
    .onClick((): void => {
      this.onPressItem();
    })
    .margin({
      left: GSYSpacing.normalEdge,
      right: GSYSpacing.normalEdge,
      top: GSYSpacing.halfEdge,
      bottom: GSYSpacing.halfEdge,
    });
    }
  }
}
