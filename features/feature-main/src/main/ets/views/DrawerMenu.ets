import bundleManager from '@ohos.bundle.bundleManager';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { I18n } from 'common';
import { CommonModal } from 'common';
import { CommonToast } from 'common';
import { NavigationService } from 'common';
import { RouteName } from 'common';
import { RepositoryService, ReleaseListItem } from 'common';
import {
  AuthStore,
  GlobalAuthStore,
} from 'common';
import { KEY_LANGUAGE_SELECT } from 'common';
import {
  LoginUseCase,
  DefaultLoginUseCase,
} from 'common';
import {
  SettingPageDeps,
  SettingPageHelper,
  LANGUAGE_OPTION_EN,
  LANGUAGE_OPTION_SYSTEM,
  LANGUAGE_OPTION_ZH,
} from 'common';
import {
  FA_USER,
  FA_COMMENT,
  FA_INFO_CIRCLE,
  FA_HISTORY,
  FA_COG,
  FA_REFRESH,
  FA_SIGN_OUT,
} from 'common';
import { GSYColor, GSYFontSize, GSYSpacing } from 'common';
import { ThemeManager } from 'common';

export class DrawerMenuItem {
  key: string;
  title: string;
  icon: string;

  constructor(key: string, title: string, icon: string) {
    this.key = key;
    this.title = title;
    this.icon = icon;
  }
}

export class DrawerMenuDeps {
  private static useCaseImpl: LoginUseCase = DefaultLoginUseCase;
  private static storeImpl: AuthStore = GlobalAuthStore;

  static setLoginUseCase(useCase: LoginUseCase): void {
    DrawerMenuDeps.useCaseImpl = useCase;
  }

  static setStore(store: AuthStore): void {
    DrawerMenuDeps.storeImpl = store;
  }

  static getLoginUseCase(): LoginUseCase {
    return DrawerMenuDeps.useCaseImpl;
  }

  static getStore(): AuthStore {
    return DrawerMenuDeps.storeImpl;
  }

  static reset(): void {
    DrawerMenuDeps.useCaseImpl = DefaultLoginUseCase;
    DrawerMenuDeps.storeImpl = GlobalAuthStore;
  }
}

export const DRAWER_MENU_KEY_HISTORY: string = 'history';
export const DRAWER_MENU_KEY_FEEDBACK: string = 'feedback';
export const DRAWER_MENU_KEY_PERSONAL_INFO: string = 'personal_info';
export const DRAWER_MENU_KEY_LANGUAGE: string = 'language';
export const DRAWER_MENU_KEY_CHECK_UPDATE: string = 'check_update';
export const DRAWER_MENU_KEY_ABOUT: string = 'about';
export const DRAWER_MENU_KEY_LOGOUT: string = 'logout';
export const DRAWER_MENU_KEY_PROFILE: string = DRAWER_MENU_KEY_PERSONAL_INFO;
export const DRAWER_MENU_KEY_SETTING: string = DRAWER_MENU_KEY_LANGUAGE;
const DRAWER_CLOSE_ACTION_DELAY_MS: number = 1800;

class DrawerLanguageOption {
  value: string;
  label: string;

  constructor(value: string, label: string) {
    this.value = value;
    this.label = label;
  }
}

function buildDrawerLanguageOptions(): DrawerLanguageOption[] {
  return [
    new DrawerLanguageOption(LANGUAGE_OPTION_SYSTEM, I18n('systemLanguage')),
    new DrawerLanguageOption(LANGUAGE_OPTION_ZH, I18n('zhLanguage')),
    new DrawerLanguageOption(LANGUAGE_OPTION_EN, I18n('enLanguage')),
  ];
}

/**
 * 反馈弹层内容（V2）。旧版经 common 的 @CustomDialog CreateIssueDialog +
 * CustomDialogController 呈现（V2 组件不可用），本轮保持内容结构原样迁为
 * @ComponentV2 + bindSheet 呈现，全部 create_issue_* 测试 id 原样保留。
 */
@ComponentV2
struct DrawerFeedbackSheet {
  @Param dialogTitle: string = '';
  @Param titlePlaceholder: string = '';
  @Param bodyPlaceholder: string = '';
  @Event onConfirm: (title: string, body: string) => void = (_t: string, _b: string): void => {};
  @Event onCancel: () => void = (): void => {};
  @Local titleText: string = '';
  @Local bodyText: string = '';

  private appendMarkdown(insertion: string): void {
    this.bodyText = this.bodyText + insertion;
  }

  @Builder
  private buildMarkdownAction(actionId: string, label: string, insertion: string): void {
    Button(label)
      .id(actionId)
      .type(ButtonType.Normal)
      .fontSize(GSYFontSize.min)
      .fontColor(ThemeManager.current().text)
      .backgroundColor(ThemeManager.current().surfaceSubtle)
      .borderRadius(6)
      .height(32)
      .padding({ left: 10, right: 10 })
      .onClick((): void => {
        this.appendMarkdown(insertion);
      });
  }

  build(): void {
    Column() {
      Text(this.dialogTitle)
        .id('create_issue_dialog_title')
        .fontSize(GSYFontSize.middleNormal)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeManager.current().text)
        .margin({ bottom: GSYSpacing.normalEdge });

      TextInput({ placeholder: this.titlePlaceholder, text: this.titleText })
        .id('create_issue_dialog_title_input')
        .fontSize(GSYFontSize.normal)
        .fontColor(ThemeManager.current().text)
        .placeholderColor(ThemeManager.current().textSecondary)
        .backgroundColor(ThemeManager.current().surfaceSubtle)
        .borderRadius(4)
        .height(40)
        .padding({ left: GSYSpacing.halfEdge, right: GSYSpacing.halfEdge })
        .onChange((value: string): void => {
          this.titleText = value;
        });

      TextArea({ placeholder: this.bodyPlaceholder, text: this.bodyText })
        .id('create_issue_dialog_body_input')
        .fontSize(GSYFontSize.small)
        .fontColor(ThemeManager.current().text)
        .placeholderColor(ThemeManager.current().textSecondary)
        .backgroundColor(ThemeManager.current().surfaceSubtle)
        .borderRadius(4)
        .height(200)
        .margin({ top: GSYSpacing.normalEdge })
        .padding(GSYSpacing.halfEdge)
        .onChange((value: string): void => {
          this.bodyText = value;
        });

      Scroll() {
        Row() {
          this.buildMarkdownAction('create_issue_markdown_toolbar_h1', 'H1', '# ');
          this.buildMarkdownAction('create_issue_markdown_toolbar_h2', 'H2', '## ');
          this.buildMarkdownAction('create_issue_markdown_toolbar_h3', 'H3', '### ');
          this.buildMarkdownAction('create_issue_markdown_toolbar_bold', 'B', '****');
          this.buildMarkdownAction('create_issue_markdown_toolbar_italic', 'I', '**');
          this.buildMarkdownAction('create_issue_markdown_toolbar_ul', 'UL', '- ');
          this.buildMarkdownAction('create_issue_markdown_toolbar_quote', 'Quote', '> ');
          this.buildMarkdownAction('create_issue_markdown_toolbar_code', 'Code', '``');
          this.buildMarkdownAction('create_issue_markdown_toolbar_image', 'IMG', '![]()');
          this.buildMarkdownAction('create_issue_markdown_toolbar_link', 'Link', '[]()');
        }
        .id('create_issue_markdown_toolbar')
        .height(36)
        .alignItems(VerticalAlign.Center);
      }
      .width('100%')
      .height(40)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .margin({ top: GSYSpacing.halfEdge });

      Row() {
        Button(I18n('cancel'))
          .id('create_issue_dialog_cancel')
          .fontSize(GSYFontSize.normal)
          .fontColor(ThemeManager.current().textSecondary)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .onClick((): void => {
            this.onCancel();
          });
        Button(I18n('ok'))
          .id('create_issue_dialog_confirm')
          .fontSize(GSYFontSize.normal)
          .fontColor(GSYColor.miWhite)
          .backgroundColor(GSYColor.primary)
          .layoutWeight(1)
          .margin({ left: GSYSpacing.normalEdge })
          .onClick((): void => {
            const t: string = this.titleText.trim();
            if (t.length === 0) {
              return;
            }
            this.onConfirm(t, this.bodyText);
          });
      }
      .width('100%')
      .margin({ top: GSYSpacing.normalEdge });
    }
    .id('create_issue_dialog_root')
    .width('90%')
    .padding(GSYSpacing.normalEdge)
    .backgroundColor(ThemeManager.current().card)
    .borderRadius(8);
  }
}

export function buildDrawerMenuItems(): DrawerMenuItem[] {
  return [
    new DrawerMenuItem(DRAWER_MENU_KEY_HISTORY, I18n('drawerHistory'), FA_HISTORY),
    new DrawerMenuItem(DRAWER_MENU_KEY_FEEDBACK, I18n('drawerFeedback'), FA_COMMENT),
    new DrawerMenuItem(DRAWER_MENU_KEY_PERSONAL_INFO, I18n('drawerPersonalInfo'), FA_USER),
    new DrawerMenuItem(DRAWER_MENU_KEY_LANGUAGE, I18n('drawerLanguage'), FA_COG),
    new DrawerMenuItem(DRAWER_MENU_KEY_CHECK_UPDATE, I18n('drawerCheckUpdate'), FA_REFRESH),
    new DrawerMenuItem(DRAWER_MENU_KEY_ABOUT, I18n('drawerAbout'), FA_INFO_CIRCLE),
    new DrawerMenuItem(DRAWER_MENU_KEY_LOGOUT, I18n('drawerLogout'), FA_SIGN_OUT),
  ];
}

@ComponentV2
export struct DrawerMenu {
  @Event onItemTap: (key: string) => void = (_key: string): void => {
  };

  private items: DrawerMenuItem[] = buildDrawerMenuItems();
  @Local currentLanguage: string = LANGUAGE_OPTION_SYSTEM;
  @Local aboutVersionText: string = '0.0.0';
  // 三个自绘弹层（About / Language / Feedback）V2 走 bindSheet 受控开合，
  // 内容结构与全部 drawer_about_* / drawer_language_* / create_issue_* id 原样保留。
  @Local aboutSheetOpen: boolean = false;
  @Local languageSheetOpen: boolean = false;
  @Local feedbackSheetOpen: boolean = false;
  private feedbackService: RepositoryService = new RepositoryService();

  aboutToAppear(): void {
    this.loadLanguage();
  }

  private async loadLanguage(): Promise<void> {
    try {
      this.currentLanguage = await SettingPageDeps.getPrefs()
        .getString(KEY_LANGUAGE_SELECT, LANGUAGE_OPTION_SYSTEM);
    } catch (_e) {
      this.currentLanguage = LANGUAGE_OPTION_SYSTEM;
    }
  }

  private async handleLogout(): Promise<void> {
    try {
      await DrawerMenuDeps.getLoginUseCase().logout();
    } catch (_e) {
    }
    NavigationService.replace(RouteName.Login);
  }

  private handleItem(item: DrawerMenuItem): void {
    this.onItemTap(item.key);
    if (item.key === DRAWER_MENU_KEY_FEEDBACK) {
      setTimeout((): void => {
        this.feedbackSheetOpen = true;
      }, DRAWER_CLOSE_ACTION_DELAY_MS);
      return;
    }
    if (item.key === DRAWER_MENU_KEY_PERSONAL_INFO) {
      NavigationService.push(RouteName.PersonInfo);
      return;
    }
    if (item.key === DRAWER_MENU_KEY_HISTORY) {
      NavigationService.push(RouteName.ReadHistory);
      return;
    }
    if (item.key === DRAWER_MENU_KEY_LANGUAGE) {
      setTimeout((): void => {
        this.languageSheetOpen = true;
      }, DRAWER_CLOSE_ACTION_DELAY_MS);
      return;
    }
    if (item.key === DRAWER_MENU_KEY_CHECK_UPDATE) {
      setTimeout((): void => {
        this.checkUpdate();
      }, DRAWER_CLOSE_ACTION_DELAY_MS);
      return;
    }
    if (item.key === DRAWER_MENU_KEY_ABOUT) {
      setTimeout((): void => {
        this.aboutVersionText = this.getCurrentVersionName();
        this.aboutSheetOpen = true;
      }, DRAWER_CLOSE_ACTION_DELAY_MS);
      return;
    }
    if (item.key === DRAWER_MENU_KEY_LOGOUT) {
      this.handleLogout();
      return;
    }
  }

  private async submitFeedback(title: string, body: string): Promise<void> {
    this.feedbackSheetOpen = false;
    const res = await this.feedbackService.createIssue('CarGuo/GSYGithubAppCompose', title, body);
    if (res.result) {
      CommonToast.showShort(I18n('issueSubmitSuccess'));
      return;
    }
    const msg: string = res.msg !== null && res.msg !== undefined && res.msg.length > 0
      ? res.msg : I18n('issueSubmitFail');
    CommonToast.showShort(msg);
  }

  private async selectLanguage(option: string): Promise<void> {
    this.currentLanguage = option;
    try {
      await SettingPageHelper.applyLanguage(option, SettingPageDeps.getPrefs());
    } catch (_e) {
      CommonToast.showShort(I18n('netError'));
    }
  }

  private async checkUpdate(): Promise<void> {
    const res = await RepositoryService.fetchRepositoryRelease('CarGuo', 'GSYGithubAppCompose', 1);
    if (!res.result) {
      CommonToast.showShort(res.msg.length > 0 ? res.msg : I18n('netError'));
      return;
    }
    const latest: ReleaseListItem | null = res.data.length > 0 ? res.data[0] : null;
    if (latest === null || latest.tagName.length === 0) {
      CommonToast.showShort(I18n('listEmpty'));
      return;
    }
    const currentVersion: string = this.getCurrentVersionName();
    if (this.compareVersion(latest.tagName, currentVersion) <= 0) {
      CommonToast.showShort(I18n('newestVersion'));
      return;
    }
    const body: string = this.stripHtml(latest.bodyHtml);
    const message: string = `${I18n('updateDialogVersionLabel')}: ${latest.tagName}\n\n${body}`;
    CommonModal.confirm({
      title: I18n('updateDialogTitle'),
      message: message,
      okText: I18n('update'),
      cancelText: I18n('cancel'),
      cancelable: true,
    }, (): void => {
      this.openUrlInBrowser(latest.htmlUrl);
    });
  }

  private getCurrentVersionName(): string {
    try {
      const flags: number = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(flags);
      return info.versionName;
    } catch (_e) {
      return '0.0.0';
    }
  }

  private compareVersion(left: string, right: string): number {
    const leftParts: number[] = this.parseVersion(left);
    const rightParts: number[] = this.parseVersion(right);
    for (let i: number = 0; i < 3; i++) {
      if (leftParts[i] !== rightParts[i]) {
        return leftParts[i] > rightParts[i] ? 1 : -1;
      }
    }
    return 0;
  }

  private parseVersion(value: string): number[] {
    let cleaned: string = '';
    for (let i: number = 0; i < value.length; i++) {
      const ch: string = value.charAt(i);
      if ((ch >= '0' && ch <= '9') || ch === '.') {
        cleaned += ch;
      }
    }
    const rawParts: string[] = cleaned.split('.');
    const result: number[] = [0, 0, 0];
    for (let i: number = 0; i < rawParts.length && i < 3; i++) {
      const part: number = parseInt(rawParts[i], 10);
      result[i] = isNaN(part) ? 0 : part;
    }
    return result;
  }

  private stripHtml(value: string): string {
    let result: string = '';
    let inTag: boolean = false;
    for (let i: number = 0; i < value.length; i++) {
      const ch: string = value.charAt(i);
      if (ch === '<') {
        inTag = true;
        if (result.length > 0 && result.charAt(result.length - 1) !== ' ' && result.charAt(result.length - 1) !== '\n') {
          result += ' ';
        }
        continue;
      }
      if (ch === '>') {
        inTag = false;
        continue;
      }
      if (!inTag) {
        result += ch;
      }
    }
    return result
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .trim();
  }

  private openUrlInBrowser(url: string): void {
    if (url.length === 0) {
      return;
    }
    try {
      const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        uri: url,
      };
      ctx.startAbility(want).catch((_err: Error): void => {
        CommonToast.showShort(I18n('openLinkFailed'));
      });
    } catch (_e) {
      CommonToast.showShort(I18n('openLinkFailed'));
    }
  }

  // ---- 三个弹层内容（结构 / id 与旧 @CustomDialog 版本一致） ----

  @Builder
  aboutSheetBuilder(): void {
    Column() {
      Text(I18n('appName'))
        .id('drawer_about_dialog_title')
        .fontSize(GSYFontSize.middleWhite)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeManager.current().text)
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge, top: 18, bottom: 8 });
      Text(I18n('appVersionPrefix') + this.aboutVersionText)
        .id('drawer_about_dialog_text')
        .fontSize(GSYFontSize.normal)
        .fontColor(ThemeManager.current().text)
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge, top: 4, bottom: 18 });
      Row() {
        Button(I18n('update'))
          .id('drawer_about_dialog_confirm')
          .type(ButtonType.Capsule)
          .fontSize(GSYFontSize.normal)
          .fontColor(GSYColor.white)
          .backgroundColor(GSYColor.linkBlue)
          .height(40)
          .width(96)
          .onClick((): void => {
            this.aboutSheetOpen = false;
          });
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .padding({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge, bottom: 16 });
    }
    .id('drawer_about_dialog_root')
    .width('86%')
    .backgroundColor(ThemeManager.current().card)
    .borderRadius(12);
  }

  @Builder
  buildLanguageRow(item: DrawerLanguageOption, index: number): void {
    Row() {
      // 原生 Radio 替代旧 '●'/'○' 文本模拟；同一 group 自动互斥，选中态走原生 checked。
      Radio({ value: item.value, group: 'drawerLanguage' })
        .id('drawer_language_radio_' + item.value)
        .checked(this.currentLanguage === item.value)
        .radioStyle({
          checkedBackgroundColor: GSYColor.linkBlue,
          uncheckedBorderColor: GSYColor.textSubtle,
          indicatorColor: GSYColor.white,
        })
        .width(20)
        .height(20)
        .onChange((isChecked: boolean): void => {
          if (isChecked) {
            this.languageSheetOpen = false;
            this.selectLanguage(item.value);
          }
        });
      Text(item.label)
        .id('drawer_language_label_' + item.value)
        .fontSize(GSYFontSize.normal)
        .fontColor(ThemeManager.current().text)
        .layoutWeight(1)
        .margin({ left: GSYSpacing.halfEdge });
    }
    .id('drawer_language_option_' + item.value)
    .width('100%')
    .height(48)
    .padding({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge })
    .alignItems(VerticalAlign.Center)
    .onClick((): void => {
      this.languageSheetOpen = false;
      this.selectLanguage(item.value);
    });
    if (index < buildDrawerLanguageOptions().length - 1) {
      Divider().color(ThemeManager.current().divider).strokeWidth(0.5);
    }
  }

  @Builder
  languageSheetBuilder(): void {
    Column() {
      Text(I18n('drawerLanguage'))
        .id('drawer_language_dialog_title')
        .fontSize(GSYFontSize.middleWhite)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeManager.current().text)
        .width('100%')
        .textAlign(TextAlign.Start)
        .padding({ left: GSYSpacing.normalEdge, right: GSYSpacing.normalEdge, top: 16, bottom: 12 });
      Repeat<DrawerLanguageOption>(buildDrawerLanguageOptions())
        .each((obj: RepeatItem<DrawerLanguageOption>): void => {
          this.buildLanguageRow(obj.item, obj.index)
        })
        .key((item: DrawerLanguageOption): string => item.value);
    }
    .id('drawer_language_dialog_root')
    .width('86%')
    .backgroundColor(ThemeManager.current().card)
    .borderRadius(12);
  }

  @Builder
  feedbackSheetBuilder(): void {
    DrawerFeedbackSheet({
      dialogTitle: I18n('drawerFeedback'),
      titlePlaceholder: I18n('issueInputTipTitle'),
      bodyPlaceholder: I18n('feedbackHint'),
      onConfirm: (title: string, body: string): void => {
        this.submitFeedback(title, body);
      },
      onCancel: (): void => {
        this.feedbackSheetOpen = false;
      },
    });
  }

  @Builder
  buildMenuRow(item: DrawerMenuItem): void {
    if (item.key === DRAWER_MENU_KEY_LOGOUT) {
      Button() {
        Text(item.title)
          .id('drawer_menu_label_' + item.key)
          .fontSize(GSYFontSize.middleWhite)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeManager.current().onBrandText);
      }
      .id('drawer_menu_item_' + item.key)
      .type(ButtonType.Capsule)
      .backgroundColor(ThemeManager.current().danger)
      .width('90%')
      .height(56)
      .margin({ left: 18, right: 18, top: 24, bottom: 20 })
      .onClick((): void => {
        this.handleItem(item);
      });
    } else {
      Text(item.title)
        .id('drawer_menu_label_' + item.key)
        .fontSize(GSYFontSize.normal)
        .fontColor(ThemeManager.current().text)
        .width('100%')
        .height(64)
        .padding({ left: 32, right: 24 })
        .textAlign(TextAlign.Start)
        .onClick((): void => {
          this.handleItem(item);
        })
        .id('drawer_menu_item_' + item.key);
    }
  }

  build(): void {
    Column() {
      Column() {
        Repeat<DrawerMenuItem>(this.items.slice(0, this.items.length - 1))
          .each((obj: RepeatItem<DrawerMenuItem>): void => {
            this.buildMenuRow(obj.item);
          })
          .key((item: DrawerMenuItem): string => item.key);
        Blank()
          .layoutWeight(1);
        this.buildMenuRow(this.items[this.items.length - 1]);
      }
      .id('drawer_menu')
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(ThemeManager.current().card)
      .border({ width: { top: 1 }, color: ThemeManager.current().divider })
      .padding({ top: GSYSpacing.padding12 })
      .bindSheet(this.feedbackSheetOpen, this.feedbackSheetBuilder(), {
        height: 520,
        dragBar: false,
        showClose: false,
        backgroundColor: ThemeManager.current().card,
      });

      // bindSheet 单节点只能挂一个弹层，三个弹层分别挂在菜单根 / 两个 0 高锚点上。
      Row()
        .width(0)
        .height(0)
        .bindSheet(this.languageSheetOpen, this.languageSheetBuilder(), {
          height: 260,
          dragBar: false,
          showClose: false,
          backgroundColor: ThemeManager.current().card,
        });

      Row()
        .width(0)
        .height(0)
        .bindSheet(this.aboutSheetOpen, this.aboutSheetBuilder(), {
          height: 200,
          dragBar: false,
          showClose: false,
          backgroundColor: ThemeManager.current().card,
        });
    }
    .width('100%')
    .layoutWeight(1);
  }
}
