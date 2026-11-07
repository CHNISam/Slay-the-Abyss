---
id: TASK-75.6
title: 补全当前完整成本并修好队列整体预算
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-05 07:58'
updated_date: '2026-11-07 05:42'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/M7-HOST-BATCH-20261105.md
parent_task_id: TASK-75
priority: medium
type: bug
ordinal: 160000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR516来源Full通过，但同树原生队列Windows1的JS和Lua均成功后，工程门禁被整体30分钟预算取消。仅Host窄校准不足以代表全部文件；全部成功JS实测单向补全后，14槽理想下界含60秒超过原预算57.262秒。需用真实完整数据修复分配与容量，不能重试涂绿或放宽门槛。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 当前同源码来源及队列的全部完整成功JS文件按平台唯一核验后ceil/max单向校准，旧值与unknown有效下限不下降；原Lua安全资格、预算、60秒余量与失败传播保持，原始完整数据及截断边界可追溯
- [x] #2 以完整成本选取可行分片容量并验证当前全部文件唯一完整覆盖；所有规划、来源、队列与交付验证器的精确作业集合一致，旧shape、缺失、重复、伪造来源仍拒绝；历史完整输入精确可逆且旧golden不刷新
- [ ] #3 独立深审、精确候选来源及原生队列和实际推送Full与原merged验证均通过，报告真实wall排队runner成本及未达稳定目标，未实测设备仍保持未完成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.保全同树来源41与原生队列完整作业、日志和整体30分钟取消证据，来源66秒门禁与47秒setup分开，截断40秒工程步骤不作完整测量。2.锁定2900成功JS及2712外层raw步骤成功认证的记录，按实际步骤排除两轮各7共14条JS内嵌Lua；全部成本ceil/max且旧显式值及fallback不降，raw只改luaShard，原timings.lua安全资格不动。3.最终选择Windows16/POSIX12 cap6/Full33，保留原30/20分钟、75/44秒门禁、60秒敏感度；当前726库存重算，POSIX9至11的真实RED保留，12最小可行两波，13的第三波模型壁钟更差不采用。12额外5%工作量即超2.061秒仅作风险诊断，不新增或放宽门槛，不承诺托管稳定30分钟。4.单一shape同步严格33项来源、队列、推送及交付集合，整源精确inverse回14/9再13/9，完整成本回旧d580再旧8e；不更新历史golden，所有错误漂移保持拒绝。5.独立深审与必要专项，精确新HEAD来源Full、原生组、实际push Full及原merged_passed，分别报告真实wall、排队、runner成本和未达稳定目标，设备证据保持未完成。

6. 集成既有UI测试时，分开固定725份历史实测清单与新增未测文件；按当前完整库存保留原预算、余量和唯一覆盖验证，不改历史测量或成本。

2026-11-07 Owner明确要求修复微小超时反复重跑机制：保留30/20分钟为性能目标，执行guard扩大为Windows45/POSIX30分钟；预测只提示，exact-once及全部断言保持；集中Lua默认执行余量，显式timeout不变。仅专项验证一次后交由最终HEAD完整CI，不逐秒扩分片。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
原入口pause已读回，PR516未merged，当前open517/503均draft不修改。当前allJS同平台成功max模型14理想+60=1857262ms，数学不可行，15仅诊断1737834ms余62166；须完整范围核算后选择，不以窄Host模型为整体通过证据。

来源41与队列源码树均65f5bb53。原队列Win1的JS和raw Lua步骤成功，工程门禁执行40秒后被整体30分钟预算截断，40秒不是完整成本样本。证据build/group-516-failure/REPORT.md及sensitivity.json；来源门禁66秒与setup/cleanup/gaps47秒分别记录，未双算。

完整Linux同平台实测校准后，最终726JS的POSIX9在真实仅JS拓扑下max+60=1510240ms，超过原20分钟310240ms。原9片候选失败保留，正在独立核算10至16片，不改预算、44秒门禁预留或降低成本。计数更正：两run排除JS步骤内完整Lua计时各7共14条；旧11为首run非锚定substring差额误用，2712条合格raw及锁SHA不变，另有独立更正receipt。

最终容量决定已独立复算：最终726JS，POSIX12 max+60=1147677ms余52323ms；13余135986ms但cap6模型由两波2295353ms变三波3192024ms。保持cap6选择最小可行12片，完整33项。初始16/9/30计划被完整Linux成本RED取代，不曾作为已通过候选交付。

本地工程AC1/2已验：5612条原日志行及SHA/实际步骤逐项认证、旧有效成本不降；新严格multi-run来源缺口修复，旧single-run断言完整保留。独立32项最终全通过，原31/32 RED保留；Full33公共4positive/68negative，另一独审84模板回放加36新delta及38整源inverse全通过，范围重叠不相加。最终726JS/1356raw完整覆盖，Win16含60秒1659439ms、POSIX12为1147677ms，原预算与安全不变。AC3待新精确候选来源、原生队列、实际push Full及merged_passed，不提前勾选。

本轮清理集成PR520复现ci-complete-calibration两处固定库存失败：727与725、728与726。来源是新增native-ui-preview和reference-ui-lab两个测试，不是历史实测记录变化；先暂停原生合并，修复合同的历史/当前清单边界。

修复后固定725份历史JS、2900条成功JS观测和2712条raw记录仍逐项认证；当前728份JS含3个明确未测文件，逐平台验证unknown成本，16/12分片完整唯一覆盖及原预算/60秒余量断言全部保留。10项校准/历史来源/容量合同通过，原2处RED保留；新HEAD独审与Full/队列/push/merged验收待执行，AC3保持未完成。

本轮接续已有#541；Owner最新授权合理扩大时间余量，覆盖历史原预算冻结要求。历史测量与失败证据不刷新，AC3仍待真实最终来源/队列/推送。

已实现Full Windows45/POSIX30分钟硬guard，原30/20为性能目标；当前forecast仅诊断，全部唯一覆盖/非法成本/safety断言保持。Lua默认90/120/180秒集中，历史UI及Sapphire早退入口同步，显式timeout/buffer/heap/worker不变。专项首轮44/45（误改历史负控已恢复，原失败保留），仅修正项+新增逆投影2/2；当前库存1/1。默认runner专项首轮28/29（新逆层CR匹配错误，原失败保留），仅受影响diagnostics10/10。其余已通过游戏回归不重跑，ci-runtime组合合同与最终独审进行中。

集中defaults已合入：普通90、battle/host120、重型180秒，Sapphire90秒，真实早退入口同步。ci-runtime组合首轮8/9，发现此前Power/Shop新增floor遗漏；按固定完整收据单独认证新floor，原8local+1hosted合同保留，针对项1/1通过。Full原有同run/HEAD/BASE failed-only证据链经独审确认可复用，无重试框架或规则变更；#542重复旧Full仅请求取消，实际末尾汇总排队未冒充terminal。最终独审和精确来源/队列/合后Full仍待。

Owner要求本轮尽快收尾结束，停止Act1延伸。最后实修：旧run取消后always汇总排队堵住同PR新run，已用原生force-cancel清除精确过期550f并读回completed/cancelled；两汇总改!cancelled()，普通失败/漏片仍原shell拒绝，取消不再占并发组。仅验证当前6文件，原失败日志保留，业务回归未重跑；最终候选待GitHub正常验证，不提前Done。
<!-- SECTION:NOTES:END -->
