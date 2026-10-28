---
id: TASK-80
title: 让规划检查符合两职业比赛范围
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-28 14:40'
updated_date: '2026-10-28 15:59'
labels: []
dependencies: []
priority: low
type: chore
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有规划检查硬编码四职业，导致正确的两职业M3范围无法通过；作为工程任务处理，不改变比赛验收标准。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 检查识别两职业两幕M3并拒绝过期的四职业必做范围。
- [x] #2 相关回归测试和Backlog一致性检查通过。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 以PR306精确HEAD为基线，核对用户确认的岩系旅行者（Ironclad）与雷电将军现有冻结V4两职业、第一幕及第二幕规划合同。
2. 仅修正规划检查及专用正负例，保留优先级、负责人、两幕与历史证据门禁；必要时简要澄清AGENTS/SCOPE/MILESTONES的当前文案，不改运行时、原卡池或概率。
3. 串行运行规划检查、专用回归、Backlog doctor、diff及轻量守卫；只凭实际证据勾验收。运行时准入和设备验收仍由TASK-59/59.3承接。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
注意：PR #301 与 #302 有在途 TASK-79 重号；合入前必须通过CLI安全协调编号，避免覆盖。

合入最新主线后经Backlog doctor将本任务从79改为80；主线TASK-79仍为CI修复历史。

2026-10-28 PR306接续（基线6fe3a6e24d3eedeb40aeb6e48aebc129b35b0a29）：修复M3过期四职业硬编码；原生里程碑标题保持不变，另将SCOPE当前决策段绑定为岩系旅行者（Ironclad）与雷电将军现有冻结V4，历史/Alpha/Dev中的职业提及不能替代当前合同。AGENTS、SCOPE与MILESTONES仅澄清这一既定范围，未动玩法、原卡池、概率、白名单或CI。
实际离线证据：verify:backlog通过；专用Node回归30/30、零跳过（具名角色、V4重设计、历史误救、四/八/全职业、两幕及CLI正负例）；Backlog doctor无重复/自依赖/环；数据与UI构建、既有competition-two-act回归通过（7组受控边界，保留同局状态/回滚与无持久历史）；网络守卫、改动JS语法与diff检查通过。使用现有固定版本依赖，无下载或依赖变更。
本任务仅完成规划检查修复，不认证运行时准入、原生候选、完整Quality、平台或实体设备；TASK-59/59.3及其未勾验收保持不变。本轮未用OpenCode（既有限额窗口未知），未占用键鼠、未推送、未合并。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
规划检查已按既定两职业两幕范围修正；30项专用正负例、两幕受控回归、Backlog doctor及轻量守卫通过。运行时和设备验收仍由TASK-59/59.3承接。
<!-- SECTION:FINAL_SUMMARY:END -->
