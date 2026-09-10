/**
 * AppNavigator —— R7 Phase A 单根 Navigation 容器
 *
 * 设计说明（参考 [r7-rebuild-blueprint.md § 1.1](https://github.com/CarGuo/GSYGithubAppOH/blob/main/harness/architecture/r7-rebuild-blueprint.md)）：
 *  - 全应用唯一一个 Navigation + NavPathStack，所有页面以 NavDestination 形式注册。
 *  - stack 在本组件构造时创建，注入到 [NavigationService](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/navigation/NavigationService.ets)
 *    供任意 push/pop/replace 调用，避免 KI-020 悬空栈 crash。
 *  - 路由名映射对齐 RN [AppNavigator.js#L144-L334](https://github.com/CarGuo/GSYGithubApp/blob/master/app/navigation/AppNavigator.js#L144-L334)。
 *
 * 注：每个页面 struct 必须 export，且不再使用 @Entry。
 */
import { LoadingModal } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';

import { WelcomePage } from 'feature_auth';
import { LoginPage } from 'feature_auth';
import { LoginWebPage } from 'feature_auth';
import { HomePage } from 'feature_main';
import { SearchPage } from 'feature_main';
import { SettingPage } from 'feature_misc';
import { AboutPage } from 'feature_misc';
import { CustomPage } from 'feature_misc';
import { HonorPage } from 'feature_misc';
import { NotifyPage } from 'feature_main';
import { ReadHistoryPage } from 'feature_main';
import { UserDetailPage } from 'feature_user';
import { RepositoryDetailPage } from 'feature_repo';
import { IssueDetailPage } from 'feature_repo';
import { CodeDetailPage } from 'feature_repo';
import { PushDetailPage } from 'feature_repo';
import { UserFollowedPage } from 'feature_user';
import { UserFollowerPage } from 'feature_user';
import { RepositoryStarPage } from 'feature_repo';
import { RepositoryWatcherPage } from 'feature_repo';
import { RepositoryForkPage } from 'feature_repo';
import { PersonInfoPage } from 'feature_user';
import { ReleasePage } from 'feature_repo';
import { PhotoPage } from 'feature_misc';
import { WebPage } from 'feature_misc';
import { CommonListPage } from 'feature_repo';

@Component
export struct AppNavigator {
  private stack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    NavigationService.setStack(this.stack);
    // LoadingModal 静态入口的 UIContext 注入（同 setStack 注入模式）。
    LoadingModal.attach(this.getUIContext());
  }

  @Builder
  routerMap(name: string, _param: Object): void {
    NavDestination() {
      if (name === RouteName.Welcome) {
        WelcomePage();
      } else if (name === RouteName.Login) {
        LoginPage();
      } else if (name === RouteName.LoginWeb) {
        LoginWebPage();
      } else if (name === RouteName.Home) {
        HomePage();
      } else if (name === RouteName.Search) {
        SearchPage();
      } else if (name === RouteName.Setting) {
        SettingPage();
      } else if (name === RouteName.About) {
        AboutPage();
      } else if (name === RouteName.Custom) {
        CustomPage();
      } else if (name === RouteName.Honor) {
        HonorPage();
      } else if (name === RouteName.Notify) {
        NotifyPage();
      } else if (name === RouteName.ReadHistory) {
        ReadHistoryPage();
      } else if (name === RouteName.UserDetail) {
        UserDetailPage();
      } else if (name === RouteName.RepositoryDetail) {
        RepositoryDetailPage();
      } else if (name === RouteName.IssueDetail) {
        IssueDetailPage();
      } else if (name === RouteName.CodeDetail) {
        CodeDetailPage();
      } else if (name === RouteName.PushDetail) {
        PushDetailPage();
      } else if (name === RouteName.UserFollowed) {
        UserFollowedPage();
      } else if (name === RouteName.UserFollower) {
        UserFollowerPage();
      } else if (name === RouteName.RepositoryStar) {
        RepositoryStarPage();
      } else if (name === RouteName.RepositoryWatcher) {
        RepositoryWatcherPage();
      } else if (name === RouteName.RepositoryFork) {
        RepositoryForkPage();
      } else if (name === RouteName.PersonInfo) {
        PersonInfoPage();
      } else if (name === RouteName.Release) {
        ReleasePage();
      } else if (name === RouteName.Photo) {
        PhotoPage();
      } else if (name === RouteName.WebPage) {
        WebPage();
      } else if (name === RouteName.CommonList) {
        CommonListPage({ initialParam: _param });
      }
    }
    .hideTitleBar(true);
  }

  build(): void {
    Navigation(this.stack) {
      WelcomePage();
    }
    .id('app_navigator_root')
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.routerMap);
  }
}
