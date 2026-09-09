import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';

const BUNDLE: string = 'cn.gsy.githubapp';
const ABILITY: string = 'TestAbility';

export default function CommonComponentsTest(): void {
  describe('CommonComponentsTest', (): void => {
    beforeAll(async (): Promise<void> => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({
        bundleName: BUNDLE,
        abilityName: ABILITY,
      });
      const driver: Driver = Driver.create();
      await driver.delayMs(1500);
    });

    afterAll(async (): Promise<void> => {
      const driver: Driver = Driver.create();
      await driver.delayMs(300);
    });

    it('should_render_common_components_root', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      await driver.delayMs(500);
      const root: Component = await driver.findComponent(ON.id('common_components_root'));
      expect(root !== null).assertTrue();
    });

    it('should_render_appbar_with_title', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      const appbar: Component = await driver.findComponent(ON.id('appbar_root'));
      expect(appbar !== null).assertTrue();
      const title: Component = await driver.findComponent(ON.text('Common Components'));
      expect(title !== null).assertTrue();
    });

    it('should_render_action_buttons', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      const btnLoading: Component = await driver.findComponent(ON.id('btn_loading'));
      const btnConfirm: Component = await driver.findComponent(ON.id('btn_confirm'));
      const btnOptions: Component = await driver.findComponent(ON.id('btn_options'));
      const btnPrompt: Component = await driver.findComponent(ON.id('btn_prompt'));
      const btnRefresh: Component = await driver.findComponent(ON.id('btn_refresh_state'));
      expect(btnLoading !== null).assertTrue();
      expect(btnConfirm !== null).assertTrue();
      expect(btnOptions !== null).assertTrue();
      expect(btnPrompt !== null).assertTrue();
      expect(btnRefresh !== null).assertTrue();
    });

    it('should_render_pull_load_more_list_rows', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      const list: Component = await driver.findComponent(ON.id('pull_list'));
      expect(list !== null).assertTrue();
      const row0: Component = await driver.findComponent(ON.id('row_0'));
      const row1: Component = await driver.findComponent(ON.id('row_1'));
      const row2: Component = await driver.findComponent(ON.id('row_2'));
      expect(row0 !== null).assertTrue();
      expect(row1 !== null).assertTrue();
      expect(row2 !== null).assertTrue();
    });

    // 旧版断言自绘 overlay（pull_refresh_overlay / pull_refresh_indicator）与
    // PullLoadMoreController 状态机；V2 受控组件改用原生 Refresh 指示器，
    // 本用例保持等价语义：编程式刷新期间页面存活、结束后列表仍在。
    it('should_survive_programmatic_refresh_state', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      const btnRefresh: Component = await driver.findComponent(ON.id('btn_refresh_state'));
      await btnRefresh.click();
      await driver.delayMs(150);
      const listDuringRefresh: Component = await driver.findComponent(ON.id('pull_list'));
      expect(listDuringRefresh !== null).assertTrue();
      await driver.delayMs(700);
      const listAfterRefresh: Component = await driver.findComponent(ON.id('pull_list'));
      expect(listAfterRefresh !== null).assertTrue();
    });

    it('should_show_loading_modal', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      const btnLoading: Component = await driver.findComponent(ON.id('btn_loading'));
      await btnLoading.click();
      await driver.delayMs(200);
      const loadingText: Component = await driver.findComponent(ON.text('loading-ok'));
      expect(loadingText !== null).assertTrue();
      await driver.delayMs(900);
    });

    it('should_show_confirm_modal', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      const btnConfirm: Component = await driver.findComponent(ON.id('btn_confirm'));
      await btnConfirm.click();
      await driver.delayMs(300);
      const message: Component = await driver.findComponent(ON.text('confirm-msg'));
      expect(message !== null).assertTrue();
      const cancelBtn: Component = await driver.findComponent(ON.text('Cancel'));
      if (cancelBtn !== null) {
        await cancelBtn.click();
      }
      await driver.delayMs(200);
    });

    it('should_show_options_modal', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      const btnOptions: Component = await driver.findComponent(ON.id('btn_options'));
      await btnOptions.click();
      await driver.delayMs(300);
      const optionA: Component = await driver.findComponent(ON.text('OptionA'));
      expect(optionA !== null).assertTrue();
      await driver.pressBack();
      await driver.delayMs(200);
    });
  });
}
