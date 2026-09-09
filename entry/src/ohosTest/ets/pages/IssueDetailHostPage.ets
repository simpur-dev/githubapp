import http from '@ohos.net.http';
import {
  HttpManager,
  HttpProvider,
  RawResponse,
} from 'common';
import { HttpHeaders } from 'common';
import { SUCCESS, CREATED } from 'common';
import { Address } from 'common';
import { IssueDetailPage } from 'feature_repo';
import { RouteName } from 'common';

const TARGET_OWNER: string = 'CarGuoUI';
const TARGET_REPO: string = 'GSYTestRepo';
const TARGET_FULL_NAME: string = TARGET_OWNER + '/' + TARGET_REPO;
const TARGET_NUMBER: number = 99;

interface MockIssueUser {
  login: string;
  avatar_url: string;
  html_url: string;
}

interface MockIssueDetail {
  id: number;
  number: number;
  title: string;
  body: string;
  body_html: string;
  state: string;
  locked: boolean;
  comments: number;
  user: MockIssueUser;
  created_at: string;
  updated_at: string;
  closed_at: string;
  html_url: string;
}

interface MockCommentItem {
  id: number;
  body: string;
  body_html: string;
  user: MockIssueUser;
  created_at: string;
  updated_at: string;
  html_url: string;
}

class IssueHostProvider implements HttpProvider {
  callCount: number = 0;
  state: string = 'open';
  postCount: number = 0;
  patchCount: number = 0;

  private buildIssueBody(): string {
    const issue: MockIssueDetail = {
      'id': 1001,
      'number': TARGET_NUMBER,
      'title': 'host issue title',
      'body': 'host issue body',
      'body_html': '<p>host issue body</p>',
      'state': this.state,
      'locked': false,
      'comments': 1,
      'user': {
        'login': TARGET_OWNER,
        'avatar_url': '',
        'html_url': 'https://github.com/' + TARGET_OWNER,
      },
      'created_at': '2024-01-01T00:00:00Z',
      'updated_at': '2024-01-02T00:00:00Z',
      'closed_at': '',
      'html_url': 'https://github.com/' + TARGET_FULL_NAME + '/issues/'
        + TARGET_NUMBER.toString(),
    };
    return JSON.stringify(issue);
  }

  private buildCommentsBody(): string {
    const comments: MockCommentItem[] = [
      {
        'id': 1,
        'body': 'first comment',
        'body_html': '<p>first comment</p>',
        'user': { 'login': TARGET_OWNER, 'avatar_url': '', 'html_url': '' },
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
        'html_url': '',
      },
    ];
    return JSON.stringify(comments);
  }

  private buildSingleCommentBody(): string {
    const item: MockCommentItem = {
      'id': 2,
      'body': 'host new comment',
      'body_html': '<p>host new comment</p>',
      'user': { 'login': TARGET_OWNER, 'avatar_url': '', 'html_url': '' },
      'created_at': '2024-01-03T00:00:00Z',
      'updated_at': '2024-01-03T00:00:00Z',
      'html_url': '',
    };
    return JSON.stringify(item);
  }

  async request(url: string,
                method: string,
                _headers: HttpHeaders,
                _body: string | null,
                _timeoutMs: number): Promise<RawResponse> {
    this.callCount = this.callCount + 1;
    const detailUrl: string = Address.getIssue(TARGET_OWNER, TARGET_REPO, TARGET_NUMBER);
    const stateUrl: string = Address.setIssueState(TARGET_OWNER, TARGET_REPO, TARGET_NUMBER);
    const createUrl: string = Address.createIssueComment(TARGET_OWNER, TARGET_REPO, TARGET_NUMBER);

    if (url === detailUrl && method === 'GET') {
      return new RawResponse(SUCCESS, this.buildIssueBody(), {});
    }
    if (url === stateUrl && method === 'PATCH') {
      this.patchCount = this.patchCount + 1;
      this.state = this.state === 'open' ? 'closed' : 'open';
      return new RawResponse(SUCCESS, this.buildIssueBody(), {});
    }
    if (url === createUrl && method === 'POST') {
      this.postCount = this.postCount + 1;
      return new RawResponse(CREATED, this.buildSingleCommentBody(), {});
    }
    if (url.indexOf('/comments') >= 0 && method === 'GET') {
      return new RawResponse(SUCCESS, this.buildCommentsBody(), {});
    }
    return new RawResponse(SUCCESS, '{}', {});
  }
}

const ISSUE_HOST_STUB: IssueHostProvider = new IssueHostProvider();

export function getIssueHostStub(): IssueHostProvider {
  return ISSUE_HOST_STUB;
}

@Entry
@Component
struct IssueDetailHostPage {
  @State navStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    HttpManager.setMockProvider(ISSUE_HOST_STUB);
  }

  aboutToDisappear(): void {
    HttpManager.setMockProvider(null);
  }

  @Builder
  navMap(name: string): void {
    if (name === RouteName.IssueDetail) {
      IssueDetailPage();
    }
  }

  build(): void {
    Column() {
      Navigation(this.navStack) {
      }
      .id('issue_detail_host_nav')
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .navDestination(this.navMap)
      .onAppear((): void => {
        this.navStack.pushPath({
          name: RouteName.IssueDetail,
          param: {
            'fullName': TARGET_FULL_NAME,
            'number': TARGET_NUMBER,
          } as Record<string, Object>,
        });
      });
    }
    .id('issue_detail_host_root')
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }
}
