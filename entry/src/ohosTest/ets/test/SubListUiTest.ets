import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';
import { Driver, ON, Component } from '@ohos.UiTest';
import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';

const BUNDLE: string = 'cn.gsy.githubapp';
const ABILITY: string = 'TestAbility';
const HOST_PAGE_PATH: string = 'pages/SubListHostPage';

// 原 SubList 宿主走 RepositoryStarPage（已删除），现宿主直接驱动生产路由
// CommonListPage（dataType=repo_star），断言 id 前缀对应改为 common_list_repo_star_*。
const ROOT_ID: string = 'common_list_repo_star_root';
const LIST_ID: string = 'common_list_repo_star_pull_list';
const TITLE_ID: string = 'common_list_repo_star_title';
const ROW0_ID: string = 'common_list_repo_star_user_0';
const ROW0_LOGIN_ID: string = 'common_list_repo_star_user_0_login';

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

export default function SubListUiTest(): void {
  describe('SubListUiTest', (): void => {
    beforeAll(async (): Promise<void> => {
      await startPage(HOST_PAGE_PATH);
    });

    afterAll(async (): Promise<void> => {
      const driver: Driver = Driver.create();
      await driver.delayMs(300);
    });

    it('should_render_repo_star_root', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      await driver.delayMs(1200);
      const root: Component = await driver.findComponent(ON.id(ROOT_ID));
      expect(root !== null).assertTrue();
    });

    it('should_render_repo_star_pull_list_and_header', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      await driver.delayMs(800);
      const list: Component = await driver.findComponent(ON.id(LIST_ID));
      expect(list !== null).assertTrue();

      const title: Component = await driver.findComponent(ON.id(TITLE_ID));
      expect(title !== null).assertTrue();
      const txt: string = await title.getText();
      expect(txt.length > 0).assertTrue();
    });

    it('should_render_first_user_row_with_login', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      await driver.delayMs(800);
      const row0: Component = await driver.findComponent(ON.id(ROW0_ID));
      expect(row0 !== null).assertTrue();

      const login0: Component = await driver.findComponent(ON.id(ROW0_LOGIN_ID));
      expect(login0 !== null).assertTrue();
      expect(await login0.getText()).assertEqual('StarUserOne');
    });

    it('should_render_second_user_row_with_login', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      const row1: Component = await driver.findComponent(ON.id('common_list_repo_star_user_1'));
      expect(row1 !== null).assertTrue();

      const login1: Component = await driver.findComponent(ON.id('common_list_repo_star_user_1_login'));
      expect(login1 !== null).assertTrue();
      expect(await login1.getText()).assertEqual('StarUserTwo');
    });

    it('should_navigate_to_user_detail_when_row_clicked', 0, async (): Promise<void> => {
      const driver: Driver = Driver.create();
      await driver.delayMs(400);
      const row0: Component = await driver.findComponent(ON.id(ROW0_ID));
      expect(row0 !== null).assertTrue();
      await row0.click();
      await driver.delayMs(1200);

      const userRoot: Component = await driver.findComponent(ON.id('user_detail_root'));
      expect(userRoot !== null).assertTrue();

      const userLogin: Component = await driver.findComponent(ON.id('user_detail_login'));
      expect(userLogin !== null).assertTrue();
      expect(await userLogin.getText()).assertEqual('StarUserOne');
    });
  });
}
