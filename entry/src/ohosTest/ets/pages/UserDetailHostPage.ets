import http from '@ohos.net.http';
import {
  HttpManager,
  HttpProvider,
  RawResponse,
} from 'common';
import { HttpHeaders } from 'common';
import { SUCCESS } from 'common';
import { Address } from 'common';
import { UserDetailPage } from 'feature_user';
import { RouteName } from 'common';

const TARGET_LOGIN: string = 'CarGuoUI';
const STATUS_NO_CONTENT: number = 204;

interface MockUserDetail {
  id: number;
  login: string;
  name: string;
  avatar_url: string;
  bio: string;
  company: string;
  location: string;
  email: string;
  blog: string;
  type: string;
  followers: number;
  following: number;
  public_repos: number;
  public_gists: number;
  created_at: string;
  updated_at: string;
}

interface MockUserRepoItem {
  id: number;
  name: string;
  full_name: string;
  description: string;
  language: string;
  stargazers_count: number;
  forks_count: number;
  watchers_count: number;
  open_issues_count: number;
  fork: boolean;
  private: boolean;
  html_url: string;
  owner_login: string;
  pushed_at: string;
  updated_at: string;
}

class UserHostProvider implements HttpProvider {
  callCount: number = 0;

  private buildUserBody(): string {
    const user: MockUserDetail = {
      'id': 1,
      'login': TARGET_LOGIN,
      'name': 'GuoUI',
      'avatar_url': '',
      'bio': 'host bio',
      'company': 'oh',
      'location': 'sh',
      'email': '',
      'blog': '',
      'type': 'User',
      'followers': 88,
      'following': 22,
      'public_repos': 7,
      'public_gists': 0,
      'created_at': '2019-01-01T00:00:00Z',
      'updated_at': '2024-01-01T00:00:00Z',
    };
    return JSON.stringify(user);
  }

  private buildReposBody(): string {
    const repos: MockUserRepoItem[] = [
      {
        'id': 1,
        'name': 'RepoZero',
        'full_name': TARGET_LOGIN + '/RepoZero',
        'description': 'desc-zero',
        'language': 'TypeScript',
        'stargazers_count': 100,
        'forks_count': 5,
        'watchers_count': 10,
        'open_issues_count': 0,
        'fork': false,
        'private': false,
        'html_url': '',
        'owner_login': TARGET_LOGIN,
        'pushed_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      },
      {
        'id': 2,
        'name': 'RepoOne',
        'full_name': TARGET_LOGIN + '/RepoOne',
        'description': 'desc-one',
        'language': 'JavaScript',
        'stargazers_count': 200,
        'forks_count': 9,
        'watchers_count': 12,
        'open_issues_count': 1,
        'fork': false,
        'private': false,
        'html_url': '',
        'owner_login': TARGET_LOGIN,
        'pushed_at': '2024-01-02T00:00:00Z',
        'updated_at': '2024-01-02T00:00:00Z',
      },
    ];
    return JSON.stringify(repos);
  }

  async request(url: string,
                _method: string,
                _headers: HttpHeaders,
                _body: string | null,
                _timeoutMs: number): Promise<RawResponse> {
    this.callCount = this.callCount + 1;
    if (url === Address.getUserInfo(TARGET_LOGIN)) {
      return new RawResponse(SUCCESS, this.buildUserBody(), {});
    }
    if (url.indexOf('/users/' + TARGET_LOGIN + '/repos') >= 0) {
      return new RawResponse(SUCCESS, this.buildReposBody(), {});
    }
    if (url === Address.getFollowStatus(TARGET_LOGIN)) {
      return new RawResponse(STATUS_NO_CONTENT, '', {});
    }
    return new RawResponse(SUCCESS, '{}', {});
  }
}

const USER_HOST_STUB: UserHostProvider = new UserHostProvider();

@Entry
@Component
struct UserDetailHostPage {
  @State navStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    HttpManager.setMockProvider(USER_HOST_STUB);
  }

  aboutToDisappear(): void {
    HttpManager.setMockProvider(null);
  }

  @Builder
  navMap(name: string): void {
    if (name === RouteName.UserDetail) {
      UserDetailPage();
    }
  }

  build(): void {
    Column() {
      Navigation(this.navStack) {
      }
      .id('user_detail_host_nav')
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .navDestination(this.navMap)
      .onAppear((): void => {
        this.navStack.pushPath({
          name: RouteName.UserDetail,
          param: { 'login': TARGET_LOGIN } as Record<string, Object>,
        });
      });
    }
    .id('user_detail_host_root')
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }
}
