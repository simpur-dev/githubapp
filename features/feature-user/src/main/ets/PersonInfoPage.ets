/**
 * PersonInfoPage —— 对齐 Compose 端
 * [InfoScreen.kt](https://github.com/CarGuo/GSYGithubAppCompose/blob/master/feature/info/src/main/java/com/shuyu/gsygithubappcompose/feature/info/InfoScreen.kt)
 *
 * Compose 端：
 *   - 抽屉 personal_info 进入 info route
 *   - 读 userInfo（name/email/blog/company/location/bio）
 *   - 6 行信息卡片，点击触发 AlertDialog + TextField → updateUser({field:text})
 *
 * OH 端：
 *   - 使用 GSYCardItem 同款 16/8 外边距、8 圆角、1px outline、2dp 近似 elevation
 *   - R9 V2：原 @CustomDialog PersonInfoEditDialog + CustomDialogController 在
 *     @ComponentV2 中不可用，内容结构原样迁为 @ComponentV2 PersonInfoEditSheet +
 *     bindSheet 呈现，person_info_edit_dialog_* 全部测试 id 原样保留。
 *   - 走 [UserService.updateUser](../../../common/src/main/ets/model/service/UserService.ets) PATCH /user
 *
 * HARD-LAW 自检：
 *   - HARD-LAW-1 TOKEN-ONLY：仅引 GSYColor/GSYFontSize/GSYSpacing/GSYShadow
 *   - HARD-LAW-2 NO-DEBUG-PROBE：无 *-count Text；调试走 Logger.i('person/info/...')
 */

import { NavTitleBridge, NavTitleConfig, RouteName } from 'common';
import { PullLoadMoreList } from 'common';
import {
  IconFont,
  FA_INFO_CIRCLE,
  FA_ENVELOPE,
  FA_LINK,
  FA_GROUP,
  FA_LOCATION,
  FA_COMMENT,
} from 'common';
import { I18n } from 'common';
import { GSYColor, GSYFontSize, GSYIconSize, GSYSpacing, GSYShadow } from 'common';
import {
  PersonInfoViewModel,
  PERSON_INFO_FIELD_NAME,
  PERSON_INFO_FIELD_EMAIL,
  PERSON_INFO_FIELD_BLOG,
  PERSON_INFO_FIELD_COMPANY,
  PERSON_INFO_FIELD_LOCATION,
  PERSON_INFO_FIELD_BIO,
} from './viewmodel/PersonInfoViewModel';

const PERSON_INFO_PLACEHOLDER: string = '---';

class PersonInfoListItem {
  key: string = 'person_info';
}

/**
 * 编辑弹层内容（V2）。旧版经 @CustomDialog PersonInfoEditDialog +
 * CustomDialogController 呈现（V2 组件不可用），内容结构原样迁为
 * @ComponentV2 + bindSheet，person_info_edit_dialog_* 测试 id 全部原样保留。
 */
@ComponentV2
struct PersonInfoEditSheet {
  @Param dialogTitle: string = '';
  @Param defaultValue: string = '';
  @Param placeholder: string = '';
  @Param okText: string = '';
  @Param cancelText: string = '';
  @Event onConfirm: (text: string) => void = (_text: string): void => {};
  @Event onCancel: () => void = (): void => {};
  @Local current: string = '';

  aboutToAppear(): void {
    this.current = this.defaultValue;
  }

  // 每次打开弹层前 View 层会更新 defaultValue，同步草稿值（等价旧弹窗每次 open 重建）。
  @Monitor('defaultValue')
  onDefaultChange(): void {
    this.current = this.defaultValue;
  }

  build(): void {
    Column() {
      Text(this.dialogTitle)
        .id('person_info_edit_dialog_title')
        .fontSize(GSYFontSize.middleWhite)
        .fontWeight(FontWeight.Bold)
        .fontColor(GSYColor.darkText)
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ bottom: GSYSpacing.normalEdge });

      TextInput({ text: this.current, placeholder: this.placeholder })
        .id('person_info_edit_dialog_input')
        .maxLength(200)
        .height(44)
        .fontSize(GSYFontSize.small)
        .fontColor(GSYColor.primary)
        .placeholderColor(GSYColor.subText)
        .backgroundColor(GSYColor.surfaceGray)
        .borderRadius(6)
        .padding({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge })
        .onChange((value: string): void => {
          this.current = value;
        });

      Row() {
        Button(this.cancelText)
          .id('person_info_edit_dialog_cancel')
          .layoutWeight(1)
          .backgroundColor(Color.Transparent)
          .fontColor(GSYColor.mediumText)
          .onClick((): void => {
            this.onCancel();
          });
        Divider().vertical(true).height(20).color(GSYColor.pillDivider);
        Button(this.okText)
          .id('person_info_edit_dialog_confirm')
          .layoutWeight(1)
          .backgroundColor(Color.Transparent)
          .fontColor(GSYColor.materialBlue)
          .onClick((): void => {
            const value: string = this.current;
            this.onConfirm(value);
          });
      }
      .id('person_info_edit_dialog_actions')
      .width('100%')
      .height(44)
      .margin({ top: GSYSpacing.normalEdge })
      .alignItems(VerticalAlign.Center);
    }
    .id('person_info_edit_dialog_root')
    .padding(2 * GSYSpacing.normalEdge)
    .borderRadius(8)
    .width('90%')
    .backgroundColor(Color.White);
  }
}

@ComponentV2
export struct PersonInfoPage {
  @Local vm: PersonInfoViewModel = new PersonInfoViewModel();
  @Local infoData: PersonInfoListItem[] = [new PersonInfoListItem()];
  // bindSheet 开合状态（@Local 双向绑定；弹层参数在 ViewModel @Trace 字段）。
  @Local editSheetOpen: boolean = false;

  aboutToAppear(): void {
    // R9 阶段4：标题栏交给 NavDestination 原生 .title（配置经 NavTitleBridge 上报）。
    NavTitleBridge.get().registerTitle(RouteName.PersonInfo, {
      titleGetter: (): string => I18n('person'),
    } as NavTitleConfig);
    this.vm.init();
  }

  private displayValue(value: string): string {
    return value !== undefined && value !== null && value.length > 0
      ? value
      : PERSON_INFO_PLACEHOLDER;
  }

  private dispatchEdit(field: string, oldValue: string, label: string): void {
    if (this.vm.openEdit(field, oldValue, label)) {
      this.editSheetOpen = true;
    }
  }

  private closeEditSheet(): void {
    this.editSheetOpen = false;
  }

  @Builder
  private editSheetBuilder(): void {
    PersonInfoEditSheet({
      dialogTitle: I18n('editField', { 'option1': this.vm.editLabel }),
      defaultValue: this.vm.editValue,
      placeholder: this.vm.editLabel,
      okText: I18n('ok'),
      cancelText: I18n('cancel'),
      onConfirm: (text: string): void => {
        this.closeEditSheet();
        this.vm.submitEdit(text);
      },
      onCancel: (): void => {
        this.closeEditSheet();
      },
    });
  }

  @Builder
  private buildInfoRow(rowId: string,
                       icon: string,
                       label: string,
                       value: string,
                       field: string,
                       rawValue: string): void {
    Row() {
      IconFont({
        char: icon,
        glyphSize: GSYIconSize.minIcon,
        glyphColor: GSYColor.primary,
      })
        .id(rowId + '_icon')
        .width(28);

      Text(label)
        .id(rowId + '_label')
        .fontSize(GSYFontSize.small)
        .fontColor(GSYColor.mainText)
        .margin({ left: GSYSpacing.normalEdge });

      Text(value)
        .id(rowId + '_value')
        .fontSize(GSYFontSize.small)
        .fontColor(GSYColor.mainText)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: GSYSpacing.normalEdge });
    }
    .id(rowId)
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({
      left: GSYSpacing.composeCardPaddingHorizontal,
      right: GSYSpacing.composeCardPaddingHorizontal,
      top: GSYSpacing.composeCardPaddingVertical,
      bottom: GSYSpacing.composeCardPaddingVertical,
    })
    .backgroundColor(GSYColor.cardBackground)
    .borderRadius(8)
    .border({
      width: 1,
      color: GSYColor.borderSubtle,
    })
    .shadow({
      radius: 6,
      color: GSYShadow.cardShadowAlpha,
      offsetX: 0,
      offsetY: 2,
    })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.dispatchEdit(field, rawValue, label);
    })
    .margin({
      left: GSYSpacing.composeCardHorizontal,
      right: GSYSpacing.composeCardHorizontal,
      top: GSYSpacing.composeCardVertical,
      bottom: GSYSpacing.composeCardVertical,
    });
  }

  @Builder
  private buildInfoContent(): void {
    Column() {
      this.buildInfoRow('person_info_row_name', FA_INFO_CIRCLE, I18n('infoName'),
        this.displayValue(this.vm.name), PERSON_INFO_FIELD_NAME, this.vm.name);
      this.buildInfoRow('person_info_row_email', FA_ENVELOPE, I18n('infoEmail'),
        this.displayValue(this.vm.email), PERSON_INFO_FIELD_EMAIL, this.vm.email);
      this.buildInfoRow('person_info_row_blog', FA_LINK, I18n('infoBlog'),
        this.displayValue(this.vm.blog), PERSON_INFO_FIELD_BLOG, this.vm.blog);
      this.buildInfoRow('person_info_row_company', FA_GROUP, I18n('infoCompany'),
        this.displayValue(this.vm.company), PERSON_INFO_FIELD_COMPANY, this.vm.company);
      this.buildInfoRow('person_info_row_location', FA_LOCATION, I18n('infoLocation'),
        this.displayValue(this.vm.location), PERSON_INFO_FIELD_LOCATION, this.vm.location);
      this.buildInfoRow('person_info_row_bio', FA_COMMENT, I18n('infoBio'),
        this.displayValue(this.vm.bio), PERSON_INFO_FIELD_BIO, this.vm.bio);
      Text(I18n('loadMoreEnd'))
        .id('person_info_no_more')
        .fontSize(GSYFontSize.middleWhite)
        .fontColor(GSYColor.mainText)
        .width('100%')
        .height(50)
        .textAlign(TextAlign.Center)
        .margin({ top: GSYSpacing.padding12 });
    }
    .id('person_info_content')
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .padding({
      top: GSYSpacing.halfEdge,
      bottom: GSYSpacing.normalEdge,
    });
  }

  @Builder
  private buildPullHeader(): void {
    Row()
      .id('person_info_pull_list')
      .width('100%')
      .height(1);
  }

  build(): void {
    Column() {
      PullLoadMoreList({
        dataSource: this.infoData,
        refreshing: this.vm.refreshing,
        loadingMore: this.vm.loadingMore,
        noMore: this.vm.noMore,
        renderHeader: (): void => this.buildPullHeader(),
        renderRow: (_item: Object, _index: number): void => this.buildInfoContent(),
        onRefresh: (): void => {
          this.vm.refresh();
        },
        onLoadMore: (): void => {
          this.vm.loadMore();
        },
        refreshingText: I18n('refreshing'),
        loadingMoreText: I18n('loadMoreing'),
        loadEndText: I18n('loadMoreEnd'),
        emptyText: I18n('listEmpty'),
      })
      .layoutWeight(1)
      .width('100%');
    }
    .id('person_info_root')
    .width('100%')
    .height('100%')
    .backgroundColor(GSYColor.mainBackground)
    .bindSheet(this.editSheetOpen, this.editSheetBuilder(), {
      height: 260,
      dragBar: false,
      showClose: false,
      backgroundColor: GSYColor.white,
    });
  }
}
