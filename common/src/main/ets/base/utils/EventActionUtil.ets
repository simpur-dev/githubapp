/**
 * EventActionUtil —— 严格对齐 RN 端 [eventUtils.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/utils/eventUtils.js#L6-L131)
 *
 * 把 GitHub 原始 event 解析为：
 *  - actionStr：列表 item 第二行的"动作摘要" (如 "opened issue 12 in CarGuo/GSYGithubApp")
 *  - des：可选的多行描述（issue.title / comment.body / push 提交信息列表）
 *
 * 对齐策略：完整覆盖 RN 处理过的全部 event.type 分支，避免出现"OH 端比 RN 少分支"。
 */

import { DynamicEvent } from '../../model/store/DynamicStore';

export interface EventActionResult {
  actionStr: string;
  des: string;
}

function readPayloadString(payload: Record<string, Object>, key: string): string {
  const value: Object | undefined = payload[key];
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value as string;
  }
  return String(value);
}

function readPayloadObject(payload: Record<string, Object>, key: string): Record<string, Object> | null {
  const value: Object | undefined = payload[key];
  if (value === undefined || value === null) {
    return null;
  }
  return value as Record<string, Object>;
}

function safeRepoName(event: DynamicEvent): string {
  if (event.repo === null || event.repo === undefined) {
    return '';
  }
  return event.repo.name !== undefined && event.repo.name !== null ? event.repo.name : '';
}

/**
 * 表驱动 event → 动作摘要规格（原 getActionAndDes 的 switch 分支逐条迁移）。
 * template 占位符（单趟正则替换，不回扫插入值）：
 *  - %t → payload.action
 *  - %r → repo.full_name（safeRepoName）
 *  - %a → actor.login
 *  - %n → payload.issue.number
 *  - %f → payload.ref_type
 *  - %v → payload[valueKey]（ref / tag_name 等逐 spec 指定）
 *  - %e → event.type
 * repositoryTemplate：CreateEvent 的 ref_type=repository 特例文案。
 * desSourceKey/desFieldKey：des 取数（issue.title / comment.body）。
 */
interface EventActionSpec {
  template: string;
  valueKey?: string;
  repositoryTemplate?: string;
  desSourceKey?: string;
  desFieldKey?: string;
}

const EVENT_ACTION_SPECS: Map<string, EventActionSpec> = new Map<string, EventActionSpec>();
EVENT_ACTION_SPECS.set('CommitCommentEvent', { template: 'Commit comment at %r' });
EVENT_ACTION_SPECS.set('CreateEvent', {
  template: 'Created %f %v at %r',
  valueKey: 'ref',
  repositoryTemplate: 'Created repository %r',
});
EVENT_ACTION_SPECS.set('DeleteEvent', { template: 'Delete %f %v at %r', valueKey: 'ref' });
EVENT_ACTION_SPECS.set('ForkEvent', { template: 'Forked %r to %a/%r' });
EVENT_ACTION_SPECS.set('GollumEvent', { template: '%a a wiki page ' });
EVENT_ACTION_SPECS.set('InstallationEvent', { template: '%t an GitHub App ' });
EVENT_ACTION_SPECS.set('InstallationRepositoriesEvent', { template: '%t repository from an installation ' });
EVENT_ACTION_SPECS.set('IssueCommentEvent', {
  template: '%t comment on issue %n in %r',
  desSourceKey: 'comment',
  desFieldKey: 'body',
});
EVENT_ACTION_SPECS.set('IssuesEvent', {
  template: '%t issue %n in %r',
  desSourceKey: 'issue',
  desFieldKey: 'title',
});
EVENT_ACTION_SPECS.set('MarketplacePurchaseEvent', { template: '%t marketplace plan ' });
EVENT_ACTION_SPECS.set('MemberEvent', { template: '%t member to %r' });
EVENT_ACTION_SPECS.set('OrgBlockEvent', { template: '%t a user ' });
EVENT_ACTION_SPECS.set('ProjectCardEvent', { template: '%t a project ' });
EVENT_ACTION_SPECS.set('ProjectColumnEvent', { template: '%t a project ' });
EVENT_ACTION_SPECS.set('ProjectEvent', { template: '%t a project ' });
EVENT_ACTION_SPECS.set('PublicEvent', { template: 'Made %r public' });
EVENT_ACTION_SPECS.set('PullRequestEvent', { template: '%t pull request %r' });
EVENT_ACTION_SPECS.set('PullRequestReviewEvent', { template: '%t pull request review at%r' });
EVENT_ACTION_SPECS.set('PullRequestReviewCommentEvent', { template: '%t pull request review comment at%r' });
EVENT_ACTION_SPECS.set('ReleaseEvent', { template: '%t release %v at %r', valueKey: 'tag_name' });
EVENT_ACTION_SPECS.set('WatchEvent', { template: '%t %r' });

const TEMPLATE_TOKEN_RE: RegExp = /%t|%r|%a|%n|%f|%v|%e/g;

function actorLogin(event: DynamicEvent): string {
  return event.actor !== null && event.actor !== undefined ? event.actor.login : '';
}

function issueNumber(payload: Record<string, Object>): string {
  const issue: Record<string, Object> | null = readPayloadObject(payload, 'issue');
  return issue !== null ? readPayloadString(issue, 'number') : '';
}

function tokenValue(token: string, event: DynamicEvent,
  payload: Record<string, Object>, repoName: string, spec: EventActionSpec): string {
  if (token === '%t') {
    return readPayloadString(payload, 'action');
  }
  if (token === '%r') {
    return repoName;
  }
  if (token === '%a') {
    return actorLogin(event);
  }
  if (token === '%n') {
    return issueNumber(payload);
  }
  if (token === '%f') {
    return readPayloadString(payload, 'ref_type');
  }
  if (token === '%v') {
    return spec.valueKey !== undefined ? readPayloadString(payload, spec.valueKey) : '';
  }
  return event.type;
}

function renderTemplate(template: string, event: DynamicEvent,
  payload: Record<string, Object>, repoName: string, spec: EventActionSpec): string {
  return template.replace(TEMPLATE_TOKEN_RE, (token: string): string =>
    tokenValue(token, event, payload, repoName, spec));
}

function readDes(spec: EventActionSpec, payload: Record<string, Object>): string {
  if (spec.desSourceKey === undefined || spec.desFieldKey === undefined) {
    return '';
  }
  const source: Record<string, Object> | null = readPayloadObject(payload, spec.desSourceKey);
  return source !== null ? readPayloadString(source, spec.desFieldKey) : '';
}

/** PushEvent 的 actionStr/des 组装（原 PushEvent 分支语义平移）。 */
function buildPushResult(event: DynamicEvent, payload: Record<string, Object>,
  repoName: string): EventActionResult {
  const refRaw: string = readPayloadString(payload, 'ref');
  const slashIdx: number = refRaw.lastIndexOf('/');
  const ref: string = slashIdx >= 0 ? refRaw.substring(slashIdx + 1) : refRaw;
  const actionStr: string = 'Push to ' + ref + ' at ' + repoName;
  let des: string = '';
  const commits: Object | undefined = payload['commits'];
  if (Array.isArray(commits)) {
    const commitArr: Record<string, Object>[] = commits as Record<string, Object>[];
    const maxLines: number = 4;
    const max: number = commitArr.length > maxLines ? maxLines - 1 : commitArr.length;
    let descSpan: string = '';
    for (let i: number = 0; i < max; i++) {
      const commit: Record<string, Object> = commitArr[i];
      const sha: string = readPayloadString(commit, 'sha');
      const shortSha: string = sha.length >= 7 ? sha.substring(0, 7) : sha;
      const message: string = readPayloadString(commit, 'message');
      if (i !== 0) {
        descSpan += '\n';
      }
      descSpan += shortSha + ' ' + message;
    }
    if (commitArr.length > maxLines) {
      descSpan = descSpan + '\n...';
    }
    des = descSpan;
  }
  return { actionStr: actionStr, des: des } as EventActionResult;
}

export class EventActionUtil {
  static getComposeActionText(event: DynamicEvent): string {
    const repoName: string = safeRepoName(event);
    const eventType: string = event.type !== undefined && event.type !== null ? event.type : '';
    let actionText: string = '';
    if (eventType.indexOf('Push') >= 0) {
      actionText = 'pushed to';
    } else if (eventType.indexOf('Create') >= 0) {
      actionText = 'created';
    } else if (eventType.indexOf('Fork') >= 0) {
      actionText = 'forked';
    } else if (eventType.indexOf('Star') >= 0) {
      actionText = 'starred';
    } else if (eventType.indexOf('Watch') >= 0) {
      actionText = 'started watching';
    } else if (eventType.indexOf('Issue') >= 0) {
      actionText = 'created issue in';
    } else if (eventType.indexOf('PullRequest') >= 0) {
      actionText = 'created pull request in';
    } else {
      actionText = eventType.replace('Event', '').toLowerCase();
    }
    if (repoName.length === 0) {
      return actionText;
    }
    return actionText + ' ' + repoName;
  }

  static getActionAndDes(event: DynamicEvent): EventActionResult {
    const repoName: string = safeRepoName(event);
    const payload: Record<string, Object> = event.payload !== undefined && event.payload !== null
      ? event.payload
      : ({} as Record<string, Object>);

    // PushEvent 保留专用组装（多行提交信息 des）。
    if (event.type === 'PushEvent') {
      return buildPushResult(event, payload, repoName);
    }
    // 其余 event.type 全部走规格表（原 switch 各分支逐条迁移，文案逐字一致）。
    const spec: EventActionSpec | undefined = EVENT_ACTION_SPECS.get(event.type);
    if (spec === undefined) {
      return { actionStr: event.type + ' ' + repoName, des: '' } as EventActionResult;
    }
    if (spec.repositoryTemplate !== undefined
      && readPayloadString(payload, 'ref_type') === 'repository') {
      return { actionStr: renderTemplate(spec.repositoryTemplate, event, payload, repoName, spec), des: '' } as EventActionResult;
    }
    const actionStr: string = renderTemplate(spec.template, event, payload, repoName, spec);
    const des: string = readDes(spec, payload);
    return { actionStr: actionStr, des: des } as EventActionResult;
  }
}
