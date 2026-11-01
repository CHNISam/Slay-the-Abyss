# Jaw Worm Horde 独立切片

本片仅实现第三幕普通来源 `Jaw Worm Horde`；Darklings、Writhing Mass及Boss保持明确拒绝，原母池/权重/拒重不改。来源为本地只读第三方反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是原版PC二进制或平台验收。

[来源锁](../../tests/fixtures/jaw-worm-horde-source-lock.json)记录ZIP及15个原始成员SHA256；[独立 Python 模型](../../tools/oracles/sts1_jaw_horde.py)不导入生产Lua/数据，重生[四条五轮向量](../../tests/fixtures/jaw-worm-horde-vectors.lua)，逐轮核对三只的实际招式、伤害、格挡、力量、下一招和完整AI words/counter。生成器和向量按LF归一化锁定，原始ZIP字节不归一化。

| 固定方法 | A0合同 |
| --- | --- |
| `MonsterHelper.getEncounter` | 按序构造三次`JawWorm(...,true)`，位置`(-490,-5)`、`(-150,20)`、`(175,5)`；没有misc池抽样、候选丢弃或MathUtils位置随机。 |
| `JawWorm` constructor、`AbstractMonster.setHp` | 每只HP40–44、一次monsterHpRng抽样，共3次。`hard=true`只把firstMove置false，不套用A2/A7/A17的伤害/HP/强化值。 |
| `MonsterGroup.init`、`JawWorm.getMove` | 三只构造全部完成后才依序开场AI：各一次0..99，开场共3次，无条件float。hard首招`<25` Chomp，`<55` Thrash，其余Bellow；第一幕仍消费一次主抽后强制Chomp。 |
| `MonsterGroup.usePreBattleAction`、`JawWorm.usePreBattleAction` | 开场AI、玩家初始洗牌后，各自按力量3→格挡6执行；不是把第一幕原样拷贝成三只。首个玩家回合可消耗该格挡，敌方pre-turn再清旧格挡。 |
| `JawWorm.takeTurn` | Chomp基础11；Thrash基础7伤害后格挡5；Bellow力量3后格挡6。初始力量使普通攻击实际为14/10，Bellow继续叠加。 |
| `JawWorm.getMove` | Chomp不连发，Thrash不三连，Bellow不连发。非法候选才额外取float：`.5625f`、`.357f`、`.416f`；严格小于，主抽仍先消费。每只保留自己的实际行动历史。 |
| `JawWorm.takeTurn`、`DamageAction`、`GainBlockAction`、`RollMoveAction` | 普通死亡。攻击中被反伤杀死后，死目标格挡取消；仍有队友时已排RollMove继续消费，最后一只死亡则清尾。毒先杀死者不行动、不排本轮RollMove。 |

实现使用独立`jaw_worm_hard`数据变体、固定formation和正式Act3 resolver。只给既有Jaw初始化和preBattle增加hard分支，继续复用后续AI与已有queuedRoll。`abyss_enemy_ai`保留Act2、Shapes、Transient和Spheric等原分派；不改Actor、Combat、普通owner-end框架、牌或遗物。没有新增核心模块，原架构分类适用。

## 真实入口与验证

原最小红例从seed15完整队列消费两个原前缀后，在公开`Run.startRoomCombat`遇到真实Horde并返回`act_content_unavailable`，日志`build/jaw-horde-entry-red.log`。接入后，同一入口三只独立hard actor、HP3/AI3/misc0、初始强化和来源位置通过。该边界为floor37、房间种子52；不能误把Raw seed15或下一层种子当HP/AI种子。

专用18组覆盖公开来源/原数据保持、formation无随机、实际HP1→HP2→HP3→AI1→AI2→AI3→洗牌→preBattle顺序、所有hard首招整数区间、四种子五轮实际动作、初始格挡、严格float界限/历史、反伤及毒死亡尾、普通奖励与真实永久UID领取、第二构造/最后preBattle/第二实际RollMove晚失败全图与原引用回滚、其余未实现拒绝、第一幕不变、真实Host三目标/HP/意图/力量帮助。

已执行：

- `node --test --test-concurrency=1 tests/jaw-worm-horde.test.mjs`：18组与来源锁通过，6.566秒。
- `node scripts/test-lua.mjs tests/lua/jaw_worm_ai.lua`：原完整13组通过，20.822秒，保留16种子×24轮及原断言。
- `node scripts/test-lua.mjs tests/lua/jaw_worm.lua`：原完整15组通过，5.283秒。
- `node --test --test-concurrency=1 tests/jaw-worm-data.test.mjs`：原13项数据正负用例通过、零skip。
- 以上Lua均保留原30秒预算。日志为本树`build/jaw-horde-{targeted,old-ai,old-actions}.log`。

Orb旧拒绝夹具的seed15第三项已被本片实现，只将输入迁至仍未实现的seed34第三项Writhing Mass。固定TheBeyond与既有独立队列模型给出前缀`3 Shapes / Orb Walker / Writhing Mass`；保留原两次队列消费和全部拒绝/RNG/资源/原引用断言，并精确核sourceName。没有改旧来源锁或缩池。实际串行复跑Orb原12组与迁移通过4.569秒、Transient完整19组及来源锁通过12.659秒，三项JS全部通过、零skip，原预算不变；日志`build/jaw-horde-adjacent-green.log`。按协调范围不重复未改变预期的Shapes夹具，不声称本片另跑了它。

架构检查157模块/913边通过；四份生产文件单独固定Luacheck零警告/错误。完整固定Luacheck1.2.0保留105项历史警告，无新增诊断；Battle render≤10、所有受管方法≤15的原绝对门槛通过，静态baseline未修改。ZIP/15个原始成员哈希与独立向量重生一致，diff检查通过。

## 边界

五轮向量使用1000玩家HP以观察算式，不是自然存活证明。死亡边界显式将目标置低HP；奖励用例调用真实Core伤害后走公开完成/领取，以隔离奖励归属，不是自然击杀证明。真实Run/Host保留80HP及起始牌组，使用完整母队列和公开入口，没有注入HP、能量或替换敌人来伪造自然路线。

本片没有全Quality、同SHA远端CI、跨幕完整自然路线、平台导入、实机UI或发布证明；不混入当前RC，也不据此宣称第三幕或M3齐备。
