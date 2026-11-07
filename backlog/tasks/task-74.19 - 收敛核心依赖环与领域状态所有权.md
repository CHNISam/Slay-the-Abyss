---
id: TASK-74.19
title: 收敛核心依赖环与领域状态所有权
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 01:46'
updated_date: '2026-11-07 05:06'
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

承接PR542原始记录（原切片范围，非当前并集验收）：
2026-11-07 用户明确继续架构治理。本线仅接 Session 奖励准备能力切片：potion_rewards、event_combat、event_combat_routes 直接消费已有遗物只读查询/奖励预览固定槽，不加载完整 Session 命令门面；保留普通动态替换、nil恢复及RNG/状态/错误轨迹。先红后绿依赖防回退与旧新完整来源对照，复采完整SCC/CC；协调者统一集成公共历史来源层和门禁，不改原认领、不覆盖Combat/Watcher并行切片。

协调#542/#543重复Watcher切片：以#543单一Watcher实现保留Inventory，承接#542独有Session三源码/来源桥与双方测试并集；保留独立历史证据，CI库存补全，组合窄测/独审后以单一superset交付。未合依赖#541不混入；不新增领取或勾AC。
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

承接PR542原始记录（原切片范围，非当前并集验收）：
2026-11-07 Session 奖励能力切片在自有隔离树实现：药水奖励与两类事件战斗准备直接消费已有查询/预览槽，未新增生产模块。实际同算法SCC 81/15→81/12，Session内部位置62→52；333模块5385/5385完整测量，CC>30=58、>15=237、最大75不变，14旧告警。84旧新VM完整图检查点逐字相等，既有事件8项与新来源3项通过；精确独审及组合历史来源/Full交付继续，所有AC保持未勾。技术证据 docs/evidence/m7-session-reward-capabilities-20261107.json。

2026-11-07 最新基线2ad07111统一接入Session奖励能力与Watcher职责切片。实采SCC81/15→81/12；未触及并行PR541的Power/商店源码，Power显示顺序成果保留待其后接续。N35与Session来源7/7、隔离闭包4/4及静态/指引/Backlog通过；组合精确独审与PR Full、正常入队和合后Full继续，不勾AC。

PR542/543并集已在隔离树实际完成：Session三源码及能力/来源合同原字节保留；最终同口径SCC81/15→81/12，Session内部位置62→52、唯一对41→31。104种测试分批最终通过，首轮5项隔离依赖缺失已补清单并保留失败；40owner独审320正常/480异常探针通过。待最终精确独审、远端superset读回及托管/合后Full，不提前关闭被承接PR或勾AC。
<!-- SECTION:NOTES:END -->
