---
id: TASK-75.5
title: 按完整负载增加一个Windows分片并保留原预算
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-05 03:41'
updated_date: '2026-11-05 03:55'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/M7-HOST-BATCH-20261105.md
parent_task_id: TASK-75
priority: medium
type: enhancement
ordinal: 159000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR516新增Host完整计时校准后，13Windows槽理想下界加原60秒余量为1894.690秒，当前LPT仅比下界多0.194秒，无法靠重排达到原1800秒预算；旧成本不得下调。与75.3并发设置和75.4数据校准分开追踪。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Windows Full矩阵由13扩为14，POSIX9与cap6保持；全部当前JS和raw Lua每平台唯一完整分配，原单测及job预算、worker安全、权限与严格门禁保持
- [x] #2 新增shape在来源规划、完整实际作业集合与交付/队列验证器一致，缺失旧新分片、重复或伪造矩阵不得通过；原历史完整来源仍可精确逆投影
- [ ] #3 独立深审、精确候选来源和原生队列及实际推送Full、原合后验证通过；分别报告实际耗时排队与runner成本，不以估算代替稳定30分钟目标
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.保留13槽理想下界及原预算失败作为证据，完整量化14槽预测；不删校准实测。2.唯一Full shape Windows改14、POSIX9/cap6不变，同步所有实际来源规划、完整作业集合、交付与队列严格验证及历史精确来源桥接。3.以14/9完整唯一覆盖、原30分钟含60秒余量、缺失/重复/伪造shape与历史漂移反例验证并独立深审。4.同一PR516精确HEAD重验来源/原生队列/实际push Full和原merged验收，报告真实成本。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
14槽完整724JS/1356Lua模型加60秒为1764.067秒，原预算余35.933秒；仅估算。独立协议审查实测queueFullErrors可把两个不同分片名称绑定同一job.id而仍无错，原RED已存build/shape-protocol-review；PR发布器/交付已有ID去重，队列发布器需同级补齐，纳入本任务AC2防伪并由非作者复验，未改门槛。

725JS/1356Lua最终14/9唯一完整分配，28exactjobs；原30分钟加60秒断言通过，模型最大1764.761秒。独立100合同与另一轮82协议用例全过，旧13绿灯/缺第14片/错误total/来源/重复ID均拒绝；真实去重guard移除变异被检出。精确HEAD与合后Full仍待，AC3不勾。
<!-- SECTION:NOTES:END -->
