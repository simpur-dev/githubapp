import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';

/**
 * NotifyLongPressUiTest —— 长按快捷菜单端到端验证（R12 KI-R12-009）。
 *
 * NotifyHostPage mock 数据：row0 未读（host-thread-zero）/ row1 已读。
 * 流程：LongPressGesture 500ms 长按 row0 → 受控 bindMenu 弹出
 * → 点击"标记已读" → mock PATCH 204 → 行状态翻转为已读。
 * 文案断言双语兜底（测试环境语言不确定）。
 */
const BUNDLE: string = 'cn.gsy.githubapp';
const ABILITY: string = 'TestAbility';
const HOST_PAGE_PATH: string = 'pages/NotifyHostPage';

async function startPage(targetPage: string): Promise<void> {
  const delegator = abilityDelegatorRegistry.getAbilityDelegator();
  await delegator.startAbility({
    bundleName: BUNDLE,
    abilityName: ABILITY,
    parameters: {
      targetPage: targetPage,
    },
  });
  const driver: Driver = Driver.create();
  await driver.delayMs(1500);
}

export default function NotifyLongPressUiTest(): void {
  describe('NotifyLongPressUiTest', (): void => {
    beforeAll(async (): Promise<void> => {
      await startPage(HOST_PAGE_PATH);
    });

    afterAll(async (): Promise<void> => {
      const driver: Driver = Driver.create();
      await driver.delayMs(300);
    });

    /** 双语文案查找：至少一个命中（菜单项随系统语言变化）。 */
    async function findAnyText(driver: Driver, texts: string[]): Promise<Component | null> {
      for (let i: number = 0; i < texts.length; i++) {
        try {
          const c: Component = await driver.findComponent(ON.text(texts[i]));
          if (c !== null) {
            return c;
          }
        } catch (_e) {
          // 未命中继续尝试下一文案
        }
      }
      return null;
    }

    it('long_press_row0_opens_menu_and_mark_read_takes_effect', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1200);

      const row0: Component = await driver.findComponent(ON.id('notify_row_0'));
      expect(row0 !== null).assertTrue();
      const rect = await row0.getBounds();
      const cx: number = (rect.left + rect.right) / 2;
      const cy: number = (rect.top + rect.bottom) / 2;

      // 长按前：状态文本含未读标记
      const statusBefore: Component = await driver.findComponent(ON.id('notify_row_status_0'));
      const beforeText: string = await statusBefore.getText();
      expect(beforeText.indexOf('Unread') >= 0 || beforeText.indexOf('未读') >= 0).assertTrue();

      // 长按触发 LongPressGesture → 受控 bindMenu 弹出
      await driver.longClick(cx, cy);
      await driver.delayMs(1000);

      // 菜单弹出（双语兜底断言）
      const markReadItem: Component | null =
        await findAnyText(driver, ['Mark read', '标记已读']);
      expect(markReadItem !== null).assertTrue();
      const openDetailItem: Component | null =
        await findAnyText(driver, ['Open detail', '打开详情']);
      expect(openDetailItem !== null).assertTrue();

      // 点击"标记已读" → mock PATCH 204 → 行状态翻转为已读
      if (markReadItem !== null) {
        await markReadItem.click();
        await driver.delayMs(1200);
        const statusAfter: Component = await driver.findComponent(ON.id('notify_row_status_0'));
        const afterText: string = await statusAfter.getText();
        expect(afterText.indexOf('Unread') < 0 && afterText.indexOf('未读') < 0).assertTrue();
      }
    });
  });
}
