// 启动参数通道键（从 EntryAbility 下沉到公共层，R9 阶段1a）
// EntryAbility 从 want.parameters 解析 boot* 参数后写这些键，
// HomePage.scheduleBoot* / 各详情页 tryAdoptBoot* 消费。
// 注意：键名是对外回归协议的一部分（scenario-tour.sh 的 aa start --ps boot* 依赖整套机制），不得改名。
export const BOOT_TAB_KEY: string = 'gsy_boot_tab';
export const BOOT_LOGIN_KEY: string = 'gsy_boot_login';
export const BOOT_WELCOME_HOLD_KEY: string = 'gsy_boot_welcome_hold';
export const BOOT_REPO_KEY: string = 'gsy_boot_repo';
export const BOOT_PUSH_KEY: string = 'gsy_boot_push';
export const BOOT_ISSUE_KEY: string = 'gsy_boot_issue';
export const BOOT_CODE_KEY: string = 'gsy_boot_code';
export const BOOT_USER_KEY: string = 'gsy_boot_user';
export const BOOT_PHOTO_KEY: string = 'gsy_boot_photo';
export const BOOT_WEB_KEY: string = 'gsy_boot_web';
export const BOOT_NOTIFY_ISSUE_KEY: string = 'gsy_boot_notify_issue';
export const BOOT_COMMON_LIST_KEY: string = 'gsy_boot_common_list';
