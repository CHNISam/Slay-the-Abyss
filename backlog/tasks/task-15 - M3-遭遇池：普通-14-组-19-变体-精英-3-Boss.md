---
id: TASK-15
title: M3 遭遇池：普通 14 组 / 19 变体 / 精英 3 + Boss
status: To Do
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-23 02:00'
due_date: '2026-10-28'
labels:
  - queued-after-M2
milestone: m-4
dependencies:
  - TASK-11
  - TASK-14
ordinal: 15000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按原版第一幕遭遇池规模配置敌人，数值走基准表。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 普通遭遇 14 组、敌人变体 19 种、精英 3 种可随机出现
- [ ] #2 每个敌人意图与数值按基准表配置
- [ ] #3 精英战难度明显高于普通战
- [ ] #4 分别列数据已交付、本地逐种可执行、平台抽样与难度证据，附版本SHA和未支持效果清单
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 以 origin/develop 083d780 为基线复查 PR53 已有证据及敌人循环契约，避免重复逐意图测试。 2. 对照现有 SOURCES 中声明的原作机制差异，列清数据支持、运行支持与无一手来源的待核实项，不猜测数值。 3. 使用真实 Combat/Run、原生命与初始牌组做不出牌的确定性压力诊断，明确不能代替构筑难度或实机验收。 4. 提交可复跑诊断与审查报告，CLI 仅更新本任务计划/notes；保留全部平台验收与难度 AC。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23审计：PR2已有14普通遭遇/19变体/3精英/1Boss数据，PR29接入节点选取；不把数据存在当作全部敌人可战。剩余需逐种真实战斗/意图验证、随机覆盖与精英难度证据，保持To Do，M1结束前不抢跑。

2026-10-23 离线审查（基线 origin/develop 083d780）：docs/reviews/TASK-15-encounter-audit.md 与 scripts/audit-encounter-pressure.lua 已列23敌人/55意图/18遭遇、原表SHA256、PR53已有逐意图与256种子覆盖，以及明确声明的固定循环/无睡眠/无分裂/无偷金逃跑/自盾/虚弱替代眩晕/无Boss变形缺口。无一手原作依据不猜测补规则。真实Run入口、原80HP与初始牌组不出牌不喝药诊断：普通五小魔4敌方回合致死，nob/lagavulin/sentries为11/10/5回合，提示优先做同构筑实战比较，不能把tier/HP当精英难度通过。build:data、validate:data、check:syntax、18遭遇诊断退出0。仅增审查与工具，不改敌人/数值/卡牌；本轮未启动原神、MCP或写存档，未改状态/AC，平台抽样、原版逐敌核验与真实难度均保留。
<!-- SECTION:NOTES:END -->
