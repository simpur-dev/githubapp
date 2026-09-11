/**
 * RepositoryHeader —— 仓库元数据卡片（V2）。
 * 原 1:1 对齐 RN [components/widget/RepositoryHeader.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/widget/RepositoryHeader.js)。
 *
 * R9 V2 + MVVM：删除 @ObjectLink RepositoryDetailStore，改 @Param 接数据字段
 * （detail / ownerName / repositoryName）。四个计数 cell（star/fork/watch/issue）
 * 的 Text 全部在 build 里 inline 读 @Param detail 字段——旧版 @Builder
 * buildBottomCell(idTag...) 值参中转 + @ObjectLink 嵌套字段不刷新，
 * 是 KI-043/048 冻结坑的发源地，V2 化后彻底消掉。
 *
 * R7-I 修复（2026-05-25 D3/D5/D8）沿用：根 Column 自然撑高 +
 * `.backgroundImage(ownerPic) + .backgroundColor(GSYColor.repositoryHeaderScrim)`
 * 让模糊/半透明覆盖严格限定在卡片内部。
 *
 * 所有 token 走 [Theme.ets](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/style/Theme.ets)。
 */

import { GSYColor, GSYFontSize, GSYSpacing, GSYShadow, ThemeManager } from 'common';
import { I18n, TimeUtil } from 'common';
import {
  IconFont,
  FA_STAR_O,
  FA_CODE_FORK,
  FA_EYE,
  FA_EXCLAMATION_CIRCLE,
} from 'common';
import { RepositoryDetail } from 'common';

const PLACEHOLDER: string = '---';
const HAIRLINE: number = 0.5;
const HEADER_BOTTOM_ICON_SIZE: number = 15;
const HEADER_RADIUS: number = 4;

@ComponentV2
export struct RepositoryHeader {
  @Param detail: RepositoryDetail | null = null;
  @Param ownerName: string = '';
  @Param repositoryName: string = '';

  @Event onTapOwner: () => void = (): void => {};
  @Event onTapStar: () => void = (): void => {};
  @Event onTapFork: () => void = (): void => {};
  @Event onTapWatch: () => void = (): void => {};
  @Event onTapIssue: () => void = (): void => {};
  @Event onTapForkSource: () => void = (): void => {};
  @Event onTapTopic: (topic: string) => void = (_topic: string): void => {};

  private ownerPic(): string {
    const d: RepositoryDetail | null = this.detail;
    if (d !== null && d.owner !== null && d.owner !== undefined) {
      return d.owner.avatar_url;
    }
    return '';
  }

  private sizeText(): string {
    const d: RepositoryDetail | null = this.detail;
    if (d === null) {
      return PLACEHOLDER;
    }
    const kb: number = d.size === undefined || d.size === null ? 0 : d.size;
    if (kb >= 1024) {
      return (kb / 1024).toFixed(2) + 'M';
    }
    return kb.toString() + 'K';
  }

  private languageText(): string {
    const d: RepositoryDetail | null = this.detail;
    if (d !== null && d.language !== null && d.language !== undefined && d.language.length > 0) {
      return d.language;
    }
    return PLACEHOLDER;
  }

  private descText(): string {
    const d: RepositoryDetail | null = this.detail;
    if (d !== null && d.description !== null && d.description !== undefined && d.description.length > 0) {
      return d.description;
    }
    return PLACEHOLDER;
  }

  private isFork(): boolean {
    const d: RepositoryDetail | null = this.detail;
    return d !== null && d.fork === true;
  }

  private topicsList(): string[] {
    const d: RepositoryDetail | null = this.detail;
    if (d !== null && d.topics !== undefined && d.topics !== null) {
      return d.topics;
    }
    return [];
  }

  private parentNameText(): string {
    const d: RepositoryDetail | null = this.detail;
    if (d !== null && d.parent !== null && d.parent !== undefined) {
      return d.parent.full_name;
    }
    return '---';
  }

  private createdAtText(): string {
    const d: RepositoryDetail | null = this.detail;
    if (d === null || d.created_at === null || d.created_at === undefined || d.created_at.length === 0) {
      return '';
    }
    return TimeUtil.resolveTime(d.created_at);
  }

  private pushedAtText(): string {
    const d: RepositoryDetail | null = this.detail;
    if (d === null || d.pushed_at === null || d.pushed_at === undefined || d.pushed_at.length === 0) {
      return '';
    }
    return TimeUtil.resolveTime(d.pushed_at);
  }

  private buildInfoText(): string {
    const create: string = this.isFork()
      ? I18n('forked_at') + ' ' + this.parentNameText() + '\n'
      : I18n('created_at') + ' ' + this.createdAtText() + ' ';
    const pushAt: string = this.pushedAtText();
    const update: string = pushAt.length > 0
      ? I18n('latest_commit') + ' ' + pushAt
      : '';
    return create + update;
  }

  build(): void {
    Stack() {
      Column() {
        Row() {
          Text(this.ownerName)
            .id('repo_header_owner')
            .fontSize(GSYFontSize.normal)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.miWhite)
            .textShadow({
              radius: GSYShadow.headerTextRadius,
              color: GSYShadow.headerTextColor,
              offsetX: GSYShadow.headerTextOffsetX,
              offsetY: GSYShadow.headerTextOffsetY,
            })
            .onClick((): void => {
              this.onTapOwner();
            });
          Text(' / ')
            .fontSize(GSYFontSize.normal)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.miWhite)
            .textShadow({
              radius: GSYShadow.headerTextRadius,
              color: GSYShadow.headerTextColor,
              offsetX: GSYShadow.headerTextOffsetX,
              offsetY: GSYShadow.headerTextOffsetY,
            });
          Text(this.repositoryName)
            .id('repo_header_name')
            .fontSize(GSYFontSize.normal)
            .fontWeight(FontWeight.Bold)
            .fontColor(GSYColor.miWhite)
            .textShadow({
              radius: GSYShadow.headerTextRadius,
              color: GSYShadow.headerTextColor,
              offsetX: GSYShadow.headerTextOffsetX,
              offsetY: GSYShadow.headerTextOffsetY,
            })
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .id('repo_header_name_row')
        .width('100%')
        .alignItems(VerticalAlign.Center);

        Row() {
          Text(this.languageText())
            .id('repo_header_language')
            .fontSize(GSYFontSize.min)
            .fontColor(GSYColor.miWhite)
            .textShadow({
              radius: GSYShadow.headerTextRadius,
              color: GSYShadow.headerTextColor,
              offsetX: GSYShadow.headerTextOffsetX,
              offsetY: GSYShadow.headerTextOffsetY,
            })
            .margin({ right: GSYSpacing.normalEdge })
            .maxLines(1);
          Text(this.sizeText())
            .id('repo_header_size')
            .fontSize(GSYFontSize.min)
            .fontColor(GSYColor.miWhite)
            .textShadow({
              radius: GSYShadow.headerTextRadius,
              color: GSYShadow.headerTextColor,
              offsetX: GSYShadow.headerTextOffsetX,
              offsetY: GSYShadow.headerTextOffsetY,
            })
            .margin({ right: GSYSpacing.normalEdge })
            .maxLines(1);
          Text(this.licenseText())
            .id('repo_header_license')
            .fontSize(GSYFontSize.min)
            .fontColor(GSYColor.miWhite)
            .textShadow({
              radius: GSYShadow.headerTextRadius,
              color: GSYShadow.headerTextColor,
              offsetX: GSYShadow.headerTextOffsetX,
              offsetY: GSYShadow.headerTextOffsetY,
            })
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .id('repo_header_meta_row')
        .width('100%')
        .margin({ top: GSYSpacing.halfEdge })
        .alignItems(VerticalAlign.Center);

        Text(this.descText())
          .id('repo_header_desc')
          .width('100%')
          .fontSize(GSYFontSize.min)
          .fontColor(GSYColor.miWhite)
          .textShadow({
            radius: GSYShadow.headerTextRadius,
            color: GSYShadow.headerTextColor,
            offsetX: GSYShadow.headerTextOffsetX,
            offsetY: GSYShadow.headerTextOffsetY,
          })
          .margin({ top: GSYSpacing.halfEdge })
          .maxLines(100);

        Row() {
          Text(this.buildInfoText())
            .id('repo_header_info_text')
            .fontSize(GSYFontSize.min)
            .fontColor(this.isFork() ? GSYColor.actionBlue : GSYColor.white)
            .textShadow({
              radius: GSYShadow.headerTextRadius,
              color: GSYShadow.headerTextColor,
              offsetX: GSYShadow.headerTextOffsetX,
              offsetY: GSYShadow.headerTextOffsetY,
            })
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .id('repo_header_info_row')
        .width('100%')
        .margin({
          top: GSYSpacing.normalEdge,
          bottom: GSYSpacing.normalEdge,
        })
        .justifyContent(FlexAlign.End)
        .onClick((): void => {
          if (this.isFork()) {
            this.onTapForkSource();
          }
        });

        // ── 四个计数 cell：全部 inline 展开，Text 在 build 里直接读 @Param detail
        // 字段（star→watchers_count / fork→forks_count / watch→subscribers_count /
        // issue→open_issues_count，与 RN 端字段映射一致）。不再走 @Builder 值参。 ──
        Row() {
          Row() {
            IconFont({
              char: FA_STAR_O,
              glyphSize: HEADER_BOTTOM_ICON_SIZE,
              glyphColor: GSYColor.white,
            });
            Text(this.detail !== null ? ' ' + this.detail.watchers_count.toString() : ' ' + PLACEHOLDER)
              .id('repo_header_bottom_text_star')
              .fontSize(GSYFontSize.small)
              .fontColor(GSYColor.white)
              .textShadow({
                radius: GSYShadow.headerTextRadius,
                color: GSYShadow.headerTextColor,
                offsetX: GSYShadow.headerTextOffsetX,
                offsetY: GSYShadow.headerTextOffsetY,
              });
          }
          .id('repo_header_bottom_cell_star')
          .layoutWeight(1)
          .padding({ top: GSYSpacing.normalEdge, bottom: GSYSpacing.normalEdge })
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .onClick((): void => {
            this.onTapStar();
          });

          Row() {
            IconFont({
              char: FA_CODE_FORK,
              glyphSize: HEADER_BOTTOM_ICON_SIZE,
              glyphColor: GSYColor.white,
            });
            Text(this.detail !== null ? ' ' + this.detail.forks_count.toString() : ' ' + PLACEHOLDER)
              .id('repo_header_bottom_text_fork')
              .fontSize(GSYFontSize.small)
              .fontColor(GSYColor.white)
              .textShadow({
                radius: GSYShadow.headerTextRadius,
                color: GSYShadow.headerTextColor,
                offsetX: GSYShadow.headerTextOffsetX,
                offsetY: GSYShadow.headerTextOffsetY,
              });
          }
          .id('repo_header_bottom_cell_fork')
          .layoutWeight(1)
          .padding({ top: GSYSpacing.normalEdge, bottom: GSYSpacing.normalEdge })
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .border({
            width: { left: HAIRLINE },
            color: GSYColor.repositoryHeaderLine,
          })
          .onClick((): void => {
            this.onTapFork();
          });

          Row() {
            IconFont({
              char: FA_EYE,
              glyphSize: HEADER_BOTTOM_ICON_SIZE,
              glyphColor: GSYColor.white,
            });
            Text(this.detail !== null ? ' ' + this.detail.subscribers_count.toString() : ' ' + PLACEHOLDER)
              .id('repo_header_bottom_text_watch')
              .fontSize(GSYFontSize.small)
              .fontColor(GSYColor.white)
              .textShadow({
                radius: GSYShadow.headerTextRadius,
                color: GSYShadow.headerTextColor,
                offsetX: GSYShadow.headerTextOffsetX,
                offsetY: GSYShadow.headerTextOffsetY,
              });
          }
          .id('repo_header_bottom_cell_watch')
          .layoutWeight(1)
          .padding({ top: GSYSpacing.normalEdge, bottom: GSYSpacing.normalEdge })
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .border({
            width: { left: HAIRLINE, right: HAIRLINE },
            color: GSYColor.repositoryHeaderLine,
          })
          .onClick((): void => {
            this.onTapWatch();
          });

          Row() {
            IconFont({
              char: FA_EXCLAMATION_CIRCLE,
              glyphSize: HEADER_BOTTOM_ICON_SIZE,
              glyphColor: GSYColor.white,
            });
            Text(this.detail !== null ? ' ' + this.detail.open_issues_count.toString() : ' ' + PLACEHOLDER)
              .id('repo_header_bottom_text_issue')
              .fontSize(GSYFontSize.small)
              .fontColor(GSYColor.white)
              .textShadow({
                radius: GSYShadow.headerTextRadius,
                color: GSYShadow.headerTextColor,
                offsetX: GSYShadow.headerTextOffsetX,
                offsetY: GSYShadow.headerTextOffsetY,
              });
          }
          .id('repo_header_bottom_cell_issue')
          .layoutWeight(1)
          .padding({ top: GSYSpacing.normalEdge, bottom: GSYSpacing.normalEdge })
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .onClick((): void => {
            this.onTapIssue();
          });
        }
        .id('repo_header_bottom_row')
        .width('100%')
        .margin({ top: GSYSpacing.halfEdge })
        .padding({ top: GSYSpacing.halfEdge, bottom: GSYSpacing.halfEdge })
        .border({
          width: { top: HAIRLINE },
          color: GSYColor.repositoryHeaderLine,
        });

        if (this.topicsList().length > 0) {
          Flex({
            direction: FlexDirection.Row,
            wrap: FlexWrap.Wrap,
          }) {
            Repeat<string>(this.topicsList())
              .each((obj: RepeatItem<string>): void => {
                Text(obj.item)
                  .id('repo_header_topic_' + obj.index.toString())
                  .fontSize(GSYFontSize.min)
                  .fontColor(GSYColor.miWhite)
                  .backgroundColor(GSYColor.primaryLight)
                  .padding({
                    left: GSYSpacing.halfEdge,
                    right: GSYSpacing.halfEdge,
                    top: 2,
                    bottom: 2,
                  })
                  .margin({ right: GSYSpacing.halfEdge, top: GSYSpacing.halfEdge })
                  .border({
                    width: HAIRLINE,
                    color: GSYColor.miWhite,
                    radius: 2,
                  })
                  .onClick((): void => {
                    this.onTapTopic(obj.item);
                  });
              })
              .key((topic: string): string => topic);
          }
          .id('repo_header_topics')
          .width('100%')
          .margin({ top: GSYSpacing.halfEdge });
        }
      }
      .id('repo_header_content')
      .width('100%')
      .padding(GSYSpacing.normalEdge)
      // 无头图时走品牌深色底（palette 驱动）；有头图时保留半透明压暗遮罩。
      // miWhite/white 文字是深色表面上的白字，两种模式下都保持可读，不随主题切换。
      .backgroundColor(this.ownerPic().length > 0
        ? GSYColor.repositoryHeaderScrim
        : ThemeManager.current().navBackground)
      .alignItems(HorizontalAlign.Start);
    }
    .id('repo_header_root')
    .width('auto')
    .margin({
      top: GSYSpacing.normalEdge,
      left: GSYSpacing.normalEdge,
      right: GSYSpacing.normalEdge,
    })
    .borderRadius(HEADER_RADIUS)
    .clip(true)
    .backgroundImage(this.ownerPic().length > 0 ? this.ownerPic() : '')
    .backgroundImageSize(ImageSize.Cover);
  }

  private licenseText(): string {
    const d: RepositoryDetail | null = this.detail;
    if (d !== null && d.license !== null && d.license !== undefined
        && d.license.name !== null && d.license.name !== undefined && d.license.name.length > 0) {
      return d.license.name;
    }
    return PLACEHOLDER;
  }
}
