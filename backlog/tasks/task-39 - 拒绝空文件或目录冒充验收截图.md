---
id: TASK-39
title: 检查验收截图是不是真图片
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 12:55'
updated_date: '2026-10-24 03:15'
due_date: '2026-10-29'
labels: []
milestone: m-6
dependencies: []
references:
  - scripts/verify-ui-acceptance.mjs
  - docs/design/ui-acceptance.json
  - docs/backlog-details/TASK-39.md
priority: high
type: bug
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
避免把空文件、文件夹或不存在的路径误当成游戏截图，导致没验过也显示通过。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 只有实际存在、非空的图片文件才能使用；空文件、文件夹和坏路径要报错。
- [ ] #2 正常截图仍能使用，原来的检查项保留；有错误时不能显示通过。
- [ ] #3 用真实文件测试这些错误情况，检查通过；不改变其他任务的完成状态。
<!-- AC:END -->
