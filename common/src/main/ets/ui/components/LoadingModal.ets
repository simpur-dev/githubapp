import { UIContext } from '@ohos.arkui.UIContext';
import { ComponentContent } from '@kit.ArkUI';
import promptAction from '@ohos.promptAction';
import { GSYColor, GSYFontSize, GSYSpacing } from '../style/Theme';

/**
 * LoadingModal —— 全局加载弹层（static show/hide 单例入口，签名与旧版一致）。
 *
 * R9 V2：不再用 @CustomDialog + static 内 new CustomDialogController
 * （KI-046：CustomDialogController 必须在组件 build 上下文创建，static 里静默不弹）。
 * 改为 ComponentContent + wrapBuilder + promptAction.openCustomDialog(content)。
 * 注意：builder 不能传"匿名函数里再调 @Builder"的闭包——@Builder 编译产物依赖
 * observeComponentCreation2 的组件上下文，脱离组件树调用会 TypeError 闪退（R9 真机模拟器已踩）。
 * UIContext 由 UI 根注入：AppNavigator（生产）/ 测试宿主页 aboutToAppear 调
 * LoadingModal.attach(this.getUIContext())，同 NavigationService.setStack 注入模式。
 */

class LoadingDialogContentParams {
  text: string = '';
}

@Builder
export function loadingDialogContent(params: LoadingDialogContentParams): void {
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
  content: ComponentContent<LoadingDialogContentParams> | null = null;
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
    const content: ComponentContent<LoadingDialogContentParams> =
      new ComponentContent(ctx, wrapBuilder(loadingDialogContent), params);
    LoadingModal.holder.content = content;
    LoadingModal.holder.visible = true;
    ctx.getPromptAction().openCustomDialog(content, {
      alignment: DialogAlignment.Center,
      isModal: true,
      autoCancel: cancelable,
      onDidDisappear: (): void => {
        // autoCancel 点外部关闭与 closeCustomDialog 都会走到这里，统一清句柄。
        LoadingModal.holder.visible = false;
        LoadingModal.holder.content = null;
      },
    })
      .then((): void => {
        // 打开成功（本 SDK 该重载返回 void，关闭走 content 句柄）。
      })
      .catch((_err: Error): void => {
        LoadingModal.holder.visible = false;
        LoadingModal.holder.content = null;
      });
  }

  static hide(): void {
    const ctx: UIContext | null = LoadingModal.holder.uiContext;
    if (ctx !== null && LoadingModal.holder.content !== null) {
      try {
        ctx.getPromptAction().closeCustomDialog(LoadingModal.holder.content);
      } catch (_e) {
        // 句柄已被 autoCancel 关闭等场景：忽略，状态照常复位。
      }
    }
    LoadingModal.holder.content = null;
    LoadingModal.holder.visible = false;
  }

  static isShowing(): boolean {
    return LoadingModal.holder.visible;
  }
}
