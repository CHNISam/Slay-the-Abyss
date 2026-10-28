---
id: TASK-75
title: 缩短完整跨平台检查的实际执行时间
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-28 03:47'
updated_date: '2026-10-28 04:03'
labels: []
dependencies: []
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
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR269合后Windows日志确认两类合同错误：新快反馈工作流CRLF未归一，三份fixture合同冻结旧runner整文件hash未识别已批准的调度编辑。修复保留原63ec1495全runner SHA，通过严格校验新调度block的SHA64f2b495后仅逆转该block和单一import；原runLua、全部超时、进程参数、输出/失败路径仍由原hash保护。新增LF/CRLF等价、任意deadline/进程修改仍拒绝、调度改写仍拒绝负例。精确Node24.18.0在已构建数据/UI上18/18过0skip，165.697秒；含真实7UI片/53case/6播放种子与原全部负例。用户已明确授权先合并后完整CI，未宣称远端通过。复用现有TASK75，不再建重复任务。
<!-- SECTION:NOTES:END -->
