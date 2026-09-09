/**
 * ReleaseViewModel —— Release 页双 Tab（reposRelease / reposTag）状态与分页（R9 V2 + MVVM）。
 * 原页面级 @State 字段语义平移；RepositoryService.fetchRepositoryRelease / fetchRepositoryTag
 * 本就是静态无状态方法，这里按返回结果写 @Trace。
 */
import { RepositoryService, ReleaseListItem, FetchReleaseListResult } from 'common';

const PAGE_SIZE: number = 30;

@ObservedV2
export class ReleaseViewModel {
  /** 目标仓库（owner / name，View 层从路由参数解析后调用 init）。 */
  @Trace ownerName: string = '';
  @Trace repositoryName: string = '';
  /** Release tab 数据源与分页 / 加载态。 */
  @Trace releaseItems: ReleaseListItem[] = [];
  @Trace releaseRefreshing: boolean = false;
  @Trace releaseLoadingMore: boolean = false;
  @Trace releaseNoMore: boolean = false;
  /** Tag tab 数据源与分页 / 加载态（首切到 tag tab 且为空时触发加载）。 */
  @Trace tagItems: ReleaseListItem[] = [];
  @Trace tagRefreshing: boolean = false;
  @Trace tagLoadingMore: boolean = false;
  @Trace tagNoMore: boolean = false;

  private releasePage: number = 1;
  private releaseHasMore: boolean = true;
  private tagPage: number = 1;
  private tagHasMore: boolean = true;
  private tagLoaded: boolean = false;

  /** 设置目标仓库（onReady 取参后调用）。 */
  init(ownerName: string, repositoryName: string): void {
    this.ownerName = ownerName;
    this.repositoryName = repositoryName;
  }

  /** 是否需要首次加载 tag 列表（原 onChange 里 tagItems.length === 0 判断的语义升级）。 */
  shouldLoadTagOnFirstSwitch(): boolean {
    return !this.tagLoaded && this.tagItems.length === 0;
  }

  private applyRelease(items: ReleaseListItem[], append: boolean, page: number): void {
    if (append) {
      const merged: ReleaseListItem[] = this.releaseItems.slice();
      for (let i: number = 0; i < items.length; i++) {
        merged.push(items[i]);
      }
      this.releaseItems = merged;
    } else {
      this.releaseItems = items.slice();
    }
    this.releasePage = page;
    this.releaseHasMore = items.length >= PAGE_SIZE;
  }

  private applyTag(items: ReleaseListItem[], append: boolean, page: number): void {
    if (append) {
      const merged: ReleaseListItem[] = this.tagItems.slice();
      for (let i: number = 0; i < items.length; i++) {
        merged.push(items[i]);
      }
      this.tagItems = merged;
    } else {
      this.tagItems = items.slice();
    }
    this.tagPage = page;
    this.tagHasMore = items.length >= PAGE_SIZE;
    this.tagLoaded = true;
  }

  async refreshRelease(): Promise<void> {
    if (this.ownerName.length === 0 || this.repositoryName.length === 0) {
      return;
    }
    this.releaseRefreshing = true;
    this.releaseLoadingMore = false;
    this.releaseNoMore = false;
    const res: FetchReleaseListResult = await RepositoryService.fetchRepositoryRelease(
      this.ownerName, this.repositoryName, 1);
    if (res.result) {
      this.applyRelease(res.data, false, 1);
    }
    this.releaseRefreshing = false;
    this.releaseLoadingMore = false;
    this.releaseNoMore = !(this.releaseHasMore);
  }

  async loadMoreRelease(): Promise<void> {
    if (!this.releaseHasMore) {
      this.releaseLoadingMore = false;
      this.releaseNoMore = true;
      return;
    }
    const next: number = this.releasePage + 1;
    const res: FetchReleaseListResult = await RepositoryService.fetchRepositoryRelease(
      this.ownerName, this.repositoryName, next);
    if (res.result) {
      this.applyRelease(res.data, true, next);
    }
    this.releaseLoadingMore = false;
    this.releaseNoMore = !(this.releaseHasMore);
  }

  async refreshTag(): Promise<void> {
    if (this.ownerName.length === 0 || this.repositoryName.length === 0) {
      return;
    }
    this.tagRefreshing = true;
    this.tagLoadingMore = false;
    this.tagNoMore = false;
    const res: FetchReleaseListResult = await RepositoryService.fetchRepositoryTag(
      this.ownerName, this.repositoryName, 1);
    if (res.result) {
      this.applyTag(res.data, false, 1);
    }
    this.tagRefreshing = false;
    this.tagLoadingMore = false;
    this.tagNoMore = !(this.tagHasMore);
  }

  async loadMoreTag(): Promise<void> {
    if (!this.tagHasMore) {
      this.tagLoadingMore = false;
      this.tagNoMore = true;
      return;
    }
    const next: number = this.tagPage + 1;
    const res: FetchReleaseListResult = await RepositoryService.fetchRepositoryTag(
      this.ownerName, this.repositoryName, next);
    if (res.result) {
      this.applyTag(res.data, true, next);
    }
    this.tagLoadingMore = false;
    this.tagNoMore = !(this.tagHasMore);
  }
}
