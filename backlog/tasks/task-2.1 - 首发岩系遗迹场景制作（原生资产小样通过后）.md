---
id: TASK-2.1
title: 制作首发岩系遗迹场景
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-22 16:37'
updated_date: '2026-10-27 04:15'
due_date: '2026-10-28'
labels:
  - art
  - launch
milestone: m-5
dependencies: []
references:
  - docs/art/scene-spike/README.md
  - docs/backlog-details/TASK-2.1.md
  - docs/backlog-details/TASK-4.2.md
  - docs/DELIVERY-CLOSEOUT.md
parent_task_id: TASK-2
priority: medium
type: task
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用官方可用的模型制作正式场景。先验证一个小样在游戏里能用，再做完整布景。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 先把单个建筑和7件景片放进游戏，确认位置、固定镜头和性能正常。
- [ ] #2 完整场景里角色站位、脚下高度、碰撞和安全区域正确，画面符合已定方案。
- [ ] #3 分批导入并留截图，不重复堆放资产，也不覆盖原来的正式存档。
- [ ] #4 由本任务负责人把验证合格的景片接入完整游戏测试副本，读回实体并交TASK-4.2验收；未接入和未显示分别记录原因、解除条件与下一动作。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
使用PR208的41档同副本样板比较纯2D、2.5D和原生3D；保持已批准视觉方向，离线/官方导入/PC/手机证据分开。只有新一轮明确键鼠窗口内才做客户端操作；正式装配与完整UI验收仍按原AC逐项完成。

2026-10-26 离线校验切片：在独立分支 feat/dot-scene-validator 中复用已审查的景片输入校验器，只调整 scripts/art/verify-scene-spike.py、tests/art/test_scene_spike.py、tests/art/__init__.py 与 docs/art/scene-spike/README.md；核对现有六份 JSON 的输入身份，执行定向回归与现有递归发现检查。完整 Quality 与官方导入、实体读回及同版本实机验收继续分别保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26：基于 develop 4c75a31 的离线景片校验切片，六份现有 JSON 身份核对及实际输入预检通过；直接运行 24 项定向测试通过，仓库现有递归发现入口也执行同一组 24 项并通过（不是 48 个独立用例）。新增 tests/art/__init__.py 保证递归发现；README 明确目录尺寸与 yaw 包围盒只用于离线预检。没有修改模型、场景输入、GIA、游戏规则或正式存档。当前提交的完整 Quality 尚待执行，官方导入、真实 GUID、碰撞、脚高、画面及性能仍未验证；本次不勾选任务 AC。拟以 feat/dot-scene-validator 独立 Draft PR 交付。
<!-- SECTION:NOTES:END -->
