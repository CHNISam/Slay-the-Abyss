---
id: TASK-75
title: 缩短完整跨平台检查的实际执行时间
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-28 03:47'
updated_date: '2026-10-29 12:36'
labels: []
dependencies: []
priority: medium
ordinal: 120000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
完整Quality约25分钟，仅优化工作流和执行器。用户授权本地验证后PR合并再跑完整CI。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Windows和POSIX完整文件精确覆盖且断言超时保持
- [ ] #2 合入提交全部Required Checks通过
- [ ] #3 记录优化前后官方执行耗时
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
读取日志，优化分片和重复执行，验证覆盖失败传播，精确HEAD合并后验证完整CI。

继续消除raw Lua串行热点：仅托管原始Lua最多2个独立wrapper进程；同步runLua、原deadline/maxBuffer/新进程保持，JS串行和VM数量不变。原始Lua/support无文件写入或共享JS文件系统桥，真实并发、失败传播、全量集合均须验证，超时失败不放宽预算。

接续 PR267 当前9bab完整Quality三个独占30秒超时：先保留原CI和本地串行基线，采样定位验证开销；elite独立6组可按既有严格原文逆向模式分片，Silent同一实例两次完整四房及canonical比较、Intent连续双回合逐帧全字段检查保持。仅证明等价的测试层最小优化，不改运行时规则、原预算或有效断言；新精确头完整Quality仍待。

本轮集成收口：固定develop d2e0baa3的失败日志，复现unknown_event_routing 110种子独占30秒超时；先测保持同一原文helper的更小独立完整种子分区，必须覆盖原220种子、四路由/七事件及所有每种子断言，不改生产逻辑或预算。独立补反向重建/分区负例，再以精确PR HEAD与合入develop完整CI验收。

2026-10-29 Agent A：基于a5da67aa及最新CI原始时序检查权重与分片调度，仅最小调整ci-shards与专用测试；保持完整覆盖、原超时，不修改quality.yml。本轮必须精确PR SHA门禁全绿才合并。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR269合后Windows日志确认两类合同错误：新快反馈工作流CRLF未归一，三份fixture合同冻结旧runner整文件hash未识别已批准的调度编辑。修复保留原63ec1495全runner SHA，通过严格校验新调度block的SHA64f2b495后仅逆转该block和单一import；原runLua、全部超时、进程参数、输出/失败路径仍由原hash保护。新增LF/CRLF等价、任意deadline/进程修改仍拒绝、调度改写仍拒绝负例。精确Node24.18.0在已构建数据/UI上18/18过0skip，165.697秒；含真实7UI片/53case/6播放种子与原全部负例。用户已明确授权先合并后完整CI，未宣称远端通过。复用现有TASK75，不再建重复任务。

首轮40630641377在合入257d9e0c上15作业全绿；真实日志确认294个JS文件每平台一次、974原始Lua一次，0重漏。Windows峰值23分13秒、POSIX11分38秒，含排队总36分26秒。按完整原生文件计时再校准，并计入第一片Windows60秒/POSIX22秒固定门禁；本地17项及Backlog/网络检查通过，下一次完整CI仍待，任务保持In Progress。

双worker候选：21项并发/CLI/分片/门禁及6项原冻结断言负例通过；含LFS合同的31项通过。固定4个真实battle UI夹具串行41.826秒、双worker26.829秒，stdout/stderr逐字节一致；仅本机小样本，非完整CI收益。原串行encounter_coverage在本机触及原120秒上限，未计通过、未改预算。复用PR280同一完整成功run40630641377原生配置，不重复写权重；双worker把前置JS/门禁已预留负载按2倍Lua工作单位折算。所有中间记录已提交99310820保留，不丢弃在途备注。

双worker最终组合已复用PR280完整原生配置并纳入PR279可移植Windows Git夹具修复。精确Node24.18.0在实际Windows上121项选择器/快反馈/worker/分片/门禁全过0skip，11.212秒；31项含LFS合同通过。PR279已在用户本轮紧急先合并授权下按精确HEAD 2a1896c2经REST squash合入89b34d76，未修改保护；不把本地通过当作完整托管通过。双worker所有原Lua deadline/maxBuffer保持，原runner黄金SHA仍由精确逆转合同保护。

40635392726无条件双worker产生原30/120秒超时，完整CI失败。新修复仅对历史不足10秒的短夹具使用最多双进程，重/未知夹具独占并按双槽位计算分片成本，不重试失败、不放宽原预算。35项含真实屏障、全部错误传播、原runner黄金SHA及原工作流合同通过；真实失败入口复验及新完整CI仍待。

2026-10-28 统一集成在4f5bf5bb时曾实际复现缺少优先级红灯并用CLI补Medium/Furinya；随后接续257d9e0c时保留主线已经补齐的Medium和全部最新执行备注。仅依AGENTS规范负责人Furinya，原执行者Codex、状态、计划与验收不变，不接管实现。本轮复用主线原生runner逆向证明，移除整合分支重复helper，继续保留63ec1495原黄金与负例。

PR2679bab 的完整Quality40642815774仍有Silent/Intent/Elite三项独占30s超时，原失败已保留。dot独立云树串行原基线24.67/20.52/19.60s；Intent仅内联相等scalar的测试比较，原双回合/逐帧全字段/原正文不变，14.36s且stdout相同；Elite6独立组按完整原文SHA/blob可逆分成1–3与4–6，12.04/6.71s且六组全覆盖。新证明4项先红后绿，连同worker/runner12项JS、全部Intent15组、Elite6组和Backlog/syntax/network通过。Silent仍保留同一实例两次完整四房和canonical相等；profile定位真实完整snapshot遍历热点，生产候选尚未采用，不宣称三项已修复或完整Quality通过。详见docs/reviews/PR267-FIXTURE-BUDGET-20261028.md。

后续确认并纳入Silent最小生产机械快路径：仅capture显式栈/入栈去重，所有table key/value、data/catalog、alias/cycle仍完整访问，restore/ownedRestore/release原字节不动。原Silent fixture及同实例两次四房/71源池/canonical相等全部未改；旧新完整canonical6488字节相同。最终三故障入口21.47s/13.70s/Elite两片11.64与6.25s；14定向raw全部原预算通过，总137.53s。加强proof7项、原owner9组、96全图与20000深链及3漏图负例通过；独立审查发现false/key-only证明缺口后已补并重验。架构214/1237、静态84历史warnings零新增/418职责、4mutation通过。当前SHA完整托管Quality仍待，TASK75保持In Progress，不冒充真机或合后验收。

继续按用户“处理好”授权完成集成；免费OpenCode路径因TASK51已记录限额且无恢复依据，本轮由Codex直接处理，不发试额度请求。当前develop CI40657289890的rules1失败为unknown_event_routing.lua原30000ms ETIMEDOUT，其余7规则片及POSIX/presentation通过。

unknown路由修复：原110种子独占在Node22复现原30s超时；简单55种子半组缺稀有路由的诊断保留，未采纳删汇总。改4个55种子真实入口，逐种子原文反向重建hash a4d67d6a；真实完成记录1..220精确无重漏，原Lua四路由/七事件断言继续分别验证1..110及111..220。实际缺路由/事件负例均拒绝。Node24.19串行13/13过、0skip，76.653秒，全部子进程保持原30s；精确托管Node24.18完整CI和合后CI仍待。详见docs/reviews/INTEGRATION-CI-20261028.md。

2026-10-29 Agent A：仅校准完整JS权重（385文件/平台）与首片门禁75s/44s；原974 Lua权重、fallback、worker分类逐值不变，未修改ci-shards算法或workflow。来源40866923323 attempt2，真实checkout3cd0a668与起点a5da67aa同tree50c3882a；PR head1cdee不混作执行SHA。相邻成功40865898601独立回放仍预测Windows JS峰值降13.94%、Linux降15.49%，只是离线回放，完整新CI待。明细docs/reviews/CI-SHARDS-20261029.md。固定官方Node24.18已核验SHA256；本地22的16/18通过，2项因缺24专用CLI选项失败不计通过，24.18重验进行中。

固定官方Node24.18最终定向验证：36/36通过、0失败、0跳过，25.266s；含当前385 JS/1090 raw Lua完整分配、未知文件、原workflow/runner冻结、真实失败继续执行、timing reporter、LFS与worker独占屏障。network与Backlog门禁通过。仅本地切片验证；新精确HEAD完整CI及合后实际耗时仍待，TASK75继续In Progress、不提前勾验收。
<!-- SECTION:NOTES:END -->
