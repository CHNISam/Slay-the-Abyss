# M7 全函数复杂度与职责风险审计（2026-11-06）

TASK-74.20只读审计。源码基线为dedb9ed5af52fc595031d64d3e8fd84bc908b2c8，tree为ccea3d55140147e561112aed507376e8fe27bb83。以下是新鲜测量与实施建议；没有修改运行时、配置或验收标准，没有运行Full，没有把风险判断当作已复现的产品缺陷。最终实施范围和绝对出口须主控写入Backlog AC。

## 测量方法与当前绝对值

复用scripts/check-lua-static.mjs的parseDiagnostics及scripts/lua-quality-metrics.mjs的discoverSources/measureSources，不新增测量器。固定Luacheck 1.2.0 Windows二进制SHA256为0f1c69c4d09f1ebb4d8df14c215e4553e2e639bd4cb7bf3c639b0daa6198317b，与config/lua-tools.json一致；二进制来自既有pending-worktree-evidence.zip，AST依赖为现有luaparse 0.3.1。

命令为luacheck.exe src/lua --formatter plain --codes --ranges --no-color --max-cyclomatic-complexity 0 --only 561。因刻意报告全部复杂度而返回1，随后完整AST映射errors为空；这不是常规静态门禁通过或失败的替代结论。

| 指标 | 当前绝对值 |
|---|---:|
| Lua模块 / 函数 / 初始化块 | 328 / 4955 / 328 |
| 完整W561测量 | 5283 |
| 函数CC总和 / 最大CC | 29553 / 75 |
| 函数CC>15 / >30 | 258 / 67 |
| 最长完整函数跨度 / >150行函数 | 580 / 39 |
| >1000行模块 | 1：Combat 2240行 |
| 初始化块最大CC / >15 | 6 / 0 |

跨度包含嵌套函数，外层CC1不代表整个构造器简单。GameUI的151行构造器在既有200行门槛内，不能因为报告阈值150就重开。所有函数、匿名回调和初始化块都有文件LF摘要、起止行、唯一AST身份与W561对应；没有漏测、重复或未知坐标。

提交触碰数统一取当前develop可达历史，时间为2026-10-23T00:00:00Z至2026-11-07T00:00:00Z，命令git log --since=... --until=... --format=... -- <file>。按提交计数，包含合入squash，不是函数级修改次数、工时或缺陷数。新提取文件低计数不能证明低风险。

## 首批P0：状态提交与Power生命周期

### Actor状态入口和回合结束

Actor当前968行，近期31次提交触碰。status为CC33、applyPower为36、addStatus为35、endTurn为50。Actor直接修改statuses、powerOrder、temporaryPowerOrder并产生事件；Combat负责队列drain、死亡中断、选择和事务。

endTurn同时收集首次获得顺序、衰减、Artifact可抵消的临时能力回收、Ritual/Wraith分派和退场特例，顺序属于行为合同。建议拆为具名收集、单项结算与清理阶段，仍由Actor调用；禁止新增第二状态owner或让叶模块直接drain。

现有tests/lua/owner_end_powers.lua对原生/实验两路、loss/wraith两种应用顺序检查能力、Artifact、抽牌和事件相对顺序；native_power_expiration.lua覆盖自然回合衰减；source-monster-power-order.test.mjs与death-power-order.test.mjs约束排序。Actor伤害pipeline专测只锁定另一区域，不能作为这四个入口已受CC15与完整旧新差分保护的证据。

### Combat伤害协调与抽牌

Combat当前2240行，近期49次提交触碰。M.damage为CC34，局部draw为33。damage协调Actor算术、Heart/Envenom、V4、敌方失血通知、反击与独立动作收尾。draw拥有手/抽/弃牌表身份、shuffleRng及源shuffle次数、递归跨堆、TOP/BOTTOM反应和职业onDraw顺序。

建议提取纯阶段或有明确API的职责，保留Combat唯一队列和事务协调及动态派发；不顺便增加缓存、重排或新队列。tests/actor-damage-pipeline.test.mjs已有顺序、回滚和四个真实语义变异，但主要覆盖Actor管线，不能替代Combat协调差分。draw_lock.lua覆盖noDraw、满手/堆状态及真实Run奖励后再战；native_sharp_hide_top_draw.lua、potion_draw_queue.lua、death-power-order.test.mjs覆盖抽牌/死亡队列交叉。新差分应同时覆盖公开Run/Combat入口、独立直接调用和已有owner内调用。

### 首批有限出口建议

上述六个旧热点以及其新增helper、匿名回调和初始化块CC均不超过15；完整同源测量不能缺项。旧六个>30热点从6降至0，全库其他代码不变时>30由67降至61。旧新完整状态图、别名/表身份、RNG、事件和返回/错误轨迹相等，原回归与真实敏感性负控通过。不得新增持久状态或反向依赖。最大CC75仍存在，首批交付不等于全库完成。

## P1：下一轮体验和内容直接相交的边界

| 边界 | 当前计量 / 提交触碰 | owner、风险与建议出口 |
|---|---|---|
| MapUI | 737行，new跨度569/CC23，render59；20次 | Map/Run拥有进度；UI拥有drag/released/scroll/observedMap、缓存和FX。render同时校验章节、取消旧输入、建边和画节点。建议render及新职责CC≤15、new完整跨度≤200、其他提取函数≤150；保持每Host闭包和绑定/取消/绘制顺序，UI只发命令。复用map_ui_chapters、map_ui、map_draw_bounds，新增同内容不同owner、render同步回调和失效上下文反例。不得代替手机验收。 |
| RelicHooks | 474行，onEquip47；17次 | Run拥有永久relicCounters/deck/HP/miscRng，Combat只有当局投影。onEquip先稀有度模块再装备副作用，包含pending瓶装、false早返与升级回调。建议固定阶段和具名handler将onEquip及新helper约束至CC≤15，调用顺序/false返回/零单候选shuffle/卡UID不变。复用common-relic-equipment八组RNG与外层失败回滚，以及boss/shop/act2事件/max-hp合同；不新增事务提交层。 |
| Feedback | 716行，new跨度580/CC1，classify49、start35、匿名回调48；26次 | UI播放队列、取消/退休实例与规则事件帧共享长闭包。若纳入本轮，按分类、播放生命周期、绘制阶段治理；相同事件输入和clock/取消时点完整轨迹，保留原生实例引用，不重录golden。new≤200、新职责CC≤15仅为建议，未实施前不承诺降幅。 |
| Run卡牌catalog | prepare59、prepareSelected37；新文件1次 | 原始规则/职业内容适配入口。Run主入口已≤15不代表投影叶层通过。按基础/选定职业构造顺序审sourcePools/catalog身份，必要时将这两函数纳入P1，完整职业配置/RNG/目录别名回归后≤15。新文件低触碰数不降级风险。 |

首批六函数加MapUI.render、RelicHooks.onEquip，若全部纳入且无新热点，>30可由67降至59；再加Run catalog两项则为57。该数字是明确候选范围的核算，不能自动授权十项实现。

Combat超千行是另一个职责问题：只拆damage/draw约百行不足以降到1000。后续应按构造/开局、卡牌执行/选择、回合阶段三个已有owner边界审查迁出，Combat保留公开编排/API，新职责不超过1000行且新增函数CC≤15。首批不得暗示已解决文件规模。若最终AC要求超千行0，应明确Combat入口≤1000、职责模块≤1000，并事先核定较大切片的行为验证和维护成本；只把同一个全局M表分散到多文件不构成解耦。

Run685行、CardActions551行目前各自全部函数CC≤15，后者drain已经治理。二者近期40/20次触碰不构成重复重构理由。Actor中tick28、attackFloat28、queueDeathPower27等CC16–30函数仍须随调用链审查；若处于本批变动状态边界，应纳入而不能利用>30阈值漏过风险。

## 残余风险与停止条件

机器清单完整列出全部67个>30函数及39个>150行完整跨度，未选入首批的项没有被自动降为P2。当前两幕共用的Act1.choose69、Inventory.apply53、EnemyAI.advance43/initialize40、EndTurnPowers.prepare55/apply34、Effects.targetGroup33及Treasure/Choice UI仍需主控结合依赖审计明确P0/P1，或提供Owner接受的保留理由。

Watcher/Defect、V4、Act3等历史实现保留，不删除；当前未启用也不能证明共享目录未加载。残余逐组可达性与owner仍须审查。本附件不提供代Owner签署的风险豁免，也不声称全部风险已分级。

本次审计的出口是全量清单无遗漏、首批边界/测试/绝对目标可审查。后续治理出口是获批准P0/P1集合无超标失控、全部新职责有硬门禁和行为合同，残余有具体Owner接受及后续安排。不得无限清零258个>15，也不得靠减少文件长度宣称架构完美。未治理、待分级及缺少新旧证据的项保持未完成。

## 原始采集索引

以下产物在本工作树build/m7-complexity-audit-20261106/，附后列出本轮摘要。measurements.json覆盖全部模块和AST；high-cc.json完整列67热点；long-functions.json完整列39长函数；hotspot-history.json保存全部热点文件的提交列表。build产物应随交付归档，不能把临时路径本身作为永久证据。

本次只有固定工具执行、AST映射与源码/测试审读，没有运行上述行为回归，没有官方导入、ready、设备或性能结论。

可提交的完整机器清单：[M7架构基线](../evidence/m7-architecture-baseline-20261106.json)，含328源码摘要、67高CC和39长函数清单；原始大文件留在build并按以下摘要归档。

| 原始文件 | 字节 | SHA256 |
|---|---:|---|
| luacheck-complexity.txt | 614008 | 3ec44e8b58abf775f512d7a6fef9b3bcae8d05c82043c878077bd36ec96f6106 |
| measurements.json | 1537455 | 8423c484eff774b4bd4a77593fb1abe3f3c2c86f94d4fbb35ea07c36a501cab6 |
| high-cc.json | 17061 | 51412c6ea28f4e51f61602306919b6ad52b0c86f36689c02dcd9d54e29e90005 |
| long-functions.json | 9847 | de321ce51b96e1f947cd63302bd5ae968f8c68f1ab67604ff733ff9eefbf959b |
| summary.json | 469 | b04df4a8b32ceb3c8f180af29a89b7f4cb57b657c3a7442741ebfe46ba8c6fd0 |
| hotspot-history.json | 80620 | d2acf689889b74d436592d6b5e9e1f92580970cb226bdcf511ac65eec9805650 |
