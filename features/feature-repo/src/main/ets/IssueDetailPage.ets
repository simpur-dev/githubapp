/**
 * IssueDetailPage —— Issue 详情页（R9 V2 + MVVM）。
 *
 * 原 V1 @Component + IssueDetailStore + CustomDialogController 三弹层整页迁
 * @ComponentV2：issue 详情 / 评论列表 + 分页 / 权限判定 / 弹层开关与草稿 /
 * 操作 busy 态全部收敛到 IssueDetailViewModel（@Local vm 持有）；
 * 三组弹层（回复 / 编辑 issue / 编辑评论，含 issue_markdown_toolbar_* 工具条）
 * 由 @CustomDialog IssueEditDialog 迁为 @ComponentV2 IssueMarkdownEditSheet +
 * bindSheet 呈现（单节点单弹层，借 0 高锚点各挂一个，DrawerMenu 同款），
 * 全部 issue_detail_* / issue_comment_* / issue_edit_dialog_* / issue_reply_dialog_* /
 * issue_comment_edit_dialog_* / issue_markdown_toolbar_* 测试 id 原样保留；
 * 长按评论的选项菜单保持 CommonModal.options 系统弹层。
 * 登录态直读 GlobalAuthStore 单例（VM 内）。
 */
import { I18n } from 'common';
import { AppBar, AppBarAction } from 'common';
import { MarkdownText } from 'common';
import { PullLoadMoreList } from 'common';
import { Logger } from 'common';
import { BOOT_ISSUE_KEY, BootChannel } from 'common';
import { NavigationService } from 'common';
import { RouteParamStore } from 'common';
import { RouteName } from 'common';
import { GSYColor, GSYFontSize, GSYIconSize, GSYSpacing, GSYShadow } from 'common';
import {
  IssueDetailModel,
  IssueCommentModel,
  ISSUE_STATE_OPEN
} from 'common';
import { IssueService, IssueServiceResult } from 'common';
import { TimeUtil } from 'common';
import { renderEmoji } from 'common';
import { CommonBottomBar, CommonBottomBarItem } from 'common';
import { CommonToast } from 'common';
import { CommonModal, CommonOptionItem, OptionListOptions } from 'common';
import { ExternalUrlUtil } from 'common';
import pasteboard from '@ohos.pasteboard';
import {
  FA_COMMENT_O,
  FA_INFO_CIRCLE,
  FA_CHECK,
  FA_PLUS,
  FA_LOCK,
  FA_UNLOCK
} from 'common';
import { IssueDetailViewModel } from './viewmodel/IssueDetailViewModel';

/** 弹层形态枚举：回复 / 编辑 issue / 编辑评论（三组测试 id 前缀在此切换）。 */
const SHEET_MODE_REPLY: string = 'reply';
const SHEET_MODE_EDIT_ISSUE: string = 'editIssue';
const SHEET_MODE_EDIT_COMMENT: string = 'editComment';

const REPLY_SHEET_HEIGHT: number = 460;
const EDIT_ISSUE_SHEET_HEIGHT: number = 560;
const EDIT_COMMENT_SHEET_HEIGHT: number = 460;

/**
 * 编辑弹层内容（V2）。旧版经 @CustomDialog IssueEditDialog +
 * CustomDialogController 呈现（V2 组件不可用），内容结构原样迁为
 * @ComponentV2 + bindSheet，三组弹层（issue_edit_dialog_* / issue_reply_dialog_* /
 * issue_comment_edit_dialog_*，含 issue_markdown_toolbar_* 工具条）测试 id 全部原样保留。
 * 草稿值由 View 层在打开前写入 VM，经 @Param + @Monitor 同步（等价旧弹窗每次 open 重建）。
 */
@ComponentV2
struct IssueMarkdownEditSheet {
  @Param sheetMode: string = SHEET_MODE_REPLY;
  @Param dialogTitle: string = '';
  @Param showTitleField: boolean = true;
  @Param defaultTitle: string = '';
  @Param defaultBody: string = '';
  @Param titlePlaceholder: string = '';
  @Param bodyPlaceholder: string = '';
  @Param okText: string = '';
  @Param cancelText: string = '';
  @Event onConfirm: (title: string, body: string) => void = (_t: string, _b: string): void => {};
  @Event onCancel: () => void = (): void => {};
  @Local currentTitle: string = '';
  @Local currentBody: string = '';

  aboutToAppear(): void {
    this.currentTitle = this.defaultTitle;
    this.currentBody = this.defaultBody;
  }

  // 每次打开弹层前 View 层会更新 default 值，同步草稿（等价旧弹窗每次 open 重建）。
  @Monitor('defaultTitle')
  onDefaultTitleChange(): void {
    this.currentTitle = this.defaultTitle;
  }

  @Monitor('defaultBody')
  onDefaultBodyChange(): void {
    this.currentBody = this.defaultBody;
  }

  private appendMarkdown(insertion: string): void {
    this.currentBody = this.currentBody + insertion;
  }

  private titleTextId(): string {
    if (this.sheetMode === SHEET_MODE_REPLY) {
      return 'issue_reply_dialog_title';
    }
    if (this.sheetMode === SHEET_MODE_EDIT_COMMENT) {
      return 'issue_comment_edit_dialog_title';
    }
    return 'issue_edit_dialog_title';
  }

  private titleInputId(): string {
    return 'issue_edit_dialog_title_input';
  }

  private bodyInputId(): string {
    if (this.sheetMode === SHEET_MODE_REPLY) {
      return 'issue_reply_dialog_body_input';
    }
    if (this.sheetMode === SHEET_MODE_EDIT_COMMENT) {
      return 'issue_comment_edit_dialog_body_input';
    }
    return 'issue_edit_dialog_body_input';
  }

  private toolbarId(): string {
    if (this.sheetMode === SHEET_MODE_REPLY) {
      return 'issue_reply_markdown_toolbar';
    }
    if (this.sheetMode === SHEET_MODE_EDIT_COMMENT) {
      return 'issue_comment_edit_markdown_toolbar';
    }
    return 'issue_markdown_toolbar';
  }

  private rootId(): string {
    if (this.sheetMode === SHEET_MODE_REPLY) {
      return 'issue_reply_dialog_root';
    }
    if (this.sheetMode === SHEET_MODE_EDIT_COMMENT) {
      return 'issue_comment_edit_dialog_root';
    }
    return 'issue_edit_dialog_root';
  }

  private cancelButtonId(): string {
    if (this.sheetMode === SHEET_MODE_REPLY) {
      return 'issue_reply_dialog_cancel_btn';
    }
    if (this.sheetMode === SHEET_MODE_EDIT_COMMENT) {
      return 'issue_comment_edit_dialog_cancel_btn';
    }
    return 'issue_edit_dialog_cancel_btn';
  }

  private okButtonId(): string {
    if (this.sheetMode === SHEET_MODE_REPLY) {
      return 'issue_reply_dialog_ok_btn';
    }
    if (this.sheetMode === SHEET_MODE_EDIT_COMMENT) {
      return 'issue_comment_edit_dialog_ok_btn';
    }
    return 'issue_edit_dialog_ok_btn';
  }

  @Builder
  private buildMarkdownAction(actionId: string, label: string, insertion: string): void {
    Button(label)
      .id(actionId)
      .type(ButtonType.Normal)
      .fontSize(GSYFontSize.min)
      .fontColor(GSYColor.darkText)
      .backgroundColor(GSYColor.surfaceGray)
      .borderRadius(6)
      .height(32)
      .padding({ left: 10, right: 10 })
      .onClick((): void => {
        this.appendMarkdown(insertion);
      });
  }

  build(): void {
    Column() {
      if (this.dialogTitle.length > 0) {
        Text(this.dialogTitle)
          .id(this.titleTextId())
          .fontSize(GSYFontSize.middleWhite)
          .fontWeight(FontWeight.Bold)
          .fontColor(GSYColor.darkText)
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ bottom: GSYSpacing.normalEdge });
      }
      if (this.showTitleField) {
        TextInput({ text: this.currentTitle, placeholder: this.titlePlaceholder })
          .id(this.titleInputId())
          .maxLength(255)
          .height(44)
          .fontSize(GSYFontSize.small)
          .backgroundColor(GSYColor.surfaceGray)
          .borderRadius(6)
          .padding({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge })
          .onChange((value: string): void => {
            this.currentTitle = value;
          });
      }
      TextArea({ text: this.currentBody, placeholder: this.bodyPlaceholder })
        .id(this.bodyInputId())
        .maxLength(8192)
        .height(200)
        .fontSize(GSYFontSize.small)
        .backgroundColor(GSYColor.surfaceGray)
        .borderRadius(6)
        .padding(GSYSpacing.normalEdge)
        .margin({ top: this.showTitleField ? GSYSpacing.normalEdge : 0 })
        .onChange((value: string): void => {
          this.currentBody = value;
        });
      Scroll() {
        Row() {
          this.buildMarkdownAction(`${this.toolbarId()}_h1`, 'H1', '# ');
          this.buildMarkdownAction(`${this.toolbarId()}_h2`, 'H2', '## ');
          this.buildMarkdownAction(`${this.toolbarId()}_h3`, 'H3', '### ');
          this.buildMarkdownAction(`${this.toolbarId()}_bold`, 'B', '****');
          this.buildMarkdownAction(`${this.toolbarId()}_italic`, 'I', '**');
          this.buildMarkdownAction(`${this.toolbarId()}_ul`, 'UL', '- ');
          this.buildMarkdownAction(`${this.toolbarId()}_quote`, 'Quote', '> ');
          this.buildMarkdownAction(`${this.toolbarId()}_code`, 'Code', '``');
          this.buildMarkdownAction(`${this.toolbarId()}_image`, 'IMG', '![]()');
          this.buildMarkdownAction(`${this.toolbarId()}_link`, 'Link', '[]()');
        }
        .id(this.toolbarId())
        .height(36)
        .alignItems(VerticalAlign.Center);
      }
      .width('100%')
      .height(40)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .margin({ top: GSYSpacing.halfEdge });
      Row() {
        Button(this.cancelText)
          .id(this.cancelButtonId())
          .layoutWeight(1)
          .backgroundColor(GSYColor.transparent)
          .fontColor(GSYColor.mediumText)
          .onClick((): void => {
            this.onCancel();
          });
        Divider().vertical(true).height(20).color(GSYColor.pillDivider);
        Button(this.okText)
          .id(this.okButtonId())
          .layoutWeight(1)
          .backgroundColor(GSYColor.transparent)
          .fontColor(GSYColor.materialBlue)
          .onClick((): void => {
            const t: string = this.currentTitle;
            const b: string = this.currentBody;
            this.onConfirm(t, b);
          });
      }
      .width('100%')
      .height(44)
      .margin({ top: GSYSpacing.normalEdge })
      .alignItems(VerticalAlign.Center);
    }
    .id(this.rootId())
    .width('100%')
    .padding(GSYSpacing.normalEdge)
    .borderRadius(8)
    .backgroundColor(GSYColor.white);
  }
}

interface IssueDetailRouteParam {
  fullName: string;
  number: number;
}

const FALLBACK_FULL_NAME: string = '';
const FALLBACK_NUMBER: number = 0;

const HEADER_AVATAR_SIZE: number = GSYIconSize.big;
const COMMENT_AVATAR_SIZE: number = GSYIconSize.normal;
const COMMENT_CARD_RADIUS: number = 3;
const HEADER_NUMBER_GAP: number = 8;
const COMMENT_NAME_TIME_GAP: number = 4;
const COMMENT_BODY_GAP: number = 8;
const HEADER_BODY_GAP: number = 12;
const HEADER_DIVIDER_GAP: number = 12;
const HEADER_LABEL_GAP: number = 4;
const EMPTY_HEIGHT: number = 180;

@ComponentV2
export struct IssueDetailPage {
  @Local vm: IssueDetailViewModel = new IssueDetailViewModel();
  private pathStack: NavPathStack = new NavPathStack();

  private resolveParamFromStack(stack: NavPathStack): IssueDetailRouteParam | null {
    try {
      const all: string[] = stack.getAllPathName();
      if (all === undefined || all === null || all.length === 0) {
        return null;
      }
      const param: Object | undefined = stack.getParamByIndex(all.length - 1) as Object | undefined;
      if (param === undefined || param === null) {
        return null;
      }
      return param as IssueDetailRouteParam;
    } catch (_e) {
      return null;
    }
  }

  private async loadAll(): Promise<void> {
    await this.vm.loadAll();
  }

  private issueTitleForAppBar(): string {
    const title: string = this.vm.appBarTitle();
    return title.length > 0 ? title : I18n('reposIssue');
  }

  private resolveHtmlUrl(): string {
    const fullName: string = this.vm.targetFullName();
    const number: number = this.vm.targetNumber();
    if (fullName.length === 0 || number <= 0) {
      return '';
    }
    return 'https://github.com/' + fullName + '/issues/' + number.toString();
  }

  private showMoreMenu(): void {
    const htmlUrl: string = this.resolveHtmlUrl();
    const items: CommonOptionItem[] = [
      { itemName: I18n('browserOpen') } as CommonOptionItem,
      { itemName: I18n('copy') } as CommonOptionItem,
      { itemName: I18n('share') } as CommonOptionItem,
    ];
    CommonModal.options(
      { title: this.issueTitleForAppBar(), items: items },
      (index: number, _item: CommonOptionItem): void => {
        if (htmlUrl.length === 0) {
          return;
        }
        if (index === 0) {
          ExternalUrlUtil.openUrlInBrowser(this, htmlUrl, 'IssueDetailPage');
        } else if (index === 1) {
          this.copyToPasteboard(htmlUrl);
        } else if (index === 2) {
          ExternalUrlUtil.openUrlInBrowser(this, htmlUrl, 'IssueDetailPage');
        }
      }
    );
  }

  private buildRightActions(): AppBarAction[] {
    return [
      {
        iconKey: 'more',
        onAction: (): void => {
          this.showMoreMenu();
        },
      } as AppBarAction,
    ];
  }

  private renderIssueBody(value: string): string {
    const safe: string = value !== null && value !== undefined ? value : '';
    return renderEmoji(safe);
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

  private showErrorToast(msg: string): void {
    const safe: string = msg !== null && msg !== undefined && msg.length > 0 ? msg : I18n('errorUnKnow');
    CommonToast.showShort(safe);
  }

  private async runCreateComment(): Promise<void> {
    const res: IssueServiceResult<IssueCommentModel> = await this.vm.submitReply();
    if (!res.result) {
      this.showErrorToast(res.msg);
    }
  }

  private async runEditIssue(): Promise<void> {
    const res: IssueServiceResult<IssueDetailModel> = await this.vm.submitEditIssue();
    if (!res.result) {
      this.showErrorToast(res.msg);
    }
  }

  private async runEditComment(): Promise<void> {
    const res: IssueServiceResult<IssueCommentModel> = await this.vm.submitEditComment();
    if (!res.result) {
      this.showErrorToast(res.msg);
    }
  }

  private async runDeleteComment(): Promise<void> {
    const res: IssueServiceResult<boolean> = await this.vm.deleteSelectedComment();
    if (!res.result) {
      this.showErrorToast(res.msg);
    }
  }

  private toggleIssueState(): void {
    const isOpen: boolean = this.vm.isIssueOpen();
    const tip: string = isOpen ? I18n('closeIssueTip') : I18n('openIssueTip');
    Logger.i('issue/state', `confirm prepare isOpen=${isOpen}`);
    CommonModal.confirm({
      message: tip,
      okText: I18n('ok'),
      cancelText: I18n('cancel'),
    }, (): void => {
      this.runToggleIssueState(isOpen);
    });
  }

  private async runToggleIssueState(isOpen: boolean): Promise<void> {
    const res: IssueServiceResult<IssueDetailModel> = await this.vm.runToggleIssueState(isOpen);
    if (!res.result) {
      this.showErrorToast(res.msg);
    }
  }

  private onCommentMenuTap(): void {
    Logger.i('issue/comment', 'reply markdown dialog open');
    this.vm.openReplySheet();
  }

  private onEditMenuTap(): void {
    if (!this.vm.canEditIssue) {
      CommonToast.showShort(I18n('noPower'));
      return;
    }
    Logger.i('issue/edit', `markdown dialog open titleLen=${this.vm.editIssueTitleDraft.length}`
      + ` bodyLen=${this.vm.editIssueBodyDraft.length}`);
    this.vm.openEditIssueSheet();
  }

  private onLockMenuTap(): void {
    const isLocked: boolean = this.vm.isIssueLocked();
    const tip: string = isLocked ? I18n('unLockIssueTip') : I18n('lockIssueTip');
    Logger.i('issue/lock', `confirm prepare locked=${isLocked}`);
    CommonModal.confirm({
      message: tip,
      okText: I18n('ok'),
      cancelText: I18n('cancel'),
    }, (): void => {
      this.runToggleIssueLock(isLocked);
    });
  }

  private async runToggleIssueLock(currentLocked: boolean): Promise<void> {
    const res: IssueServiceResult<boolean> = await this.vm.runToggleIssueLock(currentLocked);
    if (!res.result) {
      this.showErrorToast(res.msg);
    }
  }

  private onCommentTap(item: IssueCommentModel, index: number): void {
    const canManage: boolean = this.vm.canManageComment(item);
    Logger.i('comment/tap', `index=${index} cid=${item.id} canManage=${canManage}`);
    if (!canManage) {
      return;
    }
    this.vm.selectComment(item, index);
    // 原生系统 ActionSheet（API 26 原生弹窗），替代自绘 IssueCommentOptionsDialog
    const opts: OptionListOptions = {
      items: [
        { itemName: I18n('issueCommentEdit') },
        { itemName: I18n('issueCommentDelete'), itemTextColor: GSYColor.issueClosedRed },
      ],
    };
    CommonModal.options(opts, (sel: number, _item: CommonOptionItem): void => {
      if (sel === 0) {
        Logger.i('comment/options', 'edit selected');
        this.vm.openEditCommentSheet();
      } else if (sel === 1) {
        Logger.i('comment/options', 'delete selected');
        CommonModal.confirm({
          message: I18n('issueCommentDelete'),
          okText: I18n('ok'),
          cancelText: I18n('cancel'),
        }, (): void => {
          this.runDeleteComment();
        });
      }
    });
  }

  private onCommentLongPress(item: IssueCommentModel, index: number): void {
    Logger.i('comment/longpress', `copy index=${index} cid=${item.id}`);
    this.copyToPasteboard(item.body !== null && item.body !== undefined ? item.body : '');
  }

  private buildBottomBarItems(): CommonBottomBarItem[] {
    const isOpen: boolean = this.vm.isIssueOpen();
    const isLocked: boolean = this.vm.isIssueLocked();
    const items: CommonBottomBarItem[] = [];

    const commentItem: CommonBottomBarItem = new CommonBottomBarItem();
    commentItem.itemName = I18n('issueComment');
    commentItem.icon = FA_COMMENT_O;
    commentItem.itemId = 'comment';
    commentItem.itemClick = (): void => {
      this.onCommentMenuTap();
    };
    if (this.vm.canReply) {
      items.push(commentItem);
    }

    const editItem: CommonBottomBarItem = new CommonBottomBarItem();
    editItem.itemName = I18n('editIssue');
    editItem.icon = FA_INFO_CIRCLE;
    editItem.itemId = 'edit';
    editItem.itemClick = (): void => {
      this.onEditMenuTap();
    };
    if (this.vm.canEditIssue) {
      items.push(editItem);
    }

    const stateItem: CommonBottomBarItem = new CommonBottomBarItem();
    stateItem.itemName = isOpen ? I18n('issueClose') : I18n('issueOpen');
    stateItem.icon = isOpen ? FA_CHECK : FA_PLUS;
    stateItem.iconColor = isOpen ? GSYColor.issueClosedRed : GSYColor.issueOpenGreen;
    stateItem.itemTextColor = isOpen ? GSYColor.issueClosedRed : GSYColor.issueOpenGreen;
    stateItem.itemId = 'state';
    stateItem.itemClick = (): void => {
      this.toggleIssueState();
    };
    if (this.vm.canOpenCloseIssue) {
      items.push(stateItem);
    }

    const lockItem: CommonBottomBarItem = new CommonBottomBarItem();
    lockItem.itemName = isLocked ? I18n('issueUnlock') : I18n('issueLocked');
    lockItem.icon = isLocked ? FA_UNLOCK : FA_LOCK;
    lockItem.itemId = 'lock';
    lockItem.itemClick = (): void => {
      this.onLockMenuTap();
    };
    if (this.vm.canLockUnlockIssue) {
      items.push(lockItem);
    }

    return items;
  }

  // ── 三组弹层 builder（bindSheet 内容，id 原样保留） ──────────────────────────

  @Builder
  replySheetBuilder(): void {
    IssueMarkdownEditSheet({
      sheetMode: SHEET_MODE_REPLY,
      dialogTitle: I18n('issueComment'),
      showTitleField: false,
      defaultTitle: '',
      defaultBody: this.vm.replyDraft,
      bodyPlaceholder: I18n('issueInputTip'),
      okText: I18n('ok'),
      cancelText: I18n('cancel'),
      onConfirm: (_title: string, body: string): void => {
        Logger.i('issue/comment', `reply onConfirm len=${body.length}`);
        this.vm.closeReplySheet();
        this.vm.replyDraft = body;
        this.runCreateComment();
      },
      onCancel: (): void => {
        Logger.i('issue/comment', 'reply onCancel');
        this.vm.closeReplySheet();
      },
    });
  }

  @Builder
  editIssueSheetBuilder(): void {
    IssueMarkdownEditSheet({
      sheetMode: SHEET_MODE_EDIT_ISSUE,
      dialogTitle: I18n('editIssue'),
      showTitleField: true,
      defaultTitle: this.vm.editIssueTitleDraft,
      defaultBody: this.vm.editIssueBodyDraft,
      titlePlaceholder: I18n('issueInputTitleTip'),
      bodyPlaceholder: I18n('issueInputTip'),
      okText: I18n('ok'),
      cancelText: I18n('cancel'),
      onConfirm: (title: string, body: string): void => {
        Logger.i('issue/edit', `onConfirm titleLen=${title.length} bodyLen=${body.length}`);
        this.vm.closeEditIssueSheet();
        this.vm.editIssueTitleDraft = title;
        this.vm.editIssueBodyDraft = body;
        this.runEditIssue();
      },
      onCancel: (): void => {
        Logger.i('issue/edit', 'onCancel');
        this.vm.closeEditIssueSheet();
      },
    });
  }

  @Builder
  editCommentSheetBuilder(): void {
    IssueMarkdownEditSheet({
      sheetMode: SHEET_MODE_EDIT_COMMENT,
      dialogTitle: I18n('issueCommentEdit'),
      showTitleField: false,
      defaultTitle: '',
      defaultBody: this.vm.editCommentDraft,
      bodyPlaceholder: I18n('issueInputTip'),
      okText: I18n('ok'),
      cancelText: I18n('cancel'),
      onConfirm: (_title: string, body: string): void => {
        Logger.i('comment/edit', `onConfirm len=${body.length}`);
        this.vm.closeEditCommentSheet();
        this.vm.editCommentDraft = body;
        this.runEditComment();
      },
      onCancel: (): void => {
        Logger.i('comment/edit', 'onCancel');
        this.vm.closeEditCommentSheet();
      },
    });
  }

  @Builder
  buildHeader(): void {
    Column() {
      if (this.vm.issue !== null) {
        Column() {
          Row() {
            Image((this.vm.issue as IssueDetailModel).user.avatar_url)
              .id('issue_detail_user_avatar')
              .width(HEADER_AVATAR_SIZE)
              .height(HEADER_AVATAR_SIZE)
              .borderRadius(HEADER_AVATAR_SIZE / 2)
              .objectFit(ImageFit.Cover);

            Column() {
              Row() {
                Text((this.vm.issue as IssueDetailModel).state === ISSUE_STATE_OPEN
                  ? I18n('issueOpenText') : I18n('issueCloseText'))
                  .id('issue_detail_state')
                  .fontSize(GSYFontSize.min)
                  .fontWeight(FontWeight.Bold)
                  .fontColor((this.vm.issue as IssueDetailModel).state === ISSUE_STATE_OPEN
                    ? GSYColor.issueOpenGreen : GSYColor.issueClosedRed)
                  .padding({
                    left: 0,
                    right: GSYSpacing.halfEdge,
                    top: 0,
                    bottom: 0,
                  })
                  .margin({ left: 0 });

                Text('#' + (this.vm.issue as IssueDetailModel).number.toString())
                  .id('issue_detail_number')
                  .fontSize(GSYFontSize.small)
                  .fontColor(GSYColor.mediumText)
                  .margin({ left: HEADER_NUMBER_GAP });

                Text(I18n('issueComment') + '(' + (this.vm.issue as IssueDetailModel).comments.toString() + ')')
                  .id('issue_detail_comment_count')
                  .fontSize(GSYFontSize.small)
                  .fontColor(GSYColor.mediumText)
                  .margin({ left: HEADER_NUMBER_GAP });
              }
              .alignItems(VerticalAlign.Center);

              Text((this.vm.issue as IssueDetailModel).user.login)
                .id('issue_detail_user_login')
                .fontSize(GSYFontSize.small)
                .fontWeight(FontWeight.Bold)
                .fontColor(GSYColor.mainText)
                .margin({ top: COMMENT_NAME_TIME_GAP });
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: GSYSpacing.normalEdge })
            .layoutWeight(1);

            Text(TimeUtil.resolveTime((this.vm.issue as IssueDetailModel).created_at))
              .id('issue_detail_created_time')
              .fontSize(GSYFontSize.min)
              .fontColor(GSYColor.mediumText);
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);

          Text((this.vm.issue as IssueDetailModel).title)
            .id('issue_detail_title')
            .fontSize(GSYFontSize.normal)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.mainText)
            .width('100%')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: GSYSpacing.normalEdge });

          MarkdownText({
            markdown: this.renderIssueBody((this.vm.issue as IssueDetailModel).body),
            rootId: 'issue_detail_body_html',
            textColor: GSYColor.mainText,
            textFontSize: GSYFontSize.small,
          })
            .margin({ top: HEADER_BODY_GAP });
        }
        .id('issue_detail_head_card')
        .width('auto')
        .margin({
          left: GSYSpacing.halfEdge,
          right: GSYSpacing.halfEdge,
          top: GSYSpacing.halfEdge,
          bottom: GSYSpacing.halfEdge,
        })
        .padding({
          left: GSYSpacing.normalEdge,
          right: GSYSpacing.normalEdge,
          top: GSYSpacing.normalEdge,
          bottom: GSYSpacing.normalEdge,
        })
        .borderRadius(8)
        .backgroundColor(GSYColor.cardBackground)
        .shadow({
          radius: GSYShadow.radius,
          color: GSYShadow.cardShadowAlpha,
          offsetX: 0,
          offsetY: GSYShadow.elevation,
        })
        .alignItems(HorizontalAlign.Start);
      } else {
        Text(this.vm.errorMessage.length > 0 ? this.vm.errorMessage : I18n('loading'))
          .id('issue_detail_loading_text')
          .fontSize(GSYFontSize.small)
          .fontColor(GSYColor.subText)
          .padding({
            left: GSYSpacing.normalEdge,
            right: GSYSpacing.normalEdge,
            top: GSYSpacing.normalEdge,
            bottom: GSYSpacing.normalEdge,
          });
      }

      Divider()
        .id('issue_detail_header_divider')
        .strokeWidth(1)
        .color(GSYColor.lightDivider)
        .margin({ top: HEADER_DIVIDER_GAP, bottom: HEADER_LABEL_GAP });

      Text(I18n('issueComment') + ' (' + this.vm.comments.length.toString() + ')')
        .id('issue_detail_comments_label')
        .fontSize(GSYFontSize.small)
        .fontColor(GSYColor.subText)
        .margin({
          left: GSYSpacing.normalEdge,
          top: HEADER_LABEL_GAP,
          bottom: HEADER_LABEL_GAP,
        });
    }
    .id('issue_detail_header_root')
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  buildCommentRow(item: IssueCommentModel, index: number): void {
    Column() {
      Row() {
        Image(item.user.avatar_url)
          .id('issue_comment_avatar_' + index.toString())
          .width(COMMENT_AVATAR_SIZE)
          .height(COMMENT_AVATAR_SIZE)
          .borderRadius(COMMENT_AVATAR_SIZE / 2)
          .objectFit(ImageFit.Cover);
        Column() {
          Text(item.user.login)
            .id('issue_comment_user_' + index.toString())
            .fontSize(GSYFontSize.small)
            .fontColor(GSYColor.actionBlue)
            .fontWeight(FontWeight.Bold);
          Text(TimeUtil.resolveTime(item.created_at))
            .id('issue_comment_time_' + index.toString())
            .fontSize(GSYFontSize.min)
            .fontColor(GSYColor.subText)
            .margin({ top: COMMENT_NAME_TIME_GAP });
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: GSYSpacing.normalEdge })
        .layoutWeight(1);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      MarkdownText({
        markdown: this.renderIssueBody(item.body),
        rootId: 'issue_comment_body_' + index.toString(),
        textColor: GSYColor.mainText,
        textFontSize: GSYFontSize.small,
      })
        .margin({ top: COMMENT_BODY_GAP });
    }
    .id('issue_comment_row_' + index.toString())
    .width('100%')
    .padding({
      left: GSYSpacing.normalEdge,
      right: GSYSpacing.normalEdge,
      top: GSYSpacing.normalEdge,
      bottom: GSYSpacing.normalEdge,
    })
    .margin({
      left: GSYSpacing.halfEdge,
      right: GSYSpacing.halfEdge,
      top: GSYSpacing.halfEdge,
      bottom: GSYSpacing.halfEdge,
    })
    .borderRadius(COMMENT_CARD_RADIUS)
    .backgroundColor(GSYColor.cardBackground)
    .shadow({
      radius: GSYShadow.radius,
      color: GSYShadow.cardShadowAlpha,
      offsetX: 0,
      offsetY: GSYShadow.elevation,
    })
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        TapGesture({ count: 1 })
          .onAction((_event: GestureEvent): void => {
            this.onCommentTap(item, index);
          }),
        LongPressGesture({ repeat: false })
        .onAction((_e: GestureEvent): void => {
          this.onCommentLongPress(item, index);
        })
      )
    )
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  buildEmpty(): void {
    Column() {
      Text(I18n('listEmpty'))
        .id('issue_detail_empty_text')
        .fontSize(GSYFontSize.small)
        .fontColor(GSYColor.subText);
    }
    .id('issue_detail_empty_root')
    .width('100%')
    .height(EMPTY_HEIGHT)
    .justifyContent(FlexAlign.Center);
  }

  build(): void {
    NavDestination() {
      Column() {
        Column() {
          AppBar({
            title: this.issueTitleForAppBar(),
            titleStart: true,
            showBack: true,
            rightActions: this.buildRightActions(),
            onBack: (): void => {
              NavigationService.pop();
            },
          })
            .id('issue_detail_appbar');

          PullLoadMoreList({
            dataSource: this.vm.comments as Object[],
            refreshing: this.vm.commentRefreshing,
            loadingMore: this.vm.commentLoadingMore,
            noMore: this.vm.commentNoMore,
            renderRow: (item: Object, index: number): void =>
              this.buildCommentRow(item as IssueCommentModel, index),
            renderHeader: (): void => this.buildHeader(),
            renderEmpty: (): void => this.buildEmpty(),
            onRefresh: (): void => {
              this.vm.refreshComments();
            },
            onLoadMore: (): void => {
              this.vm.loadMoreComments();
            },
          })
            .id('issue_detail_pull_list')
            .layoutWeight(1);

          if (this.vm.shouldShowBottomBar()) {
            CommonBottomBar({
              dataList: this.buildBottomBarItems(),
              rootId: 'issue_detail_bottom_bar',
            })
              .id('issue_detail_bottom_bar_wrap');
          }
        }
        .id('issue_detail_root')
        .width('100%')
        .height('100%')
        .backgroundColor(GSYColor.mainBackground)
        // bindSheet 单节点只能挂一个弹层，回复弹层挂页面根，编辑 issue / 编辑评论
        // 弹层分别挂两个 0 高锚点（DrawerMenu 同款）。
        .bindSheet(this.vm.replySheetOpen, this.replySheetBuilder(), {
          height: REPLY_SHEET_HEIGHT,
          dragBar: false,
          showClose: false,
          backgroundColor: GSYColor.white,
        });

        Row()
          .width(0)
          .height(0)
          .bindSheet(this.vm.editIssueSheetOpen, this.editIssueSheetBuilder(), {
            height: EDIT_ISSUE_SHEET_HEIGHT,
            dragBar: false,
            showClose: false,
            backgroundColor: GSYColor.white,
          });

        Row()
          .width(0)
          .height(0)
          .bindSheet(this.vm.editCommentSheetOpen, this.editCommentSheetBuilder(), {
            height: EDIT_COMMENT_SHEET_HEIGHT,
            dragBar: false,
            showClose: false,
            backgroundColor: GSYColor.white,
          });
      }
      .width('100%')
      .height('100%');
    }
    .onReady((ctx: NavDestinationContext): void => {
      const stack: NavPathStack | undefined = ctx.pathStack;
      if (stack !== undefined && stack !== null) {
        this.pathStack = stack;
      }
      let fullName: string = FALLBACK_FULL_NAME;
      let issueNumber: number = FALLBACK_NUMBER;
      // 优先级 1：RouteParamStore（NavigationService.push 同步写入，覆盖所有 push 入口）
      const routeRaw: Object | null = RouteParamStore.consume(RouteName.IssueDetail);
      if (routeRaw !== null) {
        const routeParam: IssueDetailRouteParam = routeRaw as IssueDetailRouteParam;
        let adopted: boolean = false;
        if (routeParam.fullName !== undefined && routeParam.fullName !== null && routeParam.fullName.length > 0) {
          fullName = routeParam.fullName;
          adopted = true;
        }
        if (routeParam.number !== undefined && routeParam.number !== null && routeParam.number > 0) {
          issueNumber = routeParam.number;
          adopted = true;
        }
        if (adopted) {
          Logger.i('issue/route', `IssueDetailPage adopted via RouteParamStore fullName=${fullName} number=${issueNumber}`);
          this.vm.setTarget(fullName, issueNumber);
          this.loadAll();
          return;
        }
      }
      let param: IssueDetailRouteParam | null = null;
      try {
        const info: NavPathInfo | undefined = ctx.pathInfo;
        if (info !== undefined && info !== null && info.param !== undefined && info.param !== null) {
          param = info.param as IssueDetailRouteParam;
        }
      } catch (_e) {
        param = null;
      }
      if (param === null && stack !== undefined && stack !== null) {
        param = this.resolveParamFromStack(stack);
      }
      if (param !== null) {
        if (param.fullName !== undefined && param.fullName !== null && param.fullName.length > 0) {
          fullName = param.fullName;
        }
        if (param.number !== undefined && param.number !== null && param.number > 0) {
          issueNumber = param.number;
        }
      }
      // KI-045 同款：BOOT_ISSUE_KEY 旁路优先级最高（NavDestination 复用时
      // 上一次的 fullName/number 还在状态里，需要 BOOT 强制覆盖）。
      const boot: string = BootChannel.get(BOOT_ISSUE_KEY);
      const raw: string = boot.trim();
      if (raw.length > 0) {
        const sep: number = raw.indexOf('|');
        if (sep > 0 && sep < raw.length - 1) {
          const fn: string = raw.substring(0, sep);
          const numStr: string = raw.substring(sep + 1);
          const n: number = parseInt(numStr, 10);
          if (!isNaN(n) && n > 0) {
            fullName = fn;
            issueNumber = n;
            Logger.i('boot/ts', `IssueDetailPage.onReady bootKey-priority fullName='${fullName}' number=${issueNumber}`);
          }
        }
      }
      this.vm.setTarget(fullName, issueNumber);
      this.loadAll();
    });
  }
}
