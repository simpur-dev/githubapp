/**
 * PullLoadMoreList —— V2 受控列表容器（R9 V2 + MVVM 契约，见 harness/R9/V2-MIGRATION-GUIDE.md §4）。
 *
 * 旧 V1 版（V1 组件装饰器 + PullLoadMoreController 状态机）已删除：
 *   - 刷新/加载状态全部由调用方（页面 ViewModel 的 @Trace 字段或 V1 页面的 @State）受控传入；
 *   - 删掉自绘刷新 overlay（Stack 叠 LoadingProgress + refreshingContent opacity(0) 空 Row），
 *     改用原生 Refresh 自带下拉指示器，由 refreshing 参数驱动；
 *   - 内部数据行 ForEach → Repeat（virtualScroll），cachedCount 放 List 上；
 *   - footer（Loading more… / No more data 文案行）与空态样式沿用原 token；
 *   - 调用方 .id() 机制不变（组件本身不带 id，由调用方挂在实例上）。
 */
import { systemInsets } from '../../base/utils/SafeAreaInsets';
import { GSYFontSize } from '../style/Theme';
import { ThemeManager } from '../theme/ThemeManager';

@ComponentV2
export struct PullLoadMoreList {
  @Require @Param dataSource: Object[] = [];
  /** 下拉刷新中（ViewModel 完成后置回 false，指示器随之收起）。 */
  @Param refreshing: boolean = false;
  /** 没有更多数据：footer 显示 "No more data" 文案行。 */
  @Param noMore: boolean = false;
  /** 正在加载下一页：footer 显示 spinner + "Loading more…" 文案行。 */
  @Param loadingMore: boolean = false;
  /** 空态强制开关；不传时按 dataSource 为空自动显示（与旧版行为一致）。 */
  @Param showEmpty: boolean = false;
  @Param emptyText: string = 'No content yet, tap to retry';
  @Param loadingMoreText: string = 'Loading more…';
  @Param loadEndText: string = 'No more data';
  /** 兼容旧 API 保留（旧版也未在 UI 中使用该文案）。 */
  @Param refreshingText: string = 'Refreshing…';
  /** 是否响应下拉刷新手势（历史上无调用方覆盖，默认 true）。 */
  @Param enableRefresh: boolean = true;
  /** 列表尾部追加占位高度（旧 API 保留，历史上无调用方使用）。 */
  @Param tailPadding: number = systemInsets.bottom; // 全屏沉浸：末行可滚动出手势条区
  /** 调用方可注入自己的 Scroller（如搜索页刷新后 scrollToIndex(0)）；不传时组件内部自建。 */
  @Param listScroller: Scroller | null = null;
  /** 是否渲染 footer 文案行（不支持分页的页面如趋势页传 false，保持旧版无 footer 视觉）。 */
  @Param showFooter: boolean = true;

  @Event onRefresh: () => void = (): void => {};
  @Event onLoadMore: () => void = (): void => {};

  @BuilderParam renderRow: (item: Object, index: number) => void = this.defaultRow;
  @BuilderParam renderHeader: () => void = this.defaultEmptyBuilder;
  @BuilderParam renderEmpty: () => void = this.defaultEmptyState;

  private internalScroller: Scroller = new Scroller();
  // 原生 Refresh 指示器状态：受控 refreshing 参数 + 手势状态合并驱动。
  @Local nativeRefreshing: boolean = false;

  private get scroller(): Scroller {
    return this.listScroller !== null ? this.listScroller : this.internalScroller;
  }

  aboutToAppear(): void {
    if (this.refreshing) {
      this.nativeRefreshing = true;
    }
  }

  @Monitor('refreshing')
  onRefreshingParamChange(): void {
    // ViewModel 把 refreshing 置回 false 时收起原生指示器。
    this.nativeRefreshing = this.refreshing;
  }

  private hasData(): boolean {
    return this.dataSource !== null && this.dataSource !== undefined && this.dataSource.length > 0;
  }

  @Builder
  defaultRow(_item: Object, _index: number): void {
    Row().height(0);
  }

  @Builder
  defaultEmptyBuilder(): void {
  }

  @Builder
  defaultEmptyState(): void {
    Column() {
      Text(this.emptyText)
        .fontSize(GSYFontSize.middleNormal)
        .fontColor(ThemeManager.current().textSecondary);
    }
    .width('100%')
    .height(240)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  buildFooter(): void {
    if (this.showFooter && !this.refreshing && this.hasData()) {
      if (this.loadingMore) {
        Row() {
          LoadingProgress()
            .id('pull_load_more_indicator')
            .width(24)
            .height(24)
            .color(ThemeManager.current().text);
          Text(this.loadingMoreText)
            .id('pull_load_more_text')
            .fontSize(GSYFontSize.small)
            .fontColor(ThemeManager.current().textSecondary)
            .margin({ left: 8 });
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center);
      } else if (this.noMore) {
        Row() {
          Text(this.loadEndText)
            .id('pull_load_more_end_text')
            .fontSize(GSYFontSize.small)
            .fontColor(ThemeManager.current().textSecondary);
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center);
      } else {
        Row() {
          Text(this.loadingMoreText)
            .id('pull_load_more_text')
            .fontSize(GSYFontSize.small)
            .fontColor(ThemeManager.current().textSecondary);
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center);
      }
    }
  }

  build(): void {
    Refresh({ refreshing: this.nativeRefreshing }) {
      List({ space: 0, scroller: this.scroller }) {
        ListItem() {
          this.renderHeader();
        }

        if (this.hasData()) {
          Repeat<Object>(this.dataSource)
            .virtualScroll()
            .each((obj: RepeatItem<Object>): void => {
              ListItem() {
                this.renderRow(obj.item, obj.index);
              }
            })
            .key((item: Object, index: number): string => {
              // 与旧 ForEach key 同款：index + 内容摘要，保证 dataSource 整体替换后行内容重建。
              const tag: string = JSON.stringify(item);
              return index.toString() + '_' + (tag.length > 96 ? tag.substring(0, 96) : tag);
            });
        } else {
          ListItem() {
            this.renderEmpty();
          }
        }

        ListItem() {
          this.buildFooter();
        }

        if (this.tailPadding > 0) {
          ListItem() {
            Row().height(this.tailPadding);
          }
        }
      }
      .width('100%')
      .height('100%')
      .cachedCount(5)
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd((): void => {
        if (this.refreshing || this.loadingMore || this.noMore || !this.hasData()) {
          return;
        }
        this.onLoadMore();
      });
    }
    .width('100%')
    .height('100%')
    .onStateChange((state: RefreshStatus): void => {
      if (state === RefreshStatus.Refresh) {
        this.nativeRefreshing = false;
        if (!this.enableRefresh) {
          return;
        }
        this.onRefresh();
      }
    });
  }
}
