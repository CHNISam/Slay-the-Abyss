---
id: TASK-98.1
title: 修复仓库迁移后的自动合并入口身份校验
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 05:29'
updated_date: '2026-11-04 05:33'
labels: []
milestone: m-7
dependencies: []
parent_task_id: TASK-98
priority: medium
type: bug
ordinal: 141000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
仓库 ID 1429751262 已转至 FurinyaWorks；原启用与暂停入口仍固定旧名称，导致正常项目被识别为跨仓库。独立接续迁移适配，不接管 TASK-98 的真实 PR 验收或 TASK-99 的收据修复。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 启用和暂停入口从固定仓库 ID 解析当前名称，迁移后的同仓库 PR 可正常走原有门禁
- [ ] #2 错误仓库 ID、名称不一致、fork 和未知目标在远端写入前失败关闭
- [ ] #3 启用与暂停定向测试、独立复审通过；真实 PR 与完整 CI 分别记录，未完成项保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核实不可变仓库 ID 与实际目标，保留 fork 与来源拒绝。2. 先补迁移与错误身份负例，再统一启用和暂停 CLI 的规范名称解析。3. 定向验证与独立复审，提交独立 PR；当前 CI 与真实 PR 验收交由唯一协调者，未通过不合并。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
隔离基线 develop@67493f1。按固定仓库 ID 解析规范名称，启用与暂停先验证 ID/名称和同仓库 HEAD；不改 Ruleset，不接管 TASK-99。84 项授权/交付/Full/指引定向测试通过；CLI 使用跨平台进程拦截，独立只读复审通过，Windows 实际执行尚待托管 CI。真实只读 resolver 返回 FurinyaWorks/Slay-the-Abyss；#504 当前 BLOCKED、Auto-merge 未启用，不能宣称真实流程验收完成。
<!-- SECTION:NOTES:END -->
