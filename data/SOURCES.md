# 来源与适配边界

核对日期 2026-10-22。参考初代 Slay the Spire，不引用二代。不搬运图片、程序、存档或长文，中文效果文案由本项目编写。基准为 Ascension 0，波动生命值取固定中间附近整数。

- 卡牌：https://slaythespire.wiki.gg/wiki/Ironclad_Cards ，单卡按英文 id 对应同名页，例如 https://slaythespire.wiki.gg/wiki/Bash 。
- 普通敌人与遭遇：https://slaythespire.wiki.gg/wiki/Monsters ，例如 https://slaythespire.wiki.gg/wiki/Jaw_Worm 与 https://slaythespire.wiki.gg/wiki/Cultist 。
- 精英：https://slaythespire.wiki.gg/wiki/Elites ，Boss：https://slaythespire.wiki.gg/wiki/The_Guardian 。
- 遗物：https://slaythespire.wiki.gg/wiki/Relics ，药水：https://slaythespire.wiki.gg/wiki/Potions 。

卡牌主数值为公开常见基准；无尽之刃/飞刀为本项目跨职业适配。不会声称 75 张已完成。

有意适配：所有敌人固定意图循环；沉眠遗卫不睡眠；护盾小魔格挡给自己；符文哨卫施加虚弱代替塞入眩晕；深渊守卫采用固定循环而非变形状态机。五种小魔出现在一个五敌遭遇中，待通关测试评估强度。大型软泥不分裂；窃金客不偷金逃跑。这里的适配不意味着数值已经平衡。

rules.json 的 15 层含 Boss、14 层营地及固定金币奖励/商店价格是项目配置。初始 80 生命、3 能量、5 抽牌、10 手牌上限为成熟规则起点；不声称整个地图照搬原作。

本任务仅验收内容基线与数据校验。未编译平台逻辑、未导入存档、未运行游戏、未获得 Furinya 体验验收。

药水 damage/block 与遗物 block 采用固定数值，不受攻击/格挡状态修正；这也是本项目简化。生成手牌满手进入弃牌堆。战斗状态与生成牌在战后清理，永久卡组、升级、生命和资产跨节点保留，具体时序见 README。
