import { ReadHistoryPage, setReadHistoryServiceFactory } from 'feature_main';
import { RepositoryDetailPage } from 'feature_repo';
import { UserDetailPage } from 'feature_user';
import { ReadHistoryService, ReadHistoryAddParam, ReadHistoryServiceResult } from 'common';
import { ReadHistoryItem, READ_HISTORY_TYPE_REPO, READ_HISTORY_TYPE_USER } from 'common';
import { RouteName } from 'common';
import { HttpManager, HttpProvider, RawResponse } from 'common';
import { HttpHeaders } from 'common';
import { SUCCESS } from 'common';
import http from '@ohos.net.http';

const STATUS_NO_CONTENT: number = 204;

class ReadHistoryFakeProvider implements HttpProvider {
  async request(_url: string, _method: string, _headers: HttpHeaders,
    _body: string | null, _timeoutMs: number): Promise<RawResponse> {
    return new RawResponse(STATUS_NO_CONTENT, '', {});
  }
}

class FakeReadHistoryService extends ReadHistoryService {
  addCount: number = 0;
  listCount: number = 0;
  clearCount: number = 0;
  lastClearType: string = '';
  injected: ReadHistoryItem[] = [];

  constructor() {
    super();
  }

  setInjected(items: ReadHistoryItem[]): void {
    this.injected = items.slice();
  }

  async add(_param: ReadHistoryAddParam): Promise<ReadHistoryServiceResult<number>> {
    this.addCount = this.addCount + 1;
    return new ReadHistoryServiceResult<number>(true, 1, '');
  }

  async list(type?: string, _page: number = 1,
    _size: number = 30): Promise<ReadHistoryServiceResult<ReadHistoryItem[]>> {
    this.listCount = this.listCount + 1;
    const safeType: string = type !== undefined && type !== null ? type : '';
    let filtered: ReadHistoryItem[] = [];
    for (let i = 0; i < this.injected.length; i++) {
      if (safeType.length === 0 || this.injected[i].type === safeType) {
        filtered.push(this.injected[i]);
      }
    }
    return new ReadHistoryServiceResult<ReadHistoryItem[]>(true, filtered, '');
  }

  async clear(type?: string): Promise<ReadHistoryServiceResult<number>> {
    this.clearCount = this.clearCount + 1;
    const safeType: string = type !== undefined && type !== null ? type : '';
    this.lastClearType = safeType;
    if (safeType.length === 0) {
      this.injected = [];
    } else {
      const next: ReadHistoryItem[] = [];
      for (let i = 0; i < this.injected.length; i++) {
        if (this.injected[i].type !== safeType) {
          next.push(this.injected[i]);
        }
      }
      this.injected = next;
    }
    return new ReadHistoryServiceResult<number>(true, 1, '');
  }
}

export const READ_HISTORY_HOST_FAKE: FakeReadHistoryService = new FakeReadHistoryService();

function buildSampleData(): ReadHistoryItem[] {
  const now: number = Date.now();
  const a: ReadHistoryItem = {
    'type': READ_HISTORY_TYPE_REPO,
    'key': 'CarGuoUI/GSYGithubApp',
    'title': 'CarGuoUI/GSYGithubApp',
    'subtitle': 'A GitHub client',
    'avatar': '',
    'payloadJson': '{"full_name":"CarGuoUI/GSYGithubApp","name":"GSYGithubApp","description":"A GitHub client","language":"Kotlin","stargazers_count":12000,"forks_count":3000,"watchers_count":12000,"owner":{"login":"CarGuoUI","avatar_url":"https://example.com/a.png"}}',
    'time': now + 3,
  } as ReadHistoryItem;
  const b: ReadHistoryItem = {
    'type': READ_HISTORY_TYPE_USER,
    'key': 'CarGuoUI',
    'title': 'CarGuoUI',
    'subtitle': 'gsy github user',
    'avatar': '',
    'payloadJson': '{"login":"CarGuoUI"}',
    'time': now + 2,
  } as ReadHistoryItem;
  const c: ReadHistoryItem = {
    'type': READ_HISTORY_TYPE_REPO,
    'key': 'CarGuoUI/GSYGithubAppOH',
    'title': 'CarGuoUI/GSYGithubAppOH',
    'subtitle': 'OH version',
    'avatar': '',
    'payloadJson': '{"full_name":"CarGuoUI/GSYGithubAppOH","name":"GSYGithubAppOH","description":"OH version","language":"ArkTS","stargazers_count":10,"forks_count":2,"watchers_count":10,"owner":{"login":"CarGuoUI","avatar_url":"https://example.com/oh.png"}}',
    'time': now + 1,
  } as ReadHistoryItem;
  return [a, b, c];
}

@Entry
@Component
struct ReadHistoryHostPage {
  @State navStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    READ_HISTORY_HOST_FAKE.setInjected(buildSampleData());
    READ_HISTORY_HOST_FAKE.addCount = 0;
    READ_HISTORY_HOST_FAKE.listCount = 0;
    READ_HISTORY_HOST_FAKE.clearCount = 0;
    READ_HISTORY_HOST_FAKE.lastClearType = '';
    setReadHistoryServiceFactory((): ReadHistoryService => {
      return READ_HISTORY_HOST_FAKE;
    });
    HttpManager.setMockProvider(new ReadHistoryFakeProvider());
  }

  aboutToDisappear(): void {
    setReadHistoryServiceFactory(null);
    HttpManager.setMockProvider(null);
  }

  @Builder
  navMap(name: string): void {
    if (name === RouteName.ReadHistory) {
      ReadHistoryPage();
    } else if (name === RouteName.RepositoryDetail) {
      RepositoryDetailPage();
    } else if (name === RouteName.UserDetail) {
      UserDetailPage();
    }
  }

  build(): void {
    Column() {
      Navigation(this.navStack) {
      }
      .id('read_history_host_nav')
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .navDestination(this.navMap)
      .onAppear((): void => {
        this.navStack.pushPath({
          name: RouteName.ReadHistory,
          param: {} as Record<string, Object>,
        });
      });
    }
    .id('read_history_host_root')
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }
}
