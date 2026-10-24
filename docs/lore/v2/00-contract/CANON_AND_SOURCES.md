# 官方设定、原作事实、创作选择的分界

## 三层严格分开

| 类型 | 可依据的内容 | 必须避免 |
|---|---|---|
| 《原神》背景可借用概念 | 璃月、岩元素、旅行者荧、地脉异常、深渊侵蚀、古代遗迹 | 声称本作事件是原神官方既定任务；编造官方角色说过的台词 |
| 初代《杀戮尖塔》参考 | 高塔不同区域有生态与社会结构；商人、信徒、窃贼、事件、守卫以行为讲故事 | 复制原作对白、抄原作插图/模型；把 wiki 推测写成确认事实 |
| 《杀戮深渊》原创 | 岩脉封印、旧路商人、祈火徒火焰信仰、失序遗迹的社会生态 | 冒充上两类的 canon；为了自洽增添新数值、RNG、奖惩 |

## 有证据的《杀戮尖塔》参考

1. 开发者 Casey Yano 在 2019 AMA 中解释：世界观基于区域氛围发展；高塔由地牢、社会城市层、危险未知区域构成；鸟类宗教与向上攀登有关；守护者可重新组装是其反复挑战的世界内解释。**开发者直接陈述**：https://www.reddit.com/r/IAmA/comments/aj6sq1/were_mega_crit_games_creators_of_slay_the_spire/；可搜索相应回答 `Who handled the lore`。
2. 初代 Cultist 首回合施加 Ritual 后持续增强；与乌鸦崇拜有关的深层背景属于“强暗示”，不能当完全明示。**社区百科**：https://slaythespire.wiki.gg/wiki/Cultist
3. 初代 Looter 具有偷金、逃跑、死亡返金等机制。**社区百科**：https://slaythespire.gg/monsters/Looter
4. 原作 The Cleric：付费治疗/净化/离开；Purifier：祈祷删牌/离开。**社区百科**：https://slaythespire.wiki.gg/wiki/The_Cleric 与 https://slaythespire.wiki.gg/wiki/Purifier
5. 原作 Merchant 是交易 NPC，具性格、台词，不应推定其年龄、真实种族或教团归属。**社区百科**：https://slay-the-spire.fandom.com/wiki/Merchant

## 重要幕次警示

- 原版 `Looter` 通常归 **第二幕**，本项目 `data/enemies.json` 已把 `looter` 列入现有遭遇池：**项目事实 ≠ 已严格对齐原版第一幕**。相关规则/幕次核对交现有 `TASK-15`；本包不自行移除或改值。
- 原作信徒集会 `The Nest` 是第二幕事件。可以学习“宗教通过多个系统呈现”的方法，但 **不能把它当作第一幕已含的首发事件**。
- 有“推测”或“社区百科”标志的来源只提供创作参考，**不能自动变成官方确认或验收 Oracle**。

### 来源使用

写策划案时可归纳短句；不要搬运原作整段文本。规则严格对齐时，需独立锁定初代 PC 正式版/A0、原始版本与可复核数据，不能把本包的叙事研究用作数值依据。
