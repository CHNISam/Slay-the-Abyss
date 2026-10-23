---
id: TASK-11
title: M1 状态效果框架（力量/易伤/虚弱/中毒等）
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-22 13:47'
updated_date: '2026-10-23 12:34'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-8
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
状态效果的叠加、衰减与回合结算顺序。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 状态可叠加、可衰减、结算顺序明确
- [x] #2 至少覆盖力量、敏捷、易伤、虚弱、中毒、荆棘
- [x] #3 状态在战斗界面可见
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 绑定状态定义并以纯actor接口实现数据驱动叠加、衰减及UI快照。2. 补毒/再生/临时力量/壁垒/荆棘和死亡中止hooks。3. 真实Lua覆盖九状态、原子拒绝与死亡时序，完整npmcheck后独立审查。

2026-10-23 /root/statuses 离线复审：从当前 develop 隔离工作树，核对已合入状态规则与旧工作树未提交死亡时序补丁；先复现死亡敌人意图推进缺口，再补最小回归与修复；运行完整离线门禁。保留 @Furinya 负责人，AC3 仍待平台界面验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM quality-gates；branch feat/task-11-status-rules；worktree .worktrees/status-rules；仅src/lua/abyss_actor.lua、abyss_combat.lua必要hooks、tests/lua/statuses.lua；不碰effects/run/map/UI/CI。

实现九状态数据驱动stack/decay、Combat.statusView排序拷贝、Combat.addTemporaryStrength供TASK16调用及所有者end移除。actor绑定catalog.statuses，不共享跨战斗状态。毒先直伤后减层，致死无抽牌/意图；再生封顶后减层；壁垒不无限叠层；荆棘每段正攻击全挡/致死仍直反伤，不递归，攻击者死立即停止；双方同死defeat优先。原子拒绝未知/非法状态与溢出。验证npm run check退出0：54JS通过、15战斗Lua+23状态Lua通过、Python10通过1WinError1314环境skip；syntax/六表/build/gitdiffcheck通过。AC3未勾，UI实际屏幕验收待TASK10；未操作MCP/存档/游戏。等待主Agent独立审查，保持InProgress。

实现提交23a86521bc2c314e8c27310adba567bd1b8b6dca；PR https://github.com/CHNISam/Slay-the-Abyss/pull/12 base develop，等待主Agent独立审查，不合并/标Done。

独立审查发现并修复Fengari32bit整型乘百分比溢出：damage/block入口+0.0，block累加也显式float。原build/status-overflow-probe.lua已exit0；新增100000000基数弱化、2147483647经弱化易伤跨32bit、格挡modifier与累加跨32bit三回归。npmcheck退出0：54JS、15coreLua+26statusLua通过，Python10通过1环境skip。仍待root复审，不勾UI AC3。
<!-- SECTION:NOTES:END -->
