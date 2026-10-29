---
id: TASK-87
title: 精简 Agent 指引并加入自动防回退检查
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-29 16:59'
updated_date: '2026-10-29 17:07'
labels: []
dependencies: []
documentation:
  - docs/AGENT_GUIDANCE.md
priority: medium
ordinal: 129000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
默认指引累积了重复规则、历史范围和操作细节，增加上下文负担；以现有工程门禁承接可验证要求。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 默认指引简洁，当前范围及必要安全边界仍可查到
- [x] #2 自动检查拦截指引膨胀、失效入口和适配器重复
- [ ] #3 当前提交 CI 通过并合入 develop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对现有指引和门禁，删除重复及过时叙述。2. 保留必要边界和按需入口，加入轻量防回退检查与负对照。3. 验证、PR、当前 SHA CI 成功后 squash 合入 develop 并清理。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已核对现有门禁，默认指引只保留入口及必要人工边界。AGENTS 34行/2308字符，CLAUDE 5行/150字符，Cursor 6行/82字符。新增门禁正反向5项通过，verify:backlog通过；技能校验通过（英文关键词启发式未识别已有中文工作树保护，2条warning已人工核对）。免费模型沿用TASK-51明确限额暂停，不探测额度，本轮由Codex直接执行。

本地全量npm check出现act2-intent-ui既有夹具30秒超时，已停止该次全量运行；在不改时限的单夹具复核中29.158秒通过，不能宣称本地全量通过。完整验收以PR348当前SHA的Quality/Licenses为准。审查补充Windows盘符及file URI越界负对照，专项仍5/5通过。
<!-- SECTION:NOTES:END -->
