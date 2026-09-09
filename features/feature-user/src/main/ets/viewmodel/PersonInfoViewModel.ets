/**
 * PersonInfoViewModel —— 个人信息编辑页状态与编排（R9 V2 + MVVM）。
 *
 * @Trace UI 状态：6 个可编辑字段（name/email/blog/company/location/bio）、
 * 提交中的字段（busyField）、编辑弹层参数（editField/editLabel/editValue + editSheetOpen）、
 * 下拉刷新态（refreshing/loadingMore/noMore）。
 * 数据来源：GlobalAuthStore 单例（登录用户直读，原 auth.userInfo 镜像通道已移除）；
 * 提交走 UserService.updateUser 静态方法（PATCH /user），刷新走 MyService.refreshMe。
 */
import {
  AuthUserInfo,
  GlobalAuthStore,
} from 'common';
import {
  UserService,
  UpdateUserResult,
} from 'common';
import {
  MyService,
  RefreshMeResult,
} from 'common';
import { UserDao } from 'common';
import { GlobalMyStore } from 'common';
import { CommonToast } from 'common';
import { I18n } from 'common';
import { Logger } from 'common';

export const PERSON_INFO_FIELD_NAME: string = 'name';
export const PERSON_INFO_FIELD_EMAIL: string = 'email';
export const PERSON_INFO_FIELD_BLOG: string = 'blog';
export const PERSON_INFO_FIELD_COMPANY: string = 'company';
export const PERSON_INFO_FIELD_LOCATION: string = 'location';
export const PERSON_INFO_FIELD_BIO: string = 'bio';

@ObservedV2
export class PersonInfoViewModel {
  /** 6 个可编辑字段（页面行内展示值）。 */
  @Trace name: string = '';
  @Trace email: string = '';
  @Trace blog: string = '';
  @Trace company: string = '';
  @Trace location: string = '';
  @Trace bio: string = '';
  /** 当前提交中的字段（非空时忽略新的编辑/提交）。 */
  @Trace busyField: string = '';
  /** 编辑弹层（bindSheet）参数（开合状态归 View 层 @Local，bindSheet 双向绑定需要）。 */
  @Trace editField: string = '';
  @Trace editLabel: string = '';
  @Trace editValue: string = '';
  /** 下拉刷新态（PullLoadMoreList 受控参数）。 */
  @Trace refreshing: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace noMore: boolean = true;

  private service: MyService = new MyService(GlobalMyStore, GlobalAuthStore, new UserDao());

  /** 进入页面时从 GlobalAuthStore 读一次（View aboutToAppear 调用）。 */
  init(): void {
    this.applyUserToState();
  }

  /** 登录用户直读 GlobalAuthStore 单例。 */
  private parseUser(): AuthUserInfo | null {
    if (GlobalAuthStore.userInfo !== null && GlobalAuthStore.userInfo !== undefined) {
      return GlobalAuthStore.userInfo;
    }
    return null;
  }

  private applyUserToState(): void {
    const user: AuthUserInfo | null = this.parseUser();
    if (user === null) {
      return;
    }
    this.name = user.name;
    this.blog = user.blog;
    this.company = user.company;
    this.location = user.location;
    this.bio = user.bio;
    // GitHub /user 接口的 email 字段 AuthUserInfo 暂未持有 → 从 raw json 直读，回退空串
    this.email = PersonInfoViewModel.readEmailFromRaw(user.raw);
  }

  private static readEmailFromRaw(raw: string): string {
    if (raw === undefined || raw === null || raw.length === 0) {
      return '';
    }
    try {
      const obj: Object = JSON.parse(raw) as Object;
      const rec: Record<string, Object> = obj as Record<string, Object>;
      const v: Object | undefined = rec['email'];
      if (v === undefined || v === null) {
        return '';
      }
      return String(v);
    } catch (_e) {
      return '';
    }
  }

  /**
   * 行点击 → 准备编辑弹层参数（V2 走 bindSheet，不再用 CustomDialogController）。
   * 返回 true 表示允许打开（View 层据此置 @Local 开合状态）。
   */
  openEdit(field: string, oldValue: string, label: string): boolean {
    Logger.i('person/info/edit', 'field=' + field + ' oldLen=' + oldValue.length);
    if (this.busyField.length > 0) {
      return false;
    }
    this.editField = field;
    this.editLabel = label;
    this.editValue = oldValue;
    return true;
  }

  /** 弹层确定 → PATCH /user，成功后更新本地字段并同步 GlobalAuthStore。 */
  async submitEdit(newValue: string): Promise<void> {
    const field: string = this.editField;
    if (field.length === 0 || this.busyField.length > 0) {
      return;
    }
    this.busyField = field;
    const result: UpdateUserResult = await UserService.updateUser(field, newValue, new UserDao());
    Logger.i('person/info/patch',
      'field=' + field + ' code=' + result.code + ' result=' + result.result);
    if (result.result) {
      this.applyFieldValue(field, newValue);
      this.syncAuthUserField(field, newValue);
      CommonToast.showShort(I18n('userInfoUpdateSuccess'));
    } else {
      CommonToast.showShort(result.msg.length > 0 ? result.msg : I18n('userInfoUpdateFail'));
    }
    this.busyField = '';
  }

  private applyFieldValue(field: string, value: string): void {
    if (field === PERSON_INFO_FIELD_NAME) {
      this.name = value;
    } else if (field === PERSON_INFO_FIELD_EMAIL) {
      this.email = value;
    } else if (field === PERSON_INFO_FIELD_BLOG) {
      this.blog = value;
    } else if (field === PERSON_INFO_FIELD_COMPANY) {
      this.company = value;
    } else if (field === PERSON_INFO_FIELD_LOCATION) {
      this.location = value;
    } else if (field === PERSON_INFO_FIELD_BIO) {
      this.bio = value;
    }
  }

  /** 下拉刷新：重新拉取登录用户并回填 6 字段。 */
  async refresh(): Promise<void> {
    this.refreshing = true;
    this.loadingMore = false;
    this.noMore = true;
    const result: RefreshMeResult = await this.service.refreshMe();
    if (result.result && result.data !== null) {
      this.applyUserToState();
      this.refreshing = false;
      return;
    }
    this.refreshing = false;
    if (result.msg.length > 0) {
      CommonToast.showShort(result.msg);
    }
  }

  /** 加载更多无分页语义，直接收起 footer 状态。 */
  loadMore(): void {
    this.loadingMore = false;
    this.noMore = true;
  }

  private syncAuthUserField(field: string, value: string): void {
    const current: AuthUserInfo | null = this.parseUser();
    if (current === null || current.raw.length === 0) {
      return;
    }
    try {
      const rawObj: Record<string, Object> = JSON.parse(current.raw) as Record<string, Object>;
      rawObj[field] = value;
      const raw: string = JSON.stringify(rawObj);
      const updated: AuthUserInfo | null = AuthUserInfo.fromJson(raw);
      if (updated !== null) {
        // setUser 写单例后由 EVENT_AUTH_STATE_CHANGED 驱动 DrawerHeader 等消费方刷新，
        // 无需再同步任何镜像键。
        GlobalAuthStore.setUser(GlobalAuthStore.token, updated);
      }
    } catch (_e) {
    }
  }
}
