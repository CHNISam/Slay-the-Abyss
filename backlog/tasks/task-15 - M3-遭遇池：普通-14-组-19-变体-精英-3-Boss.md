---
id: TASK-15
title: M3 遭遇池：普通 14 组 / 19 变体 / 精英 3 + Boss
status: In Progress
assignee:
  - '@codex-enemy-parity'
created_date: '2026-10-22 13:47'
updated_date: '2026-10-23 08:24'
due_date: '2026-10-28'
labels: []
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
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-23 独立切片 codex-enemy-parity（feat/continue-enemy-parity）：固定社区源码核查 Gremlin Nob A0 与 AngerPower；先写真正 Combat 入口红测，再实现 HP82–86、首动 Enrage2、33边界攻击/易伤与连续限制；沿 EnemyAI 现有钩子接技能反应，验证schema与集成回归。不碰 Combat/Inventory，不开游戏或 live MCP；全池和平台AC保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
执行者 codex-enemy-parity，基线52f35dd。已读 HANDOFF/SCOPE/TOOLCHAIN/SOURCES；本切片不声称满足仍未完成的严格数值/平台依赖。固定镜像非官方源码或原作PC实测。

2026-10-23 codex-enemy-parity 离线切片：固定 aeubanks/sts@319009d 源码镜像核查并独立实现 Gremlin Nob A0：HP82–86、开场Enrage2、技能效果前力量、Skull Bash6后易伤2、BullRush14、33边界与Rush禁三连。专项12组先红11后全绿，900组受控映射；10组schema/原生打包校验。完整npm run check结束：JS594项479通过115既有条件跳过0失败；全Lua与Python16项（1权限skip）通过。证据见docs/reviews/TASK-15-gremlin-nob-ai.md。未改Combat/Inventory，无游戏/MCP/平台编译/副本导出/实机；共享LCG、PC构建真实性、全池与精英难度AC继续保留。
<!-- SECTION:NOTES:END -->
