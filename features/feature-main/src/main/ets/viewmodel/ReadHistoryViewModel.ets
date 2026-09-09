/**
 * ReadHistoryViewModel —— 阅读历史页状态与编排（R9 V2 + MVVM）。
 *
 * @Trace UI 状态（4 个）：历史列表 / 刷新中 / 加载更多中 / 是否有更多。
 * ReadHistoryService 已无状态化（去 uiStore/bindStore），list/clear 只返回数据；
 * 工厂签名 setReadHistoryServiceFactory 同步去掉 store 参数。
 */
import { ReadHistoryItem, READ_HISTORY_TYPE_REPO } from 'common';
import { ReadHistoryService, READ_HISTORY_PAGE_SIZE } from 'common';

export type ReadHistoryServiceFactory = () => ReadHistoryService;

let readHistoryServiceFactory: ReadHistoryServiceFactory | null = null;

export function setReadHistoryServiceFactory(factory: ReadHistoryServiceFactory | null): void {
  readHistoryServiceFactory = factory;
}

export function buildReadHistoryService(): ReadHistoryService {
  if (readHistoryServiceFactory !== null) {
    return (readHistoryServiceFactory as ReadHistoryServiceFactory)();
  }
  return new ReadHistoryService();
}

@ObservedV2
export class ReadHistoryViewModel {
  @Trace items: ReadHistoryItem[] = [];
  @Trace refreshing: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = true;
  private page: number = 1;
  private service: ReadHistoryService = buildReadHistoryService();

  setService(service: ReadHistoryService): void {
    this.service = service;
  }

  currentFilterType(): string {
    return READ_HISTORY_TYPE_REPO;
  }

  /** 首屏加载（NavDestination onReady 调用，语义与旧 refreshList 一致）。 */
  async refresh(): Promise<void> {
    this.refreshing = true;
    try {
      const filterType: string = this.currentFilterType();
      const res = await this.service.list(filterType.length > 0 ? filterType : undefined, 1,
        READ_HISTORY_PAGE_SIZE);
      if (res.result && res.data !== null) {
        this.items = res.data;
        this.page = 1;
        this.hasMore = res.data.length >= READ_HISTORY_PAGE_SIZE;
      } else {
        this.hasMore = false;
      }
    } finally {
      this.refreshing = false;
    }
  }

  async loadMore(): Promise<void> {
    if (!this.hasMore) {
      return;
    }
    this.loadingMore = true;
    try {
      const next: number = this.page + 1;
      const filterType: string = this.currentFilterType();
      const res = await this.service.list(filterType.length > 0 ? filterType : undefined, next,
        READ_HISTORY_PAGE_SIZE);
      if (res.result && res.data !== null) {
        this.items = this.items.concat(res.data);
        this.page = next;
        this.hasMore = res.data.length >= READ_HISTORY_PAGE_SIZE;
      } else {
        this.hasMore = false;
      }
    } finally {
      this.loadingMore = false;
    }
  }

  async clear(): Promise<void> {
    const filterType: string = this.currentFilterType();
    await this.service.clear(filterType.length > 0 ? filterType : undefined);
    await this.refresh();
  }
}
