import { AppBar } from 'common';
import { I18n } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { GSYColor, GSYFontSize } from 'common';

export const APP_VERSION: string = '1.0.0';
export const APP_AUTHOR: string = 'CarGuo';
export const APP_PROJECT_URL: string = 'https://github.com/CarGuo/GSYGithubAppOH';
export const APP_LICENSE: string = 'MIT License';

/**
 * AboutInfoRow —— 信息行展示数据（Repeat 数据源，纯静态页无 VM）。
 * idValue 是测试脚本依赖的组件 id 前缀（about_*），一字不动。
 */
class AboutInfoRow {
  readonly idValue: string;
  readonly label: string;
  readonly value: string;

  constructor(idValue: string, label: string, value: string) {
    this.idValue = idValue;
    this.label = label;
    this.value = value;
  }
}

/**
 * AboutPage —— 关于页 View 层（R9 V2 + MVVM）。
 * 纯静态信息展示，无异步编排/业务状态，按迁移指南不强抽 ViewModel，
 * 仅做 @ComponentV2 化；信息行改由 Repeat 渲染。
 */
@ComponentV2
export struct AboutPage {
  @Local rows: AboutInfoRow[] = [
    new AboutInfoRow('about_version', I18n('version'), APP_VERSION),
    new AboutInfoRow('about_author', I18n('author'), APP_AUTHOR),
    new AboutInfoRow('about_project_url', I18n('projectUrl'), APP_PROJECT_URL),
    new AboutInfoRow('about_license', 'License', APP_LICENSE),
  ];

  private goHonor(): void {
    NavigationService.push(RouteName.Honor);
  }

  private goCustom(): void {
    NavigationService.push(RouteName.Custom);
  }

  build(): void {
    Column() {
      AppBar({
        title: I18n('about'),
        showBack: true,
        onBack: (): void => {
          NavigationService.pop();
        },
      });
      Scroll() {
        Column() {
          Column() {
            Text('GSY')
              .id('about_logo')
              .fontSize(40) // TODO: 字号 40 暂无 token 映射
              .fontWeight(FontWeight.Bold)
              .fontColor(GSYColor.white)
              .width(96)
              .height(96)
              .textAlign(TextAlign.Center)
              .borderRadius(48)
              .backgroundColor(GSYColor.linkBlue);
            Text(I18n('appName'))
              .id('about_app_name')
              .fontSize(GSYFontSize.normal)
              .fontWeight(FontWeight.Bold)
              .fontColor(GSYColor.primary)
              .margin({ top: 12 });
          }
          .id('about_logo_block')
          .width('100%')
          .padding({ top: 32, bottom: 24 })
          .alignItems(HorizontalAlign.Center);

          Repeat(this.rows)
            .each((obj: RepeatItem<AboutInfoRow>) => {
              Row() {
                Text(obj.item.label)
                  .id(obj.item.idValue + '_label')
                  .fontSize(GSYFontSize.small)
                  .fontColor(GSYColor.textSubtle)
                  .width(96);
                Text(obj.item.value)
                  .id(obj.item.idValue + '_value')
                  .fontSize(GSYFontSize.small)
                  .fontColor(GSYColor.primary)
                  .layoutWeight(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .maxLines(2);
              }
              .id(obj.item.idValue + '_row')
              .width('100%')
              .padding({ top: 12, bottom: 12, left: 16, right: 16 })
              .backgroundColor(GSYColor.white)
              .border({ width: { bottom: 0.5 }, color: GSYColor.borderSubtle });
            })
            .key((item: AboutInfoRow): string => item.idValue)

          Button(I18n('beStaredText'))
            .id('about_honor_btn')
            .type(ButtonType.Capsule)
            .width('90%')
            .height(46)
            .fontSize(GSYFontSize.middleNormal)
            .fontColor(GSYColor.white)
            .backgroundColor(GSYColor.successGreen)
            .margin({ top: 24 })
            .onClick((): void => {
              this.goHonor();
            });

          Button('Custom')
            .id('about_custom_btn')
            .type(ButtonType.Capsule)
            .width('90%')
            .height(46)
            .fontSize(GSYFontSize.middleNormal)
            .fontColor(GSYColor.white)
            .backgroundColor(GSYColor.linkBlue)
            .margin({ top: 12, bottom: 24 })
            .onClick((): void => {
              this.goCustom();
            });
        }
        .id('about_content')
        .width('100%')
        .alignItems(HorizontalAlign.Center);
      }
      .id('about_scroll')
      .layoutWeight(1)
      .width('100%');
    }
    .id('about_root')
    .width('100%')
    .height('100%')
    .backgroundColor(GSYColor.pageBackground);
  }
}
