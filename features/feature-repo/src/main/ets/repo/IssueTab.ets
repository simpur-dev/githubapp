/**
 * IssueTab —— 仓库详情 Issue 列表 tab（R9 V2 + MVVM）。
 * 上批特意保留 V1 的组件本体，本批迁 @ComponentV2：列表 / 分页 / 筛选 / 搜索状态
 * 全部收敛在 IssueTabViewModel（@Param vm 传入，对象引用传递，@Trace 自动刷新），
 * 组件只做组装 + 点击转发。全部 repo_issue_* 测试 id 原样保留。
 */
import { I18n } from 'common';
import type { TranslationMap } from 'common';
import { PullLoadMoreList } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { GSYSpacing, GSYFontSize, GSYShadow, ThemeManager } from 'common';
import { IconFont, FA_PLUS, FA_SEARCH, FA_TIMES, FA_BUG } from 'common';
import { RepositoryIssueItem, ISSUE_STATE_OPEN, ISSUE_STATE_CLOSED, ISSUE_STATE_ALL } from 'common';
import { IssueTabViewModel } from '../viewmodel/IssueTabViewModel';

const ISSUE_SEARCH_HEADER_HEIGHT: number = 56;
const ISSUE_SEARCH_INPUT_HEIGHT: number = 52;
const ISSUE_SEARCH_ICON_SIZE: number = 22;

interface IssueChipModel {
  key: string;
  label: keyof TranslationMap;
  id: string;
}

@ComponentV2
export struct IssueTab {
  /** 列表 + 分页 + 筛选态（由宿主页面持有并下发；tab 自身不再持有状态）。 */
  @Param vm: IssueTabViewModel = new IssueTabViewModel();
  /** 是否显示创建 Issue 的 FAB（仓库详情页 FAB 上移到页面级，传 false）。 */
  @Param showCreateFab: boolean = true;
  @Event onIssueClick: (item: RepositoryIssueItem) => void = (_item: RepositoryIssueItem): void => {};
  @Event onCreateIssue: () => void = (): void => {};

  private chipDefs: IssueChipModel[] = [
    { key: ISSUE_STATE_ALL, label: 'issueAllText', id: 'repo_issue_chip_all' },
    { key: ISSUE_STATE_OPEN, label: 'issueOpenText', id: 'repo_issue_chip_open' },
    { key: ISSUE_STATE_CLOSED, label: 'issueCloseText', id: 'repo_issue_chip_closed' },
  ];

  private handleChipTap(state: string): void {
    this.vm.handleIssueStateChange(state);
  }

  private hasSearchQuery(): boolean {
    return this.vm.issueSearchQuery !== null && this.vm.issueSearchQuery !== undefined
      && this.vm.issueSearchQuery.trim().length > 0;
  }

  private submitSearch(): void {
    this.vm.handleIssueSearch();
  }

  private clearSearch(): void {
    if (!this.hasSearchQuery()) {
      return;
    }
    this.vm.setIssueSearchQuery('');
    this.vm.handleIssueSearch();
  }

  private handleRowTap(item: RepositoryIssueItem): void {
    this.onIssueClick(item);
    if (this.vm.fullName.length > 0) {
      const param: Record<string, Object> = {
        'fullName': this.vm.fullName,
        'number': item.number,
      };
      NavigationService.push(RouteName.IssueDetail, param);
    }
  }

  private issueTitle(item: RepositoryIssueItem): string {
    return '#' + item.number.toString() + ' ' + item.title;
  }

  private issueDate(item: RepositoryIssueItem): string {
    const raw: string = item.created_at !== null && item.created_at !== undefined ? item.created_at : '';
    const idx: number = raw.indexOf('T');
    return idx >= 0 ? raw.substring(0, idx) : raw;
  }

  private issueOpenedBy(item: RepositoryIssueItem): string {
    const user: string = item.user !== null && item.user !== undefined && item.user.login.length > 0
      ? item.user.login : I18n('unknown');
    return I18n('issueOpenedBy', { 'user': user });
  }

  @Builder
  searchHeaderBuilder(): void {
    Row() {
      TextInput({ text: this.vm.issueSearchQuery, placeholder: I18n('searchIssue') })
        .id('repo_issue_search_input')
        .layoutWeight(1)
        .height(ISSUE_SEARCH_INPUT_HEIGHT)
        .fontSize(GSYFontSize.small)
        .fontColor(ThemeManager.current().text)
        .placeholderColor(ThemeManager.current().textSecondary)
        .placeholderFont({ size: GSYFontSize.small })
        .caretColor(ThemeManager.current().text)
        .defaultFocus(false)
        .backgroundColor(ThemeManager.current().card)
        .borderRadius(3)
        .padding({
          left: GSYSpacing.halfEdge,
          right: GSYSpacing.halfEdge,
        })
        .margin({
          left: GSYSpacing.halfEdge,
          right: GSYSpacing.halfEdge,
        })
        .enterKeyType(EnterKeyType.Search)
        .onChange((value: string): void => {
          this.vm.setIssueSearchQuery(value);
        })
        .onSubmit((): void => {
          this.submitSearch();
        });

      Column() {
        IconFont({
          char: this.hasSearchQuery() ? FA_TIMES : FA_SEARCH,
          glyphSize: ISSUE_SEARCH_ICON_SIZE,
          glyphColor: ThemeManager.current().text,
        })
          .id(this.hasSearchQuery() ? 'repo_issue_search_clear_icon' : 'repo_issue_search_icon');
      }
      .id('repo_issue_search_submit_btn')
      .width(44)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick((): void => {
        if (this.hasSearchQuery()) {
          this.clearSearch();
          return;
        }
        this.submitSearch();
      });
    }
    .id('repo_issue_search_row')
    .width('auto')
    .height(ISSUE_SEARCH_HEADER_HEIGHT)
    .margin({
      left: GSYSpacing.normalEdge,
      right: GSYSpacing.normalEdge,
      top: GSYSpacing.normalEdge,
    })
    .backgroundColor(ThemeManager.current().card)
    .border({
      width: 0.5,
      color: ThemeManager.current().divider,
      radius: 3,
    })
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  chipBuilder(chip: IssueChipModel): void {
    Row() {
      if (this.vm.issueState === chip.key) {
        IconFont({
          char: '\uf00c',
          glyphSize: 12,
          glyphColor: ThemeManager.current().onBrandText,
        })
          .margin({ right: 4 });
      }
      Text(I18n(chip.label))
        .id(chip.id)
        .fontSize(GSYFontSize.small)
        .fontColor(this.vm.issueState === chip.key
          ? ThemeManager.current().onBrandText : ThemeManager.current().textSecondary);
    }
    .layoutWeight(1)
    .padding({ top: 8, bottom: 8 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.handleChipTap(chip.key);
    });
  }

  @Builder
  chipBarBuilder(): void {
    Row() {
      this.chipBuilder(this.chipDefs[0]);
      Divider().vertical(true).strokeWidth(0.5).color(ThemeManager.current().divider).height(16);
      this.chipBuilder(this.chipDefs[1]);
      Divider().vertical(true).strokeWidth(0.5).color(ThemeManager.current().divider).height(16);
      this.chipBuilder(this.chipDefs[2]);
    }
    .id('repo_issue_chip_bar')
    .width('auto')
    .margin({
      left: GSYSpacing.normalEdge,
      right: GSYSpacing.normalEdge,
      top: GSYSpacing.normalEdge,
    })
    .backgroundColor(ThemeManager.current().navBackground)
    .borderRadius(4)
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  rowBuilder(item: RepositoryIssueItem, index: number): void {
    Column() {
      Row() {
        IconFont({
          char: FA_BUG,
          glyphSize: 24,
          glyphColor: ThemeManager.current().text,
        })
          .id('repo_issue_row_icon_' + index.toString())
          .margin({ right: 8 });

        Text(this.issueTitle(item))
          .id('repo_issue_row_title_' + index.toString())
          .fontSize(GSYFontSize.normal)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeManager.current().text)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Text(item.body)
        .id('repo_issue_row_body_' + index.toString())
        .fontSize(GSYFontSize.small)
        .fontColor(ThemeManager.current().textSecondary)
        .margin({ top: 4 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      Row() {
        Text(this.issueOpenedBy(item))
          .id('repo_issue_row_opened_by_' + index.toString())
          .fontSize(GSYFontSize.small)
          .fontColor(ThemeManager.current().textSecondary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(this.issueDate(item))
          .id('repo_issue_row_date_' + index.toString())
          .fontSize(GSYFontSize.small)
          .fontColor(ThemeManager.current().textSecondary);
      }
      .width('100%')
      .margin({ top: 4 })
      .alignItems(VerticalAlign.Center);
    }
    .id('repo_issue_row_' + index.toString())
    .width('auto')
    .margin({
      left: GSYSpacing.normalEdge,
      right: GSYSpacing.normalEdge,
      top: GSYSpacing.halfEdge,
      bottom: GSYSpacing.halfEdge,
    })
    .padding(GSYSpacing.normalEdge)
    .borderRadius(3)
    .backgroundColor(ThemeManager.current().card)
    .shadow({
      radius: GSYShadow.radius,
      color: GSYShadow.cardShadowAlpha,
      offsetX: 0,
      offsetY: 1,
    })
    .alignItems(HorizontalAlign.Start)
    .onClick((): void => {
      this.handleRowTap(item);
    });
  }

  @Builder
  emptyBuilder(): void {
    Column() {
      Text(I18n('reposIssue'))
        .id('repo_issue_empty_title')
        .fontSize(GSYFontSize.middleNormal)
        .fontColor(ThemeManager.current().textSecondary);
      Text(I18n('userInfoNoting'))
        .id('repo_issue_empty_desc')
        .fontSize(GSYFontSize.small)
        .fontColor(ThemeManager.current().textSecondary)
        .margin({ top: 8 });
    }
    .id('repo_issue_empty_root')
    .width('100%')
    .height(240)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  fabBuilder(): void {
    Row() {
      IconFont({
        char: FA_PLUS,
        glyphSize: 24,
        glyphColor: ThemeManager.current().onBrandText,
      });
    }
    .id('repo_issue_create_fab')
    .width(48)
    .height(48)
    .borderRadius(24)
    .backgroundColor(ThemeManager.current().navBackground)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .shadow({
      radius: GSYShadow.radius,
      color: GSYShadow.cardShadowAlpha,
      offsetX: 0,
      offsetY: 2,
    })
    .onClick((): void => {
      this.onCreateIssue();
    });
  }

  build(): void {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Text('')
          .id('repo_issue_initial_focus_sink')
          .width(1)
          .height(1)
          .opacity(0)
          .focusable(true)
          .defaultFocus(true);
        this.searchHeaderBuilder();
        this.chipBarBuilder();
        PullLoadMoreList({
          dataSource: this.vm.issues as Object[],
          refreshing: this.vm.issueRefreshing,
          loadingMore: this.vm.issueLoadingMore,
          noMore: this.vm.issueNoMore,
          renderRow: (item: Object, index: number): void =>
            this.rowBuilder(item as RepositoryIssueItem, index),
          renderEmpty: (): void => this.emptyBuilder(),
          onRefresh: (): void => {
            this.vm.refreshIssues();
          },
          onLoadMore: (): void => {
            this.vm.loadMoreIssues();
          },
          tailPadding: GSYSpacing.normalEdge * 5,
        })
          .id('repo_issue_list')
          .layoutWeight(1);
      }
      .id('repo_issue_root')
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeManager.current().background);

      if (this.showCreateFab) {
        this.fabBuilder();
      }
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: GSYSpacing.normalEdge * 2 });
  }
}
