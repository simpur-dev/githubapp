import { I18n } from 'common';
import router from '@ohos.router';
import pasteboard from '@ohos.pasteboard';

import { NavigationService } from 'common';
import { RouteName } from 'common';
import { RouteParamStore } from 'common';
import { BOOT_REPO_KEY, BootChannel } from 'common';
import { AppBar, AppBarAction } from 'common';
import { CommonToast } from 'common';
import { CommonModal, CommonOptionItem } from 'common';
import { LoadingModal } from 'common';
import { Logger } from 'common';
import {
  RepositoryFileItem,
  RepositoryIssueItem,
  RepositoryServiceResult
} from 'common';
import { ReadmeTab } from './repo/ReadmeTab';
import { IssueTab } from './repo/IssueTab';
import { ActivityTab } from './repo/ActivityTab';
import { FilesTab, isImageOrArchiveFile } from './repo/FilesTab';
import { ExternalUrlUtil } from 'common';
import { GSYColor, GSYFontSize, GSYSpacing } from 'common';
import { CommonBottomBar, CommonBottomBarItem } from 'common';
import {
  FA_STAR,
  FA_STAR_O,
  FA_EYE,
  FA_EYE_SLASH,
  FA_CODE_FORK,
  FA_CHEVRON_DOWN,
  FA_PLUS,
  IconFont,
} from 'common';
import { RepositoryDetailViewModel } from './viewmodel/RepositoryDetailViewModel';

interface RepositoryDetailRouteParam {
  fullName?: string;
  owner?: string;
  name?: string;
  reposOwner?: string;
  reposName?: string;
  ownerName?: string;
  repositoryName?: string;
}

interface RepoTabItem {
  key: string;
  title: string;
  index: number;
}

interface CommonListRouteParam {
  dataType: string;
  showType: string;
  currentUser: string;
  repoName: string;
  title: string;
}

const FALLBACK_FULL_NAME: string = '';
const TAB_BAR_HEIGHT: number = 48;
const BRANCH_MENU_WIDTH: number = 220;
const BRANCH_MENU_MAX_HEIGHT: number = 300;
const CREATE_ISSUE_SHEET_HEIGHT: number = 520;
const COMMON_LIST_SHOW_TYPE_USER: string = 'user';
const COMMON_LIST_SHOW_TYPE_REPOSITORY: string = 'repository';

/**
 * 创建 Issue 弹层内容（V2）。旧版经 common 的 @CustomDialog CreateIssueDialog +
 * CustomDialogController 呈现（V2 组件不可用），本轮保持内容结构原样迁为
 * @ComponentV2 + bindSheet 呈现，全部 create_issue_* 测试 id 原样保留。
 */
@ComponentV2
struct RepoCreateIssueSheet {
  @Param dialogTitle: string = '';
  @Param titlePlaceholder: string = '';
  @Param bodyPlaceholder: string = '';
  @Event onConfirm: (title: string, body: string) => void = (_t: string, _b: string): void => {};
  @Event onCancel: () => void = (): void => {};
  @Local titleText: string = '';
  @Local bodyText: string = '';

  private appendMarkdown(insertion: string): void {
    this.bodyText = this.bodyText + insertion;
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
      Text(this.dialogTitle)
        .id('create_issue_dialog_title')
        .fontSize(GSYFontSize.middleNormal)
        .fontWeight(FontWeight.Bold)
        .fontColor(GSYColor.primary)
        .margin({ bottom: GSYSpacing.normalEdge });

      TextInput({ placeholder: this.titlePlaceholder, text: this.titleText })
        .id('create_issue_dialog_title_input')
        .fontSize(GSYFontSize.normal)
        .fontColor(GSYColor.primary)
        .placeholderColor(GSYColor.subText)
        .backgroundColor(GSYColor.surfaceSubtle)
        .borderRadius(4)
        .height(40)
        .padding({ left: GSYSpacing.halfEdge, right: GSYSpacing.halfEdge })
        .onChange((value: string): void => {
          this.titleText = value;
        });

      TextArea({ placeholder: this.bodyPlaceholder, text: this.bodyText })
        .id('create_issue_dialog_body_input')
        .fontSize(GSYFontSize.small)
        .fontColor(GSYColor.primary)
        .placeholderColor(GSYColor.subText)
        .backgroundColor(GSYColor.surfaceSubtle)
        .borderRadius(4)
        .height(200)
        .margin({ top: GSYSpacing.normalEdge })
        .padding(GSYSpacing.halfEdge)
        .onChange((value: string): void => {
          this.bodyText = value;
        });

      Scroll() {
        Row() {
          this.buildMarkdownAction('create_issue_markdown_toolbar_h1', 'H1', '# ');
          this.buildMarkdownAction('create_issue_markdown_toolbar_h2', 'H2', '## ');
          this.buildMarkdownAction('create_issue_markdown_toolbar_h3', 'H3', '### ');
          this.buildMarkdownAction('create_issue_markdown_toolbar_bold', 'B', '****');
          this.buildMarkdownAction('create_issue_markdown_toolbar_italic', 'I', '**');
          this.buildMarkdownAction('create_issue_markdown_toolbar_ul', 'UL', '- ');
          this.buildMarkdownAction('create_issue_markdown_toolbar_quote', 'Quote', '> ');
          this.buildMarkdownAction('create_issue_markdown_toolbar_code', 'Code', '``');
          this.buildMarkdownAction('create_issue_markdown_toolbar_image', 'IMG', '![]()');
          this.buildMarkdownAction('create_issue_markdown_toolbar_link', 'Link', '[]()');
        }
        .id('create_issue_markdown_toolbar')
        .height(36)
        .alignItems(VerticalAlign.Center);
      }
      .width('100%')
      .height(40)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .margin({ top: GSYSpacing.halfEdge });

      Row() {
        Button(I18n('cancel'))
          .id('create_issue_dialog_cancel')
          .fontSize(GSYFontSize.normal)
          .fontColor(GSYColor.subText)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .onClick((): void => {
            this.onCancel();
          });
        Button(I18n('ok'))
          .id('create_issue_dialog_confirm')
          .fontSize(GSYFontSize.normal)
          .fontColor(GSYColor.miWhite)
          .backgroundColor(GSYColor.primary)
          .layoutWeight(1)
          .margin({ left: GSYSpacing.normalEdge })
          .onClick((): void => {
            const t: string = this.titleText.trim();
            if (t.length === 0) {
              return;
            }
            this.onConfirm(t, this.bodyText);
          });
      }
      .width('100%')
      .margin({ top: GSYSpacing.normalEdge });
    }
    .id('create_issue_dialog_root')
    .width('100%')
    .padding(GSYSpacing.normalEdge)
    .backgroundColor(GSYColor.white)
    .borderRadius(8);
  }
}

@ComponentV2
export struct RepositoryDetailPage {
  @Local vm: RepositoryDetailViewModel = new RepositoryDetailViewModel();
  @Local currentIndex: number = 0;
  @Local branchMenuVisible: boolean = false;
  @Local createIssueSheetOpen: boolean = false;
  private tabsController: TabsController = new TabsController();
  private pathStack: NavPathStack = new NavPathStack();

  private tabs: RepoTabItem[] = [
    { key: 'info', title: I18n('reposActivity'), index: 0 },
    { key: 'readme', title: I18n('reposReadme'), index: 1 },
    { key: 'issue', title: I18n('reposIssue'), index: 2 },
    { key: 'file', title: I18n('reposFile'), index: 3 },
  ];

  aboutToAppear(): void {
    this.applyRouterParams();
    Logger.i('boot/ts', `RepositoryDetailPage.aboutToAppear t=${Date.now()} fullName='${this.vm.fullName}'`);
    if (this.vm.fullName.length > 0) {
      this.loadAll();
    }
  }

  private resolveFullNameFromObject(raw: Object | undefined | null): string {
    if (raw === undefined || raw === null) {
      return FALLBACK_FULL_NAME;
    }
    const obj: RepositoryDetailRouteParam = raw as RepositoryDetailRouteParam;
    if (obj.fullName !== undefined && obj.fullName !== null && obj.fullName.length > 0) {
      return obj.fullName;
    }
    const owner: string = (obj.owner !== undefined && obj.owner !== null && obj.owner.length > 0)
      ? obj.owner
      : ((obj.reposOwner !== undefined && obj.reposOwner !== null && obj.reposOwner.length > 0)
        ? obj.reposOwner
        : ((obj.ownerName !== undefined && obj.ownerName !== null) ? obj.ownerName : ''));
    const name: string = (obj.name !== undefined && obj.name !== null && obj.name.length > 0)
      ? obj.name
      : ((obj.reposName !== undefined && obj.reposName !== null && obj.reposName.length > 0)
        ? obj.reposName
        : ((obj.repositoryName !== undefined && obj.repositoryName !== null) ? obj.repositoryName : ''));
    if (owner.length > 0 && name.length > 0) {
      return owner + '/' + name;
    }
    return FALLBACK_FULL_NAME;
  }

  private applyRouterParams(): void {
    // 优先级 1：RouteParamStore（NavigationService.push 同步写入，覆盖所有 push 入口）
    const routeRaw: Object | null = RouteParamStore.consume(RouteName.RepositoryDetail);
    if (routeRaw !== null) {
      const resolvedFromRoute: string = this.resolveFullNameFromObject(routeRaw);
      if (resolvedFromRoute.length > 0) {
        this.vm.setFullName(resolvedFromRoute);
        Logger.i('repo/route', `RepositoryDetailPage adopted via RouteParamStore fullName=${resolvedFromRoute}`);
        return;
      }
    }
    try {
      const raw: Object | undefined = router.getParams() as Object | undefined;
      const resolved: string = this.resolveFullNameFromObject(raw === undefined ? null : raw);
      if (resolved.length > 0) {
        this.vm.setFullName(resolved);
        return;
      }
    } catch (_e) {
    }
    if (this.vm.fullName.length === 0) {
      const bootRepo: string = BootChannel.get(BOOT_REPO_KEY);
      if (bootRepo.length > 0) {
        this.vm.setFullName(bootRepo);
      }
    }
  }

  private resolveFullNameFromStack(stack: NavPathStack): string {
    try {
      const all: string[] = stack.getAllPathName();
      if (all === undefined || all === null || all.length === 0) {
        return FALLBACK_FULL_NAME;
      }
      const param: Object | undefined = stack.getParamByIndex(all.length - 1) as Object | undefined;
      return this.resolveFullNameFromObject(param === undefined ? null : param);
    } catch (_e) {
      return FALLBACK_FULL_NAME;
    }
  }

  private async loadAll(): Promise<void> {
    if (this.vm.fullName.length === 0) {
      return;
    }
    // 首次进入要让用户看到"正在加载"——这一批请求里 README 最慢，
    // 之前没有任何加载提示导致整个详情页空白十几秒。LoadingModal 全屏遮罩 + 自动 hide。
    LoadingModal.show(I18n('loading'), false);
    try {
      await this.vm.loadAll();
    } finally {
      LoadingModal.hide();
    }
    // 分支菜单改为原生受控 bindMenu：点按钮即刻弹层，提前拉一次分支列表，
    // 避免用户点开时菜单里 branches 还是空的（失败静默，点开时再走 ensureBranchesLoaded）。
    this.vm.ensureBranchesLoaded().catch((_err: Error): void => {});
  }

  private openCreateIssueSheet(): void {
    this.createIssueSheetOpen = true;
  }

  private async submitCreateIssue(title: string, body: string): Promise<void> {
    if (this.vm.fullName.length === 0) {
      return;
    }
    // 创建 Issue 编排（含「插到列表头部」）已收敛到 IssueTabViewModel。
    const res: RepositoryServiceResult<RepositoryIssueItem | null> =
      await this.vm.issueTab.createIssue(title, body);
    if (res.result) {
      CommonToast.showShort(I18n('createIssue'));
    } else {
      const msg: string = (res.msg !== null && res.msg !== undefined && res.msg.length > 0)
        ? res.msg : I18n('netError');
      CommonToast.showShort(msg);
    }
  }

  private async refreshFiles(path: string): Promise<void> {
    await this.vm.refreshFiles(path);
  }

  private async openFile(item: RepositoryFileItem): Promise<void> {
    if (item.type === 'dir') {
      await this.vm.openDir(item.path);
      return;
    }
    // Compose FileItem 对图片和压缩包禁用点击，其余文件进入 CodeDetail。
    if (isImageOrArchiveFile(item.name)) {
      return;
    }
    const branch: string = this.vm.currentBranchName();
    Logger.i('FilesTab', `openFile push CodeDetail fullName=${this.vm.fullName}`
      + ` branch=${branch} path=${item.path}`);
    const codeParam: Record<string, Object> = {
      'fullName': this.vm.fullName,
      'branch': branch,
      'path': item.path,
    };
    NavigationService.push(RouteName.CodeDetail, codeParam as Object);
  }

  private async backFiles(): Promise<void> {
    await this.vm.backFiles();
  }

  private async toggleStar(): Promise<void> {
    if (this.vm.fullName.length === 0) {
      return;
    }
    LoadingModal.show(I18n('loading'), false);
    let res: RepositoryServiceResult<boolean>;
    try {
      res = await this.vm.toggleStar();
    } finally {
      LoadingModal.hide();
    }
    if (res.result) {
      CommonToast.showShort(this.vm.starred ? I18n('reposStar') : I18n('reposUnStar'));
    } else {
      const msg: string = (res.msg !== null && res.msg !== undefined && res.msg.length > 0)
        ? res.msg : I18n('netError');
      CommonToast.showShort(msg);
    }
  }

  private async toggleWatch(): Promise<void> {
    if (this.vm.fullName.length === 0) {
      return;
    }
    LoadingModal.show(I18n('loading'), false);
    let res: RepositoryServiceResult<boolean>;
    try {
      res = await this.vm.toggleWatch();
    } finally {
      LoadingModal.hide();
    }
    if (res.result) {
      CommonToast.showShort(this.vm.watching ? I18n('reposWatcher') : I18n('reposUnWatcher'));
    } else {
      const msg: string = (res.msg !== null && res.msg !== undefined && res.msg.length > 0)
        ? res.msg : I18n('netError');
      CommonToast.showShort(msg);
    }
  }

  private async doFork(): Promise<void> {
    if (this.vm.fullName.length === 0) {
      return;
    }
    LoadingModal.show(I18n('loading'), false);
    let res: RepositoryServiceResult<boolean>;
    try {
      res = await this.vm.doFork();
    } finally {
      LoadingModal.hide();
    }
    if (!res.result) {
      CommonToast.showShort(I18n('netError'));
    }
  }

  private async openBranchSelector(): Promise<void> {
    if (this.vm.fullName.length === 0) {
      return;
    }
    if (this.vm.branches.length === 0) {
      LoadingModal.show(I18n('loading'), false);
      try {
        const ok: boolean = await this.vm.ensureBranchesLoaded();
        if (!ok) {
          CommonToast.showShort(I18n('netError'));
          return;
        }
      } finally {
        LoadingModal.hide();
      }
    }
    const list: string[] = this.vm.branches;
    if (list.length === 0) {
      CommonToast.showShort(I18n('netError'));
      return;
    }
    if (list.length === 1) {
      await this.handleBranchChange(list[0]);
      return;
    }
    this.branchMenuVisible = true;
  }

  private async handleBranchChange(branch: string): Promise<void> {
    this.branchMenuVisible = false;
    LoadingModal.show(I18n('loading'), false);
    try {
      await this.vm.applyBranchChange(branch);
    } finally {
      LoadingModal.hide();
    }
    CommonToast.showShort(branch);
  }

  private handleTabTap(index: number): void {
    this.currentIndex = index;
    this.tabsController.changeIndex(index);
  }

  private buildAppBarTitle(): string {
    if (this.vm.fullName.length > 0) {
      return this.vm.fullName;
    }
    return '';
  }

  private resolveHtmlUrl(): string {
    return this.vm.htmlUrl();
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
      { title: this.vm.fullName, items: items },
      (index: number, _item: CommonOptionItem): void => {
        if (htmlUrl.length === 0) {
          return;
        }
        if (index === 0) {
          ExternalUrlUtil.openUrlInBrowser(this.getUIContext().getHostContext(), htmlUrl, 'RepositoryDetailPage');
        } else if (index === 1) {
          this.copyToPasteboard(htmlUrl);
        } else if (index === 2) {
          ExternalUrlUtil.openUrlInBrowser(this.getUIContext().getHostContext(), htmlUrl, 'RepositoryDetailPage');
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

  private openRepositoryCommonList(dataType: string, showType: string, titlePrefix: string): void {
    const owner: string = this.vm.ownerName();
    const repo: string = this.vm.repositoryName();
    if (owner.length === 0 || repo.length === 0) {
      Logger.w('RepositoryDetailPage', 'openRepositoryCommonList skipped, fullName=' + this.vm.fullName + ' type=' + dataType);
      return;
    }
    const param: CommonListRouteParam = {
      dataType: dataType,
      showType: showType,
      currentUser: owner,
      repoName: repo,
      title: repo + ' ' + titlePrefix,
    };
    Logger.i('RepositoryDetailPage', 'openRepositoryCommonList type=' + dataType + ' owner=' + owner + ' repo=' + repo);
    NavigationService.push(RouteName.CommonList, param as Object);
  }

  private openTopicList(topic: string): void {
    const safeTopic: string = topic !== null && topic !== undefined ? topic.trim() : '';
    if (safeTopic.length === 0) {
      return;
    }
    const param: CommonListRouteParam = {
      dataType: 'topics',
      showType: COMMON_LIST_SHOW_TYPE_REPOSITORY,
      currentUser: safeTopic,
      repoName: '',
      title: I18n('listTopics').replace('%s', safeTopic),
    } as CommonListRouteParam;
    Logger.i('RepositoryDetailPage', 'openTopicList topic=' + safeTopic);
    NavigationService.push(RouteName.CommonList, param as Object);
  }

  /**
   * 分支菜单弹层内容：经受控 bindMenu(isShow, builder, options) 挂在
   * common_bottom_bar_item_branch 上（原生 Menu 弹层，遮罩/定位/关闭交给系统）。
   * repo_branch_menu_overlay / repo_branch_menu_scrim 两层仅保留 id 供
   * scenario-tour.sh 场景 35 断言使用，无遮罩与点击语义。
   */
  @Builder
  buildBranchMenuContent(): void {
    Column() {
      Column() {
        Scroll() {
          Column() {
            Repeat<string>(this.vm.branches)
              .each((obj: RepeatItem<string>): void => {
                Row() {
                  Text(obj.item)
                    .id('repo_branch_menu_item_text_' + obj.index.toString())
                    .fontSize(GSYFontSize.small)
                    .fontColor(GSYColor.primary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1);
                }
                .id('repo_branch_menu_item_' + obj.index.toString())
                .width('100%')
                .height(44)
                .padding({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge })
                .alignItems(VerticalAlign.Center)
                .onClick((): void => {
                  this.handleBranchChange(obj.item);
                });
                if (obj.index < this.vm.branches.length - 1) {
                  Divider().color(GSYColor.line).strokeWidth(0.5);
                }
              })
              .key((branch: string, index: number): string => index.toString() + ':' + branch);
          }
          .width('100%');
        }
        .id('repo_branch_menu_root')
        .width(BRANCH_MENU_WIDTH)
        .constraintSize({ maxHeight: BRANCH_MENU_MAX_HEIGHT })
        .backgroundColor(GSYColor.hdsMaterialSurface)
        .border({
          width: 0.5,
          color: GSYColor.hdsMaterialBorder,
        })
        .borderRadius(12);
      }
      .id('repo_branch_menu_scrim');
    }
    .id('repo_branch_menu_overlay');
  }

  @Builder
  buildTabBar(item: RepoTabItem): void {
    Column() {
      Text(item.title)
        .fontSize(GSYFontSize.small)
        .fontColor(this.currentIndex === item.index ? GSYColor.primary : GSYColor.subText)
        .fontWeight(this.currentIndex === item.index ? FontWeight.Bold : FontWeight.Normal)
        .layoutWeight(1);
      Divider()
        .strokeWidth(GSYSpacing.tabIndicatorThickness)
        .color(this.currentIndex === item.index ? GSYColor.primary : Color.Transparent)
        .width('100%');
    }
    .id('repo_detail_tab_bar_' + item.key)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(HorizontalAlign.Center)
    .onClick((): void => {
      this.handleTabTap(item.index);
    });
  }

  @Builder
  buildCreateIssueFab(): void {
    Row() {
      IconFont({
        char: FA_PLUS,
        glyphSize: GSYFontSize.middleWhite,
        glyphColor: GSYColor.miWhite,
      });
    }
    .id('repo_detail_create_issue_fab')
    .width(GSYSpacing.tabBarHeight)
    .height(GSYSpacing.tabBarHeight)
    .borderRadius(GSYSpacing.tabBarHeight / 2)
    .backgroundColor(GSYColor.primary)
    .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
    .border({
      width: 0.5,
      color: GSYColor.hdsMaterialBorder,
    })
    .shadow({
      radius: 14,
      color: GSYColor.hdsMaterialShadow,
      offsetX: 0,
      offsetY: 4,
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .margin({
      right: GSYSpacing.normalEdge,
      bottom: GSYSpacing.normalEdge,
    })
    .onClick((): void => {
      this.openCreateIssueSheet();
    });
  }

  @Builder
  buildCreateIssueSheet(): void {
    RepoCreateIssueSheet({
      dialogTitle: I18n('createIssue'),
      titlePlaceholder: I18n('issueInputTipTitle'),
      bodyPlaceholder: I18n('issueInputTip'),
      onConfirm: (title: string, body: string): void => {
        this.createIssueSheetOpen = false;
        this.submitCreateIssue(title, body);
      },
      onCancel: (): void => {
        this.createIssueSheetOpen = false;
      },
    });
  }

  private buildBottomBarItems(): CommonBottomBarItem[] {
    const items: CommonBottomBarItem[] = [];

    const starItem: CommonBottomBarItem = new CommonBottomBarItem();
    starItem.itemId = 'star';
    starItem.itemName = this.vm.starred ? I18n('reposUnStar') : I18n('reposStar');
    starItem.icon = this.vm.starred ? FA_STAR : FA_STAR_O;
    starItem.iconColor = GSYColor.primary;
    starItem.itemTextColor = GSYColor.primary;
    starItem.itemClick = (): void => {
      this.toggleStar();
    };
    items.push(starItem);

    const watchItem: CommonBottomBarItem = new CommonBottomBarItem();
    watchItem.itemId = 'watch';
    watchItem.itemName = this.vm.watching ? I18n('reposUnWatcher') : I18n('reposWatcher');
    watchItem.icon = this.vm.watching ? FA_EYE_SLASH : FA_EYE;
    watchItem.iconColor = GSYColor.primary;
    watchItem.itemTextColor = GSYColor.primary;
    watchItem.itemClick = (): void => {
      this.toggleWatch();
    };
    items.push(watchItem);

    const forkItem: CommonBottomBarItem = new CommonBottomBarItem();
    forkItem.itemId = 'fork';
    forkItem.itemName = I18n('reposFork');
    forkItem.icon = FA_CODE_FORK;
    forkItem.iconColor = GSYColor.primary;
    forkItem.itemTextColor = GSYColor.primary;
    forkItem.itemClick = (): void => {
      this.doFork();
    };
    items.push(forkItem);

    const branchItem: CommonBottomBarItem = new CommonBottomBarItem();
    branchItem.itemId = 'branch';
    branchItem.itemName = this.vm.currentBranchName();
    branchItem.icon = FA_CHEVRON_DOWN;
    branchItem.iconColor = GSYColor.primary;
    branchItem.itemTextColor = GSYColor.primary;
    branchItem.itemClick = (): void => {
      this.openBranchSelector();
    };
    items.push(branchItem);

    return items;
  }

  build(): void {
    NavDestination() {
      Column() {
        AppBar({
          title: this.buildAppBarTitle(),
          titleStart: true,
          showBack: true,
          rightActions: this.buildRightActions(),
          onBack: (): void => {
            NavigationService.pop();
          },
        });
        Stack({ alignContent: Alignment.BottomEnd }) {
          Tabs({
            barPosition: BarPosition.Start,
            index: this.currentIndex,
            controller: this.tabsController,
          }) {
            TabContent() {
              ActivityTab({
                activity: this.vm.activity,
                commits: this.vm.commits,
                detail: this.vm.detail,
                refreshing: this.vm.activityRefreshing,
                loadingMore: this.vm.activityLoadingMore,
                noMore: this.vm.activityNoMore,
                ownerName: this.vm.ownerName(),
                repositoryName: this.vm.repositoryName(),
                refresh: (): void => {
                  this.vm.refreshCurrentActivityTab();
                },
                loadMore: (): void => {
                  this.vm.loadMoreCurrentActivityTab();
                },
                onSelectChange: (sel: number): void => {
                  this.vm.handleActivitySelectChange(sel);
                },
                onTapStar: (): void => {
                  this.openRepositoryCommonList('stargazers', COMMON_LIST_SHOW_TYPE_USER, 'stargazers');
                },
                onTapWatch: (): void => {
                  this.openRepositoryCommonList('watchers', COMMON_LIST_SHOW_TYPE_USER, 'watchers');
                },
                onTapFork: (): void => {
                  this.openRepositoryCommonList('forks', COMMON_LIST_SHOW_TYPE_REPOSITORY, 'forks');
                },
                onTapIssue: (): void => {
                  this.handleTabTap(2);
                },
                onTapForkSource: (): void => {
                },
                onTapOwner: (): void => {
                },
                onTapTopic: (topic: string): void => {
                  this.openTopicList(topic);
                },
              })
                .id('repo_detail_tab_content_info');
            }
            .tabBar(this.buildTabBar(this.tabs[0]));

            TabContent() {
              ReadmeTab({
                fullName: this.vm.fullName,
                branch: this.vm.currentBranchName(),
                readmeHtml: this.vm.readmeHtml,
                readmeMarkdown: this.vm.readmeMarkdown,
                readmeLoading: this.vm.readmeLoading,
                readmeError: this.vm.readmeError,
              })
                .id('repo_detail_tab_content_readme');
            }
            .tabBar(this.buildTabBar(this.tabs[1]));

            TabContent() {
              IssueTab({
                vm: this.vm.issueTab,
                showCreateFab: false,
                onIssueClick: (_item: RepositoryIssueItem): void => {
                },
                onCreateIssue: (): void => {
                  this.openCreateIssueSheet();
                },
              })
                .id('repo_detail_tab_content_issue');
            }
            .tabBar(this.buildTabBar(this.tabs[2]));

            TabContent() {
              FilesTab({
                files: this.vm.files,
                currentPath: this.vm.currentFilePath,
                refreshing: this.vm.filesRefreshing,
                loadingMore: this.vm.filesLoadingMore,
                noMore: this.vm.filesNoMore,
                refresh: (): void => {
                  this.refreshFiles(this.vm.currentFilePath);
                },
                onFileClick: (item: RepositoryFileItem): void => {
                  this.openFile(item);
                },
                onBack: (): void => {
                  this.backFiles();
                },
              })
                .id('repo_detail_tab_content_file');
            }
            .tabBar(this.buildTabBar(this.tabs[3]));
          }
          .id('repo_detail_tabs')
          .barHeight(TAB_BAR_HEIGHT)
          .barMode(BarMode.Fixed)
          .scrollable(true)
          .width('100%')
          .height('100%')
          .onChange((index: number): void => {
            this.currentIndex = index;
          });

          if (this.vm.fullName.length > 0) {
            this.buildCreateIssueFab();
          }
        }
        .id('repo_detail_content_stack')
        .layoutWeight(1)
        .width('100%');

        if (this.vm.fullName.length > 0) {
          CommonBottomBar({
            rootId: 'repo_detail_bottom_bar',
            dataList: this.buildBottomBarItems(),
            repoActionStyle: true,
            materialFloatingStyle: true,
            trailingItemId: 'branch',
            rootMarginHorizontal: GSYSpacing.hdsFloatingBarSideMargin,
            rootMarginBottom: GSYSpacing.hdsFloatingBarBottomMargin,
            rootBorderRadius: GSYSpacing.hdsFloatingBarRadius,
            rootHeight: GSYSpacing.bottomBarDefault,
            trailingMenuShow: this.branchMenuVisible,
            trailingMenuBuilder: (): void => {
              this.buildBranchMenuContent();
            },
            onTrailingMenuDismiss: (): void => {
              this.branchMenuVisible = false;
            },
          });
        }
      }
      .id('repo_detail_root')
      .width('100%')
      .height('100%')
      .backgroundColor(GSYColor.white)
      .bindSheet(this.createIssueSheetOpen, this.buildCreateIssueSheet(), {
        height: CREATE_ISSUE_SHEET_HEIGHT,
        dragBar: false,
        showClose: false,
        backgroundColor: GSYColor.white,
      });
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      NavigationService.pop();
      return true;
    })
    .onReady((ctx: NavDestinationContext): void => {
      const stack: NavPathStack | undefined = ctx.pathStack;
      const previous: string = this.vm.fullName;
      let stackSize: number = -1;
      let resolved: string = FALLBACK_FULL_NAME;
      if (stack !== undefined && stack !== null) {
        this.pathStack = stack;
        try {
          const all: string[] = stack.getAllPathName();
          stackSize = (all === undefined || all === null) ? 0 : all.length;
        } catch (_e) {
          stackSize = -1;
        }
        resolved = this.resolveFullNameFromStack(stack);
        if (resolved.length > 0) {
          this.vm.setFullName(resolved);
        }
      }
      if (this.vm.fullName.length === 0 || this.vm.fullName === FALLBACK_FULL_NAME) {
        const info: NavPathInfo | undefined = ctx.pathInfo;
        if (info !== undefined && info !== null) {
          const raw: Object | undefined = info.param as Object | undefined;
          const fromParam: string = this.resolveFullNameFromObject(raw === undefined ? null : raw);
          if (fromParam.length > 0) {
            resolved = fromParam;
            this.vm.setFullName(fromParam);
          }
        }
      }
      // KI-045 同款：BOOT_REPO_KEY 旁路优先级最高（dispatcher 路径上 stack/pathInfo
      // 都拿不到 param，必须靠 BOOT 旁路覆盖上一次残留的 fullName）。
      const bootRepo: string = BootChannel.get(BOOT_REPO_KEY);
      const bootRepoTrim: string = bootRepo.trim();
      if (bootRepoTrim.length > 0) {
        resolved = bootRepoTrim;
        this.vm.setFullName(bootRepoTrim);
      }
      Logger.i('boot/ts',
        `RepositoryDetailPage.onReady t=${Date.now()} stackSize=${stackSize}` +
        ` previous='${previous}' resolved='${resolved}' fullName='${this.vm.fullName}'`);
      if (this.vm.fullName.length > 0 && this.vm.fullName !== previous) {
        this.loadAll();
      } else if (previous.length === 0 && this.vm.fullName.length > 0) {
        this.loadAll();
      }
    });
  }
}
