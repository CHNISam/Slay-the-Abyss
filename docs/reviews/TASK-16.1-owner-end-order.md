# 玩家回合末共享阶段修复

本片基于 `cce95d01`，只修 Lua 核心的玩家回合末阶段及现有队列接线。未做平台导入、实机或完整跨卡组合验收。原创 V4 保留既有自定义路径。

## 固定来源与结论

固定源码提交为 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`。ZIP 与 47 个成员的 SHA256 见 `tests/fixtures/owner-end-source-lock.json`；这是固定反编译源码证据，不代表官方二进制或平台验证。

- `GameActionManager.callEndOfTurnActions:358`：前置 Powers 先构造格挡，再 BOT 球回合末触发，再自动 Burn/Regret。格挡产生的 Juggernaut BOT 伤害在球触发后执行；球触发同步增长 Dark，并把 Frost 格挡加到已有 BOT 尾部。
- `AbstractRoom.endTurn:383`、`AbstractCreature.applyEndOfTurnTriggers:536`：所有普通 Power 按优先级、同级取得顺序先构造动作，再执行。默认优先级 5，Establishment 25，Constricted 105。Regen 的 TOP 动作先执行。临时属性归还、No Draw 移除也属于该阶段。
- `GameActionManager.clearPostCombatActions` 保留 DAMAGE 与 GainBlock 等动作。Combust、Omega、Bomb 的已排队伤害继续执行；Combust 杀死最后来源后，捕获该真实来源的 Constricted THORNS 仍可杀死玩家，最终为 defeat。Omega/Bomb 的固定 `DamageAllEnemiesAction` 来源为 null。
- `RetainCardsAction` 暂停后继续原普通队列，后续 Establishment 不得抢跑或重触发。`DiscardAtEndOfTurnAction.update:25` 先取出保留牌，再排 Ethereal、弃牌、恢复保留牌；Ethereal 产生的 Dark Embrace BOT 抽牌在恢复之后执行。

## 最窄接线

新增 `abyss_end_turn_powers` 仅构造这些已核实钩子的既有 ActionQueue 数据。`PowerSchedule.ownerEnd` 读取实际成功取得历史，保留优先级及同级顺序；多项缺失历史明确拒绝，不猜测字母序。No Draw 重加去重后移到取得历史尾部。

前置格挡和球触发共用现有队列。仅已核实的 Juggernaut、Corpse Explosion、Sadistic Nature 的原 BOT DAMAGE 回调从 `cardActions` 转交，保留原 source/target/instance 引用；未知回调失败并回滚。没有新增全局队列、职业分支或任意回调放行。

普通阶段扩展接口是 `ownerEndIds` 与 `ownerEndPlan(state,id,amount)`，返回 `{top={},bottom={}}`。伤害载荷捕获真实来源对象，执行时不按 ID/slot 替换来源。主模块在全部普通动作构造完成后统一执行并判定终局。WLP 暂停沿用原队列、现有 typed choice 与 Core 快照。

普通宿主共用现有 `exhaustHand → discardEndHand → restoreRetained` 队列。原生 Dark Embrace/Feel No Pain 的实际取得顺序转交已有 exhaust hook，不按职业身份禁用机制。

## RED → GREEN

- 原始阶段：Burn 先死仍执行 Combust、Study/Combust 取得顺序、原生 Like Water 缺失、临时属性与后置伤害优先级均有真实 RED。
- 独立预览保护探针：去掉动作 kind guard 后，末敌击杀后 `useCard` 处置会 nil 解引用；真实 Strike 回归锁定原物理 UID 正常弃牌。
- 新增前置回调 RED：真实升级 Juggernaut、Metallicize、Dark/Frost，末敌死亡时仅格挡 3，源应格挡 5、Dark 12。修复后双派发通过；非终局严格顺序为 `block3, damage7, block2, damage7`，恰好消费两次真实 cardRandom 目标抽取；Frost 晚失败恢复原 actor/orb/RNG 图及已消费随机流。
- 原生清理 RED：真实 WLP、DE2、9 Protect、Dazed，恢复后敌方回合手牌 9/新 Defend 0；源应 10/1。双派发修复后通过，满手第二张正常进入弃牌堆。

8 份专用 Lua 共 39 个用例全部通过，保留默认每份 30 秒，不改旧断言/输入规模。另复验原 Strength 30、Native expiration 5、Silent Final 28 次真实基本/升级出牌及交互、PowerSchedule 24、Watcher turn 与 block/retention 短例。

只读覆盖不可变 Maw/Growth `e6398c6e` 的真实来源模块、Actor/AI/UI，使用本片 Core/阶段 helper，原 18 组全绿。覆盖借用了该提交 Actor（缺本片 No Draw 记录，18 组不使用 No Draw）；这不是最终合并树验收。对方须接入本片 SHA、保留双方 Actor 窄改动后正式复验。

Architecture：151 模块 / 860 边通过。Lua static 没有新增诊断；旧基线 `abyss_effects.lua:197/199` 两个 W542 仍存在，由主线程独立负责，本片未改它或豁免。

## 验证边界

Core 的全状态/原对象快照覆盖 endTurn 与 WLP 选择继续中的晚失败。Run 奖励准备阶段的外层事务缺口由主线程另片修复，本片不修改 Run。

未扩展不支持的回合末遗物或回调，不宣称多 Ethereal 的 Java 全局 shuffle、全部 relic/跨色组合、完整自然渠道或平台表现已等价。阶段用例中的边界 HP/球槽/计时值为明确夹具；它们不作为自然获得或完整关卡证明。
