import { DrawerHeader } from 'feature_main';
import { DrawerMenu } from 'feature_main';
import { AuthUserInfo, GlobalAuthStore } from 'common';

const DRAWER_HOST_USER_BODY: string =
  '{"login":"DrawerLogin","name":"DrawerName","avatar_url":"",' +
  '"html_url":"https://github.com/DrawerLogin","bio":"drawer-bio",' +
  '"followers":12,"following":34,"public_repos":5}';

@Entry
@Component
struct DrawerHostPage {
  aboutToAppear(): void {
    // 预置登录用户：直写 GlobalAuthStore 单例（DrawerHeader 直读该单例）。
    const user: AuthUserInfo | null = AuthUserInfo.fromJson(DRAWER_HOST_USER_BODY);
    if (user !== null) {
      GlobalAuthStore.userInfo = user;
    }
  }

  build(): void {
    Column() {
      DrawerHeader();
      DrawerMenu();
    }
    .id('drawer_root')
    .width('100%')
    .height('100%')
    .backgroundColor('#24292E');
  }
}
