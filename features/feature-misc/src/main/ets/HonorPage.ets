import { NavTitleBridge, NavTitleConfig, RouteName } from 'common';
import { I18n } from 'common';
import { GSYColor, GSYFontSize, GSYSpacing } from 'common';
import { ThemeManager } from 'common';
import { ContributionDay, emptyContributionDay } from 'common';
import { ContributionHeatmap } from 'common';

export class HonorEntry {
  name: string;
  desc: string;

  constructor(name: string, desc: string) {
    this.name = name;
    this.desc = desc;
  }
}

export const HONOR_LIST: HonorEntry[] = [
  new HonorEntry('CarGuo', 'GSYGithubApp 项目作者'),
  new HonorEntry('OpenHarmony', 'OpenHarmony / ArkTS 框架'),
  new HonorEntry('GitHub REST API', 'github.com/api/v3'),
  new HonorEntry('hypium', 'OpenHarmony 单元测试 / UI 测试框架'),
  new HonorEntry('Contributors', 'GSYGithubApp 全体贡献者'),
];

const SAMPLE_LEVEL_CYCLE: number[] = [0, 0, 1, 2, 1, 0, 3, 4, 2, 0, 1, 1, 2, 3];
/** 一年热力图总格数（53 周 × 7 天）。 */
const SAMPLE_TOTAL_DAYS: number = 371;

function formatSampleDate(d: Date): string {
  const m: number = d.getMonth() + 1;
  const day: number = d.getDate();
  return d.getFullYear().toString() + '-' + (m < 10 ? '0' + m.toString() : m.toString())
    + '-' + (day < 10 ? '0' + day.toString() : day.toString());
}

/**
 * TODO(R10) 接真数据：ContributionService.getContributions(login) 已就绪
 * （返回 ContributionDay[]，与 ContributionHeatmap.days 同构），
 * 待定下荣誉榜页展示哪位用户的贡献数据后替换此静态示例。
 */
function buildHonorSampleDays(): ContributionDay[] {
  const out: ContributionDay[] = [];
  for (let i: number = 0; i < SAMPLE_TOTAL_DAYS; i++) {
    const d: Date = new Date(2025, 8, 14 + i);
    const day: ContributionDay = emptyContributionDay();
    day.date = formatSampleDate(d);
    day.level = SAMPLE_LEVEL_CYCLE[i % SAMPLE_LEVEL_CYCLE.length];
    day.count = day.level * 3;
    out.push(day);
  }
  return out;
}

const HONOR_CONTRIBUTION_SAMPLE: ContributionDay[] = buildHonorSampleDays();

/**
 * HonorPage —— 荣耀榜页 View 层（R9 V2 + MVVM）。
 * 纯静态列表展示，无异步编排/业务状态，不强抽 ViewModel，仅做 @ComponentV2 化；
 * 列表 ForEach → Repeat（短列表，不用 virtualScroll），测试 id（honor_*）一字不动。
 */
@ComponentV2
export struct HonorPage {
  @Local items: HonorEntry[] = HONOR_LIST;

  @Builder
  buildItem(item: HonorEntry, index: number): void {
    Row() {
      Text((index + 1).toString())
        .id('honor_index_' + index.toString())
        .fontSize(GSYFontSize.small)
        .fontColor(GSYColor.white)
        .width(28)
        .height(28)
        .textAlign(TextAlign.Center)
        .borderRadius(14)
        .backgroundColor(GSYColor.linkBlue);
      Column() {
        Text(item.name)
          .id('honor_name_' + index.toString())
          .fontSize(GSYFontSize.middleNormal)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeManager.current().text);
        Text(item.desc)
          .id('honor_desc_' + index.toString())
          .fontSize(GSYFontSize.min)
          .fontColor(ThemeManager.current().textSecondary)
          .margin({ top: 4 });
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 });
    }
    .id('honor_row_' + index.toString())
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 16, right: 16 })
    .backgroundColor(ThemeManager.current().card)
    .border({ width: { bottom: 0.5 }, color: ThemeManager.current().divider })
    .alignItems(VerticalAlign.Center);
  }

  // R9 阶段4：标题栏交给 NavDestination 原生 .title（配置经 NavTitleBridge 上报）。
  aboutToAppear(): void {
    NavTitleBridge.get().registerTitle(RouteName.Honor, {
      titleGetter: (): string => I18n('beStaredText'),
    } as NavTitleConfig);
  }

  build(): void {
    Column() {
      Column() {
        Text('CarGuo / GSYGithubApp')
          .id('honor_header_title')
          .fontSize(GSYFontSize.middleWhite)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeManager.current().text);
        Text(I18n('beStared100Title'))
          .id('honor_header_subtitle')
          .fontSize(GSYFontSize.min)
          .fontColor(ThemeManager.current().textSecondary)
          .margin({ top: 4 });
      }
      .id('honor_header')
      .width('100%')
      .padding({ top: 24, bottom: 16, left: 16, right: 16 })
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(ThemeManager.current().card);

      // R10 阶段3：贡献热力图（数据结构对齐 ContributionStore.days；
      // 当前为静态示例，见上方 TODO 接真数据说明）。
      Column() {
        ContributionHeatmap({
          days: HONOR_CONTRIBUTION_SAMPLE,
          userName: 'CarGuo',
        })
      }
      .id('honor_heatmap_card')
      .width('100%')
      .padding({
        top: GSYSpacing.padding12,
        bottom: GSYSpacing.padding12,
        left: GSYSpacing.normalEdge,
        right: GSYSpacing.normalEdge,
      })
      .border({
        width: { top: GSYSpacing.dividerThickness, bottom: GSYSpacing.dividerThickness },
        color: ThemeManager.current().divider,
      })
      .backgroundColor(ThemeManager.current().card)
      .alignItems(HorizontalAlign.Start);

      List() {
        Repeat(this.items)
          .each((obj: RepeatItem<HonorEntry>) => {
            ListItem() {
              this.buildItem(obj.item, obj.index);
            }
            .id('honor_item_' + obj.index.toString());
          })
          .key((item: HonorEntry): string => item.name)
      }
      .id('honor_list')
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0, color: GSYColor.transparent });
    }
    .id('honor_root')
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeManager.current().background);
  }
}
