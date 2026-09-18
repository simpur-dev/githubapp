/**
 * SearchPage follows the Compose SearchScreen:
 * top app bar, GitHub search input, search history for an empty query,
 * Repository/User type buttons, and a pull list for the selected result type.
 * View 只做组装（@ComponentV2），状态在 [SearchViewModel]（viewmodel/SearchViewModel.ets）。
 */

import { I18n } from 'common';
import { PullLoadMoreList } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { RecommendRepo } from 'common';
import { SearchTab, SEARCH_TAB_REPO, SEARCH_TAB_USER, SearchUserItem } from 'common';
import { IconFont, FA_SEARCH, FA_TIMES } from 'common';
import { NavTitleBridge, NavTitleConfig } from 'common';
import { GSYFontSize, GSYSpacing } from 'common';
import { ThemeManager } from 'common';
import { RepositoryItem } from 'common';
import { UserItem, UserItemData } from 'common';
import { SearchViewModel, SearchPageDeps } from './viewmodel/SearchViewModel';

interface RepositoryDetailRouteParam {
  reposOwner: string;
  reposName: string;
  fullName: string;
}

interface UserDetailRouteParam {
  login: string;
}

const SEARCH_HEADER_HEIGHT: number = 56;
const SEARCH_INPUT_HEIGHT: number = 52;
const SEGMENT_BAR_RADIUS: number = 4;
const SPACER_HEIGHT: number = 2;
const SEARCH_ICON_SIZE: number = 24;
const SEARCH_PAGE_PADDING: number = 16;
const SEARCH_TYPE_BUTTON_HEIGHT: number = 40;

@ComponentV2
export struct SearchPage {
  @Local vm: SearchViewModel = new SearchViewModel();
  // 供新搜索提交后回到列表顶部（旧 PullLoadMoreController.refreshComplete(x, true) 语义）。
  private listScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    // R9 阶段4：标题栏交给 NavDestination 原生 .title（配置经 NavTitleBridge 上报）。
    NavTitleBridge.get().registerTitle(RouteName.Search, {
      titleGetter: (): string => I18n('search'),
    } as NavTitleConfig);
    // Host 页 / 测试在构造后可能重设 Deps，这里重读一次注入面再载入历史。
    this.vm.rebindDeps();
    this.vm.loadHistory();
  }

  private scrollToTop(): void {
    try {
      this.listScroller.scrollToIndex(0);
    } catch (_e) {
    }
  }

  private async submitFromUi(text: string): Promise<void> {
    await this.vm.submitSearch(text);
    this.scrollToTop();
  }

  private async refreshFromUi(): Promise<void> {
    await this.vm.refresh();
    this.scrollToTop();
  }

  private onRepoRowTap(item: RecommendRepo): void {
    const ownerLogin: string = item.owner !== null && item.owner !== undefined ? item.owner.login : '';
    const param: RepositoryDetailRouteParam = {
      reposOwner: ownerLogin,
      reposName: item.name,
      fullName: item.full_name,
    };
    NavigationService.push(RouteName.RepositoryDetail, param as Object);
  }

  private onUserRowTap(item: SearchUserItem): void {
    const param: UserDetailRouteParam = { login: item.login };
    NavigationService.push(RouteName.UserDetail, param as Object);
  }

  @Builder
  buildRepoRow(item: RecommendRepo, index: number): void {
    RepositoryItem({
      ownerName: item.owner.login,
      ownerPic: item.owner.avatar_url,
      repositoryName: item.full_name !== null && item.full_name !== undefined && item.full_name.length > 0
        ? item.full_name
        : item.name,
      repositoryStar: item.stargazers_count.toString(),
      repositoryFork: item.forks_count.toString(),
      repositoryWatch: item.watchers_count.toString(),
      repositoryType: item.language !== null && item.language !== undefined && item.language.length > 0
        ? item.language
        : '---',
      repositoryDes: item.description !== null && item.description !== undefined && item.description.length > 0
        ? item.description
        : '---',
      rowId: 'search_repo_' + index.toString(),
      onPressItem: (): void => this.onRepoRowTap(item),
    });
  }

  @Builder
  buildUserRow(item: SearchUserItem, index: number): void {
    UserItem({
      data: {
        login: item.login,
        avatar_url: item.avatar_url,
        html_url: item.html_url,
        desc: '',
      } as UserItemData,
      rowId: 'search_user_' + index.toString(),
      onPress: (): void => this.onUserRowTap(item),
    });
  }

  @Builder
  buildEmpty(): void {
    Column() {
      Text(I18n('listEmpty'))
        .id('search_empty_text')
        .fontSize(GSYFontSize.small)
        .fontColor(ThemeManager.current().textSecondary);
    }
    .id('search_empty_root')
    .width('100%')
    .padding({ top: GSYSpacing.tabBarHeight, bottom: GSYSpacing.tabBarHeight })
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  buildHistory(): void {
    Column() {
      Text(I18n('searchHistory'))
        .id('search_history_title')
        .fontSize(GSYFontSize.normal)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeManager.current().text)
        .width('100%')
        .margin({ bottom: GSYSpacing.halfEdge });
      Repeat<string>(this.vm.historyItems)
        .each((obj: RepeatItem<string>): void => {
          Column() {
            Text(obj.item)
              .id('search_history_text_' + obj.index.toString())
              .fontSize(GSYFontSize.small)
              .fontColor(ThemeManager.current().text)
              .width('100%')
              .padding({ top: GSYSpacing.halfEdge, bottom: GSYSpacing.halfEdge });
            Divider()
              .color(ThemeManager.current().divider)
              .strokeWidth(0.5);
          }
          .id('search_history_row_' + obj.index.toString())
          .width('100%')
          .onClick((): void => {
            this.vm.queryText = obj.item;
            this.submitFromUi(obj.item);
          });
        })
        .key((item: string): string => item)
    }
    .id('search_history_list')
    .width('100%')
    .padding({
      left: SEARCH_PAGE_PADDING,
      right: SEARCH_PAGE_PADDING,
      top: GSYSpacing.normalEdge,
    });
  }

  @Builder
  buildTypeButtons(): void {
    Row() {
      Button(I18n('searchRepos'))
        .id('search_type_repo_btn')
        .layoutWeight(1)
        .height(SEARCH_TYPE_BUTTON_HEIGHT)
        .fontSize(GSYFontSize.small)
        .fontColor(this.vm.hasTypedQuery() && this.vm.currentTab === SEARCH_TAB_REPO
          ? ThemeManager.current().onBrandText : ThemeManager.current().textSecondary)
        .backgroundColor(this.vm.hasTypedQuery() && this.vm.currentTab === SEARCH_TAB_REPO
          ? ThemeManager.current().navBackground : ThemeManager.current().surfaceSubtle)
        .enabled(this.vm.hasTypedQuery())
        .onClick((): void => {
          this.vm.switchTab(SEARCH_TAB_REPO);
        });

      Blank()
        .width(GSYSpacing.normalEdge);

      Button(I18n('searchUser'))
        .id('search_type_user_btn')
        .layoutWeight(1)
        .height(SEARCH_TYPE_BUTTON_HEIGHT)
        .fontSize(GSYFontSize.small)
        .fontColor(this.vm.hasTypedQuery() && this.vm.currentTab === SEARCH_TAB_USER
          ? ThemeManager.current().onBrandText : ThemeManager.current().textSecondary)
        .backgroundColor(this.vm.hasTypedQuery() && this.vm.currentTab === SEARCH_TAB_USER
          ? ThemeManager.current().navBackground : ThemeManager.current().surfaceSubtle)
        .enabled(this.vm.hasTypedQuery())
        .onClick((): void => {
          this.vm.switchTab(SEARCH_TAB_USER);
        });
    }
    .id('search_type_button_row')
    .width('100%')
    .padding({
      left: SEARCH_PAGE_PADDING,
      right: SEARCH_PAGE_PADDING,
      top: GSYSpacing.normalEdge,
    });
  }

  @Builder
  buildSearchHeader(): void {
    Row() {
      TextInput({ text: this.vm.queryText, placeholder: I18n('searchHint') })
        .id('search_input')
        .layoutWeight(1)
        .height(SEARCH_INPUT_HEIGHT)
        .fontSize(GSYFontSize.small)
        .fontColor(ThemeManager.current().text)
        .placeholderColor(ThemeManager.current().textSecondary)
        .placeholderFont({ size: GSYFontSize.small })
        .caretColor(ThemeManager.current().text)
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
          this.vm.onInputChanged(value);
        })
        .onFocus((): void => {
          this.vm.markFocused(true);
        })
        .onBlur((): void => {
          this.vm.markFocused(false);
        })
        .onSubmit((): void => {
          this.submitFromUi(this.vm.queryText);
        });

      Column() {
        IconFont({
          char: this.vm.hasTypedQuery() ? FA_TIMES : FA_SEARCH,
          glyphSize: SEARCH_ICON_SIZE,
          glyphColor: ThemeManager.current().text,
        })
          .id(this.vm.hasTypedQuery() ? 'search_clear_icon' : 'search_submit_icon');
      }
      .id('search_submit_btn')
      .margin({
        left: GSYSpacing.normalEdge,
        right: GSYSpacing.normalEdge,
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick((): void => {
        if (this.vm.hasTypedQuery()) {
          this.vm.clearSearch();
        }
      });
    }
    .id('search_header_row')
    .width('auto')
    .height(SEARCH_HEADER_HEIGHT)
    .margin({
      left: SEARCH_PAGE_PADDING,
      right: SEARCH_PAGE_PADDING,
      top: GSYSpacing.normalEdge,
    })
    .backgroundColor(ThemeManager.current().card)
    .border({
      width: GSYSpacing.dividerThickness,
      color: ThemeManager.current().divider,
    })
    .borderRadius(SEGMENT_BAR_RADIUS)
    .alignItems(VerticalAlign.Center);
  }

  /** R12：联想词块（历史前缀匹配结果；点击行直接以该词提交搜索）。 */
  @Builder
  buildSuggestions(): void {
    Column() {
      Repeat<string>(this.vm.suggestions)
        .each((obj: RepeatItem<string>): void => {
          Row() {
            SymbolGlyph($r('sys.symbol.magnifyingglass'))
              .fontSize(18)
              .fontColor([ThemeManager.current().textSecondary]);
            Text(obj.item)
              .fontSize(GSYFontSize.middleWhite)
              .fontColor(ThemeManager.current().text)
              .margin({ left: 12 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
          .id('search_suggestion_' + obj.index.toString())
          .width('100%')
          .height(44)
          .padding({ left: 16, right: 16 })
          .onClick((): void => {
            this.suggestionPicked(obj.item);
          });
        })
        .key((item: string): string => 'suggestion_' + item);
    }
    .id('search_suggestions')
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  private async suggestionPicked(text: string): Promise<void> {
    await this.submitFromUi(text);
  }

  @Builder
  buildContent(): void {
    Column() {
      this.buildSearchHeader();

      if (this.vm.queryText.trim().length === 0) {
        if (this.vm.searchFocused && this.vm.historyItems.length > 0) {
          this.buildHistory();
        } else {
          this.buildTypeButtons();
        }
      } else if (this.vm.suggestions.length > 0 && this.vm.isEmptyQuery()) {
        // R12：输入联想（历史前缀匹配，点击直接提交搜索）
        this.buildSuggestions();
      } else {
        this.buildTypeButtons();

        Row()
          .id('search_segment_spacer')
          .width('100%')
          .height(SPACER_HEIGHT)
          .opacity(0.3);

        if (this.vm.currentTab === SEARCH_TAB_REPO) {
          PullLoadMoreList({
            dataSource: this.vm.repos,
            refreshing: this.vm.refreshing,
            loadingMore: this.vm.loadingMore,
            noMore: !this.vm.hasMore,
            listScroller: this.listScroller,
            renderRow: (item: Object, index: number): void => this.buildRepoRow(item as RecommendRepo, index),
            renderEmpty: (): void => this.buildEmpty(),
            onRefresh: (): void => {
              this.refreshFromUi();
            },
            onLoadMore: (): void => {
              this.vm.loadMore();
            },
          })
            .id('search_pull_list_repo')
            .layoutWeight(1);
        } else {
          PullLoadMoreList({
            dataSource: this.vm.users,
            refreshing: this.vm.refreshing,
            loadingMore: this.vm.loadingMore,
            noMore: !this.vm.hasMore,
            listScroller: this.listScroller,
            renderRow: (item: Object, index: number): void => this.buildUserRow(item as SearchUserItem, index),
            renderEmpty: (): void => this.buildEmpty(),
            onRefresh: (): void => {
              this.refreshFromUi();
            },
            onLoadMore: (): void => {
              this.vm.loadMore();
            },
          })
            .id('search_pull_list_user')
            .layoutWeight(1);
        }
      }
    }
    .id('search_main_column')
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeManager.current().background);
  }

  build(): void {
    Column() {
      this.buildContent();
    }
    .id('search_page_root')
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeManager.current().background);
  }
}
