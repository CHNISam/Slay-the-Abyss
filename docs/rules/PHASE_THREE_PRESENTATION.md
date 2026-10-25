# 第三批职业卡牌展示

`abyss_character_presentation`补齐战士力量、静默攻击、防御及下一回合资源、故障机器人实用牌、观者攻击/衍生牌，以及余像、凌迟、涂毒、狂怒、散热片、雷暴六种打牌触发能力的中文说明。它从已核实的效果数据、状态ID、条件与卡牌元数据构造说明，不读取`card.text`或`upgradeText`作为捷径。

新覆盖的语义包括Heavy Blade力量倍率、Perfected Strike打击标签计数、Brutality抽牌后失血、Combust重复施加增加失血次数、前张牌类型跨回合条件、Signature Move排除自身的其他攻击限制、Grand Finale空抽牌堆限制、生成洞见/安全/惩罚及伤口/灼伤/虚空、NoDraw限制下的抽满手牌，以及六种打牌能力的触发条件。升级费用、X费、不能打出、保留、先天、消耗、虚无仍由结构化字段展示；不改变战斗规则、构筑池或正式上线状态。

## 动态数值契约

普通数值占位符为`{effects.i.value}`，i从0开始。新增Bowling Bash、Barrage、FTL、Heel Hook每击普通伤害以及X格挡、下一回合格挡均读取真实`Combat.cardPreview`；本模块不重算力量、敏捷、脆弱、姿态或目标易伤。

Bane条件追加伤害使用`{effects.i.then.j.value}`，i/j均从0开始，对应共享`preview[i+1]['then'][j+1]`。两个伤害片段分别预览，不能误用第一段的token，也不能将条件伤害永远显示为未经力量修饰的基础数值。未知条件/嵌套层级继续拒绝。

Halt战斗说明的主token显示当前姿态下的**总格挡**，静态说明保留“基础格挡＋愤怒额外格挡，两份分别受敏捷/脆弱影响”的语义；不把两份先合并再修饰。例：未升级、敏捷2、脆弱、愤怒时显示11。Brilliance从共享定义适配器读取已含真言的基础伤害，然后使用普通伤害预览，不在展示层再次增加真言。Dodge and Roll下一回合格挡显示本次使用时已计算的值；固定发放时不再叠加下回合敏捷。

空效果状态牌只允许已知定义：伤口不能打出；灼伤说明回合末受伤和格挡可抵挡；虚空说明抽到失去能量及虚无。未知op、状态ID、球类型、生成牌ID、前张类型、条件、费用模式和空效果牌继续拒绝。条件/费用模式在空牌早返回之前验证，避免已知状态牌携带未知规则字段时被展示层静默接受。

## 验证

`node scripts/test-lua.mjs tests/lua/phase_three_presentation.lua`：11组通过，370个基本/升级变体均实际调用BattleUI和DeckUI渲染（约7.8秒）。数据基于根线程sts-triggers共享接线，并读取另外两个独立agent的Silent攻击与CardTriggers模块；这些baseline副本不是本切片交付。

定向断言包括：普通新攻击力量加成与绿色箭头、Dodge and Roll当前/下一回合两处5↑、Reinforced Body脆弱后的6↓、Halt总11、神格/力量/真言Brilliance57、Heavy Blade20、Bane两个独立9↑、生成牌说明、六Power及先天升级、原展示数据隔离，以及未知字段在普通/空牌上的拒绝。战斗展示token均完整替换，不留下未解析占位符。主动篡改所有源卡`text`为虚构数字后，生成说明仍不出现该数字。

另以冻结的sts-builds版适配器独立对照本轮版本，在相同Foundation准备数据上逐项比较40张既有卡的name/text/upgradeText/combatText/upgradeCombatText/cost/upgradeCost/type，结果全部相同。此次没有改动已有批准文案；原来已明确改写的七张Foundation牌继续遵守此前适配器逻辑。

这是Lua原生UI夹具验证，未运行全量检查，没有本轮平台实机、导入或发布证据。交付仅适配器、新测试和本文档。
