# TASK-15：祈火徒 Ritual 状态机候选

资料读取日期：2026-10-23。原候选基线：`be5093f541724405154c4ee1c656fccc08e329e1`；本次生产接线基线：`7d809f3afa9f0350321409b3c55e9d2825c445c3`。

**原独立候选保留；本PR已补生产接线，本地验证见末节，正式CI及平台尚未验收。** 前文保留 PR65 候选的来源与历史验证记录。 TASK-15 仍为排队 To Do，全部 AC 保留。本轮没有原作实测、平台编译、存档导入或游戏试玩，不宣称原版一致性通过。

## 固定来源与行为事实

只读第三方反编译镜像 `purewhitelove/ButterflyGame`，固定提交 `fc379c875c11e008e9c10548ac8e394c301c532f`。[版本字段](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/core/CardCrawlGame.java#L1403-L1404)自称 V2.3.4 / 2022-12-18；**不是官方开源，未与正版 PC 二进制核验真实性**。已读取相关完整方法；只提取行为事实，未复制、执行或分发原实现与资产。

- [Cultist：构造函数32–56、takeTurn63–96、getMove131–145](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/exordium/Cultist.java)：A0 HP48–54、攻击6、Ritual3；首动施加 Ritual，此后只攻击，不重复首动。blob `991f46014688e8d7bfb673eb0c774fc7a257de52`。
- [RitualPower：构造及回调20–62](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/powers/RitualPower.java)：敌方 Ritual 跳过施加当轮，之后每轮结束增加对应力量；玩家版本回调不同，不在候选范围。blob `6a0edd2d38fe616af6f8b1dc32f55414f750fe10`。
- [GameActionManager.update419–449](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/GameActionManager.java#L419-L449)：所有敌人行动完成后，才处理整组回合结束能力。blob `931cded5ae1aed78771e0a5389e8358946b78f8f`。
- [MonsterGroup.applyEndOfTurnPowers405–438](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/MonsterGroup.java#L405-L438)：先处理敌方回合结束触发，再依次处理玩家和存活、未逃跑敌人的轮末回调。blob `8a61dcf17de6560b9aa986bc99f54835acff5a52`。

由此推导无修正的单敌行动伤害轨迹为 **0、6、9、12、15**，不是原作录像结果。HP 分布及随机流、调用顺序未建模或认证。

## 候选与调用边界

`tools/candidates/cultist_ai.lua` 是独立编写、返回新状态的纯 reducer：

- 调用者传入 HP，原样保留；不以固定中点或自定抽样冒充原版随机。
- `act` 返回 Ritual 或基础伤害动作；实际伤害、虚弱/易伤、格挡、反伤、死亡与队友行动由调用者处理。
- `endRound` 必须在全部敌人及前置回合结束触发之后调用；首次跳过力量增长。
- API 按最新状态拒绝紧邻的重复动作/轮末调用，不防止旧快照重放；状态限定为平坦标量，不深拷贝任意嵌套扩展。它**没有团队调度器，不能识别调用者谎报“队友已完成”**。整组时序是明确输入契约，不是已验证的引擎保证。
- 不包含通用 Ritual 能力、逃跑、跳过敌方回合或持久化格式。

## 已执行验证

`tests/lua/cultist_ai_candidate.lua` 七组 Lua5.4 回归通过：首动与输入不变、五轮轨迹、队友行动间隙不增长、多实例隔离、行动/轮末前死亡、重复调用拒绝、输入 HP 保留。

- 缺模块红灯 exit1；实现后七组绿灯 exit0。
- 五个独立变异均被测试检出（exit1）：首动立即加力量、取消首轮跳过、单敌行动时提前增长、允许重复轮末增长、死亡后仍增长。
- JavaScript 语法检查 exit0；所有已有文件与固定基线 blob 相同。
- 使用已安装 `liblua5.4.so.0` 及现有 ctypes harness；未安装依赖。现有 Fengari 目录为空，**未运行 Fengari 或完整 `npm run check`**。局部通过不等于 CI 或运行时通过。

依赖可用时，仓库测试入口会自动发现此用例，也可单独执行：

```sh
node scripts/test-lua.mjs tests/lua/cultist_ai_candidate.lua
```

## PR65 历史接线约束（落实情况见末节）

PR65 当时的生产祈火徒仍是攻击6与力量3交替，AI 仅支持睡眠循环和默认循环；本次已替换该祈火徒分支。已有 `hpRange` 接口使用项目 RNG，不代表原版随机已对齐。

1. 重新核对文件认领。此次 PR62 未改 combat/AI/schema；不得覆盖 Lagavulin 或其他并行工作。
2. 在整组敌人行动及回合结束效果之后增加轮末入口；**不能在逐敌 `EnemyAI.advance` 里加 Ritual 力量**。
3. 明确 Ritual 状态、首动意图/效果及 UI 展示契约。现有状态表无 Ritual，活动意图禁止空效果；不能伪装成立即加力量、放宽全局校验或隐藏核心信息。
4. HP48–54 可复用已有抽样入口，但须继续披露 RNG 算法/流/顺序限制，不新增种子、改抽取顺序或调平衡。
5. 补运行时首动显示、延迟增长、死亡/反伤、多敌时序、空效果拒绝、回滚/恢复、Lagavulin、事件快照与 UI 回归；完整测试及独立审查后才集成。正版 PC 与平台证据另验。

以上第1–4项及第5项中的本地接线/回归已在本次落实，完整Fengari、正式CI与平台/原作实测仍待验。PR65本身未改共享Backlog或生产祈火徒；本次进展如下，不关闭TASK-15。


## 2026-10-23 生产接线与本地复验

接线基线 `7d809f3afa9f0350321409b3c55e9d2825c445c3`。仅增加祈火徒分支，保留其他敌人及既有状态时序：

- 首动用现有 `gainStatus` 给自身仪式3；之后只攻击6。状态表提供“仪式”名称，复用已批准 buff 图标；现有 UI 显示首动仪式3、存续仪式3、后续攻击6→9，无新效果操作或空意图放宽。
- AI 只在首动结束记录平坦的首次跳过标志。Combat 在整个敌方循环结束后、下次玩家回合前统一调用轮末入口；力量增长不发生在逐敌 advance。死亡敌人、玩家死亡、提前胜负结束不增长。
- HP使用已有 `hpRange=48–54` 入口每次实际抽取，保留的 `hp=50` 只是旧兼容名义值，不是实战固定值。64个项目种子覆盖全部7个HP及重现性；**不代表原版RNG/种子映射一致**。
- 不改变现有卡牌失败回滚契约；新增平坦AI字段及状态由既有快照覆盖。没有把非事务型 `endTurn` 宣称为原子事务。
- 陈旧测试若只需普通攻击或自定义意图，改用非状态机敌人夹具；不通过禁用生产AI或删断言隐藏差异。Ritual与Lagavulin另有真实入口测试。

初版接线本地证据（PR69 集成前，非当前全量计数）：

| 检查 | 结果与边界 |
|---|---|
| 新增 Cultist 实际 Combat 测试 | 14组通过，含多敌事件先后、后行动队友致死、毒/反伤死亡、负力量/虚弱、HP采样、回滚及混合Lagavulin |
| 数据schema | 31组通过；仪式首动只准自身3层、攻击只准单次基础6，拒绝错引用/额外效果/跨策略字段 |
| 全部Lua文件 | Lua5.4下31/31文件通过；其中真实原生控件UI38组、Lagavulin12组、遭遇174组 |
| 生产负向变异 | 5/5被检出：取消首轮跳过、逐敌增长、死敌增长、重复轮末、重复首动 |
| 构建/独立校验 | 数据、UI、主题构建及数据校验通过；Python16/16通过 |
| `npm run check` | **未通过（exit1）**：Node287项中280通过，7项因缺 `fengari-node-cli` 失败；因此正式Fengari/完整聚合检查仍待CI。本轮未安装依赖 |

TASK-15只通过CLI追加计划与结果注记，原状态、旧计划、assignee及AC不变。原版构建真实性、原版随机、完整敌人/状态顺序、平台编译/导入/试玩均未据此验收。


## 2026-10-23 Guardian 合并与 CI 超时修复

当前基线为 `fcc1dca5d9b512f932e4122c025bf8d13cf25d5a`。逐处合并祈火徒增量，保留 Guardian 的伤害后结算、整卡捕获/Sharp Hide 反应、排队模式切换及毒伤刷新，并继承 PR68 拖拽修复；未用旧整文件覆盖新基线。Guardian 基线上新 Cultist 测试先因首动仍为攻击而失败，接线后通过。

PR70 首次 CI 在主战斗 UI 文件触发15秒超时，没有断言错误。本次仅把新增 Ritual UI 用例拆至自动发现的 `tests/lua/cultist_ui.lua`，使用实际生成的控件树与真实 Run/Combat，保留首动、状态、跳过首轮及攻击6→9的全部断言。主 UI 保留原夹具修正及 Guardian 用例；不提高超时，不缩减断言。Lua5.4验证行为不等于Fengari耗时达标，后者待新CI。

当前本地结果：Lua5.4全35文件通过（主UI38、独立Ritual UI1、Cultist14、Guardian24、Lagavulin12、drag7、IronWave12、遭遇159）；构建、schema、语法检查及Python16通过。Node299项292通过、7项因缺Fengari失败，无跳过；未安装依赖，不宣称完整聚合检查通过。正式CI、平台及正版原作证据仍待验，TASK-15保持To Do、原计划/assignee/AC不变。
