/**
 * TimeText —— 对齐 RN 端
 * [components/widget/TimeText.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/widget/TimeText.js)
 * 仅渲染 [TimeUtil.resolveTime](../utils/TimeUtil.ets) 的本地化结果。
 */

import { TimeUtil } from '../../base/utils/TimeUtil';
import { GSYFontSize } from '../style/Theme';
import { ThemeManager } from '../theme/ThemeManager';

@ComponentV2
export struct TimeText {
  @Param time: string = '';
  @Param marginTopValue: number = 0;
  @Param textId: string = '';

  build(): void {
    Text(TimeUtil.resolveTime(this.time))
      .id(this.textId.length > 0 ? this.textId : 'time_text')
      .fontSize(GSYFontSize.small)
      .fontColor(ThemeManager.current().textSecondary)
      .margin({ top: this.marginTopValue });
  }
}
