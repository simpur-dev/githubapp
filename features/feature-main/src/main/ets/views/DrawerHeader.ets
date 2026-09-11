import { I18n } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import {
  AuthStore,
  AuthUserInfo,
  GlobalAuthStore,
} from 'common';
import { EventBus, EVENT_AUTH_STATE_CHANGED } from 'common';
import { GSYColor, GSYFontSize } from 'common';
import { ThemeManager } from 'common';

export class DrawerHeaderTexts {
  nameText: string;
  loginText: string;
  bioText: string;
  followersText: string;
  followingText: string;

  constructor(nameText: string, loginText: string, bioText: string,
              followersText: string, followingText: string) {
    this.nameText = nameText;
    this.loginText = loginText;
    this.bioText = bioText;
    this.followersText = followersText;
    this.followingText = followingText;
  }
}

export class DrawerHeaderLogic {
  static parseUser(raw: string): AuthUserInfo | null {
    if (raw === undefined || raw === null || raw.length === 0) {
      return null;
    }
    return AuthUserInfo.fromJson(raw);
  }

  static buildTexts(user: AuthUserInfo | null): DrawerHeaderTexts {
    const login: string = user !== null && user.login.length > 0 ? user.login : '--';
    const nameText: string = user !== null && user.name.length > 0
      ? user.name
      : login;
    const loginText: string = login;
    const bioText: string = user !== null && user.bio.length > 0
      ? user.bio
      : I18n('userInfoNoting');
    const followersText: string = user !== null
      ? user.followers.toString()
      : '--';
    const followingText: string = user !== null
      ? user.following.toString()
      : '--';
    return new DrawerHeaderTexts(nameText, loginText, bioText, followersText, followingText);
  }

  static fromAuthStore(store: AuthStore): DrawerHeaderTexts {
    return DrawerHeaderLogic.buildTexts(store.userInfo);
  }
}

export class DrawerHeaderDeps {
  private static storeImpl: AuthStore = GlobalAuthStore;

  static setStore(store: AuthStore): void {
    DrawerHeaderDeps.storeImpl = store;
  }

  static getStore(): AuthStore {
    return DrawerHeaderDeps.storeImpl;
  }

  static reset(): void {
    DrawerHeaderDeps.storeImpl = GlobalAuthStore;
  }
}

@ComponentV2
export struct DrawerHeader {
  @Local userRev: number = 0;
  private offAuthChanged: (() => void) | null = null;
  @Event onAvatarTap: () => void = (): void => {
  };

  aboutToAppear(): void {
    // 登录态直读 GlobalAuthStore 单例；V2 @Local 无法自动订阅外部单例 @Trace，
    // 通过 EVENT_AUTH_STATE_CHANGED 事件驱动本组件重渲染（等价旧双向绑定响应）。
    this.offAuthChanged = EventBus.on(EVENT_AUTH_STATE_CHANGED, (_payload: ESObject): void => {
      this.userRev = this.userRev + 1;
    });
  }

  aboutToDisappear(): void {
    if (this.offAuthChanged !== null) {
      this.offAuthChanged();
      this.offAuthChanged = null;
    }
  }

  private resolveUser(): AuthUserInfo | null {
    return DrawerHeaderDeps.getStore().userInfo;
  }

  private handleAvatarTap(): void {
    const user: AuthUserInfo | null = this.resolveUser();
    if (user !== null && user.login.length > 0) {
      NavigationService.push(RouteName.UserDetail,
        { 'login': user.login } as Record<string, Object>);
    }
    this.onAvatarTap();
  }

  @Builder
  buildAvatar(user: AuthUserInfo | null): void {
    Column() {
      if (user !== null && user.avatarUrl.length > 0) {
        Image(user.avatarUrl)
          .id('drawer_avatar_image')
          .width(88)
          .height(88)
          .borderRadius(22)
          .backgroundColor(ThemeManager.current().surfaceSubtle);
      } else {
        Text(user !== null && user.login.length > 0
          ? user.login.substring(0, 1).toUpperCase()
          : '?')
          .id('drawer_avatar_placeholder')
          .width(88)
          .height(88)
          .borderRadius(22)
          .textAlign(TextAlign.Center)
          .fontSize(24) // TODO: 字号 24 暂无 token 映射
          .fontWeight(FontWeight.Bold)
          .fontColor(GSYColor.white)
          .backgroundColor(GSYColor.linkBlue);
      }
    }
    .id('drawer_avatar')
    .width(88)
    .height(88)
    .onClick((): void => {
      this.handleAvatarTap();
    });
  }

  /**
   * R-UI-05 inline 直读：buildCounter 不再接收 value 值参（旧版 `value: string`
   * 触发 ArkTS @Builder 值参冻结陷阱），idSuffix 仅用作 cellId 路由 + switch
   * 内部直接读 this.resolveUser()（GlobalAuthStore 单例）→ buildTexts，
   * userRev 变化触发本组件 build 重渲染时自然驱动 cell 文案刷新。
   * KI-048 / R-UI-05 守则参考：[ui-parity-with-rn.md](https://github.com/CarGuo/GSYGithubAppOH/blob/main/harness/rules/ui-parity-with-rn.md)
   */
  @Builder
  buildCounter(idSuffix: string, label: string): void {
    Column() {
      Text(idSuffix === 'followers'
        ? DrawerHeaderLogic.buildTexts(this.resolveUser()).followersText
        : idSuffix === 'following'
          ? DrawerHeaderLogic.buildTexts(this.resolveUser()).followingText
          : '--')
        .id('drawer_counter_value_' + idSuffix)
        .fontSize(GSYFontSize.middleWhite)
        .fontWeight(FontWeight.Bold)
        .fontColor(GSYColor.white);
      Text(label)
        .id('drawer_counter_label_' + idSuffix)
        .fontSize(GSYFontSize.min)
        .fontColor(GSYColor.darkSurfaceText)
        .margin({ top: 2 });
    }
    .id('drawer_counter_cell_' + idSuffix)
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start);
  }

  build(): void {
    Column() {
      this.buildAvatar(this.resolveUser());

      Text(DrawerHeaderLogic.buildTexts(this.resolveUser()).nameText)
        .id('drawer_name')
        .fontSize(GSYFontSize.big)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeManager.current().text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 18 });

      Text(DrawerHeaderLogic.buildTexts(this.resolveUser()).loginText)
        .id('drawer_login')
        .fontSize(GSYFontSize.middleWhite)
        .fontColor(ThemeManager.current().textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 8 });
    }
    .id('drawer_header')
    .width('100%')
    .padding({ left: 24, right: 24, top: 56, bottom: 28 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(ThemeManager.current().card);
  }
}
