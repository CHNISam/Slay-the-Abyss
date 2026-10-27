# 自动牌沿用生产选择续队列

机器人与观者Final接线共用现有`queuedCards`，不另设身份框架。`Combat.queueCard(state, instance, options)`只登记数据；调用者负责原牌、stat-equivalent新UID/无deckUid，或保留永久归属的同源复制。

身份由三个字段分别承担：`uid`为每个物理实例唯一编号，`uuid`为本场逻辑来源，`deckUid`仅为永久牌组owner。`CardActions.fresh`构造与stat-equivalent复制分配新uid/uuid并清deckUid；`CardActions.sameInstance`也分配新物理uid，但保留原uuid与deckUid。native Duplication/DoubleTap已使用同源接口，不能再复制相同物理uid。Ritual增长按uuid更新所有在途同源实例，永久增量仍只由deckUid认领。

`autoplay_identity.lua`真实Duplication+ThinkingAhead两轮选择先红后绿，覆盖副本purge、牌堆/in-use物理UID不冲突；构造检查临时/永久Genetic两副本，以及真实临时/永久Ritual增长时same-instance同步而stat-equivalent保持隔离。Genetic构造检查尚不冒充其真实出牌/成长已完成；该牌将在机器人Final专属切片接入后单独验证。

options支持`append`、`purge`、`exhaustCards`、`targetIndex`、`randomTarget`、`energyOnUse`。`randomTarget=true`在每次实际执行时使用cardRandomRng选择活敌；未提供energyOnUse时读取执行时能量。自动牌免费使用，X仍以快照确定效果，但不消费当前真实能量。显式exhaustCards强制原实例消耗；purge优先，不重复落堆或触发消耗。

原生牌沿用CardActions，职业flow/选牌牌使用原ActionQueue及真实handlers。出现手牌、弃牌、抽牌堆或占卜选择时，自动队列停止，原token命令恢复后才继续下一张自动牌。历史、出牌反应、cardInUse、死亡处置及外层命令回滚保留原宿主语义。

两条路径均在使用时触发遗物onUseCard、处置时触发afterCard；非purge使用清理freeToPlayOnce，按原Power顺序消耗Duplication/DoubleTap并登记同源purge回放。共享登记不重复触发原生路径的回调。Havoc的目标遵循固定源Havoc.use：使用时从活敌池抽取一次，PlayTopCardAction及后续自动牌复用该目标，不在执行时重新抽样。

审查回归先证红：合法混色Havoc顶牌Strike漏6伤害；Defect自动Strike未更新Nunchaku、未消耗Duplication及回放；Forethought免费标记未清理。修复后`autoplay_class_continuation.lua`核对伤害与cardRandom计数，`autoplay_lifecycle.lua`核对真实Run药水及原生攻击各次回调次数；旧`potion_duplication.lua`八组继续通过。

永久变更由Run统一认领：Combat接收`options.masterDeck`私有纯data快照与独立miscRng（正式房间在怪物构造消耗后复制该房间流）。职业动作仅将完整结果写入`state.masterDeckChanges[deckUid]`，并更新本地有序快照；不直接触碰run.deck或升级战斗实例。Run在原play/endTurn/所有选择/药水/胜利的成功边界提交结果与miscRng，清空一次ledger；失败命令维持原永久牌及RNG。Ritual增长保留原增量语义，并刷新本地快照，避免后续永久升级抹掉已成长的misc。`permanent_owner_boundary.lua`仅验宿主隔离/提交/失败事务，Lesson与Genetic实际效果另有角色切片，不以该注入测试冒充牌已完成。

短回归`autoplay_class_continuation.lua`真实验证：Chaos原先报unsupported_effect的自动出牌；Warcry暂停手选后再执行下一张purge牌；Tempest与ReinforcedBody的执行时X快照与免费能量；合法混色Havoc下游故障保持原牌堆引用、UID、能量和RNG。各缺口先红后绿，单次运行不足1秒。本切片尚不表示Defect剩余19牌或Watcher Final已完成；后续专属模块继续独立验收。
