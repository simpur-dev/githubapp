import uiMaterial from '@ohos.arkui.uiMaterial';
import { ThemeManager } from '../theme/ThemeManager';

export interface CommonOptionItem {
  itemName: string;
  itemTextColor?: ResourceColor;
}

export interface ConfirmOptions {
  title?: string;
  message: string;
  okText?: string;
  cancelText?: string;
  cancelable?: boolean;
}

export interface OptionListOptions {
  title?: string;
  items: CommonOptionItem[];
}

/**
 * 输入弹窗已迁移：V2 时代统一走 common/ui 的 PromptSheet（bindSheet 实现），
 * static 方法内 new CustomDialogController 静默不弹的坑（KI-046/047）就此物理消除。
 */

/**
 * 沉浸光感系统材质（API 26+）：弹窗底板交给系统材质，深浅色自适配；
 * 设备不支持时返回 undefined，弹窗退回默认主题背景（ThemeControl.setDefaultTheme 已接官方主题）。
 */
export function dialogMaterial(): uiMaterial.Material | undefined {
  try {
    if (uiMaterial.isImmersiveMaterialSupported()) {
      const material: uiMaterial.ImmersiveMaterial =
        new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.REGULAR, applyShadow: true });
      return material;
    }
  } catch (_e) {
  }
  return undefined;
}

export class CommonModal {
  static confirm(options: ConfirmOptions, onConfirm: () => void, onCancel?: () => void): void {
    AlertDialog.show({
      title: options.title ?? '',
      message: options.message,
      autoCancel: options.cancelable ?? true,
      alignment: DialogAlignment.Center,
      systemMaterial: dialogMaterial(),
      primaryButton: {
        value: options.cancelText ?? 'Cancel',
        action: (): void => {
          if (onCancel) {
            onCancel();
          }
        },
      },
      secondaryButton: {
        value: options.okText ?? 'OK',
        fontColor: ThemeManager.current().accent,
        action: (): void => {
          onConfirm();
        },
      },
      cancel: (): void => {
        if (onCancel) {
          onCancel();
        }
      },
    });
  }

  static options(options: OptionListOptions, onSelect: (index: number, item: CommonOptionItem) => void): void {
    const sheets: SheetInfo[] = options.items.map((item: CommonOptionItem, idx: number): SheetInfo => {
      return {
        title: item.itemName,
        action: (): void => {
          onSelect(idx, item);
        },
      };
    });
    ActionSheet.show({
      title: options.title ?? '',
      message: '',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      systemMaterial: dialogMaterial(),
      sheets: sheets,
    });
  }
}
