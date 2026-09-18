/**
 * TabIcon —— 对齐 RN 端
 * [components/widget/TabIcon.js](https://github.com/CarGuo/GSYGithubApp/blob/master/app/components/widget/TabIcon.js)
 *
 * RN 端 TabIcon render 同时输出图标 + 文字（L52-L55）：
 *   <View style={styles.centered}>
 *     <Icon name={iconPath} size={tabIconSize=20} color={selectedColor}/>
 *     <Text style={[{color}, {fontSize: smallTextSize=14}]}>{title}</Text>
 *   </View>
 * 颜色：focused → primaryColor (#24292e)；否则 #a6aaaf
 *
 * iconPath 映射（RN 端 react-native-vector-icons/Feather -> 系统 SymbolGlyph）：
 *   R12 P1 对齐官方五 Tab 图标（key 字符串与 tab_icon_* 测试 id 保持不变）：
 *   aperture（首页 Feed）   -> sys.symbol.house
 *   activity（探索）        -> sys.symbol.compass
 *   user（个人资料）        -> sys.symbol.person
 *   code（代码，R12 新增）  -> sys.symbol.code
 *   notifications（通知）   -> sys.symbol.bell
 * 只使用系统符号表中确定存在的资源名。
 */

import { GSYFontSize, GSYIconSize } from 'common';
import { ThemeManager } from 'common';

export type TabIconKey = 'aperture' | 'activity' | 'user' | 'code' | 'notifications';

@ComponentV2
export struct TabIcon {
  @Param iconKey: TabIconKey = 'aperture';
  @Param selected: boolean = false;
  @Param title: string = '';
  iconSize: number = GSYIconSize.tab;

  private resolveColor(): string {
    // 选中 = 主文字色，未选中 = 次文字色；随 palette 深浅色自适应。
    return this.selected ? ThemeManager.current().text : ThemeManager.current().textSecondary;
  }

  private resolveSymbol(): Resource {
    if (this.iconKey === 'aperture') {
      return $r('sys.symbol.house');
    }
    if (this.iconKey === 'activity') {
      return $r('sys.symbol.compass');
    }
    if (this.iconKey === 'code') {
      return $r('sys.symbol.code');
    }
    if (this.iconKey === 'notifications') {
      return $r('sys.symbol.bell');
    }
    return $r('sys.symbol.person');
  }

  build(): void {
    Column() {
      SymbolGlyph(this.resolveSymbol())
        .fontSize(this.iconSize)
        .fontColor([this.resolveColor()]);
      Text(this.title)
        .id('tab_icon_title_' + this.iconKey)
        .fontSize(GSYFontSize.small)
        .fontColor(this.resolveColor())
        .margin({ top: 3 })
        .maxLines(1);
    }
    .id('tab_icon_root_' + this.iconKey)
    .width('100%')
    .height('100%')
    .padding({ top: 4, bottom: 4 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }
}
