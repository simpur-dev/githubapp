/**
 * MarkdownRenderer —— MD4C 解析结果的原生渲染器（无 WebView）
 *
 * 块级渲染：标题/段落/代码块/列表/引用/图片/分割线
 * 行内渲染：加粗/斜体/链接/删除线（Text 内 Span 链）
 *
 * 数据来源：MD4C（C 端）SAX 事件流 → MarkdownNative.parse → 本组件建树。
 */
import { MdEvent, MarkdownNative } from './MarkdownNative';
import { GSYColor, GSYFontSize, GSYSpacing } from 'common';

/** 行内片段（一段文字 + 样式） */
export interface MdInline {
  text: string;
  bold: boolean;
  italic: boolean;
  del: boolean;
  link: boolean;
  code: boolean;
  href: string;
}

/** 块级行模型 */
export interface MarkdownRow {
  kind: string;      // h1..h6 / p / code / quote / li / img / hr / table
  text: string;      // 纯文本（行内样式用 inlines）
  extra: string;     // img src 等
  inlines: MdInline[];
  level: number;     // 列表嵌套层级（用于缩进）
}

/**
 * 事件流 → 块级行数组。
 * span 边界跟踪：enter span → 后续 text 归入该 span 样式，leave span 弹栈。
 */
export function buildRows(events: MdEvent[]): MarkdownRow[] {
  const rows: MarkdownRow[] = [];
  let curText: string = '';
  let curKind: string = '';
  let curExtra: string = '';
  let curLevel: number = 0;
  let curInlines: MdInline[] = [];
  // span 样式栈（多层嵌套）
  const boldStack: boolean[] = [];
  const italicStack: boolean[] = [];
  const delStack: boolean[] = [];
  const linkStack: string[] = [];
  const codeStack: boolean[] = [];

  const flush = (): void => {
    if (curKind.length > 0) {
      const row: MarkdownRow = {
        kind: curKind,
        text: curText,
        extra: curExtra,
        inlines: curInlines,
        level: curLevel,
      };
      rows.push(row);
    }
    curText = '';
    curKind = '';
    curExtra = '';
    curLevel = 0;
    curInlines = [];
  };

  for (let i = 0; i < events.length; i++) {
    const e: MdEvent = events[i];

    if (e.t === 'block') {
      flush();
      curKind = e.name;
      if (e.name === 'li') {
        curLevel = (curLevel > 0 ? curLevel : 0);
      }
    } else if (e.t === 'leaveBlock') {
      flush();
      // 列表层级下降
      if (e.name === 'li') {
        curLevel = 0;
      }
    } else if (e.t === 'span') {
      if (e.name === 'strong') {
        boldStack.push(true);
      } else if (e.name === 'em') {
        italicStack.push(true);
      } else if (e.name === 'del') {
        delStack.push(true);
      } else if (e.name === 'code') {
        codeStack.push(true);
      } else if (e.name === 'a') {
        linkStack.push(e.extra !== undefined ? e.extra : '');
      } else if (e.name === 'img' && e.extra !== undefined && e.extra !== null && e.extra.length > 0) {
        flush();
        const row: MarkdownRow = { kind: 'img', text: '', extra: e.extra, inlines: [], level: 0 };
        rows.push(row);
      }
    } else if (e.t === 'leaveSpan') {
      if (e.name === 'strong') {
        boldStack.pop();
      } else if (e.name === 'em') {
        italicStack.pop();
      } else if (e.name === 'del') {
        delStack.pop();
      } else if (e.name === 'code') {
        codeStack.pop();
      } else if (e.name === 'a') {
        linkStack.pop();
      }
    } else if (e.t === 'text') {
      const txt: string = e.text !== undefined && e.text !== null ? e.text : '';
      if (txt.length > 0) {
        curText += txt;
        const inline: MdInline = {
          text: txt,
          bold: boldStack.length > 0,
          italic: italicStack.length > 0,
          del: delStack.length > 0,
          link: linkStack.length > 0,
          code: codeStack.length > 0,
          href: linkStack.length > 0 ? linkStack[linkStack.length - 1] : '',
        };
        curInlines.push(inline);
      }
    }
  }
  flush();
  return rows;
}

const MD_NUMBER_PREFIX: string = '•';
const MD_CODE_FONT: string = 'monospace';

@Builder
function buildInlineText(inlines: MdInline[]): void {
  Text() {
    ForEach(inlines, (span: MdInline, idx: number): void => {
      Span(span.text)
        .fontSize(GSYFontSize.middleWhite)
        .fontColor(GSYColor.primaryDark)
        .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
        .fontStyle(span.italic ? FontStyle.Italic : FontStyle.Normal)
        .fontFamily(span.code ? MD_CODE_FONT : undefined)
        .decoration({
          type: span.del ? TextDecorationType.LineThrough : TextDecorationType.None,
          color: GSYColor.primaryDark,
        })
        .onClick(() => {
          if (span.link && span.href.length > 0) {
            // 链接点击：交给上层处理（这里留空，上层绑定 onLinkClick）
          }
        });
    }, (span: MdInline, idx: number): string => idx.toString() + '_' + span.text.substring(0, 8));
  }
  .lineHeight(24)
  .fontColor(GSYColor.primaryDark)
  .fontSize(GSYFontSize.middleWhite);
}

@Component
export struct MarkdownRenderer {
  @Watch('onMarkdownChange') @Prop markdown: string = '';
  @State rows: MarkdownRow[] = [];
  onLinkClick: (href: string) => void = (_href: string): void => {};

  aboutToAppear(): void {
    this.rebuild();
  }

  onMarkdownChange(): void {
    this.rebuild();
  }

  private rebuild(): void {
    try {
      const events: MdEvent[] = this.parse(this.markdown);
      this.rows = buildRows(events);
    } catch (e) {
      this.rows = [];
    }
  }

  private parse(md: string): MdEvent[] {
    return MarkdownNative.parse(md);
  }

  @Builder
  private buildRow(row: MarkdownRow): void {
    if (row.kind === 'h1' || row.kind === 'h2' || row.kind === 'h3') {
      Text(row.text)
        .fontSize(row.kind === 'h1' ? GSYFontSize.big : GSYFontSize.normal)
        .fontWeight(FontWeight.Bold)
        .fontColor(GSYColor.primaryDark)
        .width('100%')
        .margin({ top: 16, bottom: 8 });
    } else if (row.kind === 'code') {
      Text(row.text)
        .fontSize(GSYFontSize.small)
        .fontColor(GSYColor.primaryDark)
        .fontFamily(MD_CODE_FONT)
        .backgroundColor(GSYColor.surfaceSubtle)
        .borderRadius(GSYSpacing.cardRadius)
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .margin({ top: 6, bottom: 6 });
    } else if (row.kind === 'quote') {
      Column() {
        Text(row.text)
          .fontSize(GSYFontSize.middleWhite)
          .fontColor(GSYColor.mediumDarkText)
          .width('100%');
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .border({
        width: { left: 3 },
        color: GSYColor.pillDivider,
      })
      .margin({ top: 6, bottom: 6 });
    } else if (row.kind === 'li') {
      Row() {
        Text(MD_NUMBER_PREFIX)
          .fontSize(GSYFontSize.middleWhite)
          .fontColor(GSYColor.subText)
          .margin({ right: 8 });
        if (row.inlines.length > 0) {
          buildInlineText(row.inlines);
        } else {
          Text(row.text)
            .fontSize(GSYFontSize.middleWhite)
            .fontColor(GSYColor.primaryDark);
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ top: 4, bottom: 4 });
    } else if (row.kind === 'img') {
      Image(row.extra)
        .width('100%')
        .objectFit(ImageFit.Contain)
        .borderRadius(GSYSpacing.cardRadius)
        .margin({ top: 6, bottom: 6 });
    } else if (row.kind === 'hr') {
      Divider()
        .color(GSYColor.pillDivider)
        .margin({ top: 12, bottom: 12 });
    } else {
      if (row.inlines.length > 0) {
        buildInlineText(row.inlines);
      } else {
        Text(row.text)
          .fontSize(GSYFontSize.middleWhite)
          .fontColor(GSYColor.primaryDark)
          .width('100%')
          .lineHeight(24)
          .margin({ top: 4, bottom: 4 });
      }
    }
  }

  build(): void {
    Scroll() {
      Column() {
        ForEach(this.rows, (row: MarkdownRow, idx: number): void => {
          this.buildRow(row);
        }, (row: MarkdownRow, idx: number): string =>
          row.kind + '_' + idx.toString() + '_' + row.text.substring(0, 16));
      }
      .id('markdown_renderer')
      .width('100%')
      .padding({ left: 8, right: 8 })
      .alignItems(HorizontalAlign.Start);
    }
    .id('markdown_scroll')
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off);
  }
}
