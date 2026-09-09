export interface UserDetail {
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
  starred: string;
}

export interface UserOrgItem {
  id: number;
  login: string;
  avatar_url: string;
}

export interface UserRepoItem {
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

export function emptyUserDetail(): UserDetail {
  return {
    'id': 0,
    'login': '',
    'name': '',
    'avatar_url': '',
    'bio': '',
    'company': '',
    'location': '',
    'email': '',
    'blog': '',
    'type': '',
    'followers': 0,
    'following': 0,
    'public_repos': 0,
    'public_gists': 0,
    'created_at': '',
    'updated_at': '',
    'starred': '',
  } as UserDetail;
}

/**
 * GitHub API 经常对 name / bio / company / location / email / blog 等字段返回 null。
 * ArkTS strict-null 下对 null 调 .length 会直接抛错，
 * 因此在写入 store 之前把所有可能为 null 的字符串字段统一兜底为 ''。
 * 与 RN 端 UserDetailReducer 的 PayloadObjectKey 行为一致：
 *   [reducer/user.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/store/reducers/user.js)
 *   会在使用前先 `userInfo && userInfo.name` 这样保护，OH 端等价地把字段在 store 入口归一化。
 */
export function sanitizeUserDetail(user: UserDetail | null | undefined): UserDetail {
  if (user === null || user === undefined) {
    return emptyUserDetail();
  }
  const safe: UserDetail = emptyUserDetail();
  const src: Record<string, Object | null | undefined> = user as Object as Record<string, Object | null | undefined>;
  const dst: Record<string, Object> = safe as Object as Record<string, Object>;

  const stringKeys: string[] = [
    'login', 'name', 'avatar_url', 'bio', 'company',
    'location', 'email', 'blog', 'type', 'created_at', 'updated_at', 'starred',
  ];
  for (let i = 0; i < stringKeys.length; i++) {
    const key: string = stringKeys[i];
    const v: Object | null | undefined = src[key];
    dst[key] = (v === null || v === undefined) ? '' : v as Object;
  }

  const numberKeys: string[] = [
    'id', 'followers', 'following', 'public_repos', 'public_gists',
  ];
  for (let i = 0; i < numberKeys.length; i++) {
    const key: string = numberKeys[i];
    const v: Object | null | undefined = src[key];
    dst[key] = (v === null || v === undefined) ? 0 : v as Object;
  }

  return safe;
}

/**
 * UserDetailStore —— V1 时代的 @Observed UI 状态容器已在 R9 V2 + MVVM 改造中删除
 * （UserService 无状态化后无人写入，用户详情页 UI 状态改由
 * feature-user 的 UserDetailViewModel @Trace 字段承载）。
 * 本文件仅保留数据实体（UserDetail / UserOrgItem / UserRepoItem）与归一化工具，
 * 供 UserService 与各页面继续引用，导出路径不变。
 */
