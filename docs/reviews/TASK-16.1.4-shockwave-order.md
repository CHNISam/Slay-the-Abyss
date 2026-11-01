# TASK-16.1.4：震慑敌阵按敌人结算减益

## 结论与边界

基础和升级牌保留两条平铺 `applyStatusAll`，用显式 `targetGroup: "weak_then_vulnerable"` 将执行顺序改为 A.虚弱、A.易伤、B.虚弱、B.易伤。不是排序已有日志：每次应用仍经过 `Actors.applyPower`，因此免疫消耗、状态和当时的事件快照同步发生。

只改四个生产文件：`data/cards.json`、`src/lua/abyss_effects.lua`、`scripts/validate-data.mjs`、`tools/render_traveler_cards.py`。第四个文件是集成时实际发现的严格表现生成入口，已经单独核定；未改模板、UI、Actor、Combat、Run、RNG、费用、数值、资产、Barricade guard、测试预算或运行器。

本轮是源码/生成链/离线测试交付。未编译或导出新 `.gil`，未官方导入、未在游戏中实测，也不以原生 Lua 5.4 代称 Fengari/平台环境。独立审查对 1320 候选已报告无阻断；当前提交 CI 及任务状态仍由集成记录承接，本报告本身不证明它们已完成。

## 基线与固定来源

基线为 `develop@ed1505bf7b69367e6479ad593319083efb5fbfd3` 加正式认领提交 `abc0cf2a96bf2386d2388321ba7f43d8622e9693`，认领 tree 为 `a7b748cd482616346fd9c3c7af5290a01ce67285`。Effects 已包含 PR180 的重复 Barricade 修正。本地隔离源的 13 个关键文件与 GitHub claim blob 匹配；全树可用的 1043 个既有 blob 中仅本片四个获准生产文件改变。轻量源未带的 188 个艺术/实机证据文件未删除，也不属于交付补丁。

以下均为实际重新取回并核对完整 Git blob 与 SHA256 的社区反编译参考 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`，不是官方开源、正版构建认证或本轮原游戏观察。只用于核对行为，没有将第三方源码/资产搬入交付。

| 参考文件 | Git blob | SHA256 |
| --- | --- | --- |
| Shockwave.java | d9b15b8ec402b8c45a0de78bdf0009adec06d3c1 | de4a47a7ae9332bded422d4e4620e3cb3174e05dc51d8647eba93ad3335d033a |
| ApplyPowerAction.java | 2b9c1d950af65d3353cf59e20ec40745c08b2a45 | 6064bffdc602f7a81f2b2ec88130f0abf87c8da456b711617dfda894fff29467 |
| ArtifactPower.java | b28bdd9cd643317f86e3bc62654f8c5630b70ad2 | c9d193e715953cd2bcfd5344b63fbe4ad7c3c4cb2b5fba7cf619ff46368ddcc4 |
| GameActionManager.java | 931cded5ae1aed78771e0a5389e8358946b78f8f | 52c359a5b977ac55d80d7c7fbfe94570a94e75a91e985d98dea2a9fcac6aa478 |
| ReducePowerAction.java | bfe41afe0304b987ce85cc426b8e63b6728cd16e | 2ff037d563351d3aa48e66f2e7326e9b2854806b0440ff4ea41fd5123ab8e9b8 |
| RemoveSpecificPowerAction.java | 8be3e7a0a1f2fe82b3eda1430011a80014db853e | ca1c4bd9dd2705768d21befd818160870e4d64d7b4c5ff1a1ac191a840abf822 |

- [Shockwave.use L35–44](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/red/Shockwave.java#L35-L44)：每次迭代先 Weak，再 Vulnerable，之后才取下一个敌人。基础 3、升级增加 2；费用 2、消耗保持不变。
- [GameActionManager L114–178](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/GameActionManager.java#L114-L178) 与 L258–263：普通加入队尾、从队首取出，TOP 反应插队；clearPostCombatActions 清理普通 POWER，保留其具体例外。
- [ApplyPowerAction L122–170](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/common/ApplyPowerAction.java#L122-L170)：应用时跳过死/逃目标，并在叠层前逐次触发 Artifact。
- [ArtifactPower L32–38](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/ArtifactPower.java#L32-L38) 及 Reduce/Remove 的 TOP 队列：第一项消耗的免疫在同目标第二项前已减少或移除。现 Actor 的即时消费覆盖本片已支持结果和帧，不等于复刻完整原动作队列/未实现钩子。

## 受限协议

1. 每个 effects 数组最多一组，恰好相邻两条，均明确携带固定枚举。顺序必须是 `applyStatusAll/weak` 后 `applyStatusAll/vulnerable`，只允许 `op/status/value/targetGroup` 四个字段。
2. 两个 value 相等，均为 1..2147483647 的整数数值。False/true、字符串、零、负数、小数、非有限值及越界值不合法。Python 接受数学上为整数的有限数值（含 3.0），与 JS/Lua 边界一致；bool 不是数字。
3. schema 仅允许卡牌顶层及升级 effects；敌方意图、药水、遗物、嵌套 then 不允许。实际只有 Shockwave 基础/升级启用此字段。
4. `Effects.supported` 只做结构判断，没有来源上下文。合法组可由公共玩家 `Combat.applyEffects` 调用，不要求 playedCard 或特定 cardId。apply 在执行自身任何效果前拒绝敌方来源、queuedEnemyAction 及坏组。
5. 新标记发现检查字段存在而非真假；false、0、空串、容器级、孔洞后、非数字键、不可达嵌套、循环与别名均不能绕过。JS/Lua 使用显式工作栈和 seen/active 标记，避免新增扫描令旧深层输入栈溢出。
6. 无任何新标记就不运行新的全面结构/op/数值预检：空 public effects、Slimed 的真实空使用、旧无标记 AoE 顺序、晚遇非法值/未知 op 时此前直接 effects 的变更均保持原行为。没有全局 `assert(supported(effects))`、自动融合或 cardId 暗分支。
7. 组前后未标记效果仍可存在。每次单独调用 Actor 前重检源/目标活性；目标在第一项后死亡/逃跑只跳过该目标后项，源死亡/逃跑停止整个组。前置伤害清掉末敌时遵循原 selective clear，保留 Block 等既有例外。
8. `Combat.play` 仍拥有整张牌的原地回滚，直接 apply 没有新增整笔事务。敌方绕过 schema 后可能在 endTurn 先产生 intent 或处理前一敌人，之后才被 apply 拒绝；不宣称整个 endTurn 原子。不可 JSON 表达的循环 Lua 卡数据也不绕过原 cardDefinition 复制器，本片只保证 supported/direct apply 的标记发现安全拒绝。

## 测试与修正过程

真实 RED：原 30 次真实入口矩阵的最终层数、2 费、消耗和 RNG 全对，但 22 个多活敌案例的顺序/逐帧状态错误，8 个单活敌对照通过，strict 测试 exit 1。实现后 30/30 严格匹配。

新增 runtime 协议首轮 69 组有 51 组失败；正确区分测试夹具与产品问题后补齐拒绝、上下文、顺序、活性和回滚。NaN 不能自等及循环数据会先经过既有 cardDefinition 深拷贝属于夹具/入口边界，已明确处理，未修改公共 Combat。UI 测试初版误用“所有敌人”而原文是“每个敌人”，只修测试；不把该次失败作为生产 RED。

集成完整生成链真实暴露 Python 严格 effect 字段拒绝新标记，导致 build-ui 及四项 Node 检查失败。新增 Python 正负测试先红，再对获准第四文件做同协议严格校验；不开放任意字段、不改模板。正式 build-ui 成功后重新执行所有 UI 测试。整份渲染结果与去掉新标记的同数值源完全相同。

独立审查又复现新增递归发现器会让 10000 层未标记 conditional 从旧 `nesting exceeds 8` 变成 RangeError。先新增有/无标记深层 RED，再将 JS/Lua 发现器改为显式栈；旧深度报错与深藏标记拒绝均保留。Lua 原生 10000 层本身未失败，不虚报它的 RED。

### 当前候选结果

- `shockwave_order.lua`：30 真实出牌矩阵全部通过，覆盖基础/升级、Artifact 0/1/2 两敌全组合、单活敌、中间死亡/逃跑、前置失活及已有状态；每条 status/Artifact 事件和全敌快照均核对。
- `shockwave_group.lua`：71 组通过，覆盖所有坏标记/形状/稀疏/重复/深层/循环、公共玩家及敌方/queued上下文、无标记兼容、独立事件帧、两项之间源/目标失活、末敌清理和完整表引用回滚。中途失活由受控包装在真实 Actor 调用完成后注入，因为现 applyPower 没有自然致死钩子；不冒充自然可打出的组合。
- `shockwave_feedback.lua`：2 组真实控制器/生成树通过，核基础/升级中文层数、两个关键词和消耗、area flight、中间播放状态、正常付费和消耗去向、事件只释放一次。
- 新 schema 56 例、既有 schema 54 例通过；Python 新 5 个方法（含逐项子例）通过。
- 重新生成 data/UI/theme 后，全部 171 个现有/新增原生 Lua 文件逐文件独立执行通过；1085 项无 Fengari 依赖的 Node 测试通过；22 项 Python 测试通过；JS 语法、数据及 Backlog 排期门禁通过。
- 独立 1320 审查：141 项 runtime、59 项 schema、17 项 JS/15 项 Lua discovery、42 项完整 Python render、五万层共享 DAG、fresh build/UI 与整份 render 全等通过，报告无阻断。
- 9 个实际负变异均失败：退回 effect-first、两项反序、漏 false 标记、去掉 apply 预检、去掉源重检、去掉目标重检、重复执行第二项、schema 不验证标记、Python 不验证标记。

Node 首轮选择包含两份间接依赖 Fengari 的 fixture，产生 3 个 MODULE_NOT_FOUND，已保留日志。当前纯 Node 选择明确排除这两份及 18 份直接引擎 wrapper；没有安装依赖、运行 npm、改 wrapper、冒称完整 npm check/Fengari 或 Windows 性能。Fengari/当前 SHA CI 仍必须由正式集成验证。

实现者阶段没有提交或推送远端、改任务/清单，费用与额度节省未知。测试源、红绿日志、负变异及固定身份随本次冻结交接保存；不删除失败证据。
