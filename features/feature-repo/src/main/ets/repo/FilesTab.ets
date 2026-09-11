import { I18n } from 'common';
import { PullLoadMoreList } from 'common';
import { RepositoryFileItem } from 'common';
import { IconFont, FA_FOLDER, FA_CODE } from 'common';
import { GSYSpacing, GSYColor, GSYFontSize, ThemeManager } from 'common';

interface BreadcrumbItem {
  label: string;
  path: string;
  index: number;
}

export function isImageOrArchiveFile(fileName: string): boolean {
  if (fileName === null || fileName === undefined) {
    return false;
  }
  const lower: string = fileName.toLowerCase();
  const ext: string = lower.lastIndexOf('.') >= 0 ? lower.substring(lower.lastIndexOf('.') + 1) : lower;
  return ext === 'png' || ext === 'jpg' || ext === 'jpeg' || ext === 'gif'
    || ext === 'bmp' || ext === 'webp' || ext === 'zip' || ext === 'rar'
    || ext === '7z' || ext === 'tar' || ext === 'gz';
}

/**
 * FilesTab（V2）：@ComponentV2 + @Param/@Event；文件列表数据由调用方
 * （RepositoryDetailPage 的 VM）传入，面包屑 ForEach → Repeat。
 */
@ComponentV2
export struct FilesTab {
  @Param files: RepositoryFileItem[] = [];
  @Param currentPath: string = '';
  @Param fullName: string = '';
  @Param branch: string = '';
  @Param refreshing: boolean = false;
  @Param loadingMore: boolean = false;
  @Param noMore: boolean = false;

  @Event refresh: () => void = (): void => {};
  @Event onFileClick: (item: RepositoryFileItem) => void = (_item: RepositoryFileItem): void => {};
  @Event onBack: () => void = (): void => {};
  @Event onPathChange: (path: string) => void = (_path: string): void => {};

  private buildCrumbs(): BreadcrumbItem[] {
    const list: BreadcrumbItem[] = [];
    list.push({ label: '.', path: '', index: 0 });
    if (this.currentPath.length === 0) {
      return list;
    }
    const segs: string[] = this.currentPath.split('/');
    let acc: string = '';
    for (let i: number = 0; i < segs.length; i++) {
      const seg: string = segs[i];
      if (seg.length === 0) {
        continue;
      }
      acc = acc.length > 0 ? acc + '/' + seg : seg;
      list.push({ label: seg, path: acc, index: i + 1 });
    }
    return list;
  }

  private handleRowTap(item: RepositoryFileItem): void {
    if (item.type === 'dir') {
      this.onPathChange(item.path);
      this.onFileClick(item);
      return;
    }
    if (isImageOrArchiveFile(item.name)) {
      return;
    }
    // 文件类型一律交给 RepositoryDetailPage.openFile 处理路由（fullName/branch 在父页面才有 context），
    // 不在这里直接 NavigationService.push。
    this.onFileClick(item);
  }

  private handleCrumbTap(crumb: BreadcrumbItem): void {
    if (crumb.path === this.currentPath) {
      return;
    }
    this.onPathChange(crumb.path);
  }

  @Builder
  rowBuilder(item: RepositoryFileItem, index: number): void {
    Row() {
      IconFont({
        char: item.type === 'dir' ? FA_FOLDER : FA_CODE,
        glyphSize: 16,
        glyphColor: item.type === 'dir' ? GSYColor.actionBlue : ThemeManager.current().textSecondary,
      })
        .id('repo_file_row_icon_' + index.toString());

      Text(item.name)
        .id('repo_file_row_name_' + index.toString())
        .fontSize(GSYFontSize.small)
        .fontColor(ThemeManager.current().text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: 12 });
    }
    .id('repo_file_row_' + index.toString())
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.handleRowTap(item);
    });
  }

  @Builder
  emptyBuilder(): void {
    Column() {
      Text(I18n('reposFile'))
        .id('repo_file_empty_title')
        .fontSize(GSYFontSize.middleNormal)
        .fontColor(ThemeManager.current().textSecondary);
      Text(I18n('userInfoNoting'))
        .id('repo_file_empty_desc')
        .fontSize(GSYFontSize.small)
        .fontColor(ThemeManager.current().textSecondary)
        .margin({ top: 8 });
    }
    .id('repo_file_empty_root')
    .width('100%')
    .height(240)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  breadcrumbBuilder(): void {
    Row() {
      Repeat<BreadcrumbItem>(this.buildCrumbs())
        .each((obj: RepeatItem<BreadcrumbItem>): void => {
          Text(obj.item.label)
            .id('repo_file_breadcrumb_seg_' + obj.item.index.toString())
            .fontSize(GSYFontSize.small)
            .fontColor(obj.item.path === this.currentPath
              ? ThemeManager.current().text : GSYColor.actionBlue)
            .fontWeight(obj.item.path === this.currentPath ? FontWeight.Bold : FontWeight.Normal)
            .onClick((): void => {
              this.handleCrumbTap(obj.item);
            });
          Text('>')
            .id('repo_file_breadcrumb_sep_' + obj.item.index.toString())
            .fontSize(GSYFontSize.small)
            .fontColor(ThemeManager.current().textSecondary)
            .margin({ left: 4, right: 4 });
        })
        .key((crumb: BreadcrumbItem): string => crumb.index.toString() + '_' + crumb.path);
    }
    .id('repo_file_breadcrumb')
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(ThemeManager.current().surfaceSubtle)
    .alignItems(VerticalAlign.Center);
  }

  build(): void {
    Column() {
      this.breadcrumbBuilder();
      PullLoadMoreList({
        dataSource: this.files as Object[],
        refreshing: this.refreshing,
        loadingMore: this.loadingMore,
        noMore: this.noMore,
        showFooter: false,
        renderRow: (item: Object, index: number): void => this.rowBuilder(item as RepositoryFileItem, index),
        renderEmpty: (): void => this.emptyBuilder(),
        onRefresh: (): void => {
          this.refresh();
        },
        onLoadMore: (): void => {
        },
        tailPadding: GSYSpacing.normalEdge * 5,
      })
        .id('repo_file_list')
        .layoutWeight(1);
    }
    .id('repo_file_root')
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeManager.current().background);
  }
}
