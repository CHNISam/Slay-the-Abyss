---
id: TASK-75.4
title: 用完整实测校正新增Host回归分配成本
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-05 03:18'
updated_date: '2026-11-05 03:54'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/M7-HOST-BATCH-20261105.md
parent_task_id: TASK-75
priority: medium
type: bug
ordinal: 158000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR516首轮Full的POSIX4至6分片真实触及20分钟原预算；新增Host完整回归仍按未知文件10秒估算，已成功文件实测94至172秒，不能以提高超时掩盖分配偏差。与75.3并发设置分开追踪。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 调度成本仅采用可追溯完整成功文件实测，旧权重不下降；原fallback、预算、worker安全和严格门禁协议保持，矩阵扩容由75.5独立验收
- [x] #2 新增校准的历史逆投影只接受精确唯一批准输入，旧完整SHA与原断言保持，错误值重复位置及其他漂移仍拒绝
- [ ] #3 独立复审、精确候选来源及原生队列和实际推送Full与原合后验证通过，分别报告实际耗时和未达目标
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.读取首轮Full实际job注释和完整文件计时，固定候选身份及原日志摘要。2.只给有完整成功记录的文件增加单向调度成本，保持未知fallback与所有执行预算；重新核对13/9文件精确分配。3.严格批准输入逆投影和漂移反例，独立复审后更新PR516同一候选。4.来源/原生队列/实际push三事件分别Full、原验证器合后验收及真实时长。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
task:pick已ALLOW；当前开放PR516为本轮失败修复唯一实现，PR503草稿不重领。仅修本轮CI准入所需校准，不启动后续MapUI实现。

独审已核16条原始完整success行/wholelog摘要及严格inverse，22专项21过1预算失败。13槽理想下界加60秒为1894.690秒，LPT仅比下界多0.194秒；不降旧权重或改预算。75.5经独立准入承接14槽扩容，本任务AC明确仅负责校准，仍未完成。

16同平台success完整计时及whole-source严格inverse独审通过；75.5扩14后独立100项CI合同全过，原13槽预算失败证据保留。来源/队列/实际push Full与原合后验证待，AC3不勾。
<!-- SECTION:NOTES:END -->
