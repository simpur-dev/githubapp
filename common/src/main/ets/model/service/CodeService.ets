import HttpManager from '../../base/net/HttpManager';
import { Address } from '../../base/net/Address';
import { HttpResult } from '../../base/net/Result';
import { HtmlUtil } from '../../base/utils/HtmlUtil';
import { GSYColor } from '../../ui/style/Theme';
import { RepositoryDao } from '../../base/dao/RepositoryDao';
import { ReadResult } from '../../base/dao/DaoBase';
import { HttpHeaders } from '../../base/net/Result';
import { CommitDetail, CommitFileItem } from './CommitService';

export class RepoOwnerNamePair {
  owner: string;
  name: string;

  constructor(owner: string, name: string) {
    this.owner = owner;
    this.name = name;
  }

  static parse(fullName: string): RepoOwnerNamePair {
    const safe: string = fullName !== null && fullName !== undefined ? fullName : '';
    const idx: number = safe.indexOf('/');
    if (idx < 0) {
      return new RepoOwnerNamePair(safe, '');
    }
    return new RepoOwnerNamePair(safe.substring(0, idx), safe.substring(idx + 1));
  }
}

export interface RawContentResponse {
  content: string;
  encoding: string;
  path: string;
  name: string;
}

const MARKDOWN_LANG: string = 'markdown';
const GITHUB_HTML_ACCEPT: string = 'application/vnd.github.html';

/**
 * 文件内容取数结果（R9 无状态化，双通道语义对齐 FetchReadmeResult）：
 *   - content：raw 原文 / markdown 原文 / patch（原生 MarkdownRenderer 通道）；
 *   - html：包好的高亮 HTML（WebView 兜底通道；markdown 通道与 content 相同）；
 *   - result=false 时两者皆空，msg 为错误文案。
 */
export class FetchCodeContentResult {
  result: boolean;
  code: number;
  content: string;
  html: string;
  fromCache: boolean;
  msg: string;

  constructor(result: boolean, code: number, content: string, html: string,
              fromCache: boolean, msg: string) {
    this.result = result;
    this.code = code;
    this.content = content;
    this.html = html;
    this.fromCache = fromCache;
    this.msg = msg;
  }
}

export class CodeService {
  private dao: RepositoryDao;

  // R9 V2 + MVVM 无状态化：构造函数不再持有 CodeDetailStore，
  // content / html 双通道结果走返回值（谁调谁更新：调用方 ViewModel 写自己的 UI 状态）。
  constructor(dao?: RepositoryDao) {
    this.dao = dao !== undefined ? dao : new RepositoryDao();
  }

  static guessLangByPath(path: string): string {
    const safe: string = path !== null && path !== undefined ? path : '';
    const dot: number = safe.lastIndexOf('.');
    if (dot < 0) {
      return 'java';
    }
    const ext: string = safe.substring(dot + 1).toLowerCase();
    if (ext === 'md' || ext === 'markdown') {
      return MARKDOWN_LANG;
    }
    if (ext === 'ts' || ext === 'tsx') {
      return 'typescript';
    }
    if (ext === 'js' || ext === 'jsx') {
      return 'javascript';
    }
    if (ext === 'java') {
      return 'java';
    }
    if (ext === 'kt' || ext === 'kts') {
      return 'kotlin';
    }
    if (ext === 'py') {
      return 'python';
    }
    if (ext === 'go') {
      return 'go';
    }
    if (ext === 'rs') {
      return 'rust';
    }
    if (ext === 'c' || ext === 'h') {
      return 'c';
    }
    if (ext === 'cc' || ext === 'cpp' || ext === 'cxx' || ext === 'hpp') {
      return 'cpp';
    }
    if (ext === 'm' || ext === 'mm') {
      return 'objectivec';
    }
    if (ext === 'swift') {
      return 'swift';
    }
    if (ext === 'php') {
      return 'php';
    }
    if (ext === 'html' || ext === 'htm') {
      return 'html';
    }
    if (ext === 'css' || ext === 'scss' || ext === 'less') {
      return 'css';
    }
    if (ext === 'json') {
      return 'json';
    }
    if (ext === 'xml') {
      return 'xml';
    }
    if (ext === 'yaml' || ext === 'yml') {
      return 'yaml';
    }
    if (ext === 'sh' || ext === 'bash') {
      return 'bash';
    }
    if (ext === 'ets' || ext === 'arkts') {
      return 'typescript';
    }
    return ext.length > 0 ? ext : 'java';
  }

  async getRawContent(fullName: string,
                      branch: string,
                      path: string,
                      onCached?: (content: string, html: string) => void): Promise<FetchCodeContentResult> {
    const owner: RepoOwnerNamePair = RepoOwnerNamePair.parse(fullName);
    if (owner.owner.length === 0 || owner.name.length === 0) {
      const msg: string = 'invalid fullName';
      return new FetchCodeContentResult(false, 0, '', '', false, msg);
    }
    const safePath: string = path !== null && path !== undefined ? path : '';
    const safeBranch: string = branch !== null && branch !== undefined && branch.length > 0
      ? branch : 'master';
    const isMarkdown: boolean = CodeService.isMarkdownPath(safePath);
    let cachedBody: string = '';
    try {
      const cache: ReadResult = await this.dao.readCodeContent(fullName, safeBranch, safePath);
      if (cache.result && cache.data.length > 0) {
        cachedBody = cache.data;
        if (!isMarkdown || CodeService.isLikelyHtml(cachedBody)) {
          if (onCached !== undefined && onCached !== null) {
            onCached(cachedBody, CodeService.wrapHtml(cachedBody, safePath));
          }
        }
      }
    } catch (_e) {
    }

    // 双通道：markdown 文件优先 raw 原文（原生 MarkdownRenderer 渲染，无 WebView、高性能）；
    // 失败再降级 GitHub HTML（WebView 兜底）。非 markdown 文件维持原逻辑。
    if (isMarkdown) {
      const rawContentsUrl: string = Address.getReposFileDir(owner.owner, owner.name, safePath, safeBranch);
      const rawHeaders: HttpHeaders = {
        'Accept': 'application/vnd.github.raw',
      };
      const rawResp: HttpResult<string> = await HttpManager.getFetch<string>(rawContentsUrl, rawHeaders);
      if (rawResp.result && rawResp.data !== null) {
        const md: string = rawResp.data as string;
        try {
          await this.dao.saveCodeContent(fullName, safeBranch, safePath, md);
        } catch (_e) {
        }
        return new FetchCodeContentResult(true, rawResp.code, md, md, false, '');
      }
    }

    const htmlHeaders: HttpHeaders = {
      'Accept': GITHUB_HTML_ACCEPT,
    };
    const contentsUrl: string = Address.getReposFileDir(owner.owner, owner.name, safePath, safeBranch);
    const htmlResp: HttpResult<string> = await HttpManager.getFetch<string>(contentsUrl, htmlHeaders);
    if (htmlResp.result && htmlResp.data !== null) {
      const body: string = htmlResp.data as string;
      const html: string = CodeService.wrapHtml(body, safePath);
      try {
        await this.dao.saveCodeContent(fullName, safeBranch, safePath, body);
      } catch (_e) {
      }
      return new FetchCodeContentResult(true, htmlResp.code, body, html, false, '');
    }

    // Compose 的文件详情对 Markdown 只走 GitHub 渲染后的 HTML，再交给 WebView。
    // 这里不再把 raw markdown 当兜底渲染，避免 README.md 显示源码文本。
    if (isMarkdown) {
      if (cachedBody.length > 0 && CodeService.isLikelyHtml(cachedBody)) {
        const cachedHtml: string = CodeService.wrapHtml(cachedBody, safePath);
        return new FetchCodeContentResult(true, htmlResp.code, cachedBody, cachedHtml, true,
          htmlResp.msg !== null ? htmlResp.msg : '');
      }
      const markdownMsg: string = htmlResp.msg !== null && htmlResp.msg.length > 0
        ? htmlResp.msg : 'network error';
      return new FetchCodeContentResult(false, htmlResp.code, '', '', false, markdownMsg);
    }

    const rawUrl: string = Address.getRawFile(owner.owner, owner.name, safeBranch, safePath);
    const rawResp: HttpResult<string> = await HttpManager.getFetch<string>(rawUrl);
    if (rawResp.result && rawResp.data !== null) {
      const text: string = rawResp.data as string;
      const html: string = CodeService.wrapHtml(text, safePath);
      try {
        await this.dao.saveCodeContent(fullName, safeBranch, safePath, text);
      } catch (_e) {
      }
      return new FetchCodeContentResult(true, rawResp.code, text, html, false, '');
    }

    const apiResp: HttpResult<RawContentResponse> =
      await HttpManager.getFetch<RawContentResponse>(contentsUrl);
    if (apiResp.result && apiResp.data !== null) {
      const data: RawContentResponse = apiResp.data as RawContentResponse;
      const decoded: string = CodeService.decodeBase64(data.content);
      const html: string = CodeService.wrapHtml(decoded, safePath);
      try {
        await this.dao.saveCodeContent(fullName, safeBranch, safePath, decoded);
      } catch (_e) {
      }
      return new FetchCodeContentResult(true, apiResp.code, decoded, html, false, '');
    }

    if (cachedBody.length > 0) {
      return new FetchCodeContentResult(true, apiResp.code, cachedBody,
        CodeService.wrapHtml(cachedBody, safePath), true,
        apiResp.msg !== null ? apiResp.msg : '');
    }
    const msg: string = apiResp.msg !== null && apiResp.msg.length > 0 ? apiResp.msg
      : (rawResp.msg !== null ? rawResp.msg : 'network error');
    return new FetchCodeContentResult(false, apiResp.code, '', '', false, msg);
  }

  async getCommitFile(fullName: string,
                      sha: string,
                      path: string): Promise<FetchCodeContentResult> {
    const owner: RepoOwnerNamePair = RepoOwnerNamePair.parse(fullName);
    const safePath: string = path !== null && path !== undefined ? path : '';
    if (owner.owner.length === 0 || owner.name.length === 0
      || sha === null || sha === undefined || sha.length === 0 || safePath.length === 0) {
      const msg: string = 'invalid params';
      return new FetchCodeContentResult(false, 0, '', '', false, msg);
    }

    const url: string = Address.getCommitDetail(owner.owner, owner.name, sha);
    const httpResult: HttpResult<CommitDetail> = await HttpManager.getFetch<CommitDetail>(url);
    if (httpResult.result && httpResult.data !== null) {
      const detail: CommitDetail = httpResult.data as CommitDetail;
      const files: CommitFileItem[] = detail.files !== null && detail.files !== undefined ? detail.files : [];
      for (let i = 0; i < files.length; i++) {
        const file: CommitFileItem = files[i];
        if (file.filename === safePath) {
          const patch: string = file.patch !== null && file.patch !== undefined ? file.patch : '';
          const html: string = CodeService.wrapHtml(patch, safePath);
          return new FetchCodeContentResult(true, httpResult.code, patch, html, false, '');
        }
      }
      const msg: string = 'File not found in commit';
      return new FetchCodeContentResult(false, httpResult.code, '', '', false, msg);
    }
    const msg: string = httpResult.msg !== null && httpResult.msg.length > 0
      ? httpResult.msg : 'network error';
    return new FetchCodeContentResult(false, httpResult.code, '', '', false, msg);
  }

  static wrapHtml(content: string, path: string): string {
    if (content === null || content === undefined) {
      return '';
    }
    const lang: string = CodeService.guessLangByPath(path);
    if (lang === MARKDOWN_LANG) {
      return CodeService.wrapMarkdownHtml(content);
    }
    return HtmlUtil.generateCode2Html(content, GSYColor.webDraculaBackground, lang, true);
  }

  private static isMarkdownPath(path: string): boolean {
    return CodeService.guessLangByPath(path) === MARKDOWN_LANG;
  }

  private static isLikelyHtml(content: string): boolean {
    const safe: string = content !== null && content !== undefined ? content.trim().toLowerCase() : '';
    if (safe.length === 0) {
      return false;
    }
    return safe.indexOf('<html') >= 0
      || safe.indexOf('<body') >= 0
      || safe.indexOf('<article') >= 0
      || safe.indexOf('<div') >= 0
      || safe.indexOf('<h1') >= 0
      || safe.indexOf('<h2') >= 0
      || safe.indexOf('<p') >= 0;
  }

  private static wrapMarkdownHtml(content: string): string {
    if (CodeService.isLikelyHtml(content) && content.toLowerCase().indexOf('<html') >= 0) {
      return content;
    }
    const viewport: string = '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
    const style: string = '<style>'
      + 'body{padding:15px;}'
      + 'img{max-width:100% !important;height:auto !important;}'
      + 'pre{background-color:#f6f8fa;padding:16px;overflow:auto;border-radius:6px;}'
      + '</style>';
    return '<html><head>' + viewport + style + '</head><body>' + content + '</body></html>';
  }

  static decodeBase64(content: string): string {
    if (content === null || content === undefined || content.length === 0) {
      return '';
    }
    try {
      const bytes: Uint8Array = CodeService.decodeBase64Bytes(content);
      return CodeService.decodeUtf8(bytes);
    } catch (_e) {
      return '';
    }
  }

  private static decodeBase64Bytes(content: string): Uint8Array {
    const alphabet: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const out: number[] = [];
    let buffer: number = 0;
    let bits: number = 0;
    for (let i = 0; i < content.length; i++) {
      const ch: string = content.charAt(i);
      if (ch === '=') {
        break;
      }
      const idx: number = alphabet.indexOf(ch);
      if (idx < 0) {
        continue;
      }
      buffer = (buffer << 6) | idx;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        out.push((buffer >> bits) & 0xFF);
      }
    }
    return new Uint8Array(out);
  }

  private static decodeUtf8(bytes: Uint8Array): string {
    let out: string = '';
    let i: number = 0;
    while (i < bytes.length) {
      const b0: number = bytes[i];
      if (b0 < 0x80) {
        out += String.fromCharCode(b0);
        i += 1;
      } else if ((b0 & 0xE0) === 0xC0 && i + 1 < bytes.length) {
        const b1: number = bytes[i + 1];
        out += String.fromCharCode(((b0 & 0x1F) << 6) | (b1 & 0x3F));
        i += 2;
      } else if ((b0 & 0xF0) === 0xE0 && i + 2 < bytes.length) {
        const b1: number = bytes[i + 1];
        const b2: number = bytes[i + 2];
        out += String.fromCharCode(((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F));
        i += 3;
      } else {
        out += '?';
        i += 1;
      }
    }
    return out;
  }
}
