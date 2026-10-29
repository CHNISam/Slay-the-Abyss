---
id: TASK-70
title: 保护核心分支并打通一次批准的应急合并
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-26 09:57'
updated_date: '2026-10-27 15:04'
labels: []
dependencies: []
documentation:
  - docs/backlog-details/task-70.md
priority: medium
ordinal: 116000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
将核心分支保护整理为 GitHub 原生规则，避免失效检查和基础设施故障造成合并死锁；应急只接受 Owner 对指定 PR 与 HEAD 的明确批准。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 master 强制 PR 且核心分支禁止强推和删除
- [x] #2 develop 仅要求三个有效检查且不强制同步最新基线
- [x] #3 两个指定个人账号仅具有 PR 豁免且不改变成员角色
- [x] #4 隔离场景验证正常阻断、SHA 绑定与应急合并并保留证据
- [x] #5 记录轻量审批流程、身份验证限制和剩余风险
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 快照配置并先激活原生规则再移除旧保护。2. 隔离分支验证阻断和按 SHA 豁免。3. 将一次批准流程和证据写入现有协作文档，验证配置与文档一致性。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
三份原生Rulesets已激活，旧保护已无真空迁移；PR220隔离实测405/422/409和精确SHA成功。第二人保持Write但无该身份凭证，未冒称其合并实测。正在记录现有文档，普通文档PR仍等完整Quality。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
三份原生规则已生效；旧develop保护已移除。隔离PR220验证失败检查阻断、引用操作拒绝、错误SHA409及精确SHA的REST应急合并；master同规则无CI直接推送也被拒绝。仅CHNISam身份实测，第二人保持Write且User/PR-only配置读回；其真实身份调用未测，限制已记录。现有AGENTS/CI/工程文档和结构化证据已准备；文档PR仍走正常完整Quality，未以应急方式合入。
<!-- SECTION:FINAL_SUMMARY:END -->
