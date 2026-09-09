/**
 * DynamicTabViewModel —— 动态页签状态与编排（R9 V2 + MVVM）。
 *
 * @Trace UI 状态（5 个）：事件列表 / 刷新中 / 加载更多中 / 是否有更多 / 错误文案。
 * 分页游标 page 为非 UI 状态，普通私有字段。
 * DynamicService 已无状态化（不写 store），返回 FetchReceivedResult（含 page/hasMore），
 * 失败时若携带首页缓存数据则兜底展示（等价旧 DynamicStore.applyCachedFallback 语义）。
 */
import { DynamicEvent } from 'common';
import { DynamicService, FetchReceivedResult } from 'common';
import { GlobalAuthStore } from 'common';

const FALLBACK_USER: string = 'octocat';

@ObservedV2
export class DynamicTabViewModel {
  @Trace items: DynamicEvent[] = [];
  @Trace refreshing: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = true;
  @Trace errorMessage: string = '';
  private page: number = 1;
  private service: DynamicService = new DynamicService();

  setService(service: DynamicService): void {
    this.service = service;
  }

  itemKey(item: DynamicEvent, index: number): string {
    return index.toString() + '_' + item.id;
  }

  private resolveUser(): string {
    const u: string | null = GlobalAuthStore.userInfo !== null && GlobalAuthStore.userInfo !== undefined
      ? GlobalAuthStore.userInfo.login
      : null;
    if (u !== null && u !== undefined && u.length > 0) {
      return u;
    }
    return FALLBACK_USER;
  }

  /** 首屏加载（View aboutToAppear 调用）。 */
  async init(): Promise<void> {
    await this.refresh();
  }

  applyResult(res: FetchReceivedResult, isAppend: boolean): void {
    if (res.result) {
      if (isAppend) {
        this.items = this.items.concat(res.data);
      } else {
        this.items = res.data;
      }
      this.page = res.page;
      this.hasMore = res.hasMore;
      this.errorMessage = '';
      return;
    }
    this.errorMessage = res.msg;
    // 失败兜底：401 时携带首页缓存 → 列表为空时展示缓存（旧 store 缓存可见语义）。
    if (this.items.length === 0 && res.data.length > 0) {
      this.items = res.data;
      this.page = res.page;
      this.hasMore = res.hasMore;
    }
  }

  async refresh(): Promise<void> {
    this.refreshing = true;
    this.errorMessage = '';
    try {
      const res: FetchReceivedResult = await this.service.fetchReceivedEvents(this.resolveUser(), 1);
      this.applyResult(res, false);
    } finally {
      this.refreshing = false;
    }
  }

  async loadMore(): Promise<void> {
    if (this.loadingMore || !this.hasMore) {
      return;
    }
    this.loadingMore = true;
    const next: number = this.page + 1;
    try {
      const res: FetchReceivedResult = await this.service.fetchReceivedEvents(this.resolveUser(), next);
      this.applyResult(res, res.result);
    } finally {
      this.loadingMore = false;
    }
  }
}
