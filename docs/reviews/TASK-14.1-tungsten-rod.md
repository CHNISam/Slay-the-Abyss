# 钨合金棍独立切片

基线 `ad4ddab5`（父组合 d7c0a02/052）。只实现 Tungsten Rod，不修改普通 Combat 阶段、公开 Run.endTurn/chooseCard 包装或其他遗物规则。

## 来源与实现

固定反编译源码提交 `319009d5df0a82d9fb0f23cc22322286c6a87ec0`，ZIP 与 9 个成员 SHA256 见 `tests/fixtures/tungsten-rod-source.json`；未认证正版 PC 二进制或平台行为。

`TungstenRod.java:13/22..27` 定义来源 ID `TungstenRod`、RARE、每次正数损血末段减 1，零保持零。`AbstractPlayer.damage:1378..1428` 的顺序为 Intangible/Block → onAttackedToChangeDamage（Buffer）→ onAttacked（Static）→ 遗物 onLoseHpLast → Power.onLoseHp → HP/死亡/Fairy。

`BufferPower:41..45` 在前段将伤害归零；`StaticDischargePower:29..36` 检查当时正数 NORMAL 伤害，并排 TOP Channel。故 Rod 将 1 减为 0 时仍可触发 Static，而 Buffer 先归零时不触发。THORNS、HP_LOSS 也经过 Rod，但不触发 Static。

新增实际 Rare 定义及中文说明，使用空 generic effects 的现有 hooks 模式。`RelicHooks.onLoseHpLast(owner,amount)` 只处理实际持有列表的 Rod；Actor 两个 HP 路径仅对玩家调用。NORMAL 保存 pre-Rod 数值供已存在 Static 回调判断，HP 通知继续用实际扣血。未扩大遗物框架。

`Run.eventDamage` 的既有事务复用同一末段钩子，再走原 Fairy。它仅使用当前 Run 遗物和 HP，不读取历史 battle。`eventNormalDamage` 仅移除 Rod 缺失拒绝，Lizard Tail 的原拒绝保留；其他缺失遗物继续待办。

## 真实取得与验证

- 最初 RED：真实 public obtain 返回 `relic_content_unavailable`；受控持有 ID 的三种伤害边界与事件损血均未减 1，0/5。受控 ID 仅为红例的效果证据，不作正常取得证明。
- GREEN 使用真实 `Run.obtainRelic → startCombat`。四份专用 Lua 共 16 例：零/正数、NORMAL/THORNS/HP_LOSS、Block、真实 Buffer/Static 卡、Intangible、逐段损血、实际 HP 通知、敌人不受影响、Fairy 左槽、晚失败原图、跨房间。
- 源完整 Rare 队列：seed `'5'` 的首候选恰为 TungstenRod；`Run.prepareRelic({tier='rare'})` 只取一次且不提前发布 pool/RNG，再真实 obtain。显式 tier 是来源组件证据，不冒充完整自然奖励路径。
- 普通宝箱：seed 54，真实 `Nodes.enter → claimTreasure` 取得 Rod，再同一 Run 开战减伤。
- 普通商店：seed 1，真实 Rare 第二格报价 290，购买扣除 290 并加入实际遗物。用 `Run.gainGold(300)` 设置购买边界，不当自然经济证明。
- 两个旧事件结果夹具仅将 Rod 缺失拒绝改为实际取得后成功：Golden Idol 的 20 → 19，Winding 的 10 → 9；Lizard/Darkstone 等拒绝、原输入规模和时限保留。
- 实际 Nodes 陷阱在 Rod/Fairy 已执行后注入失败，恢复原库存、事件、牌组、RNG 和外部地图；实际 Run.endTurn 在 HP 通知后失败，恢复完整 Run 与原 battle/player/enemy/hand 对象，重试成功。
- 同一 Rod 经真实击杀、领奖离开、Shining Light 事件、第二场开战继续生效。击杀夹具显式将末敌设为 1 HP，不当完整自然通关证明。

已通过：Rod 16 例；两个旧事件结果脚本；6 个来源 JS 断言；原 Common attacks 6、battle Fairy 6、event Fairy 8；数据构建与主题构建。Architecture 156 模块/899 边通过。固定 Luacheck 1.2.0 无新增诊断、105 条原历史警告；唯一既有 W212 从原 142 行迁到 152 行，file/column 34/code/message/exact source 行一对一不变，父已明确授权，无新增豁免。

## 独立旧缺口与边界

本片只登记 Rod 的当前项目映射及派生计数，149 个来源注册序、130 个源母池、原 source hash/locks 均未改变。该树 catalog JS 为 13/14：唯一失败是基线已有 Golden Idol 定义而当前 catalog 映射仍 null；父另片处理，不将本片说成完整 catalog 通过。

原 `common_relic_hooks` 前 8 例通过，第 9 例 Orichalcum 的 endTurn 触发断言失败。用精确基线 Actor/Hooks/Run blob、移除 Rod 定义后相同失败，已回报父线程；本片不改 Combat 阶段。

现有 Buffer 消耗仍沿用旧模块的同步 reduce 实现；本片仅验证 Buffer 在 Rod/Static 前先归零，不宣称修好了所有 TOP 交错。普通宝箱/商店仍是现有本地 supported-pool 路径，未宣称它们已消费全部原版遗物队列或完整概率等价。

新增主题图标明确沿用既有防护占位图；专属美术、完整自然渠道、完整关卡、全量 CI 和平台/实机均未在本片验收。任务整体保持未完成，由父线程统一账本和后续组合验证。
