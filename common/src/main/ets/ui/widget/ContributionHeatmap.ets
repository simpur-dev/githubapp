/**
 * ContributionHeatmap —— GitHub 风格贡献热力图（R10 阶段3）。
 *
 * 数据源：[ContributionStore.days](../../model/store/ContributionStore.ets)
 * （ContributionService.getContributions(login) 拉取，v4 API 最近一年 ≈ 53 周）。
 *
 * 布局：横向 Scroll 内 53 列（周）× 7 行（周日→周六），列内 ForEach 方格 10vp、
 * 间距 2vp、圆角 2vp；首列按首日星期补空格、尾列按 7 格补齐。
 * 5 级色 heatmapLevel0-4（GitHub 官方调色板 token，深浅色主题下通用）。
 *
 * @Param userName 非空时显示 '@user contributions' 标题。
 */
import { ContributionDay, clampContributionLevel, emptyContributionDay } from '../../model/store/ContributionStore';
import { GSYColor, GSYFontSize, GSYSpacing } from '../style/Theme';
import { ThemeManager } from '../theme/ThemeManager';

/** 热力图方格：empty=true 表示周对齐补位（不渲染颜色）。 */
interface HeatmapCellModel {
  empty: boolean;
  day: ContributionDay;
}

/** 热力图列（一周 7 格）；key 携带各级别摘要，days 原地改级也能触发重建。 */
interface HeatmapWeekModel {
  key: string;
  cells: HeatmapCellModel[];
}

/** 一周 7 天。 */
const HEATMAP_WEEK_DAYS: number = 7;

/** YYYY-MM-DD → 星期（0=周日）；手工解析避免 Date 字符串解析兼容问题。 */
function weekdayOfDate(date: string): number {
  if (date.length < 10) {
    return 0;
  }
  const y: number = Number.parseInt(date.substring(0, 4), 10);
  const m: number = Number.parseInt(date.substring(5, 7), 10);
  const d: number = Number.parseInt(date.substring(8, 10), 10);
  if (Number.isNaN(y) || Number.isNaN(m) || Number.isNaN(d)) {
    return 0;
  }
  return new Date(y, m - 1, d).getDay();
}

function buildLevelDigest(cells: HeatmapCellModel[]): string {
  let digest: string = '';
  for (let i: number = 0; i < cells.length; i++) {
    digest += cells[i].empty ? 'e' : cells[i].day.level.toString();
  }
  return digest;
}

@ComponentV2
export struct ContributionHeatmap {
  /** 贡献天列表（ContributionStore.days 原样传入）。 */
  @Param days: ContributionDay[] = [];
  /** 用户名（非空时显示标题）。 */
  @Param userName: string = '';

  @Computed
  get weeks(): HeatmapWeekModel[] {
    const weeks: HeatmapWeekModel[] = [];
    let current: HeatmapCellModel[] = [];
    const lead: number = this.days.length > 0 ? weekdayOfDate(this.days[0].date) : 0;
    for (let i: number = 0; i < lead; i++) {
      current.push({ empty: true, day: emptyContributionDay() } as HeatmapCellModel);
    }
    for (let i: number = 0; i < this.days.length; i++) {
      current.push({ empty: false, day: this.days[i] } as HeatmapCellModel);
      if (current.length === HEATMAP_WEEK_DAYS) {
        weeks.push({
          key: (this.days[i].date.length > 0 ? this.days[i].date : 'w' + weeks.length.toString())
            + '_' + buildLevelDigest(current),
          cells: current,
        } as HeatmapWeekModel);
        current = [];
      }
    }
    if (current.length > 0) {
      while (current.length < HEATMAP_WEEK_DAYS) {
        current.push({ empty: true, day: emptyContributionDay() } as HeatmapCellModel);
      }
      weeks.push({
        key: 'tail' + weeks.length.toString() + '_' + buildLevelDigest(current),
        cells: current,
      } as HeatmapWeekModel);
    }
    return weeks;
  }

  private levelColor(level: number): string {
    const lv: number = clampContributionLevel(level);
    if (lv === 1) {
      return GSYColor.heatmapLevel1;
    }
    if (lv === 2) {
      return GSYColor.heatmapLevel2;
    }
    if (lv === 3) {
      return GSYColor.heatmapLevel3;
    }
    if (lv === 4) {
      return GSYColor.heatmapLevel4;
    }
    return GSYColor.heatmapLevel0;
  }

  build(): void {
    Column() {
      if (this.userName.length > 0) {
        Text('@' + this.userName + ' contributions')
          .id('contribution_heatmap_title')
          .fontSize(GSYFontSize.small)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeManager.current().text);
      }

      Scroll() {
        Row({ space: GSYSpacing.heatmapCellGap }) {
          ForEach(this.weeks, (week: HeatmapWeekModel) => {
            Column({ space: GSYSpacing.heatmapCellGap }) {
              ForEach(week.cells, (cell: HeatmapCellModel) => {
                Column()
                  .width(GSYSpacing.heatmapCellSize)
                  .height(GSYSpacing.heatmapCellSize)
                  .borderRadius(GSYSpacing.heatmapCellRadius)
                  .backgroundColor(cell.empty ? GSYColor.transparent : this.levelColor(cell.day.level));
              }, (cell: HeatmapCellModel, cellIndex: number): string =>
                cell.empty ? 'empty_' + cellIndex.toString() : cell.day.date);
            }
          }, (week: HeatmapWeekModel): string => week.key);
        }
        .alignItems(VerticalAlign.Center)
        .padding({ right: GSYSpacing.normalEdge });
      }
      .id('contribution_heatmap_grid')
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .margin({ top: this.userName.length > 0 ? GSYSpacing.padding12 : 0 });

      Row({ space: GSYSpacing.heatmapCellGap }) {
        Text('Less')
          .fontSize(GSYFontSize.min)
          .fontColor(ThemeManager.current().textSecondary);
        Column()
          .width(GSYSpacing.heatmapCellSize)
          .height(GSYSpacing.heatmapCellSize)
          .borderRadius(GSYSpacing.heatmapCellRadius)
          .backgroundColor(GSYColor.heatmapLevel0);
        Column()
          .width(GSYSpacing.heatmapCellSize)
          .height(GSYSpacing.heatmapCellSize)
          .borderRadius(GSYSpacing.heatmapCellRadius)
          .backgroundColor(GSYColor.heatmapLevel1);
        Column()
          .width(GSYSpacing.heatmapCellSize)
          .height(GSYSpacing.heatmapCellSize)
          .borderRadius(GSYSpacing.heatmapCellRadius)
          .backgroundColor(GSYColor.heatmapLevel2);
        Column()
          .width(GSYSpacing.heatmapCellSize)
          .height(GSYSpacing.heatmapCellSize)
          .borderRadius(GSYSpacing.heatmapCellRadius)
          .backgroundColor(GSYColor.heatmapLevel3);
        Column()
          .width(GSYSpacing.heatmapCellSize)
          .height(GSYSpacing.heatmapCellSize)
          .borderRadius(GSYSpacing.heatmapCellRadius)
          .backgroundColor(GSYColor.heatmapLevel4);
        Text('More')
          .fontSize(GSYFontSize.min)
          .fontColor(ThemeManager.current().textSecondary);
      }
      .id('contribution_heatmap_legend')
      .margin({ top: GSYSpacing.halfEdge })
      .alignItems(VerticalAlign.Center);
    }
    .alignItems(HorizontalAlign.Start);
  }
}
