/**
 * NotifyViewModel —— 通知页状态与编排（R9 V2 + MVVM）。
 *
 * @Trace UI 状态（8 个）：通知列表 / 刷新中 / 加载更多中 / 是否有更多 / 当前 tab /
 * 首屏加载中 / 首屏已结束 / 错误文案。
 * NotifyService 已无状态化（不写 NotifyStore，markAsRead/markAllAsRead 也不再
 * 改本地列表）：已读状态由本 VM 在请求成功后对 @Trace 列表做整体替换。
 * BOOT 注入测试通道（applyBootNotifyIssue / isBootOnlyNotificationList）语义原样保留。
 */
import { LoadingModal } from 'common';
import { I18n } from 'common';
import { Logger } from 'common';
import { NavigationService, RouteName } from 'common';
import { BOOT_NOTIFY_ISSUE_KEY, BootChannel } from 'common';
import {
  NotifyFilter,
  NotifyThread,
  NOTIFY_FILTER_UNREAD,
  NOTIFY_FILTER_PARTICIPATING,
  NOTIFY_FILTER_ALL,
} from 'common';
import { NotifyService, FetchNotifyResult, MarkNotifyResult } from 'common';

interface IssueDetailRouteParam {
  owner: string;
  name: string;
  fullName: string;
  number: number;
  htmlUrl: string;
}

export class NotifyTabItem {
  filter: NotifyFilter;
  label: string;

  constructor(filter: NotifyFilter, label: string) {
    this.filter = filter;
    this.label = label;
  }
}

const SUBJECT_ISSUE: string = 'Issue';

function parseNumberFromUrl(url: string): number {
  if (!url || url.length === 0) {
    return 0;
  }
  const lastSlash: number = url.lastIndexOf('/');
  if (lastSlash < 0) {
    return 0;
  }
  const tail: string = url.substring(lastSlash + 1);
  const num: number = Number.parseInt(tail, 10);
  return Number.isNaN(num) ? 0 : num;
}

function parseOwnerFromFullName(fullName: string): string {
  if (!fullName || fullName.length === 0) {
    return '';
  }
  const slash: number = fullName.indexOf('/');
  if (slash < 0) {
    return fullName;
  }
  return fullName.substring(0, slash);
}

function parseNameFromFullName(fullName: string): string {
  if (!fullName || fullName.length === 0) {
    return '';
  }
  const slash: number = fullName.indexOf('/');
  if (slash < 0) {
    return '';
  }
  return fullName.substring(slash + 1);
}

function markThreadUnreadFalse(t: NotifyThread): NotifyThread {
  return {
    'id': t.id,
    'unread': false,
    'reason': t.reason,
    'updated_at': t.updated_at,
    'last_read_at': t.last_read_at,
    'url': t.url,
    'subject': t.subject,
    'repository': t.repository,
  } as NotifyThread;
}

@ObservedV2
export class NotifyViewModel {
  @Trace items: NotifyThread[] = [];
  @Trace refreshing: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = true;
  @Trace currentTabIndex: number = 0;
  @Trace initialPageLoading: boolean = true;
  @Trace initialLoadFinished: boolean = false;
  @Trace error: string = '';
  private page: number = 1;
  private service: NotifyService = new NotifyService();
  readonly tabs: NotifyTabItem[] = [
    new NotifyTabItem(NOTIFY_FILTER_UNREAD, I18n('notifyUnread')),
    new NotifyTabItem(NOTIFY_FILTER_PARTICIPATING, I18n('notifyParticipating')),
    new NotifyTabItem(NOTIFY_FILTER_ALL, I18n('notifyAll')),
  ];

  currentFilter(): NotifyFilter {
    if (this.currentTabIndex < 0 || this.currentTabIndex >= this.tabs.length) {
      return NOTIFY_FILTER_UNREAD;
    }
    return this.tabs[this.currentTabIndex].filter;
  }

  /** 首屏加载（View aboutToAppear 调用）。 */
  async init(): Promise<void> {
    await this.refresh();
  }

  private applyThreadReadLocal(threadId: string): void {
    const next: NotifyThread[] = [];
    for (let i: number = 0; i < this.items.length; i++) {
      const t: NotifyThread = this.items[i];
      next.push(t.id === threadId ? markThreadUnreadFalse(t) : t);
    }
    this.items = next;
  }

  private applyAllReadLocal(): void {
    const next: NotifyThread[] = [];
    for (let i: number = 0; i < this.items.length; i++) {
      next.push(markThreadUnreadFalse(this.items[i]));
    }
    this.items = next;
  }

  async refresh(): Promise<void> {
    const isInitialEmptyLoad: boolean = !this.initialLoadFinished && this.items.length === 0;
    if (isInitialEmptyLoad) {
      this.initialPageLoading = true;
    }
    this.refreshing = true;
    if (this.applyBootNotifyIssue()) {
      this.initialPageLoading = false;
      this.initialLoadFinished = true;
      this.refreshing = false;
      this.hasMore = false;
      return;
    }
    const res: FetchNotifyResult = await this.service.getNotifications(this.currentFilter(), 1);
    this.initialPageLoading = false;
    this.initialLoadFinished = true;
    if (res.result) {
      this.items = res.data;
      this.page = res.page;
      this.hasMore = res.hasMore;
    } else {
      this.error = res.msg;
    }
    this.refreshing = false;
  }

  async loadMore(): Promise<void> {
    if (!this.hasMore) {
      return;
    }
    this.loadingMore = true;
    const next: number = this.page + 1;
    try {
      const res: FetchNotifyResult = await this.service.getNotifications(this.currentFilter(), next);
      if (res.result) {
        this.items = this.items.concat(res.data);
        this.page = res.page;
        this.hasMore = res.hasMore;
      }
    } finally {
      this.loadingMore = false;
    }
  }

  async onTabChanged(index: number): Promise<void> {
    if (index === this.currentTabIndex) {
      return;
    }
    this.currentTabIndex = index;
    // 旧 NotifyStore.setFilter 语义：切换筛选清空列表并重置分页。
    this.items = [];
    this.page = 1;
    this.hasMore = true;
    this.error = '';
    await this.refresh();
  }

  async markAllRead(): Promise<void> {
    LoadingModal.show(I18n('loading'), false);
    try {
      if (this.isBootOnlyNotificationList()) {
        this.applyAllReadLocal();
        Logger.i('notify/markAll', 'boot notification list marked read locally');
        return;
      }
      const res: MarkNotifyResult = await this.service.markAllAsRead();
      Logger.i('notify/markAll', `result=${res.result} code=${res.code}`);
      if (res.result) {
        this.applyAllReadLocal();
        await this.refresh();
      }
    } finally {
      LoadingModal.hide();
    }
  }

  isBootOnlyNotificationList(): boolean {
    if (this.items.length === 0) {
      return false;
    }
    for (let i: number = 0; i < this.items.length; i++) {
      if (this.items[i].id.indexOf('boot-notify-issue-') !== 0) {
        return false;
      }
    }
    return true;
  }

  async onThreadClick(item: NotifyThread): Promise<void> {
    this.openSubjectDetail(item);
    if (item.id.indexOf('boot-notify-issue-') === 0) {
      Logger.i('notify/click', `skip markAsRead for boot issue id=${item.id}`);
      return;
    }
    if (item.unread) {
      this.service.markAsRead(item.id).then((res: MarkNotifyResult): void => {
        Logger.i('notify/click', `markAsRead id=${item.id} result=${res.result} code=${res.code}`);
        if (res.result) {
          this.applyThreadReadLocal(item.id);
        }
      });
    }
  }

  private applyBootNotifyIssue(): boolean {
    const value: string = BootChannel.get(BOOT_NOTIFY_ISSUE_KEY);
    const raw: string = (value || '').trim();
    if (raw.length === 0) {
      return false;
    }
    const sep: number = raw.indexOf('|');
    if (sep <= 0 || sep >= raw.length - 1) {
      BootChannel.set(BOOT_NOTIFY_ISSUE_KEY, '');
      return false;
    }
    const fullName: string = raw.substring(0, sep);
    const numberStr: string = raw.substring(sep + 1);
    const issueNumber: number = Number.parseInt(numberStr, 10);
    if (fullName.length === 0 || Number.isNaN(issueNumber) || issueNumber <= 0) {
      BootChannel.set(BOOT_NOTIFY_ISSUE_KEY, '');
      return false;
    }
    const slash: number = fullName.indexOf('/');
    const owner: string = slash > 0 ? fullName.substring(0, slash) : '';
    const name: string = slash > 0 ? fullName.substring(slash + 1) : fullName;
    const issueApiUrl: string = `https://api.github.com/repos/${fullName}/issues/${issueNumber}`;
    const thread: NotifyThread = {
      'id': `boot-notify-issue-${fullName}-${issueNumber}`,
      'unread': true,
      'reason': 'manual',
      'updated_at': new Date().toISOString(),
      'last_read_at': '',
      'url': issueApiUrl,
      'subject': {
        'title': `Issue #${issueNumber}`,
        'url': issueApiUrl,
        'latest_comment_url': issueApiUrl,
        'type': SUBJECT_ISSUE,
      },
      'repository': {
        'id': 0,
        'name': name,
        'full_name': fullName,
        'owner_login': owner,
        'html_url': `https://github.com/${fullName}`,
      },
    } as NotifyThread;
    this.items = [thread];
    this.page = 1;
    this.hasMore = false;
    this.error = '';
    BootChannel.set(BOOT_NOTIFY_ISSUE_KEY, '');
    Logger.i('notify/boot', `applied bootNotifyIssue fullName=${fullName} number=${issueNumber}`);
    return true;
  }

  private openSubjectDetail(item: NotifyThread): void {
    const subjectType: string = item.subject.type;
    const fullName: string = item.repository.full_name;
    const owner: string = item.repository.owner_login.length > 0
      ? item.repository.owner_login : parseOwnerFromFullName(fullName);
    const name: string = item.repository.name.length > 0
      ? item.repository.name : parseNameFromFullName(fullName);

    if (subjectType === SUBJECT_ISSUE) {
      const number: number = parseNumberFromUrl(item.subject.url);
      const issueParam: IssueDetailRouteParam = {
        'owner': owner,
        'name': name,
        'fullName': fullName,
        'number': number,
        'htmlUrl': item.subject.url,
      } as IssueDetailRouteParam;
      Logger.i('notify/click', `open issue fullName=${fullName} number=${number} subjectUrl=${item.subject.url}`);
      NavigationService.push(RouteName.IssueDetail, issueParam as Object);
      return;
    }
    Logger.i('notify/click', `mark-read only subjectType=${subjectType} fullName=${fullName}`);
  }
}
