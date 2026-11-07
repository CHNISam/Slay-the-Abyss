---
id: TASK-74.19
title: 收敛核心依赖环与领域状态所有权
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 01:46'
updated_date: '2026-11-07 10:00'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/M7-DEPENDENCY-AUDIT-20261106.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 161000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
当前大SCC仍有104个模块，既有职责切片未覆盖全部跨领域反向边；先确认影响后续角色内容开发的真实高风险耦合，避免仅靠拆文件宣称架构完成。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 以当前同一源码身份输出即时及延迟完整依赖图、SCC成员和内部边位置，逐类说明状态提交owner与风险依据
- [ ] #2 消除已确证P0/P1反向依赖并以旧新状态、随机、事件、队列、别名及失败回滚对照验证；保留边有生命周期依据且新增边受可执行防回退门禁
- [ ] #3 公布同算法最终SCC绝对值、残余风险与责任；独立深审及实际合后Full通过，未确认残余不冒充低风险
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.在dedb9ed5完整源码上复用AST依赖采集，核对即时及延迟SCC、真实反向调用与状态owner。2.独立审查优先核心调用链，形成逐边风险与可证实解环路径。3.按真实P0/P1选择最小职责切片，固定旧新行为并加门禁后独立深审及完整交付。

4.依据391306af只读审计与现有CardActions规范，准备单一无出边遗物只读查询模块：移动原五套有序alias及窄奖励计数，保留普通动态字段读写、Shop.aliases枚举/替换、Rare私有owns与公开替换隔离、Run调用时函数快照。先冻结完整旧源和行为/加载边界基线；当前PR521由原生队列完成，后续提交不另建待合PR或改入队HEAD，待基线落地后再集成。

5.D5完整生命周期边界：已确认孤立Boss提取仍回Session，不实施该假切口。按docs/plans/2026-11-06-relic-lifecycle.md组合Hooks Combat能力与四族固定能力，保留Session公开命令和Wish/Writhing原owner规则；四Runtime根到Session传递门禁已真实RED4/4。新隔离树feat/relic-lifecycle基于5762，先完整391旧新VM基线与独立计划审查，再写产品；原query交付树保持干净。

6.仅收口当前PR521：按Full42176327678逐项修复drain、旧语义变异定位与历史预算输入适配，保留原oracle、case、断言和预算；对本轮真实超时仅用已完成成功文件实测校正分配并采用可容纳全库存的最小布局。独立复审、新SHA完整CI、原生队列和实际合后验收完成后结束，不开启下一架构切片或新任务。

本轮最终有界切片：将Codex选牌生成与提交移回现有Combat选择事务owner，Codex仅保留开选和校验，消除其回导CardActions；原状态、RNG、事件与晚失败回滚逐字对照，保留完整图与残余，不扩大架构范围。

2026-11-07 Actor 交付接续：以最新 develop d8a57cae 建独立完整树，保留 #540 看板、归档与 roadmap 更新。移入已审 489425c1 Actor 切片，验证完整 Lua/config 与旧输入逐字一致后复用原行为/指标；重跑来源、完整库存/预算、guidance、backlog/doctor 窄测。仅准备唯一首次 Draft PR，不触发 Full、ready、队列或合并，不混其他切片，不改负责人/状态/AC。

2026-11-07下一独立切片：核对实际develop2ad07111、开放540–545及活动工作树，5个生产路径无占用。把Actor的isActive/isPresent只读查询归独立Presence叶，Actor保留固定普通动态槽，Act2决策/召唤及Silent弃牌能量仅消费存活查询，战斗写入owner保持。冻结同源before和完整图/动态/失败行为，接禁止回导及CC15，窄测与独审后交整合；不重复Full，不改负责人/状态/AC。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮新鲜AST：328模块1902引用位置1535唯一对；即时图无SCC，含延迟图104成员804内部位置538唯一对。已逐类核对RelicHooks和Session/Combat提交owner，见M7-DEPENDENCY-AUDIT-20261106。六处入队解耦只减少职责反向边，不使大环缩小；优先审清生命周期切片及历史来源适配成本，不以数字下降收口。

只读反事实提示CardPool三查询接真正叶可使104→103；更大族Session与purge路径104→88仅删边实验，不是实测改善或P2接受。补查现有规范不承诺raw反射形状，真实Shop.aliases与Rare.owns动态消费必须保留；原先要求纯反射另审批的推断已撤回。证据在主控521工作树build/g1-next-boundary及根.artifacts。所有AC仍未勾。

遗物只读查询切片已在隔离树完成本地实现：单一零依赖叶保留五别名域和动态API；139别名、48奖励场景/344随机数边界双独立VM一致，专项6/6绿。CardPool实际退出核心SCC，104→103成员、内部位置804→791，未宣称整个环完成。独立生产初审无缺陷；来源适配、最终提交与托管验证继续，AC保持未勾。技术证据见docs/backlog-details/M7-RELIC-QUERIES-20261106.md。

只读能力批次新增永久牌候选owner：仅依赖Copy，Boss不再回导LivingWall事件；原动态purgeCards、逐卡Copy图、错误和事务/RNG保持。新增6项先红后绿，原LivingWall72变换槽及Boss/Astrolabe等9项绿；同epoch十源34项绿。完整图实测331模块，大环102成员/787内部位置/527对，CardPool与LivingWall退出；14旧告警，无新增豁免。源码和来源已稳定，最终独审/提交/托管继续，AC未勾。

D5生命周期产品已在独立树实现：14 Combat Hooks+固定五族能力，23消费者118读取保持原AST时机。实际333模块/1921位置/1547对；Combat SCC82/626/402与Session15/62/41，即时无环，六入口全边不能回Session。当前35组完整旧图读回与fresh current VM逐字一致，13540检查点；冷加载与89双向普通槽位、直接/延迟治理负例9/9，原查询候选12/12。最终来源桥、具名变异、精确整片深审及托管/合后验收继续，AC不勾。见docs/backlog-details/M7-RELIC-LIFECYCLE-20261106.md。

D5来源扩展34项及独立有界审查PASS：23个391完整before另核Git blob、35 fresh owners/4 witness、精确配置逆和四copy完整旧epoch，原core guard不改。6个真实可解析语义负控控制先成功后被具名行为断言检出，覆盖双queue、TOP、counter别名、动态Boss、Wish/Bloom和Omamori发布；6/6通过。当前继续最终整片精确提交与原生交付，未用局部通过关闭AC。

7be来源Full42176327678真实失败已保留，已通过原merge:auto暂停并读回。11个测试位置归6组：drain旧inverse/动态owner、HP顺序/Spoon/Necronomicon/Victory旧mutator site、旧14片误用当前新增库存；对应点状修复保持生产333源不变。另Linux6与Windows8/14 annotations确认20/30分钟真实上限终止，不能只更正旧历史预算断言后忽略实际吞吐；按完整成功CI_FILE_TIMING实测做当前布局必要修正，未声明新候选已通过。

本批Full失败适配已定点修复并独审8file：drain5/5及raw75例/18真变异、三处定位12/12、Actor与历史预算9/9保持，补回当前13/14完整raw覆盖。真实timeout按1458条成功file原生日志校正129项JS权重，16/12工作下界已超原预算，采用必要最小17/13；原预算、unknown、raw安全/成本、worker、并发与Relic35均不变。既有CI入口仅加2个新完整SHA纯映射，3历史+4当前合同7/7及直接25/25通过。新精确HEAD/Full/队列/合后验收仍待；按Owner最新要求只收当前PR521，完成后结束，不新增任务。

657来源Full42184962874的POSIX8真实20分钟超时已由首失败CLI回传，已原入口暂停读回。精确58计划/44完成前缀定位run-max-hp-config-inverse为首未完成：Linux旧254137，当前未观测；Windows完整成功889637.0668。629181截尾不入测量。仅复用既有planning floor加889638跨平台保守分配估计，原平台表/129观测/1.17MB证据/其他floors/17-13/预算/worker/并发保持；预测Win1707732/POSIX1187278含60秒。短历史实验不支持改D5缓存，已停止额外性能设计，只收当前PR521。

本轮最终有界Codex切片已将生成、升级、插牌与完成移回Combat既有选择快照事务，Codex只做开选/校验。固定全图333模块1920引用；Combat SCC82→81、内部626→623位置/402→400对，Session15/62/41不变。原Act2遗物及Codex晚失败回滚通过；完整图和源码身份见docs/evidence/m7-final-core-20261106.json。独审/实际合前后Full仍待，不勾交付AC。

最终本地完整收据补证：新8/8及原35-owner4/4通过；V4/Codex两个独立旧新VM合计79完整状态图检查点、每侧52,016,680字节一致，含V4直接execute付款后和伤害后部分写入、原错误对象。当前候选只提供本轮集成，不另开PR；独审及实际Full/队列/合后证据由主控同一候选绑定，AC仍不提前完成。

2026-11-07 Actor presence 独立切片：只读目标/在场谓词移至无依赖叶，AI决策/召唤规划/弃牌退款退出Combat SCC；基线2ad07111实测81/623/400→78/608/391，Session15不变，CC>30仍58/最大75。行为12、旧Actor10、原Act2 34、新来源10、旧来源42、库存8通过，独立深审无阻塞。详情见 docs/backlog-details/M7-ACTOR-PRESENCE-20261107.md；本地行为31.053秒仅为规划成本，整合需保留真实floor，尚未Full/合并，整体AC不变。

Actor presence独立交付补齐真实完整12/12本地31053ms规划floor，保留9旧floors及timings、布局/worker/历史证据。当前748JS/1403Lua，含60秒规划上限Win1714151/POSIX1194287；新来源/库存/拒绝合同32/32。生产9624804字节保持，当前基线与实际CI/合并待验，不勾AC；和#545兼容另树准备。

Actor 首次交付移到 develop d8a57cae：#540 共98个路径保持新基线，实际无文本冲突；原30个非Backlog文件逐字移入，333/334 Lua与8份config、3275输入完整身份核验通过。新来源/CI29、六历史来源42、guidance/backlog/sprint58及doctor通过；748JS/1403Lua完整17/13分片预测仍Win1714151/POSIX1194287（原30/20分钟预算）。复用原完整VM/指标，不触发Full、ready或队列；仅准备首次Draft，精确HEAD独审/托管仍待，状态/AC不变。接续证据见docs/evidence/actor-presence-latest-base-20261107.json。
<!-- SECTION:NOTES:END -->
