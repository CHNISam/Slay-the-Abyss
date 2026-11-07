---
id: TASK-74.20
title: 治理阻碍角色扩展的高风险复杂度
status: In Progress
assignee:
  - Furinya
created_date: 2026-11-06 01:46
updated_date: '2026-11-07T06:49:00Z'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/M7-CORE-LIFECYCLE-20261106.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 162000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已合Host切片后仍存在最大CC75及67个CC超过30函数；现有任务未逐项界定Combat、Actor、MapUI及RelicHooks对内容迭代的风险。按真实职责治理，避免无限拆分或搬移指标。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 当前全函数含匿名及初始化块机器清单列出CC超过30、最长函数及超千行文件，并按调用链、变更频次和测试风险识别P0/P1
- [ ] #2 已确证P0/P1职责达到CC15或以完整行为对照及明确分层接口证明安全，所有新增helper计入硬门禁；旧新随机、回滚、别名和失败轨迹保持
- [ ] #3 首份机器清单审查后确定绝对出口，公布最终分布与经Owner接受的残余范围；独立深审及实际合后Full通过
- [ ] #4 首批Actor.status/applyPower/addStatus/endTurn及Combat.damage/draw六职责和全部新增helper受CC15硬门禁；完整旧新状态别名随机事件返回错误轨迹相等，真实语义负控检出，首批完成不代表其余61热点已验收
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.复用固定Luacheck和完整AST清单，以dedb9ed5列高CC及长函数。2.按M8扩展调用链、变更频次和现有差分测试识别高风险职责，与依赖审查交叉核对。3.首份机器清单确定绝对出口后治理具名职责，全部helper计入原门禁，行为对照和独立深审后完整交付。

4.首批落实Actor.status/applyPower/addStatus/endTurn及Combat.damage/draw六职责，先固定完整旧新轨迹，再按真实生命周期阶段拆分；六旧热点及全部新增helper/匿名回调/初始化块CC≤15，其他源码不变时>30为67→61。其余热点保持待分级，不视为已接受残余。

5.首轮同模块提取令Actor增至1039行，提交前继续提取无外部依赖的Power校验与堆叠规则叶模块；Actor保留状态提交及动态公开接口。Actor/叶模块1000行硬门禁与叶反向依赖门禁先红后绿，来源升级四源精确epoch并保留旧布局/新鲜读取合同。

本轮最终有界切片：按既有剩余风险建议，仅治理original_v4 validateEffects/apply/executeRoot及新helper，保持支付、唯一快照、逐效果、角色结算与AI flush顺序。全函数含匿名/初始化同口径复采并对新职责执行CC15，冻结旧源、全状态与失败对照后独立复审。

本轮继续既有任务的空闲Watcher最终卡效果执行切片：以2c85bc61冻结完整源，按效果执行/队列延续职责将M.execute局部派发移为私有执行表；状态提交仍属Combat及原模块，全部入口与新helper受CC15。保留动态公开字段、require时机、随机/别名/部分失败/选择暂停语义，完整图旧新对照、真语义负控、独审后交同轮集成，不改Inventory与事件归属切片。

本轮经主控分配继续空闲Inventory职责：在2c85bc61冻结完整原源，按开场组装、效果准入、逐效果执行拆分私有职责，原候选状态与Run提交者不变；全模块及新增helper纳入CC15，完整旧新图、加载顺序与语义负控后独立深审。与Watcher/Event切片文件不重叠，不宣称重新领取或关闭整项AC。

承接PR542原始记录（原切片范围，非当前并集验收）：
2026-11-07 用户要求持续治理。当前有界切片在Watcher现有模块内按真实卡牌效果职责拆execute，保留动态owner、返回值、队列/RNG/部分失败轨迹；与Session奖励能力统一提交，避开PR541的Power与商店改动，按原门禁验收。

协调#542/#543：只保留#543的Watcher effectHandlers实现及CC15根，移植#542独有5组场景、CRLF/依赖/实测合同并保留原9组、4负控和全部来源断言；精确错误源位置映射保留完整正文和table身份。当前组合验证前不关闭原PR、不声称已合并。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮固定Luacheck及完整AST复采328模块/5283测量：CC>15为258、CC>30为67、最大75、最长580，Combat2240行。正按真实状态owner及近期变更频率整理有限P0/P1治理出口；未实施重构，不勾AC。

完整审计附件已落盘并引用328源码摘要、67高CC与39长函数机器清单。首批六职责属于核心状态/Power及伤害抽牌协调，先于MapUI/RelicHooks/Feedback后续批次；尚未实施，无AC勾选。

六入口与纯Power叶模块本地验证完成：Actor996行、leaf62行；329模块5314完整测量、CC>30为67→61、CC>15为258→252。旧新差分、函数/错误别名、6+4真实语义变异、相关回归、四源桥51专项及原raw预算通过。独立c48b6a35深审PASS；组合接续本人PR521，当前Full/实际合后未验，所有AC仍不勾，余项风险未接受。

组合补测CI闭合库存733JS/1359Lua发现旧固定库存断言失败；仅显式登记5JS/3Lua为未测文件，原725/1356及2900/2712测量、timings、worker安全、原预算保持。主控3/3与独审3/3通过，最终源码Full仍待；不借旧7ec候选绿灯。

D5同源全采333模块5370/5370测量，CC>15降至240、>30仍61、最大75、最长580，Combat仍2275行。两新cap全函数/嵌套/初始化CC15及1000行硬门禁通过，1746 governed、14旧告警、零新增豁免。剩余热点正按真实owner/调用者与变化频次做有限风险审计，不视为接受；独立整片深审与完整交付未完成。机器证据docs/evidence/m7-relic-lifecycle-20261106.json。

独立有限审计补齐61高CC与61长跨度逐项owner/静态调用/测试/文件历史证据；未知不降级，无新P0确证。见docs/backlog-details/M7-CORE-REMAINING-RISK-20261106.md与机器附件。P1用于相关下一变更的审查顺序，非把所有数字强拆；不冒充Owner接受残余。当前D5有35组完整图等价、6具名语义负控与全新helper门槛证据，最终独审和托管仍待。

本轮仅治理既有建议V4三入口及全部新helper：validateEffects32、apply69、executeRoot40均降至15以内，原支付/唯一快照/逐效果/角色结算顺序保持。333模块5385/5385测量，CC>30=58、CC>15=237；本批各减3，最大75未掩盖。原1200冻结向量及合同/生命周期23项通过，新增支付/快照/Codex RNG真语义负控检出；静态1769职责门禁、14旧告警无新增。实际合前后Full和精确独审仍待，不提前勾AC。

最终三入口CC为validateEffects10、apply8、executeRoot11；17个入口/helper全部纳入CC15，新helper最大15，Codex全模块及新提交helper同门禁。新增8项最终8/8，原35-owner来源4/4保持，当前本轮集成候选待精确独审/Full，不启动下一切片。

Watcher效果执行切片本地完成：execute75→2、16私有executor最大13，全17职责受CC15；333模块/5401测量，>30=58→57、>15=237→236、max75→69，SCC81/15及内部边均保持。新17项全过，9组双VM全图217检查点/每侧86,658,777字节相等，18操作全触达；4真实语义负控、原150卡执行/Run晚失败回滚、N35旧合同及新桥通过。独立深审通过，精确提交/同轮集成/托管Full与合后未验，不勾AC；证据见M7-WATCHER-EXECUTION-20261107。

Inventory空闲协作切片本地完成：energyBonus/opening/validate/apply CC20/33/34/53→4/9/6/6，全模块36测量最高14并纳入CC15；同口径全库>15=237→233、>30=58→55，最大75与SCC81+15不变。99完整检查点、每侧27776302字节旧新图相等，4真实语义负控有效；新13/13、原13份Lua及历史来源4/4、完整CI库存8/8通过。内存争用kill保留，最终改为独立有界VM通过；不重复Full，交主控统一集成/精确独审/远端与合后验收，AC不勾。详见docs/backlog-details/M7-INVENTORY-RESPONSIBILITIES-20261107.md。

失败记录措辞校正：两次早期同进程回放仅确证整文件异常结束、无逐项输出；与共享内存紧张同时发生但未单独确证kill根因。最终有界VM通过，不以此声称性能根因已修复。

Watcher与Inventory已在最新develop 2ad07111统一集成：全库CC>30为58→54、>15为237→232、最大75→69，333模块5428/5428测量，SCC81/15不变。Power独立候选及三片验证保全，但在途#541已承接重叠职责，本PR不重复Power；共享门禁、来源桥与#539 CI库存保留并集。两片精确窄测/独审与远端门禁按本轮收据验收，未合并不勾AC。见docs/backlog-details/M7-CARD-EFFECTS-INTEGRATION-20261107.md。

承接PR542原始记录（原切片范围，非当前并集验收）：
2026-11-07 Watcher execute由75降至2，新效果handler与永久升级helper最高13并纳入同一CC15门禁。对最新2ad07111全仓5386→5403项完整测量，CC>30为58→57，CC>15为237→236，最大75→69；残余未宣布完成。独立切片214旧新检查点及独审通过，组合来源/CRLF复核已过，PR及完整合前后CI待正常准入。证据docs/evidence/m7-session-watcher-20261107.json。

Watcher/Inventory与Session单一并集：采用PR543真实Watcher实现，原9+PR542独有5场景全部保留，270完整图检查点一致；两侧不同变异合并为6项并绑定精确assert。全库CC>30仍58→54、>15=237→232、max75→69；完整333模块5428项测量。只补来源隔离依赖/CI库存，旧断言及预算不动；逐文件承接与失败/复测证据见M7-SESSION-INVENTORY-SUPERSET-20261107。待精确独审/远端门禁，AC未勾。

2026-11-07 按Owner持续架构指派，在PR543精确939e0820上独立推进Act1事件选择职责：choose CC69→13，六事件handler与Bonfire奖励/永久移除边界保留，新增职责全纳入CC15。相对该候选全库CC>30为54→53、>15为232→230、max69→64；SCC81/12不变。完整原事件与39组边界差分、源码闭包和本轮独审证据见docs/evidence/m7-act1-choice-responsibilities-20261107.json。依赖PR543尚未合，未启动重复Full、不勾AC，不声称主线已完成。

2026-11-07 接续Owner指定架构治理，在PR546精确35d392bc上拆分Defect纯效果规划：planEffect CC64→3，15种职责handler最高14及2别名，纯输入/原提交者/动态依赖保持。全库333模块5451测量，相对该候选CC>30为53→52、>15为230→229、max64→61；SCC81/12与所有require边不变。547完整图检查点、每侧31579585字节一致，47项唯一必要定向验证通过。独审发现历史N35 read投影遗漏后，仅补新epoch投影并完整原4项通过，旧35/144/151/295计数未改。证据docs/evidence/m7-defect-plan-responsibilities-20261107.json。依赖前置仍未合并，不勾AC或虚报架构完成；不重复Full。
<!-- SECTION:NOTES:END -->
