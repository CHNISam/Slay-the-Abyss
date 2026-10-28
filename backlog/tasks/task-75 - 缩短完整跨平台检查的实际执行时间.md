---
id: TASK-75
title: 缩短完整跨平台检查的实际执行时间
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-28 03:47'
updated_date: '2026-10-28 05:49'
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
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR269合后Windows日志确认两类合同错误：新快反馈工作流CRLF未归一，三份fixture合同冻结旧runner整文件hash未识别已批准的调度编辑。修复保留原63ec1495全runner SHA，通过严格校验新调度block的SHA64f2b495后仅逆转该block和单一import；原runLua、全部超时、进程参数、输出/失败路径仍由原hash保护。新增LF/CRLF等价、任意deadline/进程修改仍拒绝、调度改写仍拒绝负例。精确Node24.18.0在已构建数据/UI上18/18过0skip，165.697秒；含真实7UI片/53case/6播放种子与原全部负例。用户已明确授权先合并后完整CI，未宣称远端通过。复用现有TASK75，不再建重复任务。

首轮40630641377在合入257d9e0c上15作业全绿；真实日志确认294个JS文件每平台一次、974原始Lua一次，0重漏。Windows峰值23分13秒、POSIX11分38秒，含排队总36分26秒。按完整原生文件计时再校准，并计入第一片Windows60秒/POSIX22秒固定门禁；本地17项及Backlog/网络检查通过，下一次完整CI仍待，任务保持In Progress。

双worker候选：21项并发/CLI/分片/门禁及6项原冻结断言负例通过；含LFS合同的31项通过。固定4个真实battle UI夹具串行41.826秒、双worker26.829秒，stdout/stderr逐字节一致；仅本机小样本，非完整CI收益。原串行encounter_coverage在本机触及原120秒上限，未计通过、未改预算。复用PR280同一完整成功run40630641377原生配置，不重复写权重；双worker把前置JS/门禁已预留负载按2倍Lua工作单位折算。所有中间记录已提交99310820保留，不丢弃在途备注。

双worker最终组合已复用PR280完整原生配置并纳入PR279可移植Windows Git夹具修复。精确Node24.18.0在实际Windows上121项选择器/快反馈/worker/分片/门禁全过0skip，11.212秒；31项含LFS合同通过。PR279已在用户本轮紧急先合并授权下按精确HEAD 2a1896c2经REST squash合入89b34d76，未修改保护；不把本地通过当作完整托管通过。双worker所有原Lua deadline/maxBuffer保持，原runner黄金SHA仍由精确逆转合同保护。

40635392726无条件双worker产生原30/120秒超时，完整CI失败。新修复仅对历史不足10秒的短夹具使用最多双进程，重/未知夹具独占并按双槽位计算分片成本，不重试失败、不放宽原预算。35项含真实屏障、全部错误传播、原runner黄金SHA及原工作流合同通过；真实失败入口复验及新完整CI仍待。

2026-10-28 统一集成在4f5bf5bb时曾实际复现缺少优先级红灯并用CLI补Medium/Furinya；随后接续257d9e0c时保留主线已经补齐的Medium和全部最新执行备注。仅依AGENTS规范负责人Furinya，原执行者Codex、状态、计划与验收不变，不接管实现。本轮复用主线原生runner逆向证明，移除整合分支重复helper，继续保留63ec1495原黄金与负例。
<!-- SECTION:NOTES:END -->
