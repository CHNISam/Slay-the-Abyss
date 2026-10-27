# 第三幕 Orb Walker 独立切片

TASK-62 的完整第三幕范围不变。本片提供 Orb Walker 一种真实遭遇；第三幕来源清单有 16 种不同遭遇，另外 15 种仍明确返回 `act_content_unavailable`。未裁剪来源池、替换怪物、补抽队列或开放未实现 Boss。没有平台导入、实机、自然全幕通关或发布证据。

固定行为参考是第三方反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，本轮只读本地固定 ZIP。原文件路径、方法、逐文件 SHA256 和 ZIP SHA256 见 [source-lock](../../tests/fixtures/act3-orb-walker-source-lock.json)。不复制 Java 原文进产品，不将源码解读等同原版二进制验证。固定材料没有本轮已核对的中文敌人名，因此显示来源名称 `Orb Walker`。

| 固定方法 | A0 合同与实现 |
| --- | --- |
| `OrbWalker` constructor、`AbstractMonster.setHp` | superclass 参数先抽 90–96，再 `setHp(90,96)` 抽实际 HP；保留两次 monsterHpRng 消费。 |
| `usePreBattleAction`、`GenericStrengthUpPower.atEndOfRound` | 开战获得成长 3，每轮结束获得力量 3，首轮也生效；成长动作先于之后附加的轮末衰减状态。死亡敌人不再获得成长。 |
| `takeTurn` | Claw 15；Laser 10，随后分别创建一张默认 Burn 进抽牌堆与弃牌堆，再 RollMove。使用既有力量、虚弱、格挡、死亡和 Burn 生命周期。 |
| `getMove` | 每次消费一次 0..99 主 AI 抽样；低于 40 倾向 Claw，否则 Laser；两种招式各禁止三连，不增加强制改招时的随机抽样。 |
| `MakeTempCardInDiscardAndDeckAction.update`、两个 ShowCard effect constructor、`CardGroup.addToRandomSpot` | 先抽牌堆、后弃牌堆，各一个独立实例和新 UID，均未升级、无永久 deckUid；status 不受 MasterReality 升级。空抽牌堆不抽随机；非空以 cardRandomRng 从 0..size-1 插入，保持原顶牌，不用 shuffleRng。 |
| `DrawCardAction.update`、`EmptyDeckShuffleAction.update` | 复用现有补抽；只剩新 Burn 的边界可先洗一次单牌弃牌，再递归洗一次空弃牌，真实消费两次 shuffle randomLong。 |
| `TheBeyond` 遭遇生成、`MonsterHelper.getEncounter` | 正式入口 `Run.startRoomCombat` 按原 Act3 队列消费 Orb Walker 单怪编组。其余来源拒绝时不提交队列、房间随机或资源。 |

攻击者被反伤杀死且仍有队友时，已入队的双 Burn 和 RollMove 继续；最后一个敌人死亡则清空该尾部，不创建 Burn、不再抽 AI。新动作通过既有 Effects 的 final-outcome 判断执行。`Combat.endTurn` 只对含 Act3 敌人的状态增加现有 Snapshot 事务包装，覆盖原生和实验机制调度；发生 Burn 放置异常时还原伤害、牌堆、UID、事件、随机流及原对象引用。其他幕已有调度不变。

新增 `abyss_act3_enemies`、`abyss_act3_ai` 和 `abyss_act3_powers` 已登记 architecture。Host 的最小呈现增量只有 `enemyBurnBoth` 的 debuff 副意图和“各一张 Burn 进入抽牌堆/弃牌堆”详情。当前基线解析仍在 `abyss_battle_ui.lua`；集成到已抽取 IntentView 的上游时只迁移这个 op 的映射和描述，不回填旧 UI。

验证使用独立 Python 64 位 RNG 解读与生产 Lua 公开入口：

- `python tools/oracles/sts1_orb_walker.py`：不读取生产 Lua 或游戏数据。seed 1/42/77 的两次 HP 抽样为 96→95、92→95、94→96；五次 AI 主抽样分别为 55/5/88/32/21、24/41/71/88/61、80/55/93/68/47。它们是固定源码模型向量，并非原版运行 oracle。
- `node --test tests/act3-orb-walker.test.mjs`：12 组生产回归，包括真实 Run 入口、拒绝/构造失败回滚、39/40 边界、首轮成长、双 Burn 身份与 RNG、原生 Burn/空洗牌、反伤死亡队列、两种 endTurn 调度异常回滚、大 UID 拒绝和真实 Host 核心信息。使用原默认 30 秒预算。
- 基线 `8d347cca` 的原 `abyss_run` 通过同一 seed 4、act 3、floor 35 的正式入口时，红于 `act_content_unavailable`；实现后该入口成功。只读提取旧模块到忽略的 build 目录复核，没有修改基线源码。
- Host 在真实 `start` 绑定的同一 Run 上设置章节边界后调用 `Run.startRoomCombat`；断言敌人真实名称/HP、10 点意图、副图标、两堆详情以及成长层数/身份。修复前该短测明确红于缺失 Burn debuff 图标，修复后通过。
- 章节 fixture 显式设置 act/floor/原始章节队列，未模拟前两幕胜利；数值/反伤/故障注入是局部规则输入，不宣称自然通关，也不注入 HP 来作自然通关证据。生成牌和第二轮伤害用真实命令执行。

已有定向回归通过第一幕 combat 23 组、第二幕敌人 34 组、room_shuffle 6 组、queued_enemy_roll 21 组、Guardian AI 24 组和 cross_act 12 组。它们不替代第三幕全内容或平台验收。固定 Luacheck 检查新模块及其余修改的核心文件为零诊断；旧 Effects 2 条、UI 27 条历史告警按原始行文本、code、column、message 及消息中的引用行号严格重定位比较一致，新增零条，未改 baseline。
