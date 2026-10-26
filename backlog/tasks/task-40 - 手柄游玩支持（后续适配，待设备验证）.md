---
id: TASK-40
title: 补上手柄操作，复用平台导航与成熟交互
status: In Progress
assignee:
  - '@codex'
created_date: '2026-10-23 12:24'
updated_date: '2026-10-26 15:10'
labels: []
dependencies: []
references:
  - TASK-4
  - docs/design/UI_DESIGN.md
  - docs/backlog-details/TASK-40.md
priority: high
type: feature
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
提前安排手柄适配，不再等设备齐备才开始。复用平台原生导航与初代成熟交互，覆盖战斗、地图和各类房间。本轮完成源码与离线验证，真实手柄及平台导入验收单独保留，未实测前不宣传完整支持。来源、移植对应与测试见 docs/backlog-details/TASK-40.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 确认平台支持哪些手柄操作，约定按键、焦点切换和提示。
- [ ] #2 手柄能完成出牌、选目标、确认取消、结束回合、地图和各类房间，不会卡住焦点。
- [ ] #3 用真实手柄完整玩过；没有设备时明确写未验证，不能说已经支持。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
执行用户批准的方案1：核对初代固定反编译镜像和官方导航API，接入当前页面确认取消、焦点恢复、弹窗隔离及提示；复用现有命令，补关键离线回归。完整检查及功能PR后保留平台导入和真实设备验收，不以离线结果替代。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26 用户提高优先级并批准方案1，追加要求核对初代反编译手柄代码。已完成原生Focus/Confirm/Cancel绑定、牌行循环、瞄准取消回牌、各房间操作、弹窗隔离和手柄牌库分页。来源及hash见附件。专项回归已通过；完整check正在执行。没有设备，不占用鼠标键盘；平台导入和实机AC不勾选。本轮Codex串行交付，免费模型仍无额度恢复依据，未发送新委派请求。

阶段验证：全量Node发现1557项，1435通过、119跳过、3失败；两处缺少当前锁文件依赖及未启用手柄时误读父控件的问题已修复，三个失败文件重跑4项全部通过。架构115模块/554边通过；Luacheck新增诊断0，原113条仅逐行迁移；四项关键语义变异均由原断言捕获。手柄专项、房间、序章和强制选牌回归通过。全部Lua及表现层检查继续执行，最终以原始日志和PR当前SHA为准。
<!-- SECTION:NOTES:END -->
