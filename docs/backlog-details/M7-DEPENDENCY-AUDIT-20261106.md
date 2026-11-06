# M7 核心依赖与状态所有权审计

TASK-74.19 的只读基线为 `dedb9ed5af52fc595031d64d3e8fd84bc908b2c8`。本附件使用 architecture-strategist 方法，按现有领域设计核查源码职责、状态提交边界和真实反向调用。本轮未改产品源码、配置或任务，也未运行整套测试或 Luacheck；下列验证入口是下一实现切片所需合同，不能当作本轮已通过。

## 同源图证据

复用 `scripts/check-architecture.mjs` 的 `checkArchitecture`（luaparse AST、原初始化函数识别与 deferred 配置）和 `scripts/lua-quality-metrics.mjs` 的 `dependencyCycles`。没有引入另一套 require 解析器或 SCC 算法。

本地执行 `node build/dependency-audit/collect.mjs <git rev-parse HEAD>`；生成 `build/dependency-audit/graph.json`、`summary.json`。graph 含全部328模块源码 SHA256、逐 require 的 from/to/line/reviewedDeferred、完整 SCC 成员和内部边；报告中的 head 来自同次 shell Git 读取。源码内容身份以 sourceHashes 为准，后续编辑后须重新采集。

| 同次采集范围 | 模块 | require位置 | 唯一依赖对 | 非平凡 SCC |
| --- | ---: | ---: | ---: | --- |
| 所有即时及延迟边 | 328 | 1902 | 1535 | 1个，104成员、804内部位置、538内部唯一对 |
| 排除已审核 deferred 的加载图 | 同上 | 原图过滤 | 原图过滤 | 0 |

架构检查 errors 为0。即时无环只证明现有可识别加载图合法；104成员大环反映运行职责互相依赖。reviewedDeferred=false 也不等于“必在模块加载时执行”：它还包含未被配置豁免的函数内导入。不能将此二分包装成完整动态调用图、递归安全证明或可并行写入授权。

## 状态提交 owner 与风险

Session 是设计领域，当前没有 `abyss_session.lua`；实现主要由 Run/Nodes 及其安装模块承担。

| owner / 调用位置（均为基线行号） | 允许的职责 | 需约束的风险 |
| --- | --- | --- |
| `abyss_run.lua:32` transaction | 单局永久状态外层提交；复制完整可变图、共享只读 data；嵌套失败污染同一 owner | 将 relic helper 移出后另开事务，或吞掉失败，会改变原子性；不可只测试最终数值 |
| `abyss_run_rooms.lua:13` install / encounter 创建，`abyss_run.lua:341` | Session 创建并发布 Combat 实例、generation、phase | Run→Combat 是正确编排方向，不能为缩小 SCC 禁止整条边 |
| `abyss_run_settlement.lua:158` finishCombat、`:204` applyPermanentChanges、`:232` Run.finishCombat | 战斗结果、永久卡修改及 card/misc RNG 同步；失败恢复原图 | `:162` victory hooks 在结果发布前，`:170` healing 在奖励准备前；顺序变化可错误发布HP、遗物计数、奖励/RNG |
| `abyss_combat.lua:6,14` CardActions/RelicHooks | Combat 持有 drain、战斗命令与事务；规则 hook 只能加入现有动作所有者 | hook 自行 drain 或另造队列会破坏暂停、终局、重入和异常部分写入 |
| `abyss_actor.lua:17,160,494,504,525,692,708,849` | Actor 处理伤害/状态，通知 hp hook；已有 Reactions 是入队能力 | Actor→RelicHooks→Actor/卡动作形成运行职责环；不应把 hp callback 当普通无状态工具 |
| `abyss_relic_hooks.lua:4,148,176,318,322,337,344` | 同文件跨局内奖励/装备与战斗触发 | 规则 hook 为入队加载完整 CardActions 执行器，形成可消除的反向职责依赖；六处应统一采用已有 admission 能力 |
| `abyss_boss_relics.lua:84,106,149,154,169,172,178,181,215` | 选择/变换/永久获得调用 Run 公共能力 | 九处→Run 多数属 Session 内永久事务编排，尤其 Astrolabe/Pandora 的UID/RNG与失败回滚；不能直接内联写字段或换成纯 Catalog |
| `abyss_uncommon_relics.lua:33` battleEnd→Run.heal | 战后治疗通过永久健康规则 | 接口混合内容规则和Session写入；可后续由结算owner注入健康能力，但不能使用该文件`:21`局部heal替换，它跳过Run完整规则 |
| `abyss_hp_loss.lua:19,23,27` | Power TOP入队后通知遗物，再处理HP0与复活 | Puzzle应先于Rupture执行，两者都是TOP且后插先执行；队列所有权是验证核心，不得改成即时效果 |

尚未发现可由本次只读证据证实的 P0 玩法缺陷。首个可实施 P1 是 RelicHooks 对完整卡动作执行器的反向依赖；P1 指结构与维护风险，并非声称当前玩家必然触发错误。

## RelicHooks 全部公开入口归属

以下清单用于下一轮 session/combat 拆分，禁止仅移文件后由子模块再导入原门面。

| 入口（行号） | 责任归属 / owner |
| --- | --- |
| localId(21)、owns(24) | 只读身份/所有权查询；当前依赖四个混合遗物族模块，不能直接称纯Catalog已完成 |
| onLoseHpLast(32) | Combat HP规则；不持有外层提交 |
| gainGold(47)、onEquip(78)、onUnequip(126)、obtainCirclet(131)、scoreAdjustment(141) | Session 永久经济/装备/分数；由Run命令事务持有提交 |
| enqueuePostDraw(144)、upgradeRandomHand(152) | Combat 抽牌后动作与随机手牌升级；保留 shuffleRng.randomLong、候选顺序和升级事件 |
| campHealAmount(167) | Session 休息治疗查询 |
| onUsePotion(172) | 双生命周期桥：有battle时仅对战斗player入队heal，无battle时永久治疗；应显式分支保留 |
| onRest(179)、beforeObtainCard(186)、onPreviewObtainCard(204)、previewCardReward(210)、onObtainCard(226) | Session 获得/预览/永久卡提交；preview的副作用和 CardOrigin 记录须逐个保留，不能由名称推断纯函数 |
| onEnterRoom(251)、onSpendGold(265) | Session 房间与经济规则 |
| onVictory(271) | Combat 计数收尾，在Run结算owner确定的原时点执行 |
| bindBattle(275)、preBattle(282) | Session→Combat 构造桥；persistentCounters绑定身份不能深拷贝替代 |
| hpChanged(306)、wasHpLost(329)、atTurnStart(352)、prepareTurnStart(372)、onUseCard(394)、afterCard(408)、battleStart(422)、endTurnBlock(462)、onPlayerEndTurn(469) | Combat；既有入队、状态与事件顺序由Combat/Actor外层命令持有 |

`onUsePotion`、`bindBattle`、`onVictory` 是需逐调用者归属的桥，不能硬按文件段落把所有上半段判Session、下半段判Combat。遗物族模块、OriginalV4健康及maxHP等仍可能回连Actor/Session；仅拆RelicHooks不会自然解除104成员大环。

## 首个实施切片：规则 hook 仅依赖反应入队能力

1. 六处 `require('abyss_card_actions').enqueue/enqueueReaction` 改为既有 `abyss_combat_reactions` 的对应公开方法，保留每处运行时 require 及每次调用时方法读取；不增加模块顶层require，不捕获函数别名，不注入新的队列、drain或全局服务。这保留原初始化加载集合，收益是规则hook只依赖既有入队能力，避免把整个卡动作执行器当入队服务。
2. 六处保持原位置、参数数量、effect表身份、source默认值及top值：148为Warped Tongs底部；176为Toy Ornithopter普通cardActions入队；318/322为Red Skull TOP；337为遗物实际失血反应TOP；344为Centennial Puzzle TOP。176不能擅自改用enqueueReaction，原来即使typed queue存在也使用legacy enqueue。
3. `abyss_card_actions.lua:9-21` 已把两个 admission 公共字段通过 metatable 转发到 Reactions；普通方法替换和nil恢复互通。新hook读Reactions仍须实测保留此动态合同，不能仅从静态代理推断完备等价。rawset绕过代理是否属于已支持合同应检查既有调用者，不扩大接口承诺。
4. 配置删除失效的 RelicHooks→CardActions deferred 对，新增 dependencyBoundaries 禁止规则hook直接或延迟回导执行器；保留合法新模块分类、现有Actor→Reactions边界。不能通过保留过时豁免或改门禁阈值让检查通过。

实际动态替换已存在于 `tests/lua/combat_reactions.lua:61,68` 及 independence 入口，并非假想兼容需求。全D5拆分能更直接收敛生命周期混合，但其30多个公开入口、永久事务及遗物族反向边不适合并入六调用切片；本片以公开能力依赖和可执行boundary先交付，再按上表逐owner推进。

此切片消除一个具体职责环入口，不承诺大SCC缩小。机器图做过**只删六处边**的反事实：仍104成员，内部位置804→798，唯一对538→537。这不是修改后图：新Reactions边仍有ActionQueue/Effects等返回路径，真实重接后的绝对值须重新采集。该限制避免用“少六条require”冒充完整领域解环。

## 验证入口与缺口

现有窄入口：`tests/combat-reactions.test.mjs`（动态代理、nil恢复、两种队列、TOP/BOTTOM、effect身份和意外drain语义变异）、`tests/architecture-boundaries.test.mjs`（含延迟边）、`tests/actor-damage-pipeline.test.mjs`。Lua真实行为入口包括 `centennial_puzzle_queue.lua`、`fatal_hp_loss_callbacks.lua`、`hp_loss_action_boundaries.lua`、`lizard_tail_action_order.lua`、`native_rupture_queue.lua`、`relic_top_bridge.lua`、`class_potion_relic_heal.lua`、`mark_of_bloom_healing.lua`、`common_relic_final.lua`。通过现有 `scripts/test-lua.mjs`/`runLua` 执行，不另造执行器。

现有测试不能替代以下新增旧新差分：固定本基线完整RelicHooks旧源，两个独立VM/相同真实依赖，对六条触发路径在legacy与typed owner分别比较全状态图、表/函数别名、RNG、事件、入队顺序、零返回/异常对象、部分写入、暂停与重入。需要显式覆盖两种queue同时存在、CardActions普通动态替换/nil恢复、WarpedTongs单候选仍消耗shuffle RNG、Puzzle/Rupture/RedSkull/复活同次失血、Toy Ornithopter死亡player与Mark of Bloom。

对调TOP/BOTTOM、复制effect、错用typed owner、额外drain及捕获过时方法应以真实可解析语义变异被具名断言拒绝；不把语法错/构造失败当作检测成功。变更后再采完整AST图、现有架构边界与源码逆转换合同，最终独立深审及精确来源/队列/实际合后Full仍为交付要求。

测试适配不能按六行源码估算：config及Hooks进入多个完整历史inverse链，其中 `tests/helpers/game-ui-extraction-source-inverse.mjs` 每次绑定7份当前来源且严格校验config完整身份。新配置应作为精确新epoch先逆投影到本基线再接旧链；旧golden/摘要不改，缺失、篡改、等价格式、暖调用后漂移和linked-reader失败仍拒绝。此处历史消费链接线成本可能高于产品修改，应在实施前列出全部消费者，避免只跑Reactions专项后提交Full才发现旧来源合同失效。

## 残余责任

主控在评估历史适配成本后决定本轮不实施上述六调用迁移。它是可验证的局部能力边界候选，不能当作G1/74.19的终点；仅为这六处新增一整个历史epoch的收益不足。下一实施优先把这项入队依赖治理组合进D5的真实生命周期拆分，统一承担一次历史适配成本。

优先组合应单独审计 Actor↔RelicHooks 的HP规则边界及跨生命周期 facade：拆出只读身份查询、Session hooks、Combat hooks，明确桥的适配owner；从每个实际调用者改到其领域能力，兼容门面只单向委托。需要保持已有公开动态替换行为且子模块不回导门面。若通过回调注入来解除Actor↔hook边，应注入少数具体能力并绑定构造生命周期，禁止服务定位器与另一个可变全局API。首次可交付范围应以Actor/HP-loss只消费Combat hooks且不再加载Session装备/经济能力为真实收益，同时覆盖构造桥和onUsePotion双分支，不以文件拆分或require数量作为验收。

该组合的预期改动横跨Hooks公开门面、Actor/HP-loss/CardActions/Combat调用者、Run及结算桥和架构配置；历史适配至少包含本次7源GameUI绑定、relic-completion及其传递消费链，并保留现有固定旧来源证明。必须在编码前列清新epoch的完整拥有文件、精确逆投影层、所有直接及传递消费者和旧新VM矩阵，再由独立审查确认收益与成本相称；本附件尚不证明这项实施计划完备。

BossRelics/RelicChoices/RelicPending/RelicCardRewards→Run 的永久事务反向导入也须后续收敛到Session编排能力。当前分别删除每组边的反事实均仍104成员，不代表这些边可无损删除；它们仍属已知未治理风险，不能在首个六调用切片后改标为低风险或宣布M7架构完成。

## 本轮证据交付

机器图 `build/dependency-audit/graph.json` 的 SHA256 为 `632d62b0df0d24b9b7181f0da5da423d89e07fdbe9a155c2328bed74dac05b4e`。可复现采集器与两份输出打包在仓库相对路径 `build/dependency-audit/evidence.zip`，供主控作为本PR的artifact保留，不加入运行时或仓库历史golden。压缩包 SHA256 为 `888f2740fdddb8496a92571ce8f4137e00fca5b53260dd31a7be4a280f2df978`，同目录 `evidence.sha256` 同步记录。运行要求使用锁定依赖，工作目录为本仓库根，命令及算法见前文。生成物不随文档自动发布，未上传前不能称已远端交付。

本轮完成的是同源图基线、公开入口owner审计、有限候选与验证成本定位；TASK-74.19 AC2/3未完成，AC1中的全部104成员逐类owner仍需主控与其他审计证据补全。本附件不会把未逐项确认的残余判低风险。
