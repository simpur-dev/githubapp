/**
 * CommonBottomBar —— 1:1 对齐 RN 端
 * [components/common/CommonBottomBar.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/common/CommonBottomBar.js)
 *
 * 通用横向按键控件，dataList 驱动 N 项；每项 = TouchableOpacity{ Icon + Text }，
 * 平均分配剩余空间（layoutWeight=1）。RN 端 paddingVertical=normalMarginEdge + shadowCard。
 *
 * RN 用 react-native-vector-icons/Octicons；OH 端无 Octicons，
 * 调用方需自行传入 [IconFont.ets](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/common/IconFont.ets) 暴露的 FontAwesome 码点字符串。
 *
 * R9 阶段4：页面级底部工具栏改由 NavDestination .toolbarConfiguration 呈现
 * （经 common/ui/navigation/NavTitleBridge.ets 的 NavBottomBarView 复用本组件，id 全保留）。
 * 本组件保留的直接调用方：RepositoryDetail 的 ActivityTab 头部选择条（repo_activity_select_bar，
 * 属随内容滚动的头部控件，不是页底工具栏，不做迁移）。
 */

import { GSYColor, GSYFontSize, GSYSpacing, GSYShadow } from '../style/Theme';
import { IconFont } from './IconFont';

const ITEM_ICON_SIZE: number = 14;
const ICON_TEXT_GAP: number = 10;
const REPO_ACTION_WIDTH: number = 78;
const REPO_ACTION_ICON_TEXT_GAP: number = 4;

export class CommonBottomBarItem {
  itemName: string = '';
  icon: string = '';
  iconColor: string = GSYColor.primary;
  itemTextColor: string = GSYColor.primary;
  itemClick: () => void = (): void => {};
  itemId: string = '';
}

@Builder
function doNothingTrailingMenuBuilder(): void {
}

@ComponentV2
export struct CommonBottomBar {
  @Param dataList: CommonBottomBarItem[] = [];
  @Param rootId: string = 'common_bottom_bar';
  @Param rootBackgroundColor: ResourceColor = GSYColor.white;
  @Param rootMarginHorizontal: number = 0;
  @Param rootMarginTop: number = 0;
  @Param rootMarginBottom: number = 0;
  @Param rootBorderRadius: number = 0;
  // 0 表示不显式约束（保持 wrap content）。
  // 历史教训：父侧若用 `.layoutWeight(1)` 给 Tabs 撑满，再放本组件兄弟节点时
  // 子项 Row .height('100%') 会向上传染撑垮 Tabs.layoutWeight(1)。
  // 调用方应主动传一个固定 height（与 RN CommonBottomBar 高度一致 ~ 50）。
  @Param rootHeight: number = 0;
  @Param showShadow: boolean = true;
  @Param repoActionStyle: boolean = false;
  @Param materialFloatingStyle: boolean = false;
  @Param trailingItemId: string = 'branch';
  /** repoActionStyle 尾项受控 bindMenu（API 11+）的显隐，由调用方状态驱动。 */
  @Param trailingMenuShow: boolean = false;
  /** repoActionStyle 尾项菜单内容（调用方 @Builder 经 @BuilderParam 传入）。 */
  @BuilderParam trailingMenuBuilder: () => void = doNothingTrailingMenuBuilder;
  /** 菜单因点外部等原因关闭时回传调用方，用于同步调用侧显隐状态。 */
  @Event onTrailingMenuDismiss: () => void = (): void => {};
  @Local dataListRev: number = 0;

  // dataList 整体替换时也强制行重建（与旧 @Watch 版同款语义）。
  @Monitor('dataList')
  onDataListChanged(): void {
    this.dataListRev++;
  }

  @Builder
  buildItem(item: CommonBottomBarItem, index: number): void {
        if (this.repoActionStyle && item.itemId !== this.trailingItemId) {
          Column() {
            if (item.icon.length > 0) {
              IconFont({
                char: item.icon,
                glyphSize: ITEM_ICON_SIZE + 2,
                glyphColor: item.iconColor,
              });
            }
            Text(item.itemName)
              .id(item.itemId.length > 0
                ? 'common_bottom_bar_text_' + item.itemId
                : 'common_bottom_bar_text_' + index.toString())
              .margin({ top: REPO_ACTION_ICON_TEXT_GAP })
              .fontSize(GSYFontSize.min)
              .fontColor(item.itemTextColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .id(item.itemId.length > 0
            ? 'common_bottom_bar_item_' + item.itemId
            : 'common_bottom_bar_item_' + index.toString())
          .width(REPO_ACTION_WIDTH)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .hitTestBehavior(HitTestMode.Block)
          .onClick((): void => {
            item.itemClick();
          });
        } else if (this.repoActionStyle) {
          Row() {
            Text(item.itemName)
              .id(item.itemId.length > 0
                ? 'common_bottom_bar_text_' + item.itemId
                : 'common_bottom_bar_text_' + index.toString())
              .fontSize(GSYFontSize.min)
              .fontColor(item.itemTextColor)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
            if (item.icon.length > 0) {
              IconFont({
                char: item.icon,
                glyphSize: ITEM_ICON_SIZE,
                glyphColor: item.iconColor,
              })
                .margin({ left: 4 });
            }
          }
          .id(item.itemId.length > 0
            ? 'common_bottom_bar_item_' + item.itemId
            : 'common_bottom_bar_item_' + index.toString())
          .layoutWeight(1)
          .height('100%')
          .padding({ right: GSYSpacing.normalEdge })
          .justifyContent(FlexAlign.End)
          .alignItems(VerticalAlign.Center)
          .hitTestBehavior(HitTestMode.Block)
          .bindMenu(this.trailingMenuShow, this.trailingMenuBuilder, {
            onDisappear: (): void => {
              this.onTrailingMenuDismiss();
            },
          })
          .onClick((): void => {
            item.itemClick();
          });
        } else {
          Row() {
            if (item.icon.length > 0) {
              IconFont({
                char: item.icon,
                glyphSize: ITEM_ICON_SIZE,
                glyphColor: item.iconColor,
              });
            }
            Text(item.itemName)
              .id(item.itemId.length > 0
                ? 'common_bottom_bar_text_' + item.itemId
                : 'common_bottom_bar_text_' + index.toString())
              .margin({ left: ICON_TEXT_GAP })
              .fontSize(GSYFontSize.small)
              .fontColor(item.itemTextColor);
          }
          .id(item.itemId.length > 0
            ? 'common_bottom_bar_item_' + item.itemId
            : 'common_bottom_bar_item_' + index.toString())
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .hitTestBehavior(HitTestMode.Block)
          .onClick((): void => {
            item.itemClick();
          });
        }
  }

  build(): void {
    Row() {
      Repeat<CommonBottomBarItem>(this.dataList)
        .each((obj: RepeatItem<CommonBottomBarItem>): void => {
          this.buildItem(obj.item, obj.index);
        })
        .key((item: CommonBottomBarItem, index: number): string =>
          this.dataListRev.toString() + ':' + index.toString() + ':' + item.itemId + ':' + item.itemName + ':' + item.icon + ':' + item.iconColor + ':' + item.itemTextColor);
    }
    .id(this.rootId)
    .width('100%')
    .height(this.rootHeight > 0 ? this.rootHeight : GSYSpacing.bottomBarDefault)
    .padding({
      top: GSYSpacing.normalEdge,
      bottom: GSYSpacing.normalEdge,
    })
    .margin({
      left: this.rootMarginHorizontal,
      right: this.rootMarginHorizontal,
      top: this.rootMarginTop,
      bottom: this.rootMarginBottom,
    })
    .borderRadius(this.rootBorderRadius)
    .backgroundColor(this.materialFloatingStyle ? GSYColor.hdsMaterialSurface : this.rootBackgroundColor)
    .backgroundBlurStyle(this.materialFloatingStyle ? BlurStyle.COMPONENT_REGULAR : BlurStyle.NONE)
    .border(this.materialFloatingStyle ? {
      width: 0.5,
      color: GSYColor.hdsMaterialBorder,
    } : undefined)
    .shadow(this.showShadow ? {
      radius: this.materialFloatingStyle ? 14 : GSYShadow.radius,
      color: this.materialFloatingStyle ? GSYColor.hdsMaterialShadow : GSYColor.line,
      offsetX: 0,
      offsetY: this.materialFloatingStyle ? -2 : -GSYShadow.elevation,
    } : undefined)
    .alignItems(VerticalAlign.Center);
  }
}
