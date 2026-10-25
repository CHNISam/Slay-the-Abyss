# PR196 消耗事务独立审查

## 结论

本轮没有发现可证实的规则缺陷。交付6组新增真实 Combat/Run 消耗事务测试，全部通过；3个隔离源码负变异全部被检出。不是重跑已有 warrior75 用例的计数，也不等于完整75张或平台验收通过。

- PR：https://github.com/CHNISam/Slay-the-Abyss/pull/196
- 冻结并于2026-10-24 20:31 UTC再次确认的 head：`529c8af1c2fd0bc6d501260824b04eb6f18821ee`。
- 启动时按任务读取 develop `9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db` 的 AGENTS/HANDOFF/SCOPE 与 Backlog；PR再次读取的当前 base 为 `f6712d0976235483794946863ff1bae9436c3053`。本报告只适用于冻结PR头，不主张已覆盖较新develop组合。
- TASK-16、TASK-16.1、TASK-47仍由 Codex 负责，保持 In Progress；未认领、未写 Backlog、未修改远端或原执行者代码。
- 51件纯运行模块、输入JSON与数据构建脚本逐Git blob匹配，见 runtime-verified.json。数据模块由本轮输入重新生成；4件未覆盖的旧UI文件不在本轮执行路径中。

## 新增用例与实际输出

1. Burning Pact + Sentinel + Dark Embrace，抽牌堆及弃牌堆均空：Pact自己的抽2不提前抽到自身；弃置后Sentinel的DE尾钩子才洗牌，重新抽回相同Pact UID。实际只消耗Sentinel、净能量+1、洗牌计数+1、手牌恰为原Pact。
2. 上述场景加Corruption和FNP：免费Pact与Sentinel各消耗一次，净能量+2、格挡6、没有手牌，也没有无牌洗牌。实际 `sentinel@E14,burning_pact@E16,block:3,block:3`。
3. Second Wind + 升级Sentinel/普通Sentinel/Defend/Strike + DE/FNP：原非攻击快照逆序消耗，Sentinel能量TOP插入优先于下一次消耗，之后才有Second Wind格挡、FNP和DE尾链；新抽牌不再次被消耗。实际 `defend@E16,sentinel@E16,sentinel@E18,block:5,block:5,block:5,block:3,block:3,block:3`，最后格挡24、净能量+4、保留原Strike加抽3张。
4. 基本与升级Fiend Fire，玩家2HP、目标2Thorns、其余手牌2张，DE/FNP已通过真实出牌获得：先消耗原手牌2张，第一击后玩家死亡，后续命中/抽牌/FNP/自身消耗均停止。实际各只有7/10伤害，玩家0HP、格挡0、2张仍在抽牌堆，Fiend Fire保留cardInUse，不入消耗/弃牌堆。
5. 真实 Run.play → Run.chooseCard：Pact暂停后选Sentinel，提交恰好一次；重复原token/UID返回stale_card_choice，深遍历验证原run内全部表身份与每个键值不变。实际净能量+1、格挡3、1张消耗、4张手牌。
6. 失败原子性边界：Pact暂停后选择Sentinel，真实执行能量/抽牌洗牌/弃置/FNP，直至真实Juggernaut尾链遇到显式损坏RNG counter而抛错。没有替换任何函数。全对象图确认选择前原表身份、键值、RNG、牌堆、队列、事件完全恢复；仅修正counter后重试成功，Sentinel/FNP只触发一次、Juggernaut伤害5。这是故意构造的异常状态测试，不称可自然触发的bug。

完整实际日志：logs/exhaust-transactions-final.log。

## 期望依据与证据边界

固定对照是仓库已经采用的第三方反编译镜像 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`，不是已认证正版PC二进制，也没有本轮原作试玩。独立重取17件来源，SHA256与本PR sources.json逐件相符，见 references-verified.json；临时方法体仅留本审查目录，没有复制进产品或交付源码。

- BurningPact.use：先排消耗，再排自身抽牌；UseCardAction.update负责后续弃置/消耗。DE/FNP的onExhaust追加到队尾，因此空堆Pact只有在弃置后才可能被DE抽回。
- BlockPerNonAttackAction.update：快照当前非攻击，分别将格挡和指定消耗插到队首；Sentinel.triggerOnExhaust把能量插到队首。由此得出多Sentinel逐帧顺序，不从被测Lua反推期望。
- FiendFireAction.update：按当前手牌数量生成伤害及随机消耗动作；CardGroup.moveToExhaustPile依次触发能力与卡牌回调；玩家死亡停止动作队列。DE/FNP均是追加尾动作。
- GameActionManager.clearPostCombatActions区分胜利保留动作；本轮致死测试明确是玩家defeat，不将胜利保留规则误用为继续FNP。
- 异常原子性来自本项目Combat.play/chooseCard既有事务契约，非宣称原作会出现损坏Lua RNG状态。

相关实现入口：abyss_card_actions.lua:23–38、122–147、215–228；abyss_combat.lua:346–386、448–477；abyss_run.lua:189–216。

## 负变异证明

全部变异仅在本审查目录mutants/的独立源码副本中，不改变冻结head。每个用同一个真实Combat测试重新执行：

- Sentinel能量由TOP改为BOTTOM：Second Wind轨迹断言红，期望18、实际16。
- 跳过Dark Embrace：空堆Pact、Second Wind和Run提交三组断言红。
- 去掉chooseCard失败回滚：完整表身份/键值断言红。

记录：mutation-results.json 与 logs/mutation-*.log。原head再次运行6/6绿，冻结51/51 blob再次核对相符。未跑全量、未安装依赖、未使用用户电脑、未平台构建/导入/实机。

## 复跑及移交

在本审查目录执行：

    cd <review-directory>/head
    python $LUA54_RUNNER ../exhaust-transactions.lua

预期摘要：`SUMMARY new exhaust probes: 6 passed / 0 failed`，exit 0。

测试SHA256：`b51b82f138c6db790438e39296aef070283d478b46a4ba32ba47e58b47c9e300`。

原PR执行者可以把 exhaust-transactions.lua 作为新增回归文件吸收，并在其实际最新头重新运行。此审查不自行提交/修复生产，也不把本轮小范围通过扩大为整个PR放行。
