/**
 * NotifyContent —— 通知列表内容（R12 P1 从 NotifyPage 抽取复用）。
 *
 * 推送页（NotifyPage，NavDestination 外壳 + 原生标题栏菜单）与
 * 通知 Tab（NotificationsTabPage，首页五 Tab 之一）共用本组件，
 * 各自持有独立的 NotifyViewModel 实例。
 * 全部测试 id（notify_tab_bar / notify_row_* / notify_empty_* 等）原样保留。
 */
import { I18n } from 'common';
import { TimeUtil } from 'common';
import { PullLoadMoreList } from 'common';
import { GSYColor, GSYFontSize, GSYShadow, GSYSpacing } from 'common';
import { ThemeManager } from 'common';
import { EmptyState } from 'common';
import { SkeletonList } from 'common';
import { PressableCard } from 'common';
import { NotifyThread } from 'common';
import { NotifyViewModel, NotifyTabItem } from '../viewmodel/NotifyViewModel';

@ComponentV2
export struct NotifyContent {
  @Param vm: NotifyViewModel = new NotifyViewModel();

  private buildStatusText(item: NotifyThread): string {
    const status: string = item.unread ? I18n('notifyStatusUnread') : I18n('notifyStatusRead');
    return I18n('notifyType') + ': ' + item.subject.type + ', '
      + I18n('notifyStatus') + ': ' + status;
  }

  @Builder
  buildTabBar(): void {
    // R10 阶段3：三段切换条升级 —— surfaceSubtle 胶囊容器，选中段 navBackground 底 +
    // onBrandText 字，未选段透明底 + textSecondary 字，150ms 属性动画过渡。
    // 结构与测试 id（notify_tab_bar / notify_tab_N）原样保留。
    Row() {
      Row() {
        Repeat<NotifyTabItem>(this.vm.tabs)
          .each((obj: RepeatItem<NotifyTabItem>): void => {
            Button(obj.item.label)
              .id('notify_tab_' + obj.index.toString())
              .type(ButtonType.Capsule)
              .height(GSYSpacing.segBarHeight)
              .layoutWeight(1)
              .backgroundColor(this.vm.currentTabIndex === obj.index
                ? ThemeManager.current().navBackground : GSYColor.transparent)
              .fontColor(this.vm.currentTabIndex === obj.index
                ? ThemeManager.current().onBrandText : ThemeManager.current().textSecondary)
              .fontSize(GSYFontSize.small)
              .animation({
                duration: 150,
                curve: Curve.EaseInOut,
                expectedFrameRateRange: { min: 60, max: 120, expected: 120 } as ExpectedFrameRateRange,
              })
              .onClick((): void => {
                this.vm.onTabChanged(obj.index);
              });
          })
          .key((tab: NotifyTabItem): string => 'notify_tab_key_' + tab.filter)
      }
      .layoutWeight(1)
      .height(GSYSpacing.segBarHeight + GSYSpacing.segBarPadding * 2)
      .padding(GSYSpacing.segBarPadding)
      .borderRadius(GSYSpacing.segBarRadius)
      .backgroundColor(ThemeManager.current().surfaceSubtle)
      .alignItems(VerticalAlign.Center)
    }
    .id('notify_tab_bar')
    .width('100%')
    .height(72)
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(ThemeManager.current().tabBackground)
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  rowBuilder(item: NotifyThread, index: number): void {
    Row() {
      // R10 阶段3：整卡按压反馈；未读行加 accent 圆点指示（深浅色通用，unreadBg
      // 为浅色专属 token 故不采用）。行内 .id / onClick 原样保留。
      PressableCard({ cornerRadius: GSYSpacing.cardRadiusLg }) {
        Row() {
          if (item.unread) {
            Column()
              .width(GSYSpacing.unreadDotSize)
              .height(GSYSpacing.unreadDotSize)
              .borderRadius(GSYSpacing.unreadDotSize / 2)
              .backgroundColor(ThemeManager.current().accent)
              .margin({ right: GSYSpacing.halfEdge });
          }

          Column() {
            Row() {
              Text(item.repository.full_name)
                .id('notify_row_repo_' + index.toString())
                .fontSize(GSYFontSize.small)
                .fontColor(ThemeManager.current().text)
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis });

              Text(TimeUtil.resolveTime(item.updated_at))
                .id('notify_row_time_' + index.toString())
                .fontSize(GSYFontSize.small)
                .fontColor(ThemeManager.current().textSecondary)
                .margin({ left: GSYSpacing.halfEdge });
            }
            .id('notify_row_meta_' + index.toString())
            .width('100%')
            .alignItems(VerticalAlign.Center);

            Text(item.subject.title)
              .id('notify_row_title_' + index.toString())
              .fontSize(GSYFontSize.middleWhite)
              .fontColor(ThemeManager.current().text)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: GSYSpacing.halfEdge });

            Text(this.buildStatusText(item))
              .id('notify_row_status_' + index.toString())
              .fontSize(GSYFontSize.small)
              .fontColor(ThemeManager.current().textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: GSYSpacing.halfEdge });
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .id('notify_row_card_' + index.toString())
        .width('100%')
        .padding({
          left: GSYSpacing.normalEdge,
          right: GSYSpacing.normalEdge,
          top: GSYSpacing.normalEdge,
          bottom: GSYSpacing.normalEdge,
        })
        .borderRadius(GSYSpacing.cardRadiusLg)
        .border({ width: 1, color: ThemeManager.current().divider })
        .backgroundColor(ThemeManager.current().card)
        .shadow({
          radius: GSYShadow.radius,
          color: GSYShadow.cardShadowAlpha,
          offsetX: 1,
          offsetY: 1,
        })
        .alignItems(VerticalAlign.Center);
      }
    }
    .id('notify_row_' + index.toString())
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .onClick((): void => {
      this.vm.onThreadClick(item);
    });
  }

  @Builder
  emptyBuilder(): void {
    // R10 阶段3：统一空态组件；rootId/titleId 透传保住历史测试 id。
    EmptyState({
      title: I18n('notifyEmpty'),
      rootId: 'notify_empty_root',
      titleId: 'notify_empty_text',
    });
  }

  @Builder
  buildInitialLoading(): void {
    // R12 P2：首屏骨架屏（呼吸属性动画走系统渲染管线），替代转圈
    Column() {
      SkeletonList({ rows: 4 })
        .id('notify_initial_loading_indicator');
    }
    .id('notify_initial_loading')
    .width('100%')
    .layoutWeight(1);
  }

  @Builder
  buildInitialError(): void {
    Column() {
      Text(this.vm.error.length > 0 ? this.vm.error : I18n('unknown'))
        .id('notify_initial_error_text')
        .fontSize(GSYFontSize.middleWhite)
        .fontColor(ThemeManager.current().textSecondary)
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 });

      // R10 阶段3：首屏错误态补重试按钮（原文案/id 不动）。
      Button(I18n('retry'))
        .id('notify_initial_error_retry')
        .type(ButtonType.Capsule)
        .height(GSYSpacing.pillButtonHeight)
        .backgroundColor(ThemeManager.current().accent)
        .fontColor(ThemeManager.current().onBrandText)
        .fontSize(GSYFontSize.small)
        .padding({ left: GSYSpacing.padding12, right: GSYSpacing.padding12 })
        .margin({ top: GSYSpacing.padding12 })
        .onClick((): void => {
          this.vm.refresh();
        });
    }
    .id('notify_initial_error')
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  /** R12 P3：左滑露出"标记已读"动作（对齐官方 App Inbox 手势）。 */
  @Builder
  rowSwipeEnd(item: Object, index: number): void {
    Row() {
      SymbolGlyph($r('sys.symbol.checkmark'))
        .fontSize(20)
        .fontColor([ThemeManager.current().onBrandText]);
      Text(I18n('notifyMarkRead'))
        .fontSize(GSYFontSize.small)
        .fontColor(ThemeManager.current().onBrandText)
        .margin({ left: 4 });
    }
    // R12 修复：swipe 露出区高度必须自适应内容（'100%' 会在短列表里被
    // ListItem 拉伸撑满整屏，如本条初版所示）
    .id('notify_row_swipe_read_' + index.toString())
    .width(96)
    .height(GSYSpacing.bottomBarDefault)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(ThemeManager.current().accent)
    .borderRadius(GSYSpacing.cardRadiusLg)
    .alignSelf(ItemAlign.Center)
    .margin({ right: 16 })
    .onClick((): void => {
      this.vm.markThreadRead(item as NotifyThread);
    });
  }

  @Builder
  buildNotifyContent(): void {
    this.buildTabBar();

    PullLoadMoreList({
      dataSource: this.vm.items,
      refreshing: this.vm.refreshing,
      loadingMore: this.vm.loadingMore,
      noMore: !this.vm.hasMore,
      enableRowSwipe: true,
      rowSwipeEnd: (item: Object, index: number): void => this.rowSwipeEnd(item, index),
      renderRow: (item: Object, index: number): void => this.rowBuilder(item as NotifyThread, index),
      renderEmpty: (): void => this.emptyBuilder(),
      onRefresh: (): void => {
        this.vm.refresh();
      },
      onLoadMore: (): void => {
        this.vm.loadMore();
      },
    })
      .id('notify_pull_list')
      .layoutWeight(1);
  }

  build(): void {
    Column() {
      if (this.vm.initialPageLoading && this.vm.items.length === 0) {
        this.buildInitialLoading();
      } else if (this.vm.error.length > 0 && this.vm.items.length === 0) {
        this.buildInitialError();
      } else {
        this.buildNotifyContent();
      }
    }
    .id('notify_root')
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeManager.current().background);
  }
}
