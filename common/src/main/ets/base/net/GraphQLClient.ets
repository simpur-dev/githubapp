/**
 * GraphQLClient —— GitHub GraphQL API v4 客户端层（R12 补齐目标规格 §6.3）。
 *
 * 定位：与 REST 并存的第二数据通道。当前策略仍为"REST 为主"（见
 * harness/R12/docs/05-API26原生技术选型.md §2.1），GraphQL 优先用于未来
 * 出现"单页 >3 次串行聚合请求"的场景（如仓库页首屏聚合 / Issue 时间线）。
 *
 * 复用 HttpManager 的鉴权（Authorization 注入 + 401 过期总线）与超时/错误码体系；
 * GraphQL 错误响应（HTTP 200 + errors 数组）单独归一化为 GraphQLError。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HttpManager } from './HttpManager';

const TAG: string = 'GraphQLClient';
const GRAPHQL_ENDPOINT: string = 'https://api.github.com/graphql';

/** GraphQL 查询错误项（GitHub errors 数组元素）。 */
export interface GraphQLError {
  message: string;
  type?: string;
  path?: string[];
}

/** GraphQL 查询结果：data 与 errors 互斥出现（也可能同时，errors 非空视为失败）。 */
export class GraphQLResult<T> {
  readonly ok: boolean;
  readonly data: T | null;
  readonly errors: GraphQLError[];
  readonly code: number;

  constructor(ok: boolean, data: T | null, errors: GraphQLError[], code: number) {
    this.ok = ok;
    this.data = data;
    this.errors = errors;
    this.code = code;
  }
}

interface GraphQLResponseShape {
  data?: Object | null;
  errors?: GraphQLError[];
}

export class GraphQLClient {
  // HttpManager 是进程级单例实例（HttpManagerImpl），直接引用以共享鉴权状态
  private http = HttpManager;

  /**
   * 执行 GraphQL 查询/变更。
   * @param query GraphQL 文档（query/mutation）
   * @param variables 变量表（可选）
   */
  async query<T>(query: string, variables: Record<string, Object> | null = null): Promise<GraphQLResult<T>> {
    // GraphQL 请求体：ArkTS 下用显式 Record 构造（query 必填 + variables 可选键）
    const body: Record<string, Object> = { 'query': query as Object };
    if (variables !== null) {
      body['variables'] = variables as Object;
    }
    // 复用 netFetch：Authorization/User-Agent 注入、401 登录过期总线、超时与错误码映射
    const res = await this.http.netFetch<GraphQLResponseShape>(
      GRAPHQL_ENDPOINT, 'POST', body, true, null);
    if (!res.result || res.data === null) {
      return new GraphQLResult<T>(false, null, [], res.code);
    }
    const errors: GraphQLError[] = res.data.errors !== undefined && res.data.errors !== null
      ? res.data.errors
      : [];
    if (errors.length > 0) {
      hilog.warn(0x0666, TAG, 'graphql errors %{public}s', JSON.stringify(errors));
      return new GraphQLResult<T>(false, null, errors, res.code);
    }
    const payload: Object | null | undefined = res.data.data;
    if (payload === null || payload === undefined) {
      return new GraphQLResult<T>(false, null, [], res.code);
    }
    const data: T = payload as T;
    return new GraphQLResult<T>(true, data, [], res.code);
  }
}

/** 默认客户端（进程级单例，与 REST 共用 HttpManager 的鉴权状态）。 */
let shared: GraphQLClient | null = null;

export function sharedGraphQLClient(): GraphQLClient {
  if (shared === null) {
    shared = new GraphQLClient();
  }
  return shared;
}

/** 示范查询：当前登录用户（用于验证通道连通，亦是"我的"页聚合查询的种子）。 */
export const QUERY_VIEWER: string = `
query ViewerLogin {
  viewer {
    login
    name
    avatarUrl
  }
}
`;
