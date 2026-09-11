// RN 行号映射: [components/widget/UserItem.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/widget/UserItem.js) L36-L72

import { GSYFontSize, GSYIconSize, GSYSpacing, GSYShadow } from '../style/Theme';
import { ThemeManager } from '../theme/ThemeManager';
import { UserImage } from './UserImage';
import { PressableCard } from './PressableCard';
import { IconFont, FA_CHEVRON_RIGHT } from '../components/IconFont';
import { NavigationService } from '../../base/navigation/NavigationService';
import { RouteName } from '../../base/navigation/Routes';

export interface UserItemData {
  login: string;
  avatar_url: string;
  desc?: string;
  html_url?: string;
}

interface UserDetailRouteParam {
  login: string;
}

@ComponentV2
export struct UserItem {
  @Param data: UserItemData = { login: '', avatar_url: '' };
  @Param rowId: string = '';
  // 保留可选语义：不传时回退站内用户详情页导航（历史行为）。
  // V2 普通属性禁止外部初始化，可选回调改 @Param 函数类型（@Event 无可选形式）。
  @Param onPress: (() => void) | undefined = undefined;

  private handleClick(): void {
    if (this.onPress) {
      this.onPress();
      return;
    }
    const param: UserDetailRouteParam = { login: this.data.login };
    NavigationService.push(RouteName.UserDetail, param);
  }

  build(): void {
    // R10 阶段3：整卡按压反馈（蒙层 + 0.98 缩放），行内 .id / onClick 原样保留。
    PressableCard({ cornerRadius: GSYSpacing.cardRadiusLg }) {
      Row() {
      UserImage({
        uri: this.data.avatar_url,
        loginUser: this.data.login,
        imageSize: GSYIconSize.normal,
        imageId: this.rowId.length > 0 ? this.rowId + '_avatar' : 'user_item_avatar',
      })
        .margin({ right: GSYSpacing.normalEdge });

      Column() {
        Text(this.data.login && this.data.login.length > 0 ? this.data.login : '---')
          .id(this.rowId.length > 0 ? this.rowId + '_login' : 'user_item_login')
          .fontSize(GSYFontSize.small)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeManager.current().text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        if (this.data.desc && this.data.desc.length > 0) {
          Text(this.data.desc)
            .id(this.rowId.length > 0 ? this.rowId + '_desc' : 'user_item_desc')
            .fontSize(GSYFontSize.min)
            .fontColor(ThemeManager.current().textSecondary)
            .margin({ top: GSYSpacing.halfEdge / 2 })
            .maxLines(GSYSpacing.normalNumberOfLine)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      Stack() {
        IconFont({
          char: FA_CHEVRON_RIGHT,
          glyphSize: GSYFontSize.small,
          glyphColor: ThemeManager.current().textSecondary,
        });
      }
        .id(this.rowId.length > 0 ? this.rowId + '_chevron' : 'user_item_chevron')
        .margin({ left: GSYSpacing.halfEdge });
    }
    .id(this.rowId.length > 0 ? this.rowId : 'user_item_root')
    .width('auto')
    .alignItems(VerticalAlign.Center)
    .padding(16)
    .margin({
      left: 16,
      right: 16,
      top: 8,
      bottom: 8,
    })
    .borderRadius(GSYSpacing.cardRadiusLg)
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
    .onClick((): void => {
      this.handleClick();
    });
    }
  }
}
