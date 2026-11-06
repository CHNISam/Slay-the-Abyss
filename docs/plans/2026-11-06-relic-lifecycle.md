# 遗物生命周期边界实施

承接 TASK-74.19/74.20，实施基底为已独审的 `5762bdd0`。原领域设计 D5、[当前所有权审计](../backlog-details/M7-DEPENDENCY-AUDIT-20261106.md)与[查询能力切片](../backlog-details/M7-RELIC-QUERIES-20261106.md)仍有效。产品已实现，本地验证进展见[生命周期证据](../backlog-details/M7-RELIC-LIFECYCLE-20261106.md)，不代表完整交付通过。

## 必须达到的边界

Actor、HP-loss、CardActions、Combat 的全部即时及延迟依赖闭包不再加载旧 Hooks、Boss、Uncommon、Rare、Shop 门面及 Run/Nodes/Choices/Pending/CardRewards 永久命令。Run→Combat 的原编排、运行时合法 Actor/Effects/Queue 关系保留。当前生产 AST 的四根传递检查已真实 RED，不能用只改 Boss 一处代替完整边界。

用两个明确能力模块承接职责：`abyss_relic_combat_hooks` 持有 14 个战斗 hook；`abyss_relic_family_combat` 使用固定 boss/uncommon/rare/shop/common 命名空间承接战斗规则与少量调用者 owner 上的规则。没有安装步骤、注册服务或新的状态提交者。五个旧门面保留 Session 命令和桥，以明确字段白名单共享原公开函数槽位；能力模块不回导门面。

## 接口与状态 owner

| 范围 | 处理 |
| --- | --- |
| 纯查询 | 继续由零出边 Queries 持有五套原 alias 和无状态写的查询；涉及计数、随机、卡升级、金币、选择的函数不进入 Queries。 |
| Combat Hooks | enqueuePostDraw、upgradeRandomHand、onVictory、bindBattle、preBattle、hpChanged、wasHpLost、atTurnStart、prepareTurnStart、onUseCard、afterCard、battleStart、endTurnBlock、onPlayerEndTurn。只处理原 Combat owner 和原反应入队。 |
| 四族规则 | Boss 6、Uncommon 9、Rare 20、Shop 10 个战斗能力；采用原参数和同次动态读取。Rare 的营地/旅行、Shop 的获得/镜像、Boss 的选择/奖励与 Uncommon 的战后治疗留原 Session 门面。 |
| common 规则 | gainGold、beforeObtainCard、onPreviewObtainCard、previewCardReward、onObtainCard 操作调用者已提供的 owner/card/offer，沿用原能力参数；不创建事务、不分配永久 UID、不提交 deck。 |
| 保留的桥 | onUsePotion 留原 RunPotionCandidate 双分支；bindBattle 的 relicCounters 仍新建外层表并复制值；Run 结算的 onVictory、战后治疗、奖励准备次序不动。 |

Wish 的金币 owner 缺字段时原错误及部分写入也属于本轮对照范围。Writhing Mass 的 Omamori、Ceramic Fish、Egg/Origin、Darkstone combatContext 身份与 Inventory 健康能力、masterDeck 发布顺序必须保持。普通 Run 的外层事务及无 adapter 的 Boss select/claim、Uncommon.battleEnd、Shop.chooseMirror 公开接口不变。

普通字段替换、nil 恢复、跨门面函数别名及 Run.loseRelic 已捕获的函数值保持。Rare 私有 owns 与公开 owns 分离，Boss 不新增公开 owns，Shop.aliases 保留真实表及原 Shop.owns 绕过 localId 的逻辑。函数内 require 保留调用时机，不捕获原本每次动态读取的函数。反射形状边界沿用现有查询/入队提取合同。

## 实施与写入范围

1. 固定完整 391 的 329 份手写 Lua 源及逐文件 SHA/Git blob，旧新独立 VM 先验证现有基线。原六源历史 proof 保持，执行 oracle 则用完整 329 源；原 purge 双源 proof 同样保持，执行 oracle 使用独立完整 a27 的 330 源。旧 VM 禁止 epoch 之外手写源回落实时目录，生成源有明确清单和摘要，并用实际可加载 trap 验拒绝。复用已有图观察器；HP/fatal、开场/回合/出牌、四族、Run 选择/回滚、特殊 owner、动态接口分有界组。默认 raw 执行全部本组断言，显式差分读回完整图；原超时和输出合同保持。确证超时可按原子 test 拆组，完整正文 hash、实际 case 并集和唯一性必须通过，同 owner/warm/重入链不拆。
2. 主控持有 Hooks 门面、Combat Hooks 和实际消费者接线；族规则实现者持有 family 模块、四族门面及 Queries。准确文件/字段/行/目标以同轮 `runtime-consumers.json` / `method-owners.json` 审核为准，未解析项明确保留，不能把静态字段扫描称完整数据流证明。
3. 原位置统一使用既有 Reactions 的 enqueue/enqueueReaction，保持 typed/legacy 选择、TOP/BOTTOM、effect/source 表身份、暂停、重入及原调用次序；不增加 drain 或另一个队列。所有迁入/新增函数和嵌套 helper 执行 CC15，两个能力文件各不超过 1000 行，复杂开场规则按实际职责拆私有 helper。
4. 历史来源只扩现有未发布 epoch：新增完整 391 的实际改动调用者，两个新模块仅作 witness；先恢复 391 Actor/Combat/config，再执行原 core/GameUI 旧 guard。不更新旧 golden 或 core 的原 after 身份。每次公开调用仍 fresh 验全部 owner，自定义 reader 失败不回退真实树；不使用许可缓存或 scoped snapshot 来减少有效读取。
5. 四份 detached copy 清单随实际旧源档补齐。调用者矩阵、warm 漂移/删除/错误、旧输入零读取和配置布局/重复键合同分开验证；现有数据/主题/UI 由主控一次生成，各路不重复 Full。

同轮方法/消费者清单包含 31 个手写源目标、115 个公开字段和 338 处字段引用；Runtime 必改与 119 个保留 Session/presentation 引用分列，15 项动态访问及 101 项触及路径参数派发明确列为静态扫描边界，不能凭字段清单宣称完整数据流已证。实际 VM 断言与四根传递门禁负责交叉核验。

来源规模为当前十源加 23 个既有调用者和两个新增 witness，`N=35、k=2`。静态调用链对应 direct/core/GameUI Host/config 分别 35/144/151/295 次 fresh 读取；这些是计数推导，不是性能通过证据。保留原 stateful-reader 与同次漂移合同，不以一次 Map 快照减少有效读取；原预算内实测失败时先定位并修复，否则不交付。

## 验收与交付

四根传递检查须从真实改后 AST 转绿，并用冷 VM 加载集合交叉验证；直接/延迟违规有可执行负例。独立 VM 对照完整状态图、别名/函数/元表、随机、事件、队列、返回、错误和部分写入，具名语义变异须被真实断言检出。原固定静态门禁、相关回归和源身份合同继续生效。

方法级有限图重接曾投影为 Combat 82 成员与 Session 11 成员两个 SCC；这是待验证模型，不是最终数值或残余风险接受。实际全图、即时图及所有剩余 SCC 按最终同源身份重采，并解释 owner；不以 SCC 数字替代状态提交证明。

独立计划审查确认职责/验证成本后实施，完成后另绑精确 HEAD 深审、来源 Full、原生队列与实际 develop push 证据。本轮不新增待合 PR 叠加验证，按依赖实际落地基线集成。没有官方候选、ready、容量或设备证据，不声明玩法/平台性能验收。
