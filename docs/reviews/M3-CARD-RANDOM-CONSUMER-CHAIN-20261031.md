# M3 共享战斗随机流的跨道具独立核验

基线 `e1ae599e17e5470c1fa4b5e4963477489a5c92df`，工作树 `/workspace/m3-rules-final`。本片只补测试、独立预期及审计，不改生产行为、原池、旧来源 hash、旧断言、30秒单fixture预算或Backlog。

## 为什么补这条链

已有完整33药水采样 oracle、130旅行者普通来源遗物绑定和153运行定义。它们证明的范围不同：完整身份绑定不证明每件效果；明确取得的fixture不证明自然获得；单消费者用生产RNG clone生成预期不独立证明多个消费者共用同一流后的次序。

已有入口包括：

- `tests/sts1-potion-random.test.mjs`、`tests/sts1-ironclad-potion-pool.test.mjs`、`tests/potion-production-channels.test.mjs`：全33原序采样、拒绝采样、奖励和商店。
- `tests/potion-channel-chain.test.mjs`：同一Run的商店/信使/奖励/熵之酿/逃离/再进房间，独立核potionRng。
- `tests/relic-catalog-completeness.test.mjs`：130身份绑定、128个不修改遗物队列的事件种子。它不逐件触发130种效果。
- `tests/rare-relics.test.mjs`、`tests/uncommon-relics.test.mjs`、`tests/shop-relics-missing.test.mjs`、`tests/boss-relics-missing.test.mjs`，及common/special/event专项：分类效果、生命周期、公开选择与组合。
- `tests/lua/sacred_bark_potions.lua`、`potion_choices.lua`、`potion_chaos.lua`、`potion_snecko.lua`、`potion_discovery.lua` 等在标准Lua扫描中运行；树皮倍率/不翻倍例外、选牌/自动打牌/费用已有实际效果断言。本轮未重复运行这些全量旧专项。

本片填的是另一条流：干瘪之手、奇怪的勺子、枯木树枝、攻击药水、万能药和异蛇之油连续消费同一 `cardRandomRng`。

## 独立来源与新增验证

固定镜像仍是 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是正版PC二进制认证。本轮读取并登记8份源文件SHA256：StrangeSpoon、DeadBranch、MummifiedHand、UseCardAction、DiscoveryAction、SneckoOil、RandomizeHandCostAction、AbstractDungeon。方法体未复制进仓库。

`tools/oracles/sts1_card_random_chain.py` 使用既有独立XS128解释器和冻结的原版牌注册/HashMap顺序输入，不导入生产Lua、生产采样器或本地牌定义。完整原common→uncommon→rare序列排除HEALING；攻击发现再按类型过滤。每个wrapper的bound、返回值、前后两个64位word及counter均固定。source/pool输入及生成器hash随fixture保留，标准测试重新生成逐byte比较。

五个固定seed `0/1/42/-1/505` 覆盖勺子改弃牌和实际消耗两分支；后者产生额外树枝身份抽样。真实 `Run` 路径依次执行：

1. 取得三件遗物/三瓶药水后开战；核初始流，手持能力牌实际触发干瘪之手，核被置零的源身份。
2. 打出岿然不动，核勺子布尔、真实弃牌/消耗目的地及条件树枝身份。
3. 使用攻击药水，核三候选；非法选择完整状态不变；合法选择还消费源DiscoveryAction retrieval时生成但不用的第二组三候选；过期选择完整状态不变。
4. 万能药选择一张真实UID并确认，核树枝生成；这不是出牌清理，不额外抽勺子布尔。
5. 禁止抽牌的受控输入下使用异蛇之油，逐张核当前手牌身份、费用；Burn/X费不抽样；原费用相同的roll不误覆盖已有本回合0费。

手牌、能量、敌人HP和noDraw是显式受控边界。取得道具用公开API，但不是自然种子获取证明。每步以公开Run命令走共享生产结算；完整pool顺序、所有wrapper调用和最终身份都与独立预期比较。额外核无关的永久和战斗随机流不变。

精确负变异在临时模块中删除Discovery retrieval抽样；新链必须在 `discovery_resolve complete stream` 处失败，原源码不被修改。本轮没有发现需要修改生产的差异；夹具早期legacy/profile种子选择与transaction克隆owner的observer错误已修，不记作生产RED→GREEN。

## 逐AC结论与真实剩余来源

| AC | 现在可独立支持 | 仍不能关闭的具体证据/来源 |
|---|---|---|
| TASK-14.1 #5 完整逐件效果 | 既有分类效果保留；本轮增强3遗物+3药水真实效果与源次序 | 不能将 `relic_catalog_completeness` 的描述/绑定检查当全130效果。每件仍须以固定镜像对应 `relics/<class>.java`、`potions/<class>.java` 及其Action/Power消费者逐项核数值、对象、持续、限制。153含事件/特殊/其它职业，不能整体当旅行者奖励池；完整清单以冻结遗物队列、data/relics.json sourceId和33药水目录逐件对账。 |
| #7 全池叠加/跨房间/战后/重复 | 新增这6项共享流的连续组合、无效/迟到选择原子性；已有potion-channel-chain跨房间不丢提交 | 本片没有新增所有153×33组合矩阵。应以实际触发交点补源行为，而非机械笛卡尔积：`Toolbox`颜色牌生成接Discovery；`DistilledChaos`/`PlayTopCardAction`提前目标抽样接Spoon/Branch/Hand；`SneckoEye`/`ConfusionPower`抽牌费用接Hand；`DeadBranch`接DarkEmbrace/CharonsAshes及最后敌人死亡；`StrangeSpoon`接BlueCandle/MedicalKit及非出牌消耗。已有专项可覆盖部分，但未形成一份逐交点独立证据总账，不能外推全齐。 |
| TASK-16.1 #5 新增与跨域共享入口 | 本轮真实Run命令核出牌、选牌、用瓶统一入口，不以直接钩子替代终态 | 本片未核所有职业/无色牌新增效果；当前比赛Geo前两幕与未来full-source必须分层。原75卡/多职业各专项保留；没有重新声称全部跨域数值和先后顺序已验。 |
| #6 完整池初始化及全部消费 | 独立全源pool次序、5seed、每次wrapper完整owner、条件消费、拒绝不抽样和无关流守恒 | 本片是显式ID开发战斗，不认证正式房间floor seed传播或全部游戏流同seed。map/monsterHp/AI/shuffle/cardRng/relicRng/treasure/potion/merchant及事件流各有专门oracle，尚需保留其来源和同一自然Run连续消费证据。Discovery真实PC等待帧可能额外执行update，本fixture只认证本地“打开+一次retrieval”投影；不声称完整PC帧重放。实际平台记录继续缺。 |

平台/自然AC继续开放；本片既不因无设备停止离线工作，也不把离线强制取得替代玩家自然结果。

## 本轮验证

标准入口：`node --test --test-concurrency=1 tests/card-random-chain.test.mjs`，包含独立fixture再生、五条真实组合链和一条精准突变。每个Lua调用继续使用默认30秒。另执行JS语法、Python编译和 `git diff --check`。未跑全npm test；无生产改动，未重复昂贵历史/全套Lua回归。最终运行日志由主控附件保存于 `/workspace/cloud-reports/m3-card-random-chain-test.log`。
