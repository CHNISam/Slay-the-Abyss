---
id: TASK-7
title: M0 数值基准与内容清单（战士卡池/敌人/遗物/状态）
status: In Progress
assignee: []
created_date: '2026-10-22 13:46'
updated_date: '2026-10-22 14:08'
due_date: '2026-10-23'
labels: []
milestone: m-1
dependencies: []
priority: high
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
复用成熟公开规则与有来源的基础数值，先定内容清单再开发，不从零设计平衡。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 定稿战士卡池清单（首轮 30+ 张，完整对标 75 张）
- [ ] #2 定稿敌人清单：普通遭遇 14 组 / 19 变体 / 精英 3 种 / Boss 1 个
- [ ] #3 定稿遗物、药水、状态效果数值表
- [x] #4 数值以表驱动落地（JSON/常量表），改数值不改代码
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 保留现有 data 草稿，核实来源并补齐卡牌、敌人、遭遇、遗物和药水表。2. 校验引用与内容规模，独立审查草稿的规则歧义。3. 经 PR 集成后解锁 TASK-8。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM 2026-10-22 Codex Sprint Lead /root；负责人仍为 Furinya；计划分支 feat/task-7-content-baseline，独立 worktree .worktrees/content-baseline。保留既有 data 草稿；禁止同时编辑同一内容表，若其他会话仍在执行请在此追加交接记录。

2026-10-22 进展：data/README.md（表驱动约定）+ data/statuses.json（9 种状态）+ data/cards.json（战士 75 张，含 3 基础 + 20 普通 + 36 罕见 + 16 稀有 + 3 状态牌；费用/数值/稀有度/类型全部照搬 slaythespire.wiki.gg 官方列表，仅换中文名并保留 sts_name 溯源；cost_verify 列出 6 张费用待二次核对）。未完成：#2 敌人清单（14 组/19 变体/3 精英/1 Boss）、#3 遗物与药水数值表。
<!-- SECTION:NOTES:END -->
