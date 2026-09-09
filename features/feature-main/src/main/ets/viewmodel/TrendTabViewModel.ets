/**
 * TrendTabViewModel —— 趋势页签状态与编排（R9 V2 + MVVM）。
 *
 * @Trace UI 状态（2 个）：仓库列表 / 刷新中。
 * since / language 归 ViewModel 持有（普通字段，当前固定 daily + all-language，
 * 与 Compose TrendingScreen 一致，不支持 load more）。
 * TrendService 已无状态化（不写 store）：V1 时代 @State store 引用不变导致 build
 * 不重跑、需要 displayList 数组快照 workaround —— V2 @Trace 数组整体替换后该
 * workaround 已删除。
 */
import { TrendRepo, TREND_SINCE_DAILY, TREND_LANGUAGE_ALL, TrendSince } from 'common';
import { TrendService, FetchTrendingResult } from 'common';

@ObservedV2
export class TrendTabViewModel {
  @Trace items: TrendRepo[] = [];
  @Trace refreshing: boolean = false;
  private since: TrendSince = TREND_SINCE_DAILY;
  private language: string = TREND_LANGUAGE_ALL;
  private service: TrendService = new TrendService();

  setService(service: TrendService): void {
    this.service = service;
  }

  /** 首屏加载（View aboutToAppear 调用）。 */
  async init(): Promise<void> {
    await this.refresh();
  }

  async refresh(): Promise<void> {
    this.refreshing = true;
    try {
      const res: FetchTrendingResult = await this.service.fetchTrending(this.since, this.language);
      this.items = res.data;
    } finally {
      this.refreshing = false;
    }
  }
}
