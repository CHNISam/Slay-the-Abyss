# 自动牌沿用生产选择续队列

机器人与观者Final接线共用现有`queuedCards`，不另设身份框架。`Combat.queueCard(state, instance, options)`只登记数据；调用者负责原牌、stat-equivalent新UID/无deckUid，或保留永久归属的同源复制。

options支持`append`、`purge`、`exhaustCards`、`targetIndex`、`randomTarget`、`energyOnUse`。`randomTarget=true`在每次实际执行时使用cardRandomRng选择活敌；未提供energyOnUse时读取执行时能量。自动牌免费使用，X仍以快照确定效果，但不消费当前真实能量。显式exhaustCards强制原实例消耗；purge优先，不重复落堆或触发消耗。

原生牌沿用CardActions，职业flow/选牌牌使用原ActionQueue及真实handlers。出现手牌、弃牌、抽牌堆或占卜选择时，自动队列停止，原token命令恢复后才继续下一张自动牌。历史、出牌反应、cardInUse、死亡处置及外层命令回滚保留原宿主语义。

短回归`autoplay_class_continuation.lua`真实验证：Chaos原先报unsupported_effect的自动出牌；Warcry暂停手选后再执行下一张purge牌；Tempest与ReinforcedBody的执行时X快照与免费能量；合法混色Havoc下游故障保持原牌堆引用、UID、能量和RNG。各缺口先红后绿，单次运行不足1秒。本切片尚不表示Defect剩余19牌或Watcher Final已完成；后续专属模块继续独立验收。
