# 原生界面离线对照

这些图片来自真实 Lua 宿主/房间状态驱动的原生控件树，在无头浏览器中绘制。图库图片以批准原型字形或几何替身表示；原生字形、图库资源、输入和音画均未在设备上验收。

生成命令：`npm run build:data`、`npm run build:ui`、`npm run build:theme`、`node scripts/native-ui-parity-preview.mjs`。脚本默认在 `.artifacts/native-parity/preview/` 保存全部34个状态及 `text-fit.json`。此处保存主要屏幕，完整对照、平台差异和设备待验见[逐屏报告](../../reviews/NATIVE-UI-PARITY-20261028.md)。

核对记录：[39项UI回归](ui-regressions.txt)、[牌库最后9项](deck-header-tests.txt)、[工程门禁](engineering.txt)、[正式选角组合](combined-formal.txt)、[退出/手柄宿主](exit-host.txt)、[手柄房间与当前状态](controller.txt)、[选牌](choices.txt)、[文字裁切清单](text-fit.json)、[源码与截图身份](validation.json)。

| 屏幕 | 离线状态 | 批准参考 |
| --- | --- | --- |
| 地图 | [当前位置](map-current.png) | [Map画布](../../design/ui-canvas/Map.dc.html) |
| 商店 | [完整货架](shop-all.png)、[触屏选择](shop-touch.png) | [原型商店](../../design/screens/shop.png) |
| 营地 | [双选项](camp-new.png) | [原型营地](../../design/screens/camp.png) |
| 锻造 | [网格](forge-grid.png)、[升级对比](forge-preview.png) | [原型](../../design/prototype/index.html) |
| 宝箱 | [全部奖励](chest-rewards.png) | [原型宝箱](../../design/screens/treasure.png) |
| 事件 | [条件与选项](event-cleric.png) | [原型事件](../../design/screens/event.png) |
| 奖励 | [战利品列表](rewards.png) | [原型奖励](../../design/screens/reward.png) |
| 牌库 | [六列](deck.png) | [原型](../../design/prototype/index.html) |
| 菜单 | [标题页](menu.png)、[操作说明](controls.png) | [Controls画布](../../design/ui-canvas/Controls.dc.html) |
| 退出 | [独立确认](exit.png) | [平台对照](../../design/PLATFORM_PARITY.md) |
