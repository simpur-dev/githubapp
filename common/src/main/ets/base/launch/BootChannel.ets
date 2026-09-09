/**
 * BootChannel —— 启动参数通道的存取介质（进程内 Map 单例）。
 *
 * 背景：EntryAbility 从 want.parameters 解析 boot* 参数后写入的 BOOT_*_KEY（键名见
 * [BootKeys.ets](./BootKeys.ets)），原先落在全局应用级 KV 存储上；本工程推行「全局状态统一走
 * 可观察单例 / 进程内通道」，BOOT 这类一次性启动参数既不是 UI 状态也不需要跨组件观察，
 * 因此下沉为普通 Map 单例，API 与原 AppStorage 用法一一对应：
 *
 *   - set(key, value)         ↔ 旧 AppStorage 字符串写入
 *   - get(key): string        ↔ 旧 AppStorage 字符串读取（缺失时返回 ''，等价 undefined 判空）
 *   - consume(key): string    ↔ 读并清除（详情页 tryAdoptBoot* 一次性消费场景）
 *   - has(key): boolean       ↔ 判断是否写过
 *
 * 注意：
 *   - 键名常量仍从 BootKeys 导出，对外协议（scenario-tour.sh 的 aa start --ps boot*）不变。
 *   - 600ms push / 1500ms 延迟清 key 的时序语义由调用方保持，本类只负责存取。
 */
class BootChannelImpl {
  private values: Map<string, string> = new Map<string, string>();

  set(key: string, value: string): void {
    this.values.set(key, value);
  }

  get(key: string): string {
    const v: string | undefined = this.values.get(key);
    return v !== undefined && v !== null ? v : '';
  }

  /**
   * 读并清：适合详情页 tryAdoptBoot* 的一次性消费；读到即删，天然避免脏数据残留。
   */
  consume(key: string): string {
    const v: string = this.get(key);
    this.values.delete(key);
    return v;
  }

  has(key: string): boolean {
    return this.values.has(key);
  }
}

export const BootChannel: BootChannelImpl = new BootChannelImpl();
