---
id: TASK-22
title: M0 轻量质量门禁：数据校验与自动测试 CI
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-22 14:01'
updated_date: '2026-10-22 14:14'
labels: []
milestone: m-1
dependencies: []
priority: high
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
当前无运行时代码和机械质量门禁，内容表正在另一会话编写。为 v0.1.0 建立最小无第三方依赖的数据契约与质量检查，不修改内容或重排既有任务。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 统一命令检查内容 ID、枚举、引用和整数数值范围，缺失或畸形数据失败退出
- [x] #2 自动测试覆盖有效样例与非法引用、重复 ID、非法数值负例
- [ ] #3 CI 有限并发运行检查与测试，失败阻止集成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 基于 data 草稿约定实现纯校验器与 CLI。2. Node 内置测试覆盖有效与无效输入、CLI 失败。3. 增加有限并发 CI 和语法检查，完整数据未集成时严格区分缺失失败与测试通过。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM 2026-10-22 子 Agent quality-gates；负责人 Furinya；分支 feat/sprint-quality-gates；worktree .worktrees/quality-gates；修改边界 scripts/ tests/ package.json .github/workflows/，禁止编辑 data/ 和其他任务。

实现 Node22 零依赖内容校验、32项内置测试、JS语法检查和限时5分钟/同分支取消旧运行的CI。验证：npm run check:syntax通过；npm test 32通过0失败0跳过；node scripts/validate-data.mjs ../content-baseline/data通过；git diff --check通过。当前worktree未包含data，npm run check预期在缺文件处失败；须先集成内容。CI实际运行与远端必需检查规则尚未验证，未勾选AC3。待独立审查，保持In Progress；未触及存档和GUI。

实现提交 d6eebfe；草稿PR https://github.com/CHNISam/Slay-the-Abyss/pull/1 ，base develop。等待独立审查及内容集成后的远端CI。

独立审查修复：rules.json纳入必需文件及全字段数值/枚举、15层地图和startingRelics引用校验；升级和效果字段白名单拒绝拼写错误；遭遇与敌人tier强制匹配。复验48测试全通过，syntax通过，content-baseline/data六份JSON校验通过。
<!-- SECTION:NOTES:END -->
