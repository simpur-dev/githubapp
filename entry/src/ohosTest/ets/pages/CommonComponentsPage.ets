import { AppBar, AppBarAction } from 'common';
import { CommonToast } from 'common';
import { LoadingModal } from 'common';
import { CommonModal, CommonOptionItem } from 'common';
import {
  PullLoadMoreList,
} from 'common';

interface DemoItem {
  id: number;
  text: string;
}

// 生产侧 PromptDialog 已删除（R9 阶段0）：输入弹窗 V2 时代统一走 bindSheet。
// 测试演示页自持一个最小 @CustomDialog，演示 component-scope controller 范式（KI-046）。
@CustomDialog
struct DemoInputDialog {
  controller?: CustomDialogController;
  onConfirm: (text: string) => void = (): void => {};
  @State current: string = '';

  build(): void {
    Column() {
      TextInput({ text: this.current, placeholder: 'something' })
        .height(44)
        .onChange((value: string): void => {
          this.current = value;
        });
      Row() {
        Button('Cancel').layoutWeight(1).onClick((): void => {
          if (this.controller) {
            this.controller.close();
          }
        });
        Button('OK').layoutWeight(1).onClick((): void => {
          const value: string = this.current;
          if (this.controller) {
            this.controller.close();
          }
          this.onConfirm(value);
        });
      }
      .width('100%')
      .height(44)
      .margin({ top: 12 });
    }
    .padding(20)
    .borderRadius(8)
    .width(300)
    .backgroundColor(Color.White);
  }
}

@Entry
@Component
struct CommonComponentsPage {
  @State data: DemoItem[] = [
    { id: 1, text: 'Item 1' },
    { id: 2, text: 'Item 2' },
    { id: 3, text: 'Item 3' },
  ];
  // 受控列表状态（R9 V2 契约）：旧 PullLoadMoreController 已删除。
  @State plmRefreshing: boolean = false;
  @State plmLoadingMore: boolean = false;
  @State plmNoMore: boolean = false;

  // 输入弹窗必须在 @Component 实例 build 上下文里 new CustomDialogController 才能弹。
  // 不能在 static 函数内 new（KI-046 已暴露过 → KI-047 收尾把 CommonModal.prompt 删掉）。
  private promptController: CustomDialogController = new CustomDialogController({
    builder: DemoInputDialog({
      onConfirm: (text: string): void => {
        CommonToast.showShort(text);
      },
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true,
  });

  aboutToAppear(): void {
    // LoadingModal 静态入口的 UIContext 注入（同生产 AppNavigator）。
    LoadingModal.attach(this.getUIContext());
  }

  @Builder
  rowBuilder(item: DemoItem, index: number): void {
    Row() {
      Text(item.text)
        .fontSize(16)
        .fontColor('#222222');
    }
    .id('row_' + index.toString())
    .width('100%')
    .height(48)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center);
  }

  build(): void {
    Column() {
      AppBar({
        title: 'Common Components',
        subtitle: 'ohosTest harness',
        showBack: true,
        rightActions: [
          {
            text: 'Toast',
            onAction: (): void => {
              CommonToast.showShort('toast-ok');
            },
          } as AppBarAction,
        ],
      })
        .id('appbar_root');

      Row() {
        Button('Loading')
          .id('btn_loading')
          .onClick((): void => {
            LoadingModal.show('loading-ok');
            setTimeout((): void => {
              LoadingModal.hide();
            }, 800);
          });
        Button('Confirm')
          .id('btn_confirm')
          .margin({ left: 8 })
          .onClick((): void => {
            CommonModal.confirm({
              title: 'Tip',
              message: 'confirm-msg',
            }, (): void => {
              CommonToast.showShort('confirmed');
            });
          });
        Button('Options')
          .id('btn_options')
          .margin({ left: 8 })
          .onClick((): void => {
            const items: CommonOptionItem[] = [
              { itemName: 'OptionA' },
              { itemName: 'OptionB' },
            ];
            CommonModal.options({ title: 'Pick', items: items }, (_idx: number, item: CommonOptionItem): void => {
              CommonToast.showShort(item.itemName);
            });
          });
        Button('Prompt')
          .id('btn_prompt')
          .margin({ left: 8 })
          .onClick((): void => {
            this.promptController.open();
          });
        Button('Refresh')
          .id('btn_refresh_state')
          .margin({ left: 8 })
          .onClick((): void => {
            this.plmRefreshing = true;
            this.plmLoadingMore = false;
            this.plmNoMore = false;
            setTimeout((): void => {
              this.plmRefreshing = false;
              this.plmLoadingMore = false;
              this.plmNoMore = false;
            }, 600);
          });
      }
      .width('100%')
      .padding(12)
      .id('action_row');

      PullLoadMoreList({
        dataSource: this.data,
        refreshing: this.plmRefreshing,
        loadingMore: this.plmLoadingMore,
        noMore: this.plmNoMore,
        renderRow: (item: Object, index: number): void => this.rowBuilder(item as DemoItem, index),
        onRefresh: (): void => {
          setTimeout((): void => {
            this.plmRefreshing = false;
            this.plmLoadingMore = false;
            this.plmNoMore = false;
          }, 200);
        },
        onLoadMore: (): void => {
          setTimeout((): void => {
            this.plmLoadingMore = false;
            this.plmNoMore = true;
          }, 200);
        },
      })
        .id('pull_list')
        .layoutWeight(1);
    }
    .id('common_components_root')
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF');
  }
}
