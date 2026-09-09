import { DrawerHeader } from 'feature_main';
import { DrawerMenu } from 'feature_main';
import { APP_STORAGE_KEY_USER_INFO } from 'common';

const DRAWER_HOST_USER_BODY: string =
  '{"login":"DrawerLogin","name":"DrawerName","avatar_url":"",' +
  '"html_url":"https://github.com/DrawerLogin","bio":"drawer-bio",' +
  '"followers":12,"following":34,"public_repos":5}';

@Entry
@Component
struct DrawerHostPage {
  aboutToAppear(): void {
    AppStorage.setOrCreate<string>(APP_STORAGE_KEY_USER_INFO, DRAWER_HOST_USER_BODY);
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
