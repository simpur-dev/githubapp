/**
 * CommonListPage —— 通用列表页（user_repos / user_star / follower / followed / user_be_stared）
 * 严格对齐 RN [ListPage.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/ListPage.js)
 * 设计：dataType 决定接口分支；showType 决定行模板（user / repository）；localData 用于 user_be_stared 直接渲染。
 *
 * R9 V2 + MVVM：@ComponentV2；状态与 dataType 分发抽到 CommonListViewModel，
 * View 只做路由参数解析 + 组装（SubListView 已是 V2 受控组件）。
 *
 * HARD-LAW-1：颜色/字号/间距全部走 [Theme.ets](https://github.com/CarGuo/GSYGithubAppOH/blob/main/entry/src/main/ets/style/Theme.ets)。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GSYColor } from 'common';
import { NavTitleBridge, NavTitleConfig } from 'common';
import { SubRepositoryItem, SubUserItem } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { SubListView } from 'common';
import { CommonListViewModel } from './viewmodel/CommonListViewModel';

interface CommonListRouteParam {
  dataType: string;
  showType: string;
  currentUser: string;
  title: string;
  repoName?: string;
  localData?: SubRepositoryItem[];
}

interface UserDetailRouteParam {
  login: string;
}

interface RepoDetailRouteParam {
  owner: string;
  name: string;
  fullName: string;
  ownerName: string;
  reposName: string;
}

@ComponentV2
export struct CommonListPage {
  // AppNavigator 直传的入口参数（V2 需 @Param 才允许父侧初始化）。
  @Param initialParam: Object | null = null;
  @Local vm: CommonListViewModel = new CommonListViewModel();

  aboutToAppear(): void {
    // R9 阶段4：标题栏交给 NavDestination 原生 .title（resolveTitle 读 @Trace 状态可刷新）。
    NavTitleBridge.get().registerTitle(RouteName.CommonList, {
      titleGetter: (): string => this.vm.resolveTitle(),
    } as NavTitleConfig);
    if (this.initialParam !== null) {
      const ok: boolean = this.applyParamObj(this.initialParam);
      hilog.info(0x6666, 'CommonList', 'aboutToAppear initialParam ok=%{public}s dataType=%{public}s user=%{public}s',
        String(ok), this.vm.dataType, this.vm.currentUser);
    }
  }

  private applyParamObj(rawParam: Object | null | undefined): boolean {
    if (rawParam === undefined || rawParam === null) {
      return false;
    }
    const obj: CommonListRouteParam = rawParam as CommonListRouteParam;
    let touched: boolean = false;
    const dataType: string = obj.dataType !== undefined && obj.dataType !== null ? obj.dataType : '';
    const showType: string = obj.showType !== undefined && obj.showType !== null ? obj.showType : '';
    const currentUser: string = obj.currentUser !== undefined && obj.currentUser !== null ? obj.currentUser : '';
    const repoName: string = obj.repoName !== undefined && obj.repoName !== null ? obj.repoName : '';
    const title: string = obj.title !== undefined && obj.title !== null ? obj.title : '';
    const localData: SubRepositoryItem[] = obj.localData !== undefined && obj.localData !== null
      ? obj.localData : [];
    if (dataType.length > 0) {
      touched = true;
    }
    if (showType.length > 0) {
      touched = true;
    }
    if (obj.currentUser !== undefined && obj.currentUser !== null && obj.currentUser.length > 0) {
      touched = true;
    }
    if (obj.repoName !== undefined && obj.repoName !== null && obj.repoName.length > 0) {
      touched = true;
    }
    this.vm.init(dataType, showType, currentUser, repoName, title, localData);
    return touched;
  }

  private resolveParamFromCtx(ctx: NavDestinationContext): boolean {
    let ok: boolean = false;
    try {
      const info: NavPathInfo | undefined = ctx.pathInfo;
      if (info !== undefined && info !== null) {
        const param: Object | undefined = info.param as Object | undefined;
        ok = this.applyParamObj(param === undefined ? null : param);
      }
    } catch (_e) {
      ok = false;
    }
    if (ok) {
      return true;
    }
    try {
      const stack: NavPathStack | undefined = ctx.pathStack;
      if (stack !== undefined && stack !== null) {
        const all: string[] = stack.getAllPathName();
        if (all !== undefined && all !== null && all.length > 0) {
          const idx: number = all.length - 1;
          const fromStack: Object | undefined = stack.getParamByIndex(idx) as Object | undefined;
          ok = this.applyParamObj(fromStack === undefined ? null : fromStack);
        }
      }
    } catch (_e) {
      ok = false;
    }
    return ok;
  }

  private openUser(item: SubUserItem): void {
    const param: UserDetailRouteParam = { 'login': item.login } as UserDetailRouteParam;
    NavigationService.push(RouteName.UserDetail, param as Object);
  }

  private openRepo(item: SubRepositoryItem): void {
    const owner: string = item.owner_login;
    const repoName: string = item.name;
    if (owner.length === 0 || repoName.length === 0) {
      return;
    }
    const fullName: string = item.full_name.length > 0 ? item.full_name : owner + '/' + repoName;
    const param: RepoDetailRouteParam = {
      owner: owner,
      name: repoName,
      fullName: fullName,
      ownerName: owner,
      reposName: repoName,
    } as RepoDetailRouteParam;
    NavigationService.push(RouteName.RepositoryDetail, param as Object);
  }

  build(): void {
    NavDestination() {
      Column() {
        SubListView({
          title: this.vm.resolveTitle(),
          mode: this.vm.resolveSubListMode(),
          users: this.vm.users,
          repos: this.vm.repos,
          refreshing: this.vm.refreshing,
          loadingMore: this.vm.loadingMore,
          noMore: this.vm.noMore,
          idPrefix: this.vm.resolveIdPrefix(),
          refresh: (): void => {
            this.vm.refreshList();
          },
          loadMore: (): void => {
            this.vm.loadMoreList();
          },
          onUserClick: (item: SubUserItem): void => {
            this.openUser(item);
          },
          onRepoClick: (item: SubRepositoryItem): void => {
            this.openRepo(item);
          },
        })
          .id(this.vm.resolveIdPrefix() + '_view')
          .layoutWeight(1);
      }
      .id(this.vm.resolveIdPrefix() + '_root')
      .width('100%')
      .height('100%')
      .backgroundColor(GSYColor.white);
    }
    .hideTitleBar(true)
    .onBackPressed((): boolean => {
      NavigationService.pop();
      return true;
    })
    .onReady((ctx: NavDestinationContext): void => {
      const ok: boolean = this.resolveParamFromCtx(ctx);
      hilog.info(0x6666, 'CommonList', 'onReady ok=%{public}s dataType=%{public}s showType=%{public}s user=%{public}s title=%{public}s',
        String(ok), this.vm.dataType, this.vm.showType, this.vm.currentUser, this.vm.title);
      this.vm.refreshList();
    });
  }
}
