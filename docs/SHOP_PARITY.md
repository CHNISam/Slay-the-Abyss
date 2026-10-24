# 商店修复：规则、内容缺口与验收边界

2026-10-24，承接 TASK-13.1；独立分支 `feat/shop-parity`，起点 `b3c2ecb`。复用 [价格证据](reviews/TASK-13.1-shop-card-price-evidence.md)、[Lua 算术候选](reviews/TASK-13.1-shop-price-lua-candidate.md) 和 [既有节点账本](NODE_ECONOMY_PARITY.md)。没有启动原作或认证目标 PC 二进制。此文是该商店切片的当前说明；旧账本“未售药水、全池商店、固定最终价”的描述保留为历史。

## 当前实现

- 正常商店只有七个卡槽：攻击×2、技能×2、能力×1；无色罕见×1、无色稀有×1。重复的攻击/技能会重新抽稀有度与牌。能力没有普通牌，普通结果进入罕见能力池。基础/特殊/状态/诅咒不售；不展示完整可玩目录。删牌/升级选择器的分页保留。
- 三件遗物中第三槽为商店专属，另外两槽按 48/34/18 的候选阈值抽普通/罕见/稀有；三瓶药水按 65/25/10 抽稀有度，允许相同药水多瓶。药水购买以槽位寻址，装入最左空槽，满槽不扣金币、不售罄、不消耗 RNG。Ironclad 不出售 Silent 专属毒药水。
- 职业卡稀有度用 `roll+offset` 比较 9、46 两个阈值；初始 offset=+5，即初始普通59%、罕见37%、稀有4%（能力普通分支转罕见）。商店本身不累积/重置该偏移。接口接受 `run.cardRarityOffset`，但当前战后奖励仍是原有受限抽选，**未接入原作共享 cardRng 与动态偏移历史**；不能将新局阈值测试写成所有路线概率一致。
- 卡价沿用已审算术：50/75/150 为基价，binary32 的 0.9–1.1 抖动，无色先乘1.2再截断；仅职业五槽中的一槽特价，整数价除2向下取整。初始特价先于快递员八折、会员卡半价，后两步各自 half-up。遗物基价150/250/300/150、药水50/75/100，0.95–1.05 抖动后 half-up，再逐次遗物折扣。
- 会员卡作为可获得的商店专属遗物加入。购买时对当前货架既有报价半价取整，不重抽随机价。快递员、微笑面具加入支持数据，但自身 `canSpawn` 禁止出现在商店，只能从其他遗物来源获得。持有快递员时购卡/遗物/药水后补货；补卡不再特价，卡价保留浮点到最后截断；原商店专属遗物槽补货后按普通遗物稀有度抽取。无快递员时商品永久标为售罄。
- 每店一次删牌，跨店基础75+25n。快递员与会员卡同时存在时，删牌价按最后一次折扣从基础费用重算（75→38），不是货架商品的连续折扣（75→60→30）。微笑面具覆盖为50，包括店内新购会员卡后的服务价。Sozu 的禁止获得药水拒绝路径已防护，但 Sozu 本身尚未纳入内容。
- `Nodes.enter` 在合法入口一次生成货架；view、开关牌库/退出层、重绘、地图恢复不重抽。离开完成节点后不能沿旧节点 ID 重入或继续购买。新商店延续本局商店流，新局重置。仅购买成功消耗金币、UID和库存；普通售罄、缺失内容、非法ID、资金不足、药水槽满均原子拒绝。

## 固定来源与冲突

目标仍为初代 PC A0。以下沿用仓库既有固定镜像 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`，版本字符串为 V2.3.4；它不是官方发行构建认证。只读取规则，独立实现，未复制原作方法体或素材。

| 规则 | 固定方法证据 |
|---|---|
| 五职业牌分类、重复重抽、两种无色稀有度 | [Merchant 构造](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/Merchant.java) |
| 9/37 基准、是否使用偏移 | [ShopRoom](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/rooms/ShopRoom.java)、[AbstractRoom.getCardRarity](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/rooms/AbstractRoom.java)、[AbstractDungeon.rollRarity/getCardFromPool/初始offset](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/dungeons/AbstractDungeon.java) |
| 稀有度内选牌及排序 | [CardGroup.getRandomCard](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/CardGroup.java) |
| 价格、特价、遗物48/34/18、初始折扣与补卡、删牌重算 | [ShopScreen](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/ShopScreen.java)；精确 float 边界仍以既有价格账本为准 |
| 会员卡现场折扣、遗物补货排除、药水满槽/Sozu | [StoreRelic](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/StoreRelic.java)、[StorePotion](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/StorePotion.java) |
| 不得在商店出售快递员/面具 | [Courier.canSpawn](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/relics/Courier.java)、[SmilingMask.canSpawn](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/relics/SmilingMask.java) |
| 药水65/25/10、各职业专属药水 | [PotionHelper](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/helpers/PotionHelper.java) |

旧 Wiki 摘要的遗物50/33/17和部分价格整数范围与镜像有冲突，本实现采用上表固定候选规则；冲突尚无目标 PC 运行观察消解，不据此宣布严格一致。

## 不可隐去的缺口

1. **内容仍受限**：无色牌0张；稀有药水0瓶；普通/罕见药水也只有已有子集；稀有遗物0件，商店专属只有会员卡。职业卡只从已支持的内容选取，远少于75张；部分类型×稀有度组合可能为空。这不是完整原版商品池。
2. **空桶处理是明确降级**：原定稀有度保留，生成带 `unavailable` 的不可售槽，界面显示“未实装/内容缺口”，核心禁止购买。不会将稀有10%改成普通药水，不会给无色槽塞职业牌，不会给商店专属槽塞普通遗物。不可售槽不是实际商品，不能称“每店已有七张可买牌、三件可买遗物、三瓶可买药水全部齐备”。重复重抽设置256次防挂上限，达到上限同样标内容缺口；它是受限池保护，非原版规则。
3. **RNG/遗物队列尚未严格对齐**：使用现有 STS RNG 适配器的独立 card/merchant/potion 状态，保存同局进度；当前支持池按项目ID排序抽取。原版完整牌池排序、战后奖励共享流及偏移、药水全池拒绝抽样消费、全局遗物预洗牌队列尾端取货和未购买物品消耗未接通。当前未拥有遗物排重不能代替全局队列。固定seed只证明项目复现，不是原版同seed轨迹。
4. **其他遗物交互尚未支持**：Meal Ticket入店治疗、Maw Bank消费停用、Ceramic Fish获牌金币及其他获得物品钩子不在当前数据/执行器中；不得纳入可玩池后宣称已支持。Sozu只有拒绝路径，不代表该遗物完整实现。
5. **删末张牌仍受旧核心限制**：`last_card` 保留，不宣称原版禁止空牌组。原版不可删除的瓶装牌等资格也需随相关内容加入。
6. **实机未验**：离线控件回调与HTML预览不能证明平台图片语义、字体换行、触摸派发或真实账本。没有本候选导入后新日志/ready/商店截图，不复用旧M1日志。

## 回归与实机执行单

自动化入口：`npm run check`。`tests/lua/shop.lua` 固定 seed42 的卡序/价格为 dropkick70、anger53、shrug_it_off46、entrench34（特价）、inflame81，两个无色缺口槽89/173但不可购买；同seed/复制状态/view不变，异seed变化。100个整数输入穷举稀有度阈值；同seed检验逐次折扣、会员卡现场购买、面具覆盖、三类快递员补货、Sozu拒绝、满槽及重复购买。价格候选差分套件同时执行投产 `abyss_shop_price.lua` 和原候选，保留端点/半ULP/4096报价向量。

`node_ui.lua` 覆盖七槽同屏/禁止翻页、缺口显示、价格/效果、资金不足、药水满槽与售罄、删牌一次和UI请求重验；`node_card_ownership.lua`、`game_ui_exit_swipe.lua` 保留重绘/遮罩/退出后的旧触摸拒绝，选牌器翻页仍测；`inventory_restore.lua` 使用seed36实际供应的clothesline和oddly_smooth_stone，保留UID/资源/恢复断言；全卡池行为回归寻找可重复的合法抽样店，不再要求同一家店卖全部牌。

离线对照：`node scripts/node-ui-preview.mjs .artifacts/shop-preview`。右图是生成控件驱动的预览，图库图片由字形代替，绝非游戏截图。按用户本次规则从原型示例5牌/2遗物调整成7牌/3遗物/3药水同屏；沿用PR19牌框、主题、字号和按钮。原型演示数量不是规则来源。

同一固定候选的实机待执行：

- 记录源SHA、候选SHA256、官方导入ID；启动显式 `clientScriptLog:true`，取本轮ready与新日志。
- seed42进入商店：实数五职业槽/两无色缺口槽/三遗物槽/三药水槽、类型与特价；确认没有全池/翻页入口；截图核对金币、费用、能力说明和缺口文字。
- 记录买前/买后金币、永久UID、药水槽、遗物；成功/资金不足/满槽/重复触摸、售罄拒绝；打开关闭牌库及退出取消后旧触摸不误购，新触摸可用。
- 会员卡购买前后全货架/删牌价账本；通过正常合法来源持有快递员/面具再验补货/不再特价及删牌覆盖，记录取得路径；不得将调试注入当自然可获得证据。
- 离店、尝试旧请求、进下一店、失败重开：旧库存不复购，新店服务恢复、删牌递增，新局归零。电脑及手机分别截图/事件日志，观察文字溢出和底栏遮挡。
- 用同一候选更新 `docs/design/ui-acceptance.json` 的真实截图及检查项，再运行 `npm run verify:ui -- <候选.gil>`。在此之前门禁保持未通过，TASK-13.1整体与平台AC不勾选。
