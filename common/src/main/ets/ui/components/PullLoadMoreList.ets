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
import { GSYFontSize } from '../style/Theme';
import { ThemeManager } from '../theme/ThemeManager';
import { EmptyState } from './EmptyState';
import { I18n, TranslationMap } from '../../base/i18n/I18n';

/** 错误态标题（渲染期兜底 I18n，页面也可显式覆盖）。 */
const DEFAULT_ERROR_TITLE: string = 'Something went wrong';
/** 重试按钮文案（R12：英文默认值改为渲染期 I18n 兜底）。 */
const DEFAULT_RETRY_TEXT: string = '';

/** 错误态文案兜底：参数未传时取当前语言文案。 */
function resolveRetryText(passed: string): string {
  if (passed.length > 0) {
    return passed;
  }
  return I18n('retry');
}

/** 错误态标题兜底。 */
function resolveErrorTitle(): string {
  return DEFAULT_ERROR_TITLE;
}

/** 空态/页脚文案兜底：参数未传时取当前语言文案。 */
function resolveListText(passed: string, i18nKey: keyof TranslationMap): string {
  if (passed.length > 0) {
    return passed;
  }
  return I18n(i18nKey);
}

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
  /** R11 A7：文案参数不传时渲染期兜底 I18n（原先英文默认值导致未传页显示英文）。 */
  @Param emptyText: string = '';
  @Param loadingMoreText: string = '';
  @Param loadEndText: string = '';
  /** 兼容旧 API 保留（旧版也未在 UI 中使用该文案）。 */
  @Param refreshingText: string = '';
  /** 是否响应下拉刷新手势（历史上无调用方覆盖，默认 true）。 */
  @Param enableRefresh: boolean = true;
  /** 列表尾部追加占位高度（旧 API 保留，历史上无调用方使用）。 */
  @Param tailPadding: number = 0;
  /** 调用方可注入自己的 Scroller（如搜索页刷新后 scrollToIndex(0)）；不传时组件内部自建。 */
  @Param listScroller: Scroller | null = null;
  /** 是否渲染 footer 文案行（不支持分页的页面如趋势页传 false，保持旧版无 footer 视觉）。 */
  @Param showFooter: boolean = true;
  /** R10 阶段3 错误态：true 且无数据时渲染 EmptyState（带重试按钮）替代 renderEmpty。 */
  @Param error: boolean = false;
  /** 错误详情文案（EmptyState 副标题，可选）。 */
  @Param errorText: string = '';
  /** R12 P2：预缓存行数分级（图片重的列表传大值保障快滑无白块；默认纯文本 5）。 */
  @Param cachedCountParam: number = 5;
  /** R12 P3：行左滑开关（与 rowSwipeEnd 配套；默认关，不传完全无侧滑开销）。 */
  @Param enableRowSwipe: boolean = false;
  /** R12 P3：左滑露出内容（官方通知交互：左滑标记已读）。 */
  @BuilderParam rowSwipeEnd: (item: Object, index: number) => void = this.noSwipe;

  @Builder
  noSwipe(_item: Object, _index: number): void {
  }

  @Event onRefresh: () => void = (): void => {};
  @Event onLoadMore: () => void = (): void => {};
  /** 错误态重试回调（页面侧负责清错误标记并重新拉取）。 */
  @Event retryError: () => void = (): void => {};

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
    // R10 阶段3：默认空态统一走 EmptyState（无重试按钮形态）。
    EmptyState({ title: resolveListText(this.emptyText, 'listEmpty') });
  }

  @Builder
  buildErrorState(): void {
    EmptyState({
      iconText: 'more',
      title: resolveErrorTitle(),
      subtitle: this.errorText,
      retryText: resolveRetryText(DEFAULT_RETRY_TEXT),
      retry: (): void => {
        this.retryError();
      },
    });
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
          Text(resolveListText(this.loadingMoreText, 'loadMoreing'))
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
          Text(resolveListText(this.loadEndText, 'loadMoreEnd'))
            .id('pull_load_more_end_text')
            .fontSize(GSYFontSize.small)
            .fontColor(ThemeManager.current().textSecondary);
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center);
      } else {
        Row() {
          Text(resolveListText(this.loadingMoreText, 'loadMoreing'))
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
            // API 26 VirtualScrollOptions.memoryOptimizationStrategy：
            // Repeat 自动缓存优化，进一步降低长列表内存占用。
            .virtualScroll({ memoryOptimizationStrategy: RepeatMemOptStrategy.ENABLE_AUTO_CACHE_OPTIMIZATION })
            .each((obj: RepeatItem<Object>): void => {
              ListItem() {
                this.renderRow(obj.item, obj.index);
              }
                .swipeAction(this.enableRowSwipe
                  ? {
                    end: (): void => {
                      this.rowSwipeEnd(obj.item, obj.index);
                    },
                  }
                  : {})
            })
            .key((item: Object, index: number): string => {
              // 与旧 ForEach key 同款：index + 内容摘要，保证 dataSource 整体替换后行内容重建。
              const tag: string = JSON.stringify(item);
              return index.toString() + '_' + (tag.length > 96 ? tag.substring(0, 96) : tag);
            });
        } else {
          ListItem() {
            if (this.error) {
              this.buildErrorState();
            } else {
              this.renderEmpty();
            }
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
      // R12 修复：短列表时 ListItem 交叉/主轴不得拉伸（默认 Stretch 会把唯一一行
      // 拉成整屏高，swipeAction 露出区因此以全高为参考系跑到屏幕中部）
      .alignListItem(ListItemAlign.Start)
      .cachedCount(this.cachedCountParam)
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
