/**
 * PushDetailPage —— 提交（commit）详情页（R9 V2 + MVVM）。
 *
 * 原 V1 @Component + PushDetailStore + CommitService(store) 整页迁 @ComponentV2：
 * 提交详情 / 文件列表 / 加载错误态收敛到 PushViewModel（@Local vm 持有），
 * CommitService 已无状态化（cache-first 经 onCached 回调）；
 * 文件列表 ForEach → Repeat（virtualScroll，sha+文件名稳定 key），
 * 全部 push_detail_* 测试 id 原样保留。
 */
import pasteboard from '@ohos.pasteboard';
import { NavTitleAction, NavTitleBridge, NavTitleConfig } from 'common';
import { I18n } from 'common';
import { Logger } from 'common';
import { CommonModal, CommonOptionItem } from 'common';
import { CommonToast } from 'common';
import { BOOT_PUSH_KEY } from 'common';
import { NavigationService } from 'common';
import { RouteParamReader } from 'common';
import { RouteName } from 'common';
import { GSYColor, GSYFontSize, GSYIconSize, GSYShadow, GSYSpacing, ThemeManager } from 'common';
import { IconFont } from 'common';
import { TimeUtil } from 'common';
import {
  CommitAuthorInfo,
  CommitDetail,
  CommitFileItem,
  CommitInner,
} from 'common';
import { ExternalUrlUtil } from 'common';
import { PushViewModel } from './viewmodel/PushViewModel';

interface PushDetailRouteParam {
  fullName?: string;
  sha?: string;
}

const FALLBACK_SHA: string = '';
const FA_EDIT: string = '\uf044';

@ComponentV2
export struct PushDetailPage {
  @Local vm: PushViewModel = new PushViewModel();
  private pathStack: NavPathStack = new NavPathStack();

  // R9 阶段4：标题栏交给 NavDestination 原生 .title/.menus（push_detail_appbar id 经 barId 保留）。
  aboutToAppear(): void {
    NavTitleBridge.get().registerTitle(RouteName.PushDetail, {
      titleGetter: (): string => this.titleOwnerRepo(),
      barId: 'push_detail_appbar',
      rightActions: this.buildRightActions(),
    } as NavTitleConfig);
  }

  private resolveParamFromStack(stack: NavPathStack): PushDetailRouteParam | null {
    const raw: Object | null = RouteParamReader.readStackTopParam(stack);
    return raw !== null ? raw as PushDetailRouteParam : null;
  }

  private loadAll(): void {
    this.vm.loadAll();
  }

  private openFile(item: CommitFileItem): void {
    NavigationService.push(RouteName.CodeDetail, {
      'fullName': this.vm.fullName,
      'sha': this.vm.sha,
      'path': item.filename,
    } as Record<string, Object>);
  }

  private titleOwnerRepo(): string {
    return this.vm.fullName.length > 0 ? this.vm.fullName : I18n('reposPush');
  }

  private resolveHtmlUrl(): string {
    if (this.vm.fullName.length === 0 || this.vm.sha.length === 0) {
      return '';
    }
    return 'https://github.com/' + this.vm.fullName + '/commit/' + this.vm.sha;
  }

  private copyToPasteboard(text: string): void {
    if (text.length === 0) {
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const board: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      board.setData(data);
      CommonToast.showShort(I18n('hadCopy'));
    } catch (_e) {
      CommonToast.showShort(I18n('hadCopy'));
    }
  }

  private showMoreMenu(): void {
    const htmlUrl: string = this.resolveHtmlUrl();
    const items: CommonOptionItem[] = [
      { itemName: I18n('browserOpen') } as CommonOptionItem,
      { itemName: I18n('copy') } as CommonOptionItem,
      { itemName: I18n('share') } as CommonOptionItem,
    ];
    CommonModal.options(
      { title: this.titleOwnerRepo(), items: items },
      (index: number, _item: CommonOptionItem): void => {
        if (htmlUrl.length === 0) {
          return;
        }
        if (index === 0) {
          ExternalUrlUtil.openUrlInBrowser(this.getUIContext().getHostContext(), htmlUrl, 'PushDetailPage');
        } else if (index === 1) {
          this.copyToPasteboard(htmlUrl);
        } else if (index === 2) {
          ExternalUrlUtil.openUrlInBrowser(this.getUIContext().getHostContext(), htmlUrl, 'PushDetailPage');
        }
      }
    );
  }

  private buildRightActions(): NavTitleAction[] {
    return [
      {
        iconKey: 'more',
        onAction: (): void => {
          this.showMoreMenu();
        },
      } as NavTitleAction,
    ];
  }

  private getAuthorAvatar(): string {
    const c: CommitDetail | null = this.vm.commit;
    if (c !== null && c.author !== null && c.author !== undefined) {
      return c.author.avatar_url;
    }
    if (c !== null && c.committer !== null && c.committer !== undefined) {
      return c.committer.avatar_url;
    }
    return '';
  }

  private getAuthorName(): string {
    const c: CommitDetail | null = this.vm.commit;
    if (c === null) {
      return '';
    }
    if (c.author !== null && c.author !== undefined && c.author.login.length > 0) {
      return c.author.login;
    }
    if (c.commit !== null && c.commit !== undefined
      && c.commit.author !== null && c.commit.author !== undefined) {
      return c.commit.author.name;
    }
    return '';
  }

  private getAuthorDate(): string {
    const c: CommitDetail | null = this.vm.commit;
    if (c === null || c.commit === null || c.commit === undefined) {
      return '';
    }
    const inner: CommitInner = c.commit;
    if (inner.committer !== null && inner.committer !== undefined && inner.committer.date.length > 0) {
      return inner.committer.date;
    }
    if (inner.author !== null && inner.author !== undefined) {
      return inner.author.date;
    }
    return '';
  }

  private getAuthorEmail(): string {
    const c: CommitDetail | null = this.vm.commit;
    if (c === null || c.commit === null || c.commit === undefined) {
      return '';
    }
    const author: CommitAuthorInfo = c.commit.author;
    if (author !== null && author !== undefined) {
      return author.email;
    }
    return '';
  }

  private getMessage(): string {
    const c: CommitDetail | null = this.vm.commit;
    if (c === null || c.commit === null || c.commit === undefined) {
      return '';
    }
    return c.commit.message !== null ? c.commit.message : '';
  }

  private filePathOf(filename: string): string {
    const safe: string = filename !== null && filename !== undefined ? filename : '';
    const idx: number = safe.lastIndexOf('/');
    return idx > -1 ? safe.substring(0, idx) : '';
  }

  private fileNameOf(filename: string): string {
    const safe: string = filename !== null && filename !== undefined ? filename : '';
    const idx: number = safe.lastIndexOf('/');
    return idx > -1 ? safe.substring(idx + 1) : safe;
  }

  @Builder
  buildCommitCard(): void {
    Column() {
      Row() {
        Image(this.getAuthorAvatar())
          .id('push_detail_author_avatar')
          .alt($r('app.media.app_icon'))
          .width(GSYIconSize.normal)
          .height(GSYIconSize.normal)
          .borderRadius(GSYIconSize.normal / 2)
          .objectFit(ImageFit.Cover);

        Column() {
          if (this.vm.commit !== null) {
            Row() {
              IconFont({
                char: FA_EDIT,
                glyphSize: 16,
                glyphColor: ThemeManager.current().text,
              });
              Text((this.vm.commit as CommitDetail).stats.total.toString())
                .id('push_detail_file_count_text')
                .fontSize(GSYFontSize.min)
                .fontColor(ThemeManager.current().text)
                .margin({ left: GSYSpacing.halfEdge, right: GSYSpacing.normalEdge });
              Text('+' + (this.vm.commit as CommitDetail).stats.additions.toString())
                .id('push_detail_additions_text')
                .fontSize(GSYFontSize.min)
                .fontColor(GSYColor.issueOpenGreen)
                .margin({ right: GSYSpacing.normalEdge });
              Text('-' + (this.vm.commit as CommitDetail).stats.deletions.toString())
                .id('push_detail_deletions_text')
                .fontSize(GSYFontSize.min)
                .fontColor(GSYColor.issueClosedRed);
            }
            .id('push_detail_stats_row')
            .alignItems(VerticalAlign.Center);
          }
          Text(TimeUtil.resolveTime(this.getAuthorDate()))
            .id('push_detail_date_text')
            .fontSize(GSYFontSize.min)
            .fontColor(ThemeManager.current().textSecondary)
            .margin({ top: GSYSpacing.halfEdge });
        }
        .layoutWeight(1)
        .margin({ left: GSYSpacing.normalEdge })
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Text(this.getMessage().length > 0 ? this.getMessage() : I18n('userInfoNoting'))
        .id('push_detail_message_text')
        .fontSize(GSYFontSize.small)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeManager.current().text)
        .margin({ top: GSYSpacing.normalEdge })
        .maxLines(4)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .id('push_detail_commit_card')
    .width('auto')
    .margin({
      left: GSYSpacing.composeCardHorizontal,
      right: GSYSpacing.composeCardHorizontal,
      top: GSYSpacing.composeCardVertical,
      bottom: GSYSpacing.composeCardVertical,
    })
    .padding({
      left: GSYSpacing.normalEdge,
      right: GSYSpacing.normalEdge,
      top: GSYSpacing.normalEdge,
      bottom: GSYSpacing.normalEdge
    })
    .borderRadius(8)
    .border({ width: 1, color: ThemeManager.current().divider })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(ThemeManager.current().card)
    .shadow({
      radius: GSYShadow.radius,
      color: GSYShadow.cardShadowAlpha,
      offsetX: 0,
      offsetY: GSYShadow.elevation,
    });
  }

  @Builder
  buildFileItem(item: CommitFileItem, idx: number): void {
    Column() {
      if (this.filePathOf(item.filename).length > 0) {
        Text(this.filePathOf(item.filename))
          .id('push_detail_file_path_' + idx.toString())
          .fontSize(GSYFontSize.min)
          .fontColor(ThemeManager.current().textSecondary)
          .margin({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge, bottom: 2 });
      }

      Column() {
        Row() {
          IconFont({
            char: FA_EDIT,
            glyphSize: GSYIconSize.cardIcon,
            glyphColor: ThemeManager.current().text,
          });
          Text(this.fileNameOf(item.filename))
            .id('push_detail_file_filename_' + idx.toString())
            .fontSize(GSYFontSize.normal)
            .fontColor(ThemeManager.current().text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: GSYSpacing.normalEdge });
        }
        .id('push_detail_file_card_' + idx.toString())
        .width('100%')
        .padding({
          left: GSYSpacing.normalEdge,
          right: GSYSpacing.normalEdge,
          top: GSYSpacing.normalEdge,
          bottom: GSYSpacing.normalEdge
        })
        .borderRadius(8)
        .border({ width: 1, color: ThemeManager.current().divider })
        .backgroundColor(ThemeManager.current().card)
        .shadow({
          radius: GSYShadow.radius,
          color: GSYShadow.cardShadowAlpha,
          offsetX: 0,
          offsetY: GSYShadow.elevation,
        })
        .alignItems(VerticalAlign.Center);
      }
      .width('100%')
      .padding({
        left: GSYSpacing.composeCardHorizontal,
        right: GSYSpacing.composeCardHorizontal,
        top: GSYSpacing.composeCardVertical,
        bottom: GSYSpacing.composeCardVertical,
      });
    }
    .id('push_detail_file_row_' + idx.toString())
    .width('100%')
    .onClick((): void => {
      this.openFile(item);
    });
  }

  build(): void {
    NavDestination() {
      Column() {
        List() {
          ListItem() {
            this.buildCommitCard();
          }
          .id('push_detail_header_list_item');

          Repeat<CommitFileItem>(this.vm.files)
            .virtualScroll()
            .each((obj: RepeatItem<CommitFileItem>): void => {
              ListItem() {
                this.buildFileItem(obj.item, obj.index);
              }
              .id('push_detail_file_list_item_' + obj.index.toString());
            })
            .key((item: CommitFileItem, idx: number): string => this.vm.fileKey(item, idx))
        }
        .id('push_detail_file_list')
        .width('100%')
        .cachedCount(5)
        .layoutWeight(1);
      }
      .id('push_detail_root')
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeManager.current().background);
    }
    .onReady((ctx: NavDestinationContext): void => {
      const stack: NavPathStack | undefined = ctx.pathStack;
      if (stack !== undefined && stack !== null) {
        this.pathStack = stack;
      }
      let fullName: string = '';
      let sha: string = FALLBACK_SHA;
      // 优先级 1：RouteParamStore（NavigationService.push 同步写入，覆盖所有 push 入口）
      const routeRaw: Object | null = RouteParamReader.consumeStoreParam(RouteName.PushDetail);
      if (routeRaw !== null) {
        const routeParam: PushDetailRouteParam = routeRaw as PushDetailRouteParam;
        let adopted: boolean = false;
        if (routeParam.fullName !== undefined && routeParam.fullName !== null && routeParam.fullName.length > 0) {
          fullName = routeParam.fullName;
          adopted = true;
        }
        if (routeParam.sha !== undefined && routeParam.sha !== null && routeParam.sha.length > 0) {
          sha = routeParam.sha;
          adopted = true;
        }
        if (adopted) {
          Logger.i('push/route', `PushDetailPage adopted via RouteParamStore fullName=${fullName} sha=${sha}`);
          this.vm.setTarget(fullName, sha);
          this.loadAll();
          return;
        }
      }
      let param: PushDetailRouteParam | null = null;
      let src: string = 'none';
      let stackSize: number = -1;
      let stackNames: string = '';
      let rawType: string = 'none';
      if (stack !== undefined && stack !== null) {
        try {
          const all: string[] = stack.getAllPathName();
          stackSize = all === null || all === undefined ? 0 : all.length;
          stackNames = all !== null && all !== undefined ? all.join(',') : '';
          if (stackSize > 0) {
            const raw: Object | undefined = stack.getParamByIndex(stackSize - 1) as Object | undefined;
            rawType = raw === undefined ? 'undef' : (raw === null ? 'null' : typeof raw);
          }
        } catch (_e) {
          stackSize = -2;
        }
      }
      const ctxParam: Object | null = RouteParamReader.readContextParam(ctx);
      if (ctxParam !== null) {
        param = ctxParam as PushDetailRouteParam;
        src = 'pathInfo';
      }
      if (param === null && stack !== undefined && stack !== null) {
        param = this.resolveParamFromStack(stack);
        if (param !== null) {
          src = 'stack';
        }
      }
      const pFull: string = param !== null && param.fullName !== undefined && param.fullName !== null ? param.fullName : '<null>';
      const pSha: string = param !== null && param.sha !== undefined && param.sha !== null ? param.sha : '<null>';
      Logger.i('boot/ts', `PushDetailPage.onReady src=${src} stackSize=${stackSize} stackNames=${stackNames} rawType=${rawType} pFull='${pFull}' pSha='${pSha}'`);
      if (param !== null) {
        if (param.fullName !== undefined && param.fullName !== null && param.fullName.length > 0) {
          fullName = param.fullName;
        }
        if (param.sha !== undefined && param.sha !== null && param.sha.length > 0) {
          sha = param.sha;
        }
      }
      // KI-045 同款：BOOT_PUSH_KEY 旁路兜底；优先级最高（NavDestination 复用时
      // 上一次的 fullName/sha 还在状态里，需要 BOOT 强制覆盖）。
      const raw: string = RouteParamReader.readBootString(BOOT_PUSH_KEY).trim();
      if (raw.length > 0) {
        const sep: number = raw.indexOf('|');
        if (sep > 0 && sep < raw.length - 1) {
          fullName = raw.substring(0, sep);
          sha = raw.substring(sep + 1);
          src = src + '+bootKey';
          Logger.i('boot/ts', `PushDetailPage.onReady bootKey-priority fullName='${fullName}' sha='${sha}'`);
        }
      }
      this.vm.setTarget(fullName, sha);
      this.loadAll();
    });
  }
}
