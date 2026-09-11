/**
 * 统一的 HTTP 返回包装。结构对齐 RN 端 net/index.js 的 `{result, code, data, headers}`，
 * 上层调用者无需关心底层是否使用 @ohos.net.http 还是 mock provider。
 */

export type HttpHeaders = Record<string, string>;

export class HttpResult<T> {
  result: boolean;
  code: number;
  data: T | null;
  msg: string | null;
  headers: HttpHeaders | null;

  constructor(result: boolean,
              code: number,
              data: T | null,
              msg: string | null = null,
              headers: HttpHeaders | null = null) {
    this.result = result;
    this.code = code;
    this.data = data;
    this.msg = msg;
    this.headers = headers;
  }

  static ok<T>(code: number, data: T, headers: HttpHeaders | null = null): HttpResult<T> {
    return new HttpResult<T>(true, code, data, null, headers);
  }

  static fail<T>(code: number, msg: string, data: T | null = null): HttpResult<T> {
    return new HttpResult<T>(false, code, data, msg, null);
  }
}
