# 来源与适配边界

核对日期 2026-10-22（后续局部复核见下文）。参考初代 Slay the Spire，不引用二代。不搬运图片、程序、存档或长文，中文效果文案由本项目编写。基准为 Ascension 0；旧表的固定生命近似仍属待补缺口，已核实并支持 hpRange 的敌人按范围实际采样。

- 卡牌：https://slaythespire.wiki.gg/wiki/Ironclad_Cards ，单卡按英文 id 对应同名页，例如 https://slaythespire.wiki.gg/wiki/Bash 。
- 普通敌人与遭遇：https://slaythespire.wiki.gg/wiki/Monsters ，例如 https://slaythespire.wiki.gg/wiki/Jaw_Worm 与 https://slaythespire.wiki.gg/wiki/Cultist 。
- 精英：https://slaythespire.wiki.gg/wiki/Elites ，Boss：https://slaythespire.wiki.gg/wiki/The_Guardian 。
- 遗物：https://slaythespire.wiki.gg/wiki/Relics ，药水：https://slaythespire.wiki.gg/wiki/Potions 。

完整75卡来源表由另一会话提交1d04cf2，本分支原样保存在reference/warrior75.json；其中有6张费用待核实及未映射的效果/触发器，不能直接用作运行时数据。首轮37张均来自该战士参考表，采用统一op表达，血液操控升级伤害按来源修为20；X费用以costMode=all_energy表达。不会声称75张可玩。

历史适配记录（仍是待补机制，不能视为原版验收）：除沉眠遗卫、深渊守卫外敌人仍固定意图循环；护盾小魔格挡给自己；符文哨卫施加虚弱代替塞入眩晕。五种小魔出现在一个五敌遭遇中，待通关测试评估强度。大型软泥不分裂；窃金客不偷金逃跑。这里的适配不意味着数值已经平衡。

2026-10-23 沉眠遗卫离线切片：对照 [初代 Lagavulin wiki](https://slay-the-spire.fandom.com/wiki/Lagavulin) 的睡眠/唤醒时序，并以 [SlaySpireDB 初代条目](https://slayspiredb.com/sts1/monsters/lagavulin) 复核 A0 数值。两者为社区二手资料，不是官方源码或本轮原版实测。A0 生命范围109–111，Combat使用战斗种子实际采样（旧112属于A8+范围）；睡眠格挡8、自然睡眠3回合、HP损失唤醒并眩晕当次行动、苏醒后18伤害两次与敏捷/力量各-1循环。详细证据、测试及剩余缺口见 docs/reviews/TASK-15-lagavulin-ai.md。

rules.json 的 15 层含 Boss、14 层营地及固定金币奖励/商店价格是项目配置。初始 80 生命、3 能量、5 抽牌、10 手牌上限为成熟规则起点；不声称整个地图照搬原作。

本任务仅验收内容基线与数据校验。未编译平台逻辑、未导入存档、未运行游戏、未获得 Furinya 体验验收。

药水 damage/block 与遗物 block 采用固定数值，不受攻击/格挡状态修正；这也是本项目简化。生成手牌满手进入弃牌堆。战斗状态与生成牌在战后清理，永久卡组、升级、生命和资产跨节点保留，具体时序见 README。

2026-10-23 深渊守卫离线切片：初代PC A0攻守阶段及数值参照[Guardian社区wiki](https://slay-the-spire.fandom.com/wiki/The_Guardian)、[SlaySpireDB初代条目](https://slayspiredb.com/sts1/monsters/theguardian)。Sharp Hide按卡而非按命中、Iron Wave先得格挡的动作顺序另见[TCK原版测试答案Problem 1(g)](https://tck.mn/videogame/stsexam/OLD_stsexam1-v1-solu-v1.pdf)。未锁原版二进制版本；社区资料/作者实测与本项目离线测试分别记录于docs/reviews/TASK-17-guardian-ai.md，不据此宣称整体原版或平台通过。
