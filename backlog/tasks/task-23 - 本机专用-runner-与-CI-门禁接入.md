---
id: TASK-23
title: 本机专用 runner 与 CI 门禁接入
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 14:36'
updated_date: '2026-10-22 14:38'
labels: []
dependencies: []
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户要求本机为 Slay-the-Abyss 独立运行 GitHub Actions，并让测试与代码规范持续执行。现有 PR #1 提供待整合的数据门禁，其他项目 runner 必须保持独立。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 专用 Windows 服务自动启动且 GitHub runner 在线
- [ ] #2 PR 与 develop/master 推送执行语法、测试、数据校验并实跑成功
- [ ] #3 记录维护命令、分支门禁与发布边界
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.复用并核查 PR #1 门禁。2.独立安装和注册专用 runner。3.接入 Actions 并实跑。4.文档和 PR 交付。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
复用 PR #1 的零依赖门禁，48/48 测试和完整内容验证本地通过；专用 runner 官方安装包正在下载并将校验 SHA256。GitHub API 返回 403：私有仓库当前套餐不支持分支保护，未将仓库公开或更改套餐。
<!-- SECTION:NOTES:END -->
