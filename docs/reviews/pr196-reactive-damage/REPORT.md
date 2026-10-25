# PR196：反应伤害通知与队列有限独立复核

## 结论

- 当前 PR196 head `f93b0301f98d6cc5e2a8e2e244721b1eb3ceb2ab`，运行源 `5ceef2cbd1d65bb59b4d42ee77702bf69d331dd1`。
- 主范围 7 个新增组合通过，没有发现 Sharp Hide 通知/格挡/Blood for Blood/Rupture/致死尾队列的新缺陷。不是全75张认证，也不重复已关闭的生成BFB减费问题。
- 单列一项相邻、可重复的原版顺序差异：玩家被普通攻击杀死后，Flame Barrier 仍执行一次排队反伤。它不属于“玩家受到反应伤害”的主范围，不能把它混称为上述7组失败。
- 精确比较的 develop 为 `826db2d3b97e505ca63b9a26ae8ab6af885791af`。该版本既没有 Flame Barrier 卡牌/状态，也没有此卡牌的反伤分支，故同一真实卡牌负例无法原样运行。没有换卡、混源或虚报主线玩家已遇到。
- develop826 的 Actor blob `bc4f89a6d632be73a730f31f09ffd7ccea506135` 与 PR196 base9ae 完全相同；旧反应循环本来就没有玩家死亡 guard。准确归类为“旧反应循环被新增卡牌触发的未覆盖死亡边界”，不是已证实的既有主线 Flame Barrier 回归。

## 固定输入与限制

读取 AGENTS、SCOPE、HANDOFF、TASK-16.1 主任务与附件；原负责人/状态/严格AC不改。`backlog instructions overview` 在本执行环境因 CLI 不存在而未运行；没有进行任何 Backlog 写操作。

从已冻结 f93 最小源只读复用，逐个 git blob 检查后复制到本目录 `head/`；Actor、Guardian、Combat、CardActions、Effects、Run 六个核心文件又直接从 GitHub f93 读取并核对。67个实际源码、数据和构建输入见 `verified-runtime.json`。作者最新 `warrior75_edges.lua` 为49组而非旧42组，已阅读全文并保留身份 `92d109dafdf697f56f1c2d0b38302bb2ced96e75`，没有再次全扫49/75。

测试用真实 `Run.new → startRoomCombat(boss) → Run.play → Run.endTurn` 与真实 Guardian AI。通过 Bludgeon 32点打破30点阈值、正常 Defensive Mode 行动获得 Sharp Hide 3，不替换敌方行动定义。牌堆、能量及少量生命/状态是显式边界夹具，不宣称自然获取、自然地图到达或原版PC实玩。

原版预期独立来自固定 `fc379c875c11e008e9c10548ac8e394c301c532f` 反编译镜像，只读方法并记录 blob/行号，没有复制第三方源码正文或玩家文案到交付物。镜像不是认证PC二进制；没有平台编译、导入、实机、全量npm或重型扫描。

## 7个补充组合

1. Twin Strike、Sharp Hide3、Block2：两次命中只触发一次Sharp Hide，实际掉1HP；已有一次Bloodletting自损计数从1变2，手牌/抽牌堆/弃牌堆BFB分别继续减1费，消耗堆不变。
2. 同一组合Block3：全部格挡，HP及计数不变，三个活跃牌堆不减费；仍记录一次Sharp Hide，blocked=3。
3. Rupture+ 与 Hemokinesis：自损2 → 力量+2 → 已预计算攻击15 → Sharp Hide3。总掉5HP、BFB计数2，只有自损触发Rupture，反伤不再加力量。
4. Pommel Strike抽入BFB：BFB先实际进入手牌，再被Sharp Hide通知减费；反伤事件帧已包含正确UID与costReduction=1，攻击最后才弃置。
5. HP3、Fire Breathing、Double Tap、Pommel Strike抽Wound：本次攻击9与抽牌发生；Sharp Hide致死后Fire Breathing尾部及重复攻击都不执行。Run正式defeat、HP0、无奖励，物理卡仍在cardInUse。
6. 非致死Double Tap+Twin Strike：四次攻击、两次Sharp Hide，玩家掉6HP，BFB减2费，物理卡只弃置一次。
7. Guardian6HP、玩家3HP、Strike：末敌先死亡，其已排队Sharp Hide仍能致死；最终defeat、无奖励/胜利计数、卡不弃置，BFB仍收到这次实际HP损失通知。

`reactive-order-probe.lua` 的第1次执行有一个测试自身错误：假定存在draw事件，但生产模块不发该事件；保留于 `evidence/harness-missing-draw-event.log`。已改为核对Sharp Hide事件帧内已抽入的实际UID与折扣；这是夹具修正，不是产品修复。最终7/7通过。

## 相邻负例：死亡后多执行一次Flame Barrier

独立脚本 `lethal-incoming-probe.lua`：

1. 相同真实Run/Guardian进入防御态，正常结束一轮，让Roll Attack后进入Twin Slam（8×2）。Guardian保持208HP。
2. 边界夹具设玩家7HP、Frail1；正常打出基础Flame Barrier，真实规则产生9Block、Flame Barrier4。
3. 结束回合，第一击8全格挡：玩家仍7HP，Guardian受反伤4至204。
4. 第二击8由剩余1Block吸收1，玩家掉7HP至0，死亡画面应阻止新的反伤动作开始。

最小预期：playerHP=0、guardianHP=204、反伤事件1次、RunPhase=defeat、无奖励。
实际：playerHP=0、guardianHP=200、反伤事件2次、RunPhase=defeat、无奖励。
额外事件帧明确为 `status_damage source=player target=guardian_1 hpLost=4 playerHP=0 guardianHP=200`。

根因定位：[Actor.resolveDamageReactions 198–209](https://github.com/CHNISam/Slay-the-Abyss/blob/f93b0301f98d6cc5e2a8e2e244721b1eb3ceb2ab/src/lua/abyss_actor.lua#L198-L209) 无全局玩家死亡终止；[damage 275–286](https://github.com/CHNISam/Slay-the-Abyss/blob/f93b0301f98d6cc5e2a8e2e244721b1eb3ceb2ab/src/lua/abyss_actor.lua#L275-L286) 将这次反伤加入并立即排空。不能简单禁止dead source反伤，因为本轮第7组证明末敌死亡后它的Sharp Hide伤害仍必须保留；需要区分“敌方来源死亡”和“玩家死亡停止动作管理器”。本审查未改生产代码或尝试代作者修复。

影响有限：当前反例最终仍正确判负，无错误奖励；错误是死亡后额外伤害/事件/敌方状态变化。不将此有限差异扩张为全面反伤、遗物、Boss或M3阻断结论。是否并入作者当前修正由root与owner决定。

## 原版固定依据

以下链接均固定同一源commit；完整blob及读取边界见 `fixed-source-review.json`。

- [SharpHidePower.onUseCard 40–46](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/SharpHidePower.java#L40-L46)：每次Attack使用排队一次THORNS伤害，而非每个hit。
- [AbstractPlayer.damage 1731–1847](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/characters/AbstractPlayer.java#L1731-L1847) 及 [updateCardsOnDamage 1916–1932](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/characters/AbstractPlayer.java#L1916-L1932)：格挡后的正损伤才通知三活跃牌堆并增加damagedThisCombat，消耗堆不在循环。
- [RupturePower.wasHPLost 32–38](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/RupturePower.java#L32-L38)：正损伤且来源等于自己时排TOP力量。
- [FlameBarrierPower.onAttacked 51–59](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/FlameBarrierPower.java#L51-L59)：普通敌方攻击只将反伤加入TOP，非同步立即伤害。
- [AbstractPlayer.damage 1865–1894](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/characters/AbstractPlayer.java#L1865-L1894) → [DeathScreen 60–78](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/screens/DeathScreen.java#L60-L78) → [AbstractRoom 388–397](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/rooms/AbstractRoom.java#L388-L397)：无复活遗物/药水时致死建立DEATH、isScreenUp=true，之后不再update动作管理器；[AbstractDungeon 2852–2854](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/dungeons/AbstractDungeon.java#L2852-L2854)仅更新死亡画面。
- [DamageAction 68–103](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/common/DamageAction.java#L68-L103)：THORNS允许已死敌方来源，不等于玩家死亡后仍继续动作管理器。

## 冻结交付

- `REPRODUCE.md`：原生Lua5.4复跑命令与预期退出码。
- `reactive-order-probe.lua`、`lethal-incoming-probe.lua`：完整独立测试。
- `evidence/`：原始日志，包含保留的夹具失败。
- `verified-runtime.json`、`remote-identities.json`、`develop-comparison.json`、`fixed-source-review.json`：版本/来源边界。
- `RESULT.json`、`FROZEN.json`：最终实际结果与内容hash。

只输出有限审查，没有修改原PR、Backlog、Windows任务或他人的生产源；旧0982平台17层证据不用于认证f93/5ce新源。
