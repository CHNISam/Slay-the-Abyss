# 第四批职业卡牌展示接线

此切片只改中文展示适配器、新增UI定向测试及本文档，不改共享Combat/Display/平台组件，不把新Profile判为已通过。69张候选为战士状态构筑12、静默战术20、故障机器引擎19、观者流转18，另有Through Violence等必要特殊牌与状态牌。基础数据来自各独立helper；说明由op、状态ID、条件、费用和升级字段逐项生成，不透传源卡`text/upgradeText`。

数值、顺序与固定319009来源证据分别见[战士状态构筑](WARRIOR_STATUS_BUILD.md)、[静默战术](SILENT_TACTICS_BUILD.md)、[故障机器引擎](DEFECT_ENGINE_BUILD.md)和[观者流转](WATCHER_FLOW_BUILD.md)。展示适配器保持同一规则来源，不另立一套数值表。

## 文案与未知输入约束

扩展明确的op/status白名单，未知值继续报错。生成牌只允许已核实的洞见、安全、惩罚、以暴制暴、伤口、晕眩，并校验手牌/抽牌堆目标、随机插入、升级字段和数量；不把任意ID当成合法生成牌。已批准的三个观者生成牌句子保持原样。仅新燔祭增加灼伤生成说明，既有弃牌堆生成文案不批量改写。

新说明覆盖消耗非攻击牌、按消耗张数格挡/攻击、状态抽取触发、力量翻倍、受伤降费；利爪增长、蒸汽护壁递减、精简改良降费、弃牌堆格挡、冰霜/闪电累计历史、随机球与逐次随机攻击、移除格挡、锁定、击杀返能、X球与多次唤起；临时减力量、顺序施毒/虚弱、按技能/攻击历史多击、抽到技能才格挡、抽至指定手牌、X力量/虚弱、主动弃牌与升级飞刃；观者的回合Power、真言/印记、实际扣血格挡、振奋多击、姿态/占卜召回、原UID回牌堆及升级先天。

Blizzard说明是一次计算后的全体伤害，基础为本战生成冰霜球数量乘倍率；不会写成每个球单独命中，以免错误暗示每球增加一份力量。Thunder Strike/Rip and Tear则明确逐次普通随机攻击。Wallop说明只按实际扣掉敌人生命回固定格挡，Talk to the Hand说明完全格挡仍可触发，Like Water明确手牌处理前检查平静。Fasting能量减少从下回合开始，Collect是持续回合数，每回合生成一张奇迹+，不误写为一次生成X张。

## 共享动态接口前置

仍使用`{effects.i.value}`与单层条件的`{effects.i.then.j.value}`，索引从0开始。展示层不另算力量/敏捷/脆弱、目标易伤、振奋、当前弃牌数或球历史；读取真实定义适配与Combat.cardPreview。

| 共享Preview/Display需识别 | 数值语义 |
| --- | --- |
| fiendFire、fearNoEvil、wallop、flowDamage | 普通每击伤害，保留目标修饰 |
| finisherDamage、flechettesDamage、skewer、glassKnife | 普通每击伤害，不把命中次数乘入单击值 |
| sunderDamage | 普通伤害；返能固定3，不同于伤害值 |
| randomEngineAttack、thunderStrike | 单击普通随机伤害，未瞄准时只显示玩家修饰，不臆造选中目标的易伤或范围 |
| blizzardDamage | 实际球历史计算后的全体普通伤害，再施加玩家/目标修饰 |
| secondWind、autoShields、escapePlan | 每次/条件格挡经本次敏捷与脆弱计算的值 |
| stackBlock | 弃牌数加升级增量后计算格挡；现有定义适配器可转成标准block |

Claw/Steam Barrier/Glass Knife的永久战斗内增减以及Blood for Blood/Streamline费用字段，由共享definition适配器和当前实例提供；展示适配器不另存战斗状态。X类只显示X或X+1的规则，不把标记字段0/1误当作当前能量或实际球数。

新的手选敌人/UI识别入口需要：`fiendFire`、`fearNoEvil`、`wallop`、`flowDamage`、`applyWatcherFlowPower`、`applyLockOn`、`removeBlock`、`sunderDamage`、`finisherDamage`、`flechettesDamage`、`skewer`、`glassKnife`、`malaise`。标准damage/applyStatus保持既有逻辑。`randomEngineAttack`、`thunderStrike`、`blizzardDamage`无手选目标；Indignation/Collect/EscapePlan等自身或全体动作同样不要求手选敌人。BattleUI依赖真实canPlay判断，不能仅依据新op名称猜测目标。

## 当前验证

初始真实红为Wild Strike生成伤口时遇到旧白名单的`unknown generated Watcher card`。补齐适配器后，四职业全部基本/升级实际BattleUI与DeckUI绘制，以及原有11组展示回归通过；新增的动态硬断言首先在Fiend Fire力量2仍显示7而非9↑处失败，明确抓到共享Preview/Display尚未接入的前置。不能因token被静态fallback替换、卡面有文字就宣称新卡动态展示正确。

`tests/lua/phase_four_presentation.lua`还列出所有69张ID，要求每张仅出现一次，并逐张渲染两种升级状态。动态断言覆盖多击普通伤害、条件/重复格挡、Blizzard球历史、Claw/Steam/Glass实例变化，以及目标选择、真实受伤降费与Glass Knife跨回合再次抽到。未知Power/status/生成牌/X升级/条件与升级分支仍测试拒绝；任意篡改源卡text为虚构数字不会进入显示说明。

冻结对照从独立sts-triggers版运行中捕获176个唯一显示条目（165张非状态/非特殊候选与11张辅助牌）的name/text/upgradeText/combatText/upgradeCombatText/cost/upgradeCost/type。固定ID清单与完整字段内容滚动校验值780875649嵌入测试，不依赖当前适配器自我比较或/tmp文件。另使用旧适配器逐字段独立比较四职业185个既有展示实例，本轮全部相同。

共享新增Preview/Display及目标入口接入后，需重跑完整新定向文件并更新本节。未运行全量、平台实机或发布；Flow机制三文件保持冻结，不混入本展示交付。
