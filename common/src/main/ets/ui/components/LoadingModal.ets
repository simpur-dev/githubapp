import { UIContext } from '@ohos.arkui.UIContext';
import promptAction from '@ohos.promptAction';
import { GSYColor, GSYFontSize, GSYSpacing } from '../style/Theme';

/**
 * LoadingModal —— 全局加载弹层（static show/hide 单例入口，签名与旧版一致）。
 *
 * R9 V2：不再用 @CustomDialog + static 内 new CustomDialogController
 * （KI-046：CustomDialogController 必须在组件 build 上下文创建，static 里静默不弹）。
 * 改为 UIContext.openCustomDialog(options) → 返回 dialogId，hide 走 closeCustomDialog(id)。
 * UIContext 由 UI 根注入：AppNavigator（生产）/ 测试宿主页 aboutToAppear 调
 * LoadingModal.attach(this.getUIContext())，同 NavigationService.setStack 注入模式。
 */

class LoadingDialogContentParams {
  text: string = '';
}

@Builder
function loadingDialogContent(params: LoadingDialogContentParams): void {
  Column() {
    LoadingProgress()
      .width(48)
      .height(48)
      .color(GSYColor.white);
    Text(params.text)
      .fontSize(GSYFontSize.small)
      .fontColor(GSYColor.white)
      .margin({ top: GSYSpacing.padding12 });
  }
  .width(120)
  .height(120)
  .borderRadius(8)
  .backgroundColor(GSYColor.loadingMaskBg)
  .justifyContent(FlexAlign.Center)
  .alignItems(HorizontalAlign.Center);
}

class LoadingHolder {
  uiContext: UIContext | null = null;
  dialogId: number = -1;
  visible: boolean = false;
}

export class LoadingModal {
  private static holder: LoadingHolder = new LoadingHolder();

  /** 由 UI 根（AppNavigator / 测试宿主页）在 aboutToAppear 注入一次。 */
  static attach(uiContext: UIContext): void {
    LoadingModal.holder.uiContext = uiContext;
  }

  static show(text: string = 'Loading…', cancelable: boolean = true): void {
    const ctx: UIContext | null = LoadingModal.holder.uiContext;
    if (ctx === null || LoadingModal.holder.visible) {
      return;
    }
    const params: LoadingDialogContentParams = new LoadingDialogContentParams();
    params.text = text;
    const options: promptAction.CustomDialogOptions = {
      builder: (): void => {
        loadingDialogContent(params);
      },
      alignment: DialogAlignment.Center,
      isModal: true,
      autoCancel: cancelable,
      onDidDisappear: (): void => {
        // autoCancel 点外部关闭与 closeCustomDialog 都会走到这里，统一清句柄。
        LoadingModal.holder.visible = false;
        LoadingModal.holder.dialogId = -1;
      },
    };
    LoadingModal.holder.visible = true;
    ctx.getPromptAction().openCustomDialog(options)
      .then((dialogId: number): void => {
        LoadingModal.holder.dialogId = dialogId;
      })
      .catch((_err: Error): void => {
        LoadingModal.holder.visible = false;
        LoadingModal.holder.dialogId = -1;
      });
  }

  static hide(): void {
    const ctx: UIContext | null = LoadingModal.holder.uiContext;
    if (ctx !== null && LoadingModal.holder.dialogId >= 0) {
      try {
        ctx.getPromptAction().closeCustomDialog(LoadingModal.holder.dialogId);
      } catch (_e) {
        // 句柄已被 autoCancel 关闭等场景：忽略，状态照常复位。
      }
    }
    LoadingModal.holder.dialogId = -1;
    LoadingModal.holder.visible = false;
  }

  static isShowing(): boolean {
    return LoadingModal.holder.visible;
  }
}
