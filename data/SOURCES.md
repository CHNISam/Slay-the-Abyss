# 来源与适配边界

2026-10-23 石颚兽生产切片：据[开发者公开getMove](https://www.reddit.com/r/slaythespire/comments/1klwcgf/true_jaw_worm_ai/msefy12/)及固定镜像方法体，HP40–44、首动11伤害、Thrash7后5格挡、Bellow3力量后6格挡；按25/55边界及Java float条件抽样处理历史限制，替换旧固定循环。来源hash、首动抽样、独立预期与保留的共享LCG/非原版随机流差异见[专项账本](../docs/reviews/TASK-15-jaw-worm-ai.md)。不是原作二进制或平台验收。

2026-10-23 祈火徒运行时切片覆盖下文旧固定循环说明：生命48–54实际采样，首动施加仪式3且不立即加力量，此后基础6攻击，每个整组敌方回合结束增长3力量，跳过施加当轮。固定方法体来源及真实性/随机流限制见 [TASK-15运行时账本](../docs/reviews/TASK-15-cultist-runtime.md)。不是正版二进制或平台实测通过；其他敌人的差异继续保留。
2026-10-23 深渊守卫离线切片：A0常数先参考社区wiki/DB，再只读核实[固定镜像TheGuardian方法体](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/exordium/TheGuardian.java#L236-L293)及真实卡牌/动作队列。该镜像声明V2.3.4/2022-12-18，未经正版二进制hash核验，不是官方开源或本轮原作实测。Sharp Hide与Iron Wave次序另交叉[TCK测试答案Problem 1(g)](https://tck.mn/videogame/stsexam/OLD_stsexam1-v1-solu-v1.pdf)。对同卡多段转形、反刺消耗预算和Twin Slam延后重置，采用具体方法调用链纠正wiki摘要不足。来源、hash、24组独立规则轨迹及证据等级见docs/reviews/TASK-17-guardian-ai.md，不据此宣称整体原版或平台通过。

核对日期 2026-10-22（后续局部复核见下文）。参考初代 Slay the Spire，不引用二代。不搬运图片、程序、存档或长文，中文效果文案由本项目编写。基准为 Ascension 0；旧表的固定生命近似仍属待补缺口，已核实并支持 hpRange 的敌人按范围实际采样。

2026-10-23 节点切片覆盖旧说明：商店删牌已修复每店仅一次；原虚构金币/药水二选一事件已移除，支持初代第一幕 The Cleric（[来源及修订](https://slaythespire.wiki.gg/wiki/The_Cleric?oldid=55508)）：至少35金币才可出现；治疗花35，回复最大HP25%向下取整；A0净化花50按UID删牌；离开无收益或代价。另支持 [Purifier](https://slaythespire.wiki.gg/wiki/Purifier)：祈祷免费删一张所选牌，或离开。`rules.events.encounterId` 当前显式固定为Purifier，是支持内容基线；**不是原版完整事件池、未知房转类或神龛概率算法**，不会按低金币条件改roll。Cleric可由明确eventId或配置指定。金额来自 `rules.events`。详见 `docs/NODE_ECONOMY_PARITY.md`；没有原作客户端版本或直接观察证据，不计严格全项通过。

- 卡牌：https://slaythespire.wiki.gg/wiki/Ironclad_Cards ，单卡按英文 id 对应同名页，例如 https://slaythespire.wiki.gg/wiki/Bash 。
- 普通敌人与遭遇：https://slaythespire.wiki.gg/wiki/Monsters ，例如 https://slaythespire.wiki.gg/wiki/Jaw_Worm 与 https://slaythespire.wiki.gg/wiki/Cultist 。
- 精英：https://slaythespire.wiki.gg/wiki/Elites ，Boss：https://slaythespire.wiki.gg/wiki/The_Guardian 。
- 遗物：https://slaythespire.wiki.gg/wiki/Relics ，药水：https://slaythespire.wiki.gg/wiki/Potions 。

完整75卡来源表由另一会话提交1d04cf2，本分支原样保存在reference/warrior75.json；其中有6张费用待核实及未映射的效果/触发器，不能直接用作运行时数据。首轮37张均来自该战士参考表，采用统一op表达，血液操控升级伤害按来源修为20；X费用以costMode=all_energy表达。不会声称75张可玩。

历史适配记录（仍是待补机制，不能视为原版验收）：除沉眠遗卫、深渊守卫外敌人仍固定意图循环；护盾小魔格挡给自己；符文哨卫施加虚弱代替塞入眩晕。五种小魔出现在一个五敌遭遇中，待通关测试评估强度。大型软泥不分裂；窃金客不偷金逃跑。这里的适配不意味着数值已经平衡。

2026-10-23 沉眠遗卫离线切片：对照 [初代 Lagavulin wiki](https://slay-the-spire.fandom.com/wiki/Lagavulin) 的睡眠/唤醒时序，并以 [SlaySpireDB 初代条目](https://slayspiredb.com/sts1/monsters/lagavulin) 复核 A0 数值。两者为社区二手资料，不是官方源码或本轮原版实测。A0 生命范围109–111，Combat使用战斗种子实际采样（旧112属于A8+范围）；睡眠格挡8、自然睡眠3回合、HP损失唤醒并眩晕当次行动、苏醒后18伤害两次与敏捷/力量各-1循环。详细证据、测试及剩余缺口见 docs/reviews/TASK-15-lagavulin-ai.md。

地图计层已按 `docs/reviews/TASK-12.4-map-floor-evidence.md` 的固定提交来源链修正为15生成行、Boss16、Boss宝箱17，强制普通战斗1/宝箱9/营地15及早期限制。该证据来自明确版本字段但未经正版二进制核验的社区反编译镜像，不能视为官方开源或原作实测。三列拓扑、节点权重、遭遇池/随机流仍为未对齐候选；第17层只有独立入口，Boss遗物池/真实宝箱事务未实现。初始80生命、3能量、5抽牌、10手牌上限与其他固定奖励/价格的核对归各自任务，不声称整个地图照搬原作。

本任务仅验收内容基线与数据校验。未编译平台逻辑、未导入存档、未运行游戏、未获得 Furinya 体验验收。

药水 damage/block 与遗物 block 采用固定数值，不套用卡牌攻击/格挡修正。2026-10-23 首发逐件核对见 [TASK-14.1 账本](../docs/reviews/TASK-14.1-inventory-parity.md)：Dexterity/Frail 限定来自卡牌的格挡，因此固定 Block Potion 不应被一概当作简化而修改。铜鳞稀有度已由 Uncommon 改正为 Common，0 伤害普通攻击仍触发 Thorns；PC 构建号、精确开战队列及原作/平台实测尚未完成，不声明全量严格一致。生成手牌满手进入弃牌堆。战斗状态与生成牌在战后清理，永久卡组、升级、生命和资产跨节点保留，具体时序见 README。
