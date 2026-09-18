/**
 * NotificationUtil —— 系统原生通知能力接入（R12，客户端闭环部分）。
 *
 * 链路：应用内轮询 GitHub 通知接口（NotifyViewModel.refresh）→ 检测新未读 →
 * notificationManager.publish 本地系统通知，请求体携带 badgeNumber（API 26 官方
 * 角标路径：setBadgeNumber 已 deprecated，角标随通知发布更新）。
 *
 * 分工边界：应用前台/可见时的通知提醒与角标同步由本文件闭环；
 * 应用退后台后的实时推送需要服务端推送通道（Push Kit + GitHub webhook 桥），
 * 属服务端依赖，见 harness/R12/docs/05 §3.2。
 */
import notificationManager from '@ohos.notificationManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'NotificationUtil';
/** 应用内固定通知 id：重复发布覆盖旧通知，避免通知中心堆积。 */
const UNREAD_NOTIFY_ID: number = 1001;

/** 查询系统通知授权；异常（如能力不支持）按未授权处理。 */
export async function isNotificationEnabled(): Promise<boolean> {
  try {
    return await notificationManager.isNotificationEnabled();
  } catch (e) {
    hilog.warn(0x0666, TAG, 'isNotificationEnabled fail %{public}s', (e as Error).message);
    return false;
  }
}

/** 请求通知授权（系统弹窗；已授权时立即返回 true）。 */
export async function requestNotificationPermission(): Promise<boolean> {
  try {
    const enabled: boolean = await isNotificationEnabled();
    if (enabled) {
      return true;
    }
    await notificationManager.requestEnableNotification();
    return await isNotificationEnabled();
  } catch (e) {
    hilog.warn(0x0666, TAG, 'requestEnableNotification fail %{public}s', (e as Error).message);
    return false;
  }
}

/**
 * 发布"N 条未读通知"系统通知并同步角标。
 * badgeNumber 直接决定桌面图标角标值（<=0 清除，>99 显示 99+）。
 */
export async function publishUnreadBadgeNotification(unreadCount: number, title: string, text: string): Promise<void> {
  try {
    const request: notificationManager.NotificationRequest = {
      id: UNREAD_NOTIFY_ID,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        // BASIC_TEXT 布局的标题/正文在 normal 字段（NotificationBasicContent）
        normal: {
          title: title,
          text: text,
        },
      },
      badgeNumber: unreadCount,
    };
    await notificationManager.publish(request);
    hilog.info(0x0666, TAG, 'publish unread=%{public}d', unreadCount);
  } catch (e) {
    hilog.warn(0x0666, TAG, 'publish fail %{public}s', (e as Error).message);
  }
}
