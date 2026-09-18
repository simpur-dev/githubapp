/**
 * SearchViewModel —— 搜索页状态与编排（R9 V2 + MVVM）。
 *
 * @Trace UI 状态（9 个）：输入框文案 / 当前 tab / 历史列表 / 输入焦点 /
 * repo 结果 / user 结果 / 刷新中 / 加载更多中 / 是否有更多。
 * submittedQuery / page 为非 UI 状态，普通私有字段。
 * SearchService 已无状态化（不写 SearchStore），结果带 page/hasMore；
 * SearchPageDeps 只注入 service + history（store 依赖删除）。
 */
import { RecommendRepo } from 'common';
import { SearchTab, SEARCH_TAB_REPO, SEARCH_TAB_USER, SearchUserItem } from 'common';
import { SearchRepoResult, SearchUserResult, SearchService } from 'common';
import { SearchHistory, SearchHistoryManager } from 'common';

export class SearchPageDeps {
  private static serviceImpl: SearchService | null = null;
  private static historyImpl: SearchHistoryManager = SearchHistory;

  static setService(service: SearchService): void {
    SearchPageDeps.serviceImpl = service;
  }

  static setHistory(history: SearchHistoryManager): void {
    SearchPageDeps.historyImpl = history;
  }

  static getService(): SearchService {
    if (SearchPageDeps.serviceImpl === null) {
      SearchPageDeps.serviceImpl = new SearchService();
    }
    return SearchPageDeps.serviceImpl;
  }

  static getHistory(): SearchHistoryManager {
    return SearchPageDeps.historyImpl;
  }

  static reset(): void {
    SearchPageDeps.serviceImpl = null;
    SearchPageDeps.historyImpl = SearchHistory;
  }
}

@ObservedV2
export class SearchViewModel {
  @Trace queryText: string = '';
  @Trace currentTab: SearchTab = SEARCH_TAB_REPO;
  @Trace historyItems: string[] = [];
  /** R12：搜索联想词（历史条目的前缀匹配；输入为空时不联想）。 */
  @Trace suggestions: string[] = [];
  @Trace searchFocused: boolean = false;
  @Trace repos: RecommendRepo[] = [];
  @Trace users: SearchUserItem[] = [];
  @Trace refreshing: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = true;
  private submittedQuery: string = '';
  private page: number = 1;
  private service: SearchService = SearchPageDeps.getService();
  private history: SearchHistoryManager = SearchPageDeps.getHistory();

  /** 测试注入（ohosTest Host 页 aboutToAppear 后重设依赖时调用）。 */
  rebindDeps(): void {
    this.service = SearchPageDeps.getService();
    this.history = SearchPageDeps.getHistory();
  }

  repoKey(item: RecommendRepo, index: number): string {
    return index.toString() + '_' + item.id.toString();
  }

  userKey(item: SearchUserItem, index: number): string {
    return index.toString() + '_' + item.id.toString();
  }

  isEmptyQuery(): boolean {
    return this.submittedQuery === null || this.submittedQuery.length === 0;
  }

  hasTypedQuery(): boolean {
    return this.queryText.trim().length > 0;
  }

  async loadHistory(): Promise<void> {
    this.historyItems = await this.history.list();
  }

  markFocused(focused: boolean): void {
    this.searchFocused = focused;
  }

  onInputChanged(value: string): void {
    this.queryText = value;
    this.updateSuggestions(value);
    if (value === null || value.length === 0) {
      this.clearSearch();
    }
  }

  /** R12：联想词 = 历史条目前缀匹配（大小写不敏感，最多 5 条）。 */
  private updateSuggestions(input: string): void {
    const prefix: string = input !== null ? input.trim().toLowerCase() : '';
    if (prefix.length === 0) {
      this.suggestions = [];
      return;
    }
    const matched: string[] = [];
    for (let i: number = 0; i < this.historyItems.length && matched.length < 5; i++) {
      const item: string = this.historyItems[i];
      if (item !== null && item !== undefined && item.toLowerCase().startsWith(prefix)
        && item.toLowerCase() !== prefix) {
        matched.push(item);
      }
    }
    this.suggestions = matched;
  }

  /** 清空输入：回到初始态（旧 store.reset + refreshComplete(false) 语义）。 */
  clearSearch(): void {
    this.queryText = '';
    this.submittedQuery = '';
    this.currentTab = SEARCH_TAB_REPO;
    this.repos = [];
    this.users = [];
    this.refreshing = false;
    this.loadingMore = false;
    this.hasMore = true;
    this.page = 1;
  }

  async submitSearch(text: string): Promise<void> {
    await this.searchPageOne(text, true);
  }

  private async searchPageOne(text: string, recordHistory: boolean): Promise<void> {
    const trimmed: string = text !== null && text !== undefined ? text.trim() : '';
    if (trimmed.length === 0) {
      this.submittedQuery = '';
      return;
    }
    this.queryText = trimmed;
    this.submittedQuery = trimmed;
    this.refreshing = true;
    const page: number = 1;
    if (this.currentTab === SEARCH_TAB_REPO) {
      const res: SearchRepoResult = await this.service.searchRepo(trimmed, null, page);
      if (res.result) {
        this.repos = res.data;
        this.page = res.page;
        this.hasMore = res.hasMore;
        if (recordHistory) {
          this.historyItems = await this.history.add(trimmed);
        }
      }
    } else {
      const res: SearchUserResult = await this.service.searchUser(trimmed, null, page);
      if (res.result) {
        this.users = res.data;
        this.page = res.page;
        this.hasMore = res.hasMore;
        if (recordHistory) {
          this.historyItems = await this.history.add(trimmed);
        }
      }
    }
    this.refreshing = false;
  }

  async switchTab(tab: SearchTab): Promise<void> {
    if (tab !== this.currentTab) {
      this.currentTab = tab;
      this.page = 1;
      this.hasMore = true;
    }
    if (!this.hasTypedQuery()) {
      return;
    }
    await this.submitSearch(this.queryText);
  }

  async refresh(): Promise<void> {
    if (this.isEmptyQuery()) {
      this.refreshing = false;
      return;
    }
    // 下拉刷新不重复写历史（与旧版 searchByTab 直调语义一致）。
    await this.searchPageOne(this.submittedQuery, false);
  }

  async loadMore(): Promise<void> {
    if (this.isEmptyQuery()) {
      this.hasMore = false;
      return;
    }
    if (!this.hasMore) {
      return;
    }
    this.loadingMore = true;
    const next: number = this.page + 1;
    try {
      if (this.currentTab === SEARCH_TAB_REPO) {
        const res: SearchRepoResult = await this.service.searchRepo(this.submittedQuery, null, next);
        if (res.result) {
          this.repos = this.repos.concat(res.data);
          this.page = res.page;
          this.hasMore = res.hasMore;
        }
      } else {
        const res: SearchUserResult = await this.service.searchUser(this.submittedQuery, null, next);
        if (res.result) {
          this.users = this.users.concat(res.data);
          this.page = res.page;
          this.hasMore = res.hasMore;
        }
      }
    } finally {
      this.loadingMore = false;
    }
  }
}
