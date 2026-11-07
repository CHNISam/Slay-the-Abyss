---
id: TASK-74.20
title: 治理阻碍角色扩展的高风险复杂度
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 01:46'
updated_date: '2026-11-07 05:10'
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

主控分配下一空闲CardCapability切片，已与Colorless依赖worker核对无生产文件重叠。基于2ad07111固定完整旧源，将isImplemented的OriginalV4绑定、激活限制、状态生命周期和普通卡准入分为私有职责，保留短路字段读取、nil/false/非布尔返回及动态支持API。全模块/helper执行CC15；旧新完整图、实际卡库/升级/对抗动态读取和语义负控后独审，不重复Full或伪称重新领取。
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

CardCapability空闲切片完成本地验证：isImplemented CC57→8，全模块10测量最高11并受CC15；最新develop2ad07111同口径>15=237→236、>30=58→57，最大75及SCC81/15保持。新10/10、1739完整检查点每侧3246966字节一致，4真实语义负控及独立612对读序/故障探针通过；原25项JS与3份RunCardCatalog Lua回归通过。独审及统一集成/Full仍待，不改任务状态/AC。见docs/backlog-details/M7-CARD-CAPABILITY-RESPONSIBILITIES-20261107.md。

CardCapability与Colorless目录组合已全采：CC>30 58→57、>15 237→235、最大75，Capability57→8且模块最高11；完整源/库存与验证见M7-COLORLESS-CAPABILITY-INTEGRATION-20261107。未把#541/#543在途成果算入本片，未提前完成AC。
<!-- SECTION:NOTES:END -->
