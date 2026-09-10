/**
 * AppNavigator —— R7 Phase A 单根 Navigation 容器
 *
 * 设计说明（参考 [r7-rebuild-blueprint.md § 1.1](https://github.com/CarGuo/GSYGithubAppOH/blob/main/harness/architecture/r7-rebuild-blueprint.md)）：
 *  - 全应用唯一一个 Navigation + NavPathStack，所有页面以 NavDestination 形式注册。
 *  - stack 在本组件构造时创建，注入到 [NavigationService](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/navigation/NavigationService.ets)
 *    供任意 push/pop/replace 调用，避免 KI-020 悬空栈 crash。
 *  - 路由名映射对齐 RN [AppNavigator.js#L144-L334](https://github.com/CarGuo/GSYGithubApp/blob/master/app/navigation/AppNavigator.js#L144-L334)。
 *
 * R9 阶段4：自绘 AppBar → NavDestination 原生标题栏。
 *  - 每个"有标题栏"的路由分支一个 NavDestination，挂 .title(自定义 builder) + .menus(自定义 builder)，
 *    需要底栏的分支再挂 .toolbarConfiguration(自定义 builder)。
 *  - builder 内容是 NavTitleView / NavMenusView / NavBottomBarView（common），
 *    按 routeName 从 NavTitleBridge 单例读页面 aboutToAppear 里 register 的配置
 *    （titleGetter 闭包随对象携带，动态标题可实时刷新）。
 *  - 返回键交给系统默认返回箭头（等价原 AppBar onBack → NavigationService.pop()）。
 *  - 无标题栏的路由（Welcome/Login/Home/Photo）保持 hideTitleBar(true)：
 *    Home 的 HomePage 自带页内 AppBar（home_appbar id 不变）。
 *
 * 注：每个页面 struct 必须 export，且不再使用 @Entry。
 */
import { LoadingModal } from 'common';
import { NavigationService, SafeAreaInsets, LIGHT_PALETTE } from 'common';
import { RouteName } from 'common';
import { NavTitleView, NavMenusView } from 'common';

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

@ComponentV2
export struct AppNavigator {
  private stack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    NavigationService.setStack(this.stack);
    // LoadingModal 静态入口的 UIContext 注入（同 setStack 注入模式）。
    LoadingModal.attach(this.getUIContext());
  }

  // ── .title builder（每路由一个，NavTitleView 按 routeName 读 NavTitleBridge 配置）──

  @Builder
  loginWebTitle() {
    NavTitleView({ routeName: RouteName.LoginWeb });
  }

  @Builder
  searchTitle() {
    NavTitleView({ routeName: RouteName.Search });
  }

  @Builder
  settingTitle() {
    NavTitleView({ routeName: RouteName.Setting });
  }

  @Builder
  aboutTitle() {
    NavTitleView({ routeName: RouteName.About });
  }

  @Builder
  customTitle() {
    NavTitleView({ routeName: RouteName.Custom });
  }

  @Builder
  honorTitle() {
    NavTitleView({ routeName: RouteName.Honor });
  }

  @Builder
  notifyTitle() {
    NavTitleView({ routeName: RouteName.Notify });
  }

  @Builder
  readHistoryTitle() {
    NavTitleView({ routeName: RouteName.ReadHistory });
  }

  @Builder
  userDetailTitle() {
    NavTitleView({ routeName: RouteName.UserDetail });
  }

  @Builder
  repositoryDetailTitle() {
    NavTitleView({ routeName: RouteName.RepositoryDetail });
  }

  @Builder
  issueDetailTitle() {
    NavTitleView({ routeName: RouteName.IssueDetail });
  }

  @Builder
  codeDetailTitle() {
    NavTitleView({ routeName: RouteName.CodeDetail });
  }

  @Builder
  pushDetailTitle() {
    NavTitleView({ routeName: RouteName.PushDetail });
  }

  @Builder
  userFollowedTitle() {
    NavTitleView({ routeName: RouteName.UserFollowed });
  }

  @Builder
  userFollowerTitle() {
    NavTitleView({ routeName: RouteName.UserFollower });
  }

  @Builder
  repositoryStarTitle() {
    NavTitleView({ routeName: RouteName.RepositoryStar });
  }

  @Builder
  repositoryWatcherTitle() {
    NavTitleView({ routeName: RouteName.RepositoryWatcher });
  }

  @Builder
  repositoryForkTitle() {
    NavTitleView({ routeName: RouteName.RepositoryFork });
  }

  @Builder
  personInfoTitle() {
    NavTitleView({ routeName: RouteName.PersonInfo });
  }

  @Builder
  releaseTitle() {
    NavTitleView({ routeName: RouteName.Release });
  }

  @Builder
  webPageTitle() {
    NavTitleView({ routeName: RouteName.WebPage });
  }

  @Builder
  commonListTitle() {
    NavTitleView({ routeName: RouteName.CommonList });
  }

  // ── .menus builder（有右上动作的路由）──

  @Builder
  notifyMenus() {
    NavMenusView({ routeName: RouteName.Notify });
  }

  @Builder
  userDetailMenus() {
    NavMenusView({ routeName: RouteName.UserDetail });
  }

  @Builder
  repositoryDetailMenus() {
    NavMenusView({ routeName: RouteName.RepositoryDetail });
  }

  @Builder
  issueDetailMenus() {
    NavMenusView({ routeName: RouteName.IssueDetail });
  }

  @Builder
  codeDetailMenus() {
    NavMenusView({ routeName: RouteName.CodeDetail });
  }

  @Builder
  pushDetailMenus() {
    NavMenusView({ routeName: RouteName.PushDetail });
  }

  @Builder
  webPageMenus() {
    NavMenusView({ routeName: RouteName.WebPage });
  }

  @Builder
  routerMap(name: string, _param: Object): void {
    if (name === RouteName.LoginWeb) {
      NavDestination() {
        LoginWebPage();
      }
        .title(this.loginWebTitle);
    } else if (name === RouteName.Search) {
      NavDestination() {
        SearchPage();
      }
        .title(this.searchTitle);
    } else if (name === RouteName.Setting) {
      NavDestination() {
        SettingPage();
      }
        .title(this.settingTitle);
    } else if (name === RouteName.About) {
      NavDestination() {
        AboutPage();
      }
        .title(this.aboutTitle);
    } else if (name === RouteName.Custom) {
      NavDestination() {
        CustomPage();
      }
        .title(this.customTitle);
    } else if (name === RouteName.Honor) {
      NavDestination() {
        HonorPage();
      }
        .title(this.honorTitle);
    } else if (name === RouteName.Notify) {
      NavDestination() {
        NotifyPage();
      }
        .title(this.notifyTitle)
        .menus(this.notifyMenus);
    } else if (name === RouteName.ReadHistory) {
      NavDestination() {
        ReadHistoryPage();
      }
        .title(this.readHistoryTitle);
    } else if (name === RouteName.UserDetail) {
      NavDestination() {
        UserDetailPage();
      }
        .title(this.userDetailTitle)
        .menus(this.userDetailMenus);
    } else if (name === RouteName.RepositoryDetail) {
      NavDestination() {
        RepositoryDetailPage();
      }
        .title(this.repositoryDetailTitle)
        .menus(this.repositoryDetailMenus);
    } else if (name === RouteName.IssueDetail) {
      NavDestination() {
        IssueDetailPage();
      }
        .title(this.issueDetailTitle)
        .menus(this.issueDetailMenus);
    } else if (name === RouteName.CodeDetail) {
      NavDestination() {
        CodeDetailPage();
      }
        .title(this.codeDetailTitle)
        .menus(this.codeDetailMenus);
    } else if (name === RouteName.PushDetail) {
      NavDestination() {
        PushDetailPage();
      }
        .title(this.pushDetailTitle)
        .menus(this.pushDetailMenus);
    } else if (name === RouteName.UserFollowed) {
      NavDestination() {
        UserFollowedPage();
      }
        .title(this.userFollowedTitle);
    } else if (name === RouteName.UserFollower) {
      NavDestination() {
        UserFollowerPage();
      }
        .title(this.userFollowerTitle);
    } else if (name === RouteName.RepositoryStar) {
      NavDestination() {
        RepositoryStarPage();
      }
        .title(this.repositoryStarTitle);
    } else if (name === RouteName.RepositoryWatcher) {
      NavDestination() {
        RepositoryWatcherPage();
      }
        .title(this.repositoryWatcherTitle);
    } else if (name === RouteName.RepositoryFork) {
      NavDestination() {
        RepositoryForkPage();
      }
        .title(this.repositoryForkTitle);
    } else if (name === RouteName.PersonInfo) {
      NavDestination() {
        PersonInfoPage();
      }
        .title(this.personInfoTitle);
    } else if (name === RouteName.Release) {
      NavDestination() {
        ReleasePage();
      }
        .title(this.releaseTitle);
    } else if (name === RouteName.WebPage) {
      NavDestination() {
        WebPage();
      }
        .title(this.webPageTitle)
        .menus(this.webPageMenus);
    } else if (name === RouteName.CommonList) {
      NavDestination() {
        CommonListPage({ initialParam: _param });
      }
        .title(this.commonListTitle);
    } else {
      // 无自绘标题栏的路由：保持原 hideTitleBar 包裹结构。
      // Home 的 HomePage 自带页内 AppBar（home_appbar id 不变，见 R9 阶段4 约定）。
      NavDestination() {
        if (name === RouteName.Welcome) {
          WelcomePage();
        } else if (name === RouteName.Login) {
          LoginPage();
        } else if (name === RouteName.Home) {
          HomePage();
        } else if (name === RouteName.Photo) {
          PhotoPage();
        }
      }
        .hideTitleBar(true);
    }
  }

  build(): void {
    Navigation(this.stack) {
      WelcomePage();
    }
    .id('app_navigator_root')
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.routerMap)
    // 颜色沉浸：窗口全屏（EntryAbility.enableImmersive），此处统一把标题栏
    // 推到状态栏之下，根背景色（标题栏同色）延伸到状态栏后面；
    // 底部完全沉浸：内容直铺到屏幕底边，手势指示条悬浮于内容之上。
    .padding({ top: SafeAreaInsets.top })
    .backgroundColor(LIGHT_PALETTE.navBackground);
  }
}
