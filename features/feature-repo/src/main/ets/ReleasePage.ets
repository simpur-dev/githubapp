/**
 * ReleasePage —— 严格对齐 RN 端
 * [components/ReleasePage.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/ReleasePage.js)
 *
 * 双 Tab：reposRelease / reposTag。
 * 列表项 [ReleaseItem.ets](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/widget/ReleaseItem.ets)
 *   - actionTitle = name || tag_name
 *   - actionTime  = published_at
 *   - actionTarget / actionTargetHtml = body / body_html
 * 数据源 [RepositoryService.fetchRepositoryRelease/fetchRepositoryTag](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/service/RepositoryService.ets)
 *
 * R9 V2 + MVVM：@ComponentV2，双 tab 状态与分页抽到 ReleaseViewModel。
 */

import { I18n } from 'common';
import { AppBar } from 'common';
import { NavigationService } from 'common';
import { GSYColor, GSYFontSize, GSYSpacing } from 'common';
import { PullLoadMoreList } from 'common';
import { ReleaseItem } from './views/ReleaseItem';
import { ReleaseListItem } from 'common';
import { Logger } from 'common';
import { ReleaseViewModel } from './viewmodel/ReleaseViewModel';

interface ReleaseRouteParam {
  ownerName?: string;
  repositoryName?: string;
  reposOwner?: string;
  reposName?: string;
}

interface ReleaseTabItem {
  key: string;
  title: string;
  index: number;
}

const TAB_BAR_HEIGHT: number = 48;

@ComponentV2
export struct ReleasePage {
  @Local vm: ReleaseViewModel = new ReleaseViewModel();
  @Local currentIndex: number = 0;

  private tabsController: TabsController = new TabsController();
  private tabs: ReleaseTabItem[] = [
    { key: 'release', title: I18n('reposRelease'), index: 0 },
    { key: 'tag', title: I18n('reposTag'), index: 1 },
  ];

  private resolveParam(ctx: NavDestinationContext): void {
    const info: NavPathInfo | undefined = ctx.pathInfo;
    if (info === undefined || info === null) {
      return;
    }
    const param: Object | undefined = info.param as Object | undefined;
    if (param === undefined || param === null) {
      return;
    }
    const obj: ReleaseRouteParam = param as ReleaseRouteParam;
    let owner: string = this.vm.ownerName;
    let repository: string = this.vm.repositoryName;
    if (obj.ownerName !== undefined && obj.ownerName !== null && obj.ownerName.length > 0) {
      owner = obj.ownerName;
    } else if (obj.reposOwner !== undefined && obj.reposOwner !== null) {
      owner = obj.reposOwner;
    }
    if (obj.repositoryName !== undefined && obj.repositoryName !== null && obj.repositoryName.length > 0) {
      repository = obj.repositoryName;
    } else if (obj.reposName !== undefined && obj.reposName !== null) {
      repository = obj.reposName;
    }
    this.vm.init(owner, repository);
    Logger.i('ReleasePage', 'param resolved owner=' + this.vm.ownerName + ' repo=' + this.vm.repositoryName);
  }

  @Builder
  buildTabBar(item: ReleaseTabItem): void {
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
    .id('release_tab_bar_' + item.key)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End);
  }

  @Builder
  buildReleaseRow(item: Object, index: number): void {
    ReleaseItem({
      actionTime: (item as ReleaseListItem).publishedAt,
      actionTitle: (item as ReleaseListItem).resolveTitle(),
      actionTarget: (item as ReleaseListItem).bodyHtml,
      actionTargetHtml: (item as ReleaseListItem).bodyHtml,
      rowId: 'release_item_release_' + index.toString(),
    });
  }

  @Builder
  buildTagRow(item: Object, index: number): void {
    ReleaseItem({
      actionTime: (item as ReleaseListItem).publishedAt,
      actionTitle: (item as ReleaseListItem).resolveTitle(),
      actionTarget: (item as ReleaseListItem).bodyHtml,
      actionTargetHtml: (item as ReleaseListItem).bodyHtml,
      rowId: 'release_item_tag_' + index.toString(),
    });
  }

  build(): void {
    NavDestination() {
      Column() {
        AppBar({
          title: this.vm.repositoryName.length > 0 ? this.vm.repositoryName : I18n('reposRelease'),
          showBack: true,
          onBack: (): void => {
            NavigationService.pop();
          },
        });
        Tabs({
          barPosition: BarPosition.Start,
          index: this.currentIndex,
          controller: this.tabsController,
        }) {
          TabContent() {
            PullLoadMoreList({
              dataSource: this.vm.releaseItems as Object[],
              refreshing: this.vm.releaseRefreshing,
              loadingMore: this.vm.releaseLoadingMore,
              noMore: this.vm.releaseNoMore,
              onRefresh: (): void => {
                this.vm.refreshRelease();
              },
              onLoadMore: (): void => {
                this.vm.loadMoreRelease();
              },
              renderRow: (item: Object, index: number): void => {
                this.buildReleaseRow(item, index);
              },
            })
              .id('release_page_release_list');
          }
          .tabBar(this.buildTabBar(this.tabs[0]));

          TabContent() {
            PullLoadMoreList({
              dataSource: this.vm.tagItems as Object[],
              refreshing: this.vm.tagRefreshing,
              loadingMore: this.vm.tagLoadingMore,
              noMore: this.vm.tagNoMore,
              onRefresh: (): void => {
                this.vm.refreshTag();
              },
              onLoadMore: (): void => {
                this.vm.loadMoreTag();
              },
              renderRow: (item: Object, index: number): void => {
                this.buildTagRow(item, index);
              },
            })
              .id('release_page_tag_list');
          }
          .tabBar(this.buildTabBar(this.tabs[1]));
        }
        .id('release_page_tabs')
        .barHeight(TAB_BAR_HEIGHT)
        .barMode(BarMode.Fixed)
        .scrollable(true)
        .layoutWeight(1)
        .onChange((index: number): void => {
          this.currentIndex = index;
          if (index === 1 && this.vm.shouldLoadTagOnFirstSwitch()) {
            this.vm.refreshTag();
          }
        });
      }
      .id('release_page_root')
      .width('100%')
      .height('100%')
      .backgroundColor(GSYColor.mainBackground);
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      NavigationService.pop();
      return true;
    })
    .onReady((ctx: NavDestinationContext): void => {
      this.resolveParam(ctx);
      this.vm.refreshRelease();
    });
  }
}
