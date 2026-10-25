# 三职业基础切片历史检查点

当前后续开发与验证请先读 [四职业构筑集成](ARCHETYPE_INTEGRATION.md)；下文保留较早基础阶段和冻结检查点记录，历史“未接入”不能用于判断最新树。

基线：origin/develop `877c4af3233b42119bbef7ffa57723d0f241bd84`。
本轮用户授权在隔离目录暂免远端认领；全局暂停不变。不提交、推送或合入。

## 已接入

- Silent.withFoundationCards(data) 返回独立数据副本，Deadly Poison、Shiv、Blade Dance 使用真实 Combat.play。Blade Dance 基础/升级分别生成3/4张未升级Shiv。
- Combat.new(data, {enableStances=true}) 启用 Neutral 姿态；Stances.change 排队，Stances.flush 在调用者确认动作边界后结算。Actor 在最终取整前应用普通伤害倍率；fixed 伤害不乘。下个自身回合退出神格。
- Combat.new(data, {orbSlots=3, orbRandomSeed='42'}) 为离线开发显式配置独立卡牌随机流；正式房间应复用 options.roomStreams.cardRandomRng。不得混用旧LCG或敌方AI随机流。
- Combat 玩家能量刷新后、抽牌前触发球开始效果；轮末在现有手牌轮末动作前触发球。这是当前有限生命周期接入，尚非完整原版能力/遗物动作管理器。
- 闪电末敌致死后通过真实 finish 检查阻止敌方行动；球数、集中和暗球蓄值均保存在战斗状态内，不写永久卡组。

## 验证

从本目录所属仓库根运行：

```sh
npm ci --ignore-scripts --cache /workspace/.npm-cache
npm run build:data
node scripts/test-lua.mjs tests/lua/silent_foundation.lua
node scripts/test-lua.mjs tests/lua/defect_orbs.lua
node scripts/test-lua.mjs tests/lua/watcher_stances.lua
node scripts/test-lua.mjs tests/lua/class_mechanics_integration.lua
```

来源及各模块边界见 SILENT_FOUNDATION.md、DEFECT_ORBS.md、WATCHER_STANCES.md。采用同一固定社区镜像 aeubanks/sts@319009d5；不是正版二进制认证。源方法只作行为核对，未复制进实现。

## 尚未完成

本切片不是三个职业可独立游玩的版本。职业选择、初始牌组与遗物、自然奖励和商店池、完整卡牌/升级、平台打包/UI和实机通关未完成。猎人弃牌选择与触发队列、机器人额外球相关能力/遗物、观者真言阈值及专属卡牌动作仍未接入；观者姿态需显式开发API切换。完整卡池及TASK-56/57/58/59验收均保持未完成。现有战士完整池和其他流派缺口也未因此解决。

未运行完整 npm run check，不能声明全量CI通过。完整回归和原生平台导出需在后续接入时串行执行。

## 后续接入：真实职业开局与构筑切片

现在可从同一离线 Run 入口明确启用实验职业：

```lua
local run = Run.new(data, '42', {character='silent', experimental=true})
assert(Run.startRoomCombat(run, 'normal'))
```

`character`也可为`defect`、`watcher`。不传第三参数保持战士。此入口不代表平台已开放职业选择，且完整卡池、掉落概率与专属药水/遗物尚未齐备。

职业数据保持独立：Silent 70HP/12初始牌/蛇戒，Defect 75HP/10初始牌/破损核心/3球位，Watcher 72HP/10初始牌/纯水。基础打击和防御使用独立职业ID，移除其他职业牌；原遗物目录保留供跨引用解析，但玩家只拥有自己的起始遗物。

蛇戒开场抽5后额外抽2；破损核心在首回合前生成1闪电；纯水在首抽前生成临时奇迹。下一回合和下一战分别验证只触发一次及正确重建。`character_run.lua`用不修改数值的初始牌组，在seed42的真实首间普通房间取得三职业胜利，再进入第二间验证开局重建；这是两房间接口与首战冒烟，不是第一幕通关证明。

追加的Silent牌包括灵动步法、后空翻、投掷匕首、匕首雨、斗篷与匕首、准备、快斩；Defect追加跳跃、扫荡射线、光束射线、聚变、碎片整理；Watcher追加猛虎下山、精神护盾、内心平静。表现名和平台文案尚未作为UI交付验收，规则固定源身份见各模块账本。

观者能力在获得时记录相对顺序，姿态改变时将能力动作排在姿态能量前；真实整牌处置后才抽牌，以便抽回本次使用牌。有限循环测试从正常3能量支付基础Rushdown后，Eruption+与Inner Peace连续运行10轮，没有增加能量或牌。该夹具使用高生命敌人避免有限回归提前结束，不作为正常房间自然获取证据。

猎人的Tactician/Reflex为合法不可打出牌，手动弃牌才触发。自动全弃的Reflex尾部延迟至使用牌入弃后再抽；回合末自动弃牌不触发。选牌命令需调用`Run.chooseDiscard(run,uids,token,combatGeneration)`，同时验证战斗代数与选择token。选牌时药水原本可消费并排队等待，当前未实现延迟药水队列，因此明确返回`unsupported_potion_during_discard`，不把这项限制冒充原版规则。

商店的逻辑colored槽按职业颜色筛选；Silent可以在当前受限药水池中获得/购买毒药水，其他职业排除。稀有/无色等空桶仍显示不可用，不重抽成已有牌。当前奖励和商店的完整源池顺序、概率及随机轨迹仍是已有缺口，不能据此声明原版全量一致。
