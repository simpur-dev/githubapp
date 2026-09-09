import http from '@ohos.net.http';
import {
  HttpManager,
  HttpProvider,
  RawResponse,
} from 'common';
import { HttpHeaders } from 'common';
import { SUCCESS } from 'common';
import { Address } from 'common';
import { NotifyPage } from 'feature_main';
import { RouteName } from 'common';

const STATUS_NO_CONTENT: number = 204;
const REPO_FULL: string = 'CarGuoUI/RepoZero';

interface MockNotifySubject {
  title: string;
  url: string;
  latest_comment_url: string;
  type: string;
}

interface MockNotifyRepository {
  id: number;
  name: string;
  full_name: string;
  owner_login: string;
  html_url: string;
}

interface MockNotifyItem {
  id: string;
  unread: boolean;
  reason: string;
  updated_at: string;
  last_read_at: string;
  url: string;
  subject: MockNotifySubject;
  repository: MockNotifyRepository;
}

class NotifyHostProvider implements HttpProvider {
  callCount: number = 0;
  lastUrl: string = '';
  lastMethod: string = '';

  private buildList(): string {
    const items: MockNotifyItem[] = [
      {
        'id': 't0',
        'unread': true,
        'reason': 'mention',
        'updated_at': '2024-01-01T00:00:00Z',
        'last_read_at': '',
        'url': 'https://api.github.com/notifications/threads/t0',
        'subject': {
          'title': 'host-thread-zero',
          'url': 'https://api.github.com/repos/' + REPO_FULL + '/issues/1',
          'latest_comment_url': '',
          'type': 'Issue',
        },
        'repository': {
          'id': 1,
          'name': 'RepoZero',
          'full_name': REPO_FULL,
          'owner_login': 'CarGuoUI',
          'html_url': '',
        },
      },
      {
        'id': 't1',
        'unread': false,
        'reason': 'subscribed',
        'updated_at': '2024-01-02T00:00:00Z',
        'last_read_at': '',
        'url': 'https://api.github.com/notifications/threads/t1',
        'subject': {
          'title': 'host-thread-one',
          'url': 'https://api.github.com/repos/' + REPO_FULL + '/pulls/2',
          'latest_comment_url': '',
          'type': 'PullRequest',
        },
        'repository': {
          'id': 1,
          'name': 'RepoZero',
          'full_name': REPO_FULL,
          'owner_login': 'CarGuoUI',
          'html_url': '',
        },
      },
    ];
    return JSON.stringify(items);
  }

  async request(url: string,
                method: string,
                _headers: HttpHeaders,
                _body: string | null,
                _timeoutMs: number): Promise<RawResponse> {
    this.callCount = this.callCount + 1;
    this.lastUrl = url;
    this.lastMethod = method;
    if (method === 'GET' && url.indexOf('/notifications') >= 0) {
      return new RawResponse(SUCCESS, this.buildList(), {});
    }
    if (method === 'PATCH' && url.indexOf('/notifications/threads/') >= 0) {
      return new RawResponse(STATUS_NO_CONTENT, '', {});
    }
    if (method === 'PUT' && url === Address.setAllNotificationAsRead()) {
      return new RawResponse(STATUS_NO_CONTENT, '', {});
    }
    return new RawResponse(SUCCESS, '{}', {});
  }
}

const NOTIFY_HOST_STUB: NotifyHostProvider = new NotifyHostProvider();

@Entry
@Component
struct NotifyHostPage {
  @State navStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    HttpManager.setMockProvider(NOTIFY_HOST_STUB);
  }

  aboutToDisappear(): void {
    HttpManager.setMockProvider(null);
  }

  @Builder
  navMap(name: string): void {
    if (name === RouteName.Notify) {
      NotifyPage();
    }
  }

  build(): void {
    Column() {
      Navigation(this.navStack) {
      }
      .id('notify_host_nav')
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .navDestination(this.navMap)
      .onAppear((): void => {
        this.navStack.pushPath({
          name: RouteName.Notify,
          param: {} as Record<string, Object>,
        });
      });
    }
    .id('notify_host_root')
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }
}
