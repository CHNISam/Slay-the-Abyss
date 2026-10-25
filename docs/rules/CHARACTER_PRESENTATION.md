# 开发职业的中文卡牌显示适配

`abyss_character_presentation.prepare(existingPresentation, preparedRunData)`返回深拷贝的ID索引显示表，不修改原显示数据、职业规则数据、主题或运行状态。不负责启用职业选择、改变随机池或认证UI实机。

输入沿用 `build:ui` 生成的 `abyss_presentation` schema。每个所选职业规则卡均包含 `id/name/text/upgradeText/cost/upgradeCost`，附带`type`供调用方核对。费用按既有格式保存字符串，X费为X，不能打出的费用为长横线。BattleUI/DeckUI仍以真实卡定义决定能否打出和卡牌类型。

本轮明确保留既有已批准普通战士牌的名称和文案；新职业牌独立生成中文，不借用战士牌文案。七张获准扩展的战士牌会根据当前规则重新生成描述，保留批准名称，确保随机/指定消耗、抽牌置顶、X费、成长和吸血文字与新规则一致。三职业基础牌及Miracle/Shiv、不能打出的Tactician/Reflex均有明确文案，包含保留、消耗、虚无和弃牌触发。

生成只支持当前已核实映射的操作、状态、姿态、选牌模式、球类型及已知空效果卡。所有卡的基本/升级操作均在返回前校验，即使该ID已有旧文案也不能绕过未知op拒绝。未知条件、X费模式、稀疏数组、循环数据、缺中文名称或未知空效果卡均拒绝，不以“未实装”空描述掩盖。

动态战斗数字仅对真实 `CardDisplay` 支持的伤害/全体伤害/格挡/旋风/收割值保留 `{effects.N.value}` token，其余抽牌数、状态数、球数量等静态按所选普通/升级定义展开。永久牌库的text/upgradeText没有动态token；战斗的combatText/upgradeCombatText交给Combat.cardPreview和CardDisplay.format，保留原主题的增减颜色与箭头。预览目标造成伤害范围时仍由既有精确数字门禁处理，不能在适配层合并成错误范围。

不能打出的Tactician/Reflex并非空技能：文本按真实弃牌模块的普通/升级分支分别显示1/2能量、2/3抽牌。Dazed、Slimed和Regret沿用或明确生成其真实状态/诅咒描述。未知状态诅咒拒绝，不默认启用。

## 验证

私树生成输出执行 `npm run build:ui`，并用当前集成脚本刷新生成布局：`node /workspace/sts-next/scripts/build-ui.mjs /workspace/sts-defect/build/lua`，没有改根树源码。

`node scripts/test-lua.mjs tests/lua/character_presentation.lua`：9组通过。四个实验Profile共102个卡定义、普通/升级204个显示变体，逐一使用真实Combat.new/cardDefinition/cardPreview、BattleUI.render和DeckUI回收条目首次绘制。另验证动态增强数字、既有数据深拷贝隔离、关键字与费用，以及未知op/状态/球/模式/空效果拒绝。

这些是离线真实控制器加本仓库平台control fixture的检查，不是Windows官方导入、手机触摸或美术实机验收。新显示数据需由GameUI等宿主显式传给BattleUI/NodeUI/DeckUI；本模块不擅自修改共享控制器。


## 并行新牌的附加显示覆盖

追加精准（Accuracy）、无限刀刃（Infinite Blades）、伏身（Prostrate）、礼拜（Worship）、供奉（Devotion）的中文适配。精准描述为飞刃基础伤害+4/+6；无限刀刃从下回合起每回合开始生成一张飞刃，升级追加先天，不能暗示打出当下生成。通用先天后缀为开局优先抽到。

真言效果仅描述获取层数，不宣称“第一次达到10必进入神格”。供奉按已核实的每回合抽牌后时机描述，并明确没有真言且供奉至少10时的直接神格分支。伏身普通/升级的格挡都为4；礼拜始终2费，只有升级保留。受约束新增操作为gainMantra/gainDevotion；未知状态仍拒绝。

测试追加通过Shivs.withCardDefinitions和Mantra.withCards构造的临时数据，不改共享Profile。无限刀刃定义尚待并行模块合入时，测试只添加题定的1费能力/升级innate规则数据用于显示校验，不执行伪造战斗逻辑。

本轮额外模块尚在其他私树时，测试实际用Fengari -e安装package.preload，从`/workspace/sts-silent/src/lua/abyss_shivs.lua`和`/workspace/sts-watcher/src/lua/abyss_mantra.lua`只读加载，然后dofile测试文件；10组、214个普通/升级变体全部通过。合入这些模块后标准入口为`node scripts/test-lua.mjs tests/lua/character_presentation.lua`。没有声称未执行的标准入口已运行通过。

## 后续构筑片的显示扩展

在冻结UI树之外，以后续构筑树的只读规则定义与RetainedCards私树模块作为测试基线。显示新增以下独立helper内容，不将helper测试等同于Profile正式激活：

- 战士消耗片：Corruption的技能0耗能与使用后消耗、Feel No Pain每消耗3/4固定格挡、Dark Embrace每消耗抽1且升级只降费、Sentinel自身被消耗返2/3能量、Burning Pact先选择消耗1手牌后抽2/3。
- 猎人弃牌片：Sneaky Strike对应源Underhanded Strike，2费12/16伤害后按本回合主动弃牌条件返2能量；Eviscerate基础3费三段7/9伤害与当前实例的弃牌减费历史；Calculated Gamble弃其余整手再抽等量，基本消耗、升级不消耗。
- 机器人球能力片：gainOrbPower仅允许已知Loop/Electrodynamics，说明先AOE能力再生成闪电。连续的同种channelOrb在文案中合并数量，得到2/3球的紧凑文本，不改变规则动作数组或次序。
- 观者保留片：Protect基础格挡与保留；Perseverance的每次保留本牌格挡+2/+3；Windmill Strike本牌伤害+4/+5；Sands of Time每次保留本场费用-1、最低0。成长说明不是把基础数字误作当前数字。

新操作gainExhaustPower、gainEnergyIfDiscard、calculatedGamble、gainOrbPower均有明确映射，未知Power id仍拒绝。Sentinel等不体现在普通effect数组的生命周期通过明确特殊ID文案呈现，不自动猜测任意空效果或未来新卡。

P.cost与upgradeCost表示规则定义的基态；不会从弃牌计数、保留次数或Corruption推算当前耗能。当前费用最终由Combat.cardDefinition提供，BattleUI读取该定义。测试真实打出Prepared并选弃一张牌后，Eviscerate UI显示2费而presentation仍保留基础3；Sands经历真实C.endTurn保留后UI显示3而静态显示元数据仍是4。

Perseverance和Windmill Strike的普通/升级经历真实结束回合后，测试从Combat.cardDefinition和cardPreview获取成长后的值，再由CardDisplay.format呈现当前数字，并检查真实BattleUI的label；没有把静态介绍中的5/7当作成长后的数值。静态永久牌库仍使用text/upgradeText基态，不泄露已结束战斗的成长。

本次 `node scripts/test-lua.mjs tests/lua/character_presentation.lua`：原10组、222变体保留；新增14张基本/升级28变体、机制文案/拒绝检查、真实成长与当前费用检查，合计15组、250个静态显示变体全部通过，另含4个真实保留成长动态分支与2个真实当前费用分支。未修改共享helpers/Profiles、主题、控制器或冻结根树；未执行全量suite、提交、推送或实机验收。
