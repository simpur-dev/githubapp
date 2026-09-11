/**
 * TrendTabPage —— 对齐 Android Compose TrendingScreen。
 *
 * Compose 版固定加载 daily + all-language 趋势仓库，不渲染 RN 版的
 * daily/weekly/monthly 与 language 双下拉过滤条，也不支持 load more。
 * View 只做组装（@ComponentV2），列表状态在 [TrendTabViewModel]。
 */
import { I18n } from 'common';
import { PullLoadMoreList } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import {
  TrendRepo,
  fullNameOf,
} from 'common';
import { GSYFontSize, GSYIconSize, GSYShadow, GSYSpacing } from 'common';
import { ThemeManager } from 'common';
import { UserImage } from 'common';
import { HTMLView } from 'common';
import { CommonIconButton } from 'common';
import { FA_CODE_FORK, FA_STAR_O } from 'common';
import { TrendTabViewModel } from '../viewmodel/TrendTabViewModel';

@ComponentV2
export struct TrendTabPage {
  @Local vm: TrendTabViewModel = new TrendTabViewModel();

  aboutToAppear(): void {
    this.vm.init();
  }

  private onRowClick(item: TrendRepo): void {
    const fullName: string = fullNameOf(item);
    if (fullName.length === 0) {
      return;
    }
    const idx: number = fullName.indexOf('/');
    const ownerName: string = idx > 0 ? fullName.substring(0, idx) : '';
    const repoName: string = idx > 0 ? fullName.substring(idx + 1) : fullName;
    const repoParam: Record<string, Object> = {
      'ownerName': ownerName,
      'repositoryName': repoName,
      'owner': ownerName,
      'name': repoName,
      'fullName': fullName,
    };
    NavigationService.push(RouteName.RepositoryDetail, repoParam);
  }

  @Builder
  rowBuilder(item: TrendRepo, index: number): void {
    Column() {
      Row() {
        UserImage({
          uri: item.avatar,
          loginUser: item.author,
          imageSize: 40,
          imageId: 'trend_row_avatar_' + index.toString(),
        })
          .margin({ right: GSYSpacing.normalEdge });

        Column() {
          Text(fullNameOf(item))
            .id('trend_row_full_' + index.toString())
            .width('100%')
            .fontSize(GSYFontSize.normal)
            .fontColor(ThemeManager.current().text)
            .fontWeight(FontWeight.Medium)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          if (item.language && item.language.length > 0) {
            Text(item.language)
              .id('trend_row_lang_' + index.toString())
              .fontSize(GSYFontSize.small)
              .fontColor(ThemeManager.current().textSecondary)
              .margin({ top: 2 });
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      if (item.description && item.description.length > 0) {
        HTMLView({
          value: item.description,
          fontSize: GSYFontSize.middleWhite,
          fontColor: ThemeManager.current().text,
          maxLines: 2,
          viewId: 'trend_row_desc_' + index.toString(),
        })
          .width('100%')
          .margin({ top: GSYSpacing.halfEdge });
      }

      Row() {
        Row() {
          CommonIconButton({
            icon: FA_STAR_O,
            iconColor: ThemeManager.current().textSecondary,
            iconSize: GSYIconSize.minIcon,
            text: item.stars.toString(),
            textColor: ThemeManager.current().textSecondary,
            textFontSize: GSYFontSize.small,
          });
        }
        .id('trend_row_star_' + index.toString());

        Row() {
          CommonIconButton({
            icon: FA_CODE_FORK,
            iconColor: ThemeManager.current().textSecondary,
            iconSize: GSYIconSize.minIcon,
            text: item.forks.toString(),
            textColor: ThemeManager.current().textSecondary,
            textFontSize: GSYFontSize.small,
          });
        }
        .id('trend_row_fork_' + index.toString())
        .margin({ left: GSYSpacing.normalEdge });
      }
      .width('100%')
      .margin({ top: GSYSpacing.halfEdge });
    }
    .id('trend_row_' + index.toString())
    .width('auto')
    .padding(GSYSpacing.normalEdge)
    .margin({
      left: GSYSpacing.halfEdge,
      right: GSYSpacing.halfEdge,
      top: GSYSpacing.halfEdge,
      bottom: GSYSpacing.halfEdge,
    })
    .borderRadius(4)
    .border({
      width: 1,
      color: ThemeManager.current().divider,
    })
    .backgroundColor(ThemeManager.current().card)
    .shadow({
      radius: GSYShadow.radius,
      color: GSYShadow.cardShadowAlpha,
      offsetX: 1,
      offsetY: 1,
    })
    .alignItems(HorizontalAlign.Start)
    .onClick((): void => {
      this.onRowClick(item);
    });
  }

  @Builder
  emptyBuilder(): void {
    Column() {
      Text(I18n('listEmpty'))
        .id('trend_empty_text')
        .fontSize(GSYFontSize.middleWhite)
        .fontColor(ThemeManager.current().textSecondary);
    }
    .id('trend_empty_root')
    .width('100%')
    .height(240)
    .justifyContent(FlexAlign.Center);
  }

  build(): void {
    Column() {
      PullLoadMoreList({
        dataSource: this.vm.items,
        refreshing: this.vm.refreshing,
        loadingMore: false,
        noMore: true,
        showFooter: false,
        renderRow: (item: Object, index: number): void => this.rowBuilder(item as TrendRepo, index),
        renderEmpty: (): void => this.emptyBuilder(),
        onRefresh: (): void => {
          this.vm.refresh();
        },
        refreshingText: I18n('refreshing'),
        loadingMoreText: I18n('loadMoreing'),
        loadEndText: I18n('loadMoreEnd'),
        emptyText: I18n('listEmpty'),
      })
        .id('trend_pull_list')
        .layoutWeight(1);
    }
    .id('tab_page_root_trend')
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeManager.current().background);
  }
}
