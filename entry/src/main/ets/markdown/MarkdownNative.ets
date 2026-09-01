/**
 * MarkdownNative —— C 层 MD4C 高速解析的 NAPI 桥（无 WebView）
 *
 * 数据流：markdown 文本 → C 端 md_parse()（MD4C SAX 事件）→ ArkTS 事件数组
 *        → [MarkdownRenderer](src/main/ets/markdown/MarkdownRenderer.ets) 构建 ArkUI 原生组件树。
 *
 * 性能优势：解析在 C 端（MD4C，CommonMark 规范下最快的解析器之一），
 *          渲染在 ArkUI 原生（Text/Image/List，无 WebView 开销）。
 */
import hilog from '@ohos.hilog';
import md4cLib from 'libmd4c.so';

const TAG: string = 'MarkdownNative';

/** MD4C 解析事件：type = block / leaveBlock / span / leaveSpan / text */
export interface MdEvent {
  /** block | leaveBlock | span | leaveSpan | text */
  t: string;
  /** block/span 名字：h1..h6 / p / ul / ol / li / code / img / a / em / strong / del / tr / td ... */
  name: string;
  /** text 事件的文本 */
  text?: string;
  /** 附加信息：img 的 src / a 的 href */
  extra?: string;
}

interface NativeModule {
  parseMarkdown(input: string): MdEvent[];
}

let nativeInstance: NativeModule | null = null;

function getNative(): NativeModule {
  if (nativeInstance === null) {
    nativeInstance = md4cLib as NativeModule;
    hilog.info(0x0666, TAG, 'libmd4c.so loaded ok');
  }
  return nativeInstance;
}

export class MarkdownNative {
  /**
   * 解析 markdown 文本 → 事件数组。
   * C 端解析，返回事件流；失败返回空数组（调用方按文本兜底渲染）。
   */
  static parse(md: string): MdEvent[] {
    if (md === null || md === undefined || md.length === 0) {
      return [];
    }
    try {
      const events: MdEvent[] = getNative().parseMarkdown(md);
      hilog.info(0x0666, TAG, 'parse ok len=%{public}d events=%{public}d',
        md.length, events.length);
      return events;
    } catch (e) {
      const err = e as Error;
      hilog.warn(0x0666, TAG, 'parse fail %{public}s, fallback to plain text', err.message);
      return [];
    }
  }
}
