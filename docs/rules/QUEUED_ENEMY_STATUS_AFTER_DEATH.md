# 敌人反伤致死后的已排队单目标减益

2026-10-23，TASK-16.1，接续 `26ff410`。该增量只补齐 Fat Weak、Blue Rake Weak、Nob Skull Bash Vulnerable 在敌人行动中被反伤击杀后、仍有活队友及活玩家时的已排队 ApplyPower。未修改数据、原版随机候选或生产 LCG。

## 固定来源与证据等级

主来源仍为社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。下列文件本轮重新只读取得，原作 PC 构建及二进制身份未认证，没有官方源码、原作观察或实机证据；未编译、运行或搬运上游实现。

| 来源方法 | 核实规则 | Git blob / 本轮 UTF-8 SHA256 |
|---|---|---|
| [GremlinFat.takeTurn 62–75](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/GremlinFat.java#L62-L75) | A0 把基础 4 Damage、玩家 Weak1 ApplyPower、RollMove 依次放到队尾；A17 Frail 不在本片 | `55239a069de3b083eaedbb543a7a463a394c3e87` / `6183151f7c05a3836bb679218bc2f27dce110e94ddce6c04a8947c1f3a07f051` |
| [SlaverBlue.takeTurn 73–84](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SlaverBlue.java#L73-L84)、[GremlinNob 93–106](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/GremlinNob.java#L93-L106) | Rake 7 后 Weak1；A0 Skull Bash 6 后 Vulnerable2；攻击后还有已排队 ApplyPower | `72e0f3ec8385fe4065abb359ab8b5a03d2c41b6d` / `16d51d32d2b77f822cfb4cb47fd04735b0fce0c4`，延续[已核方法链](QUEUED_ENEMY_ROLL_AFTER_DEATH.md) |
| [ApplyPowerAction.update 90–111](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java#L90-L111) | target null / dead 时取消；没有 dead source 取消条件，仍访问 source powers 的施加钩子 | `1a6af352c02e06ecec4db87dd5e2f57d43d35b91` / `f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47` |
| [DamageAction.update 59–85](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java#L59-L85) | 普通 DamageAction 在来源已 dying / halfDead 时取消；THORNS 例外。伤害后全部怪基本死亡才清战后动作 | `ea89aeab60af8a7c297495de3cd8eb82d7130232` / `c5649fc04cbcadffa617e5c52f1a6f879f88cb1a90a543d5a0a05ebf950578ec` |
| [GainBlockAction.update 47–55](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/GainBlockAction.java#L47-L55) | target dying / dead 时不给格挡 | `ce4c481797045d55a17b133289e2e070431eacdf` / `e48f437c06b42dda312446a4b536aca54570d637e53087ac16f736d84bb5df4f` |

Thorns 加到队首、只在末敌死亡时清除 ApplyPower / RollMove、队尾动作排空才进下一个敌人的链条沿用[排队 roll 账本](QUEUED_ENEMY_ROLL_AFTER_DEATH.md)。因此不能把一个“来源死亡就停止整个效果列表”的 guard 套给所有已排队动作，也不能整体放开死者的后续攻击或自我增益。

## 最小实现和边界

`Combat` 复用原来的解析、pcall 恢复 `resolvingEffects`、EnemyAI 后处理路径，将实现收为私有 `resolveEffects`。公开 `Combat.applyEffects` 仍调用默认模式，卡牌仍经过这个公开函数，保留原有 monkeypatch / 失败回滚合同。只有 `Combat.endTurn` 已进入真实敌人行动后，调用私有实现携带 `queuedEnemyAction` 参数；它要求 enemy phase、非玩家来源和 player 目标，不写入 state、快照或任何持久字段。

Effects 的来源存活路径不改；来源死亡时默认模式仍立即停止。仅在敌方已排队模式、战斗没有胜负、player 目标仍存活时，继续单目标 `applyStatus`。其它动作不因该参数变得可执行：额外／多段 Damage 仍受原来的 source-dead 检查，Block、自身 gainStatus、治疗相关 regen / 回合结束、draw / energy 等仍不会由死者运行，`applyStatusAll` 未启用。未知 operation 仍明确报错，不把非法 payload 当作成功；已有 endTurn 的非事务性质未改变。

继续施加状态之后才进入先前新增的 `EnemyAI.afterAction`，所以 ApplyPower 先于该死者已排队的 RollMove；不会重复其行动。末敌死亡或 player 已死时立即停止新增路径；行动前中毒致死的敌人没有进入 takeTurn，完全不走该路径。弱／易伤首次跳过逻辑仍由 Actor.status 在 enemy phase 按原来源引用处理，不因 source 已死丢掉 monster-source 标记。

## 独立输入、红绿和事务验证

`tests/lua/queued_enemy_status.lua` 初始 19 组真实运行为 9 通过 / 10 失败。明确差异包括：真实 `Run.startCombat(...,"gremlin_gang")` 中 Fat HP1 / 玩家 Thorns1 后丢失 Weak；Nob HP1 执行 Skull Bash，被 Thorns1 杀死，活 Blue 执行 Stab 时只扣 12 而非 18，玩家最终 62 HP 而非预期 56 HP。后者按固定 6 + floor(12×1.5) 推导，不读取配置生成预期。

修复后增加一次真实 Strike 和后续衰减验证，共 20 组通过：

- Run 用 floor5 作为合法主机入口夹具，保留当前项目五成员 gremlin_gang 和原 payload；只把 Fat 调为 HP1、玩家施加 Thorns1，事件轨迹为 Fat damage4 → Thorns 致死 → dead-source Weak1，事件帧中 Fat 已死。该入口不是自然地图走到该层或原版完整遭遇编组／概率认证，不将其他成员的总伤害写成 Fat 原作预期。
- Fat / Blue / Nob 三者分别覆盖有活队友继续施加、末敌死亡清掉、行动前毒死不施加；dead target 不收到减益。
- Nob 的 Vulnerable 影响紧随其后的实际 Blue Stab，80→56；死 Fat 的 Weak 使下一真实 Strike 只造成 4，下一轮不再施加并归零。
- Blue 的 status 事件已经完成才消费死后 RollMove；对多段攻击、额外 damage、dead-owner block / regen 及未核实 applyStatusAll 使用显式夹具，保留不执行保护。
- 公开 applyEffects 在 enemy phase 也没有隐式获得该权限；真实玩家 Bash 被 Thorns 杀死仍不施加后续 Vulnerable。已施加 enemy Weak 后的失败玩家卡牌恢复 actor / statuses / hand / events 引用、能量、Block、seed 和事件，且没有队列上下文泄漏；未知队列 op 仍报错。

定向回归 20 新状态 + 15 queued roll + 14 atomic_play + 27 HP-loss + 11 inventory + 10 inventory_parity + 6 potion_slots + 35 statuses + 11 Fat + 9 Blue + 12 Nob + 13 Jaw + 17 round_debuffs + 23 combat，共 223 组通过。atomic_play 中公开 applyEffects 的受控失败和调用次数 monkeypatch 原样通过。没有修改 Inventory 或药水代码，现有非法药水效果／溢出拒绝及槽位原子性回归保留。

## 未认证部分

这只补齐当前支持敌人的单目标 ApplyPower guard；没有实现完整动作队列、dead-source SetMove、群体 ApplyPower、特殊免疫／Artifact、source power 的 onApplyPower 钩子、halfDead / escaping 或所有回调插队。现有玩家卡牌被反伤杀死后的效果终止约定按用户要求保留，不能据此宣称全部原作卡牌排队机制一致。

生产共享 LCG、独立随机流／种子映射等没有改动。未跑全量 check，也未做平台编译、副本导出、官方导入、原神或千星实机。严格原版身份及平台 AC 全部保持未勾；主代理整合 Fat / Sneaky 新 policy 后统一验证组合，不把本分支早期敌人 policy 版本当作新增问题。
