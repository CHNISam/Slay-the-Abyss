---
id: TASK-20
title: M6 投稿版本Tag、CHANGELOG与凭证归档
status: To Do
assignee: []
created_date: '2026-10-22 13:48'
updated_date: '2026-10-24 02:02'
due_date: '2026-10-30'
labels: []
milestone: m-0
dependencies:
  - TASK-6
ordinal: 20000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
首次真实发布打 v0.1.0 tag 并写简洁 CHANGELOG；tag 对应已验收提交，不与 milestone 一一绑定，不被 release-please 配置阻塞。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 v0.1.0 tag 打在已验收的发布提交上
- [ ] #2 CHANGELOG 简洁，遵循 Conventional Commits
- [ ] #3 不创建无意义的 Alpha/RC 中间版本
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
依docs/PUBLISHING.md：实际成功投稿之后再打已验收版本tag/CHANGELOG。M5以TASK-6成功凭证+本任务记录齐全收口。
<!-- SECTION:NOTES:END -->
