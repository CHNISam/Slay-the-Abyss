# 已行动敌人死亡后的排队选招

2026-10-23，TASK-16.1，基线 `de15f0d`。本片只修复已支持随机选招敌人在行动中被荆棘杀死、仍有活队友时漏掉已排队 RollMove 的分派边界，不是完整动作队列复刻。

## 固定方法链与证据等级

主来源为社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。本轮只读核对方法体，与 enemy_parity 的独立读取 hash 相符。镜像没有与正版 PC 构建号或二进制认证；本日期是文本核对日期，没有原作运行或观察证据。未执行、复制粘贴或提交上游实现。

| 来源 | 核实内容 | Git blob |
|---|---|---|
| [JawWorm.takeTurn 114–138](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/JawWorm.java#L114-L138)、[SlaverBlue 65–84](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SlaverBlue.java#L65-L84)、[GremlinNob 81–106](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/GremlinNob.java#L81-L106) | 先将攻击等动作加入队尾，再将 RollMoveAction 加入队尾 | `033b26ba08b7dea04d2cff62cd50da868ff887b9` / `72e0f3ec8385fe4065abb359ab8b5a03d2c41b6d` / `16d51d32d2b77f822cfb4cb47fd04735b0fce0c4` |
| [ThornsPower.onAttacked 45–49](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThornsPower.java#L45-L49) | 把 THORNS DamageAction 顶到队首，在原队尾 RollMove 之前执行 | `e898e2f525a6eb49664eadb847dacb681f2931fe` |
| [DamageAction.update 59–89](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java#L59-L89) | THORNS 不因通常的 source 死亡条件取消；伤害完成后只有全部敌人基本死亡才调用 clearPostCombatActions | `ea89aeab60af8a7c297495de3cd8eb82d7130232` |
| [MonsterGroup 85–90 / 112–116](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java#L85-L116)、[AbstractMonster.damage / die](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java#L683-L694) | 全部基本死亡以 isDying / isEscaping 判断；新一轮排怪跳过死者，伤害致死设置 isDying | `7096970a151840489a3fba89806e6391e0d82d76` / `4784e38e7afff5980736e2b5c718e62a0c838c47` |
| [GameActionManager.clearPostCombatActions 119–125](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java#L119-L125)、[getNextAction 174–178 / 297–314](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java#L174-L178) | 战后清理只保留 Heal / GainBlock / UseCard / DAMAGE，故 RollMove 被删；正常调度先排空 action，再处理下一只敌人的 takeTurn | `1662da8de2aeb42044b385f03d0c801750904b13` |
| [RollMoveAction.update 18–20](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RollMoveAction.java#L18-L20) | 无 owner 死亡检查，直接 monster.rollMove | `01731f966b9b6f8c3815b246cd02cf75eb5d2153` |
| [AbstractRoom.update 267–271 / endBattle 415–445](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L267-L271) | 战斗结束仍等待剩余 actions 排空；endBattle 最后清除 manager，不存在“任何单怪死亡立即清全部 action”的通用规则 | `c2a1a029a9f59b1b94026dff46d4155824b85f86` |

补充原始内容 SHA256：RollMove `c938d4b4a9183b39e91c1c54c79085ddf7b2bea082af14895b9a1a00a100fc50`，Damage `c5649fc04cbcadffa617e5c52f1a6f879f88cb1a90a543d5a0a05ebf950578ec`，GameActionManager `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3`。

## 确定预期和本地最小修复

| 条件 | 固定方法链推导 |
|---|---|
| Jaw / Blue / Nob 已发动攻击，被 Thorns 杀死，仍有活队友 | 该次 takeTurn 已排队的 RollMove 不被清掉；在队友行动之前消费主 roll。Jaw 若该主 roll 与历史命中条件分支，还消费额外 Boolean 请求 |
| 最后一名敌人被 Thorns 杀死 | DamageAction 触发战后清理，移除 RollMove；本次不消费该随机请求 |
| 敌人在行动前已经死亡，例如开始行动前中毒致死 | 不进入其 takeTurn，没有排队的 RollMove，不消费请求 |
| 该敌人已死，下一轮仍有活队友 | 仍不进入其 takeTurn，不重复执行前一轮已消费的 roll |
| Acid Slime S | [takeTurn 61–73](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/AcidSlime_S.java#L61-L73) 直接 setMove，没有 RollMoveAction，不因本片新增死后随机请求 |

`Combat.endTurn` 保留行动前存活检查和战斗终止检查。完成当前效果后只对活体调用 Actor.endTurn，再调用 `EnemyAI.afterAction`：活体沿原 advance；死体只对已经核实排队 RollMove 的 `jaw_worm` / `blue_slaver` / `gremlin_nob` / `rolled_attack` policy 调用同一个 advance。没有复制或简化选择器，因此 Jaw 的历史和条件额外请求仍走原入口。末敌死亡会先由 finish 返回，不执行 afterAction。

`rolled_attack` 是同批 Spike Slime S 生产片使用的 policy 名称，[其 takeTurn 58–64](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SpikeSlime_S.java#L58-L64) 也明确排队 RollMove，blob `94863463c79aadf1339af658291f6e1ffd2033fe`。该 policy 的活体分派与 HP 由 TASK-15 独立切片提供；本工作树只预留经过来源核实的名单，组合后由主代理统一验证。不把旧固定循环或其他 AI 自动当作原作 RollMove。

死体的下一意图和历史更新只记录已排队选招；`Combat.intent` 仍因 hp=0 返回 nil，死者不再行动、再生或归还临时力量。两个 Blue 的受控 primary 依次为 0、99 时，先死的 Blue 消耗 0，活 Blue 接收 99 选 Stab；省略死者 draw 会使活 Blue 接收 0 而选 Rake。这是当前适配器消费顺序的可观察差异，不是原版同种子认证。

## 验证与保留的队列缺口

`tests/lua/queued_enemy_roll.lua` 初始 13 组在修正夹具的 intent ID 后真实运行：8 通过、5 失败，失败均为存活队友情况下漏掉已排队请求。修复后增加队友后续意图与下一轮不重复消费两个边界，共 15 组通过；事务回滚用已执行死后 roll 的状态验证原 Actor / statuses / hand / events 引用、history 和 seed 不变。既有 Jaw / statuses 两个“死后总不选招”的错误预期被来源纠正，保留原有 Block、再生不执行与队友继续行动断言，没有删除测试组。

定向执行 queued roll 15、Jaw 13、Blue 9、Nob 12、statuses 35、Acid S 9、Cultist runtime 9、Cultist boundary 6、Guardian 24、round debuffs 17，共 149 组通过。完整检查和 Spike 组合由主代理统一执行，不并行跑全量。

**Blue 的 Rake / Nob 的 Skull Bash 攻击后的 debuff 队列差异仍未修复。** [ApplyPowerAction.update 90–111](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java#L90-L111)（blob `1a6af352c02e06ecec4db87dd5e2f57d43d35b91`）检查目标是否死亡，没有同样拒绝 dead source；当前 Effects 仍在 source.hp<=0 时停止整个后续 payload。因此还有活队友时，某些已排队的 Weak / Vulnerable 原作可能继续施加，项目目前会跳过。本片刻意使用 Stab / Bull Rush 等不含该后续状态的动作验证 roll，不用随机分派修复声明整段队列一致。死后 GainBlock 的目标 guard 另见 [GainBlockAction 47–55](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/GainBlockAction.java#L47-L55)，本片保留死者不获得格挡。

玩家死亡、半死／逃跑、特殊死亡能力、其他敌人未接入的原作抽样、全局 power 优先级及完整队列仍未认证。共享 LCG、16 位条件小数、独立 aiRng / HP / 洗牌流、种子映射完全未改；这里的消费次数不等于 RandomXS128 原版轨迹一致。没有平台编译、副本导出、官方导入、原神或千星实机证据。TASK-16.1 全部严格 AC 保持未勾。
