// features/feature-main 统一出口（R9 阶段1b 生成，模块间只允许从这里导入）

export { HomePage } from './src/main/ets/HomePage';
export { NotifyPage } from './src/main/ets/NotifyPage';
export { READ_HISTORY_TAB_ALL, READ_HISTORY_TAB_REPO, READ_HISTORY_TAB_USER, ReadHistoryPage } from './src/main/ets/ReadHistoryPage';
export { ReadHistoryServiceFactory, setReadHistoryServiceFactory } from './src/main/ets/viewmodel/ReadHistoryViewModel';
export { SearchPage } from './src/main/ets/SearchPage';
export { SearchPageDeps } from './src/main/ets/viewmodel/SearchViewModel';
export { DynamicTabPage } from './src/main/ets/tabs/DynamicTabPage';
export { MyTabPage } from './src/main/ets/tabs/MyTabPage';
export { MyTabPageDeps } from './src/main/ets/viewmodel/MyTabViewModel';
export { TrendTabPage } from './src/main/ets/tabs/TrendTabPage';
export { DrawerHeader, DrawerHeaderDeps, DrawerHeaderLogic, DrawerHeaderTexts } from './src/main/ets/views/DrawerHeader';
export { DRAWER_MENU_KEY_ABOUT, DRAWER_MENU_KEY_CHECK_UPDATE, DRAWER_MENU_KEY_FEEDBACK, DRAWER_MENU_KEY_HISTORY, DRAWER_MENU_KEY_LANGUAGE, DRAWER_MENU_KEY_LOGOUT, DRAWER_MENU_KEY_PERSONAL_INFO, DRAWER_MENU_KEY_PROFILE, DRAWER_MENU_KEY_SETTING, DrawerMenu, DrawerMenuDeps, DrawerMenuItem, buildDrawerMenuItems } from './src/main/ets/views/DrawerMenu';
export { TabIcon, TabIconKey } from './src/main/ets/views/TabIcon';
export { UserHeadCounter, UserHeadItem, UserHeadOrgItem } from './src/main/ets/views/UserHeadItem';
