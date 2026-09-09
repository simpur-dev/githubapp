import { GSYColor, GSYFontSize, GSYSpacing } from '../style/Theme';

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

export class CommonModal {
  static confirm(options: ConfirmOptions, onConfirm: () => void, onCancel?: () => void): void {
    AlertDialog.show({
      title: options.title ?? '',
      message: options.message,
      autoCancel: options.cancelable ?? true,
      alignment: DialogAlignment.Center,
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
        fontColor: GSYColor.materialBlue,
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
      sheets: sheets,
    });
  }
}
