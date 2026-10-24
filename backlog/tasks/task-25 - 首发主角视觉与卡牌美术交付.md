---
id: TASK-25
title: 首发主角视觉与卡牌美术交付
status: To Do
assignee: []
created_date: '2026-10-22 15:58'
updated_date: '2026-10-24 02:02'
due_date: '2026-10-28'
labels:
  - art
  - launch
milestone: m-5
dependencies:
  - TASK-10.1
type: task
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
M4首发主角视觉与卡牌美术交付，追加卡牌美术精修并复用TASK-25.2，不新增任务。沿用PR #19、docs/design/UI_DESIGN.md及data/presentation/ui_theme.json，不重做视觉体系，不改战斗规则或数值。TASK-25.1已交付4框/1背/3类型徽记，保持Done并复用；TASK-25.2负责既有肖像/卡图候选及1张高质量样卡。TASK-24负责整体UI、TASK-10负责控制器、TASK-10.1.2负责多卡长文容量、TASK-4负责多设备，避免重复。TASK-3完整游戏冒烟通过后恢复美术制作；样卡验证可行后才评估批量。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 确定首发主角形象与卡牌视觉规范，交付可审阅样张并记录素材来源和使用权限，不搬运其他创作者资产
- [ ] #2 按首发实际可玩卡池清单交付卡图、卡背及所需主角视觉，文件命名与卡牌 ID 对应，缺口明确列出
- [ ] #3 依据 TASK-10.1 结论确认尺寸、透明度、容量和导入规格或降级方案；在 TASK-10 界面及 TASK-4 多设备验收中确认可读性，导出、导入、实机结果分别记录
- [ ] #4 批量前仅审阅1张高质量完整样卡；真实显示、相对基线性能、TASK-10.1.2容量和TASK-4设备证据支持放行，否则保留缺口与降级，不用离线导出冒充实机通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复用TASK-25.1交付和TASK-25.2/PR49候选，登记画质、来源、控件成本、兼容差异。
2. TASK-3通过后仅推进1张高质量完整样卡，优先cleave/星陨剑；同卡对比现有候选与低成本降级，不扩产。
3. 单样经视觉审阅、官方导入、真实显示及同底图性能比较通过后，结合TASK-10.1.2容量和TASK-4目标设备结果再决定批量；不通过保留原生图标/低图元占位及缺口。
4. 批量若放行，仅按当时data/cards.json实际可玩ID清单；来源、规格、预算及验证逐项可追溯。编译、写副本、官方导入、实机分别报告。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23 仅规划：远端develop已核实fcc1dca5d9b512f932e4122c025bf8d13cf25d5a；主工作树落后且有既有改动，未切换覆盖。CLI task list --search查重复用TASK-25/25.2；TASK-25.1保持Done。未制作美术、未操作游戏或合并PR49。

合并准备：已在最新develop 1b63afd隔离分支重放本轮CLI规划变更；不带入主工作树其他任务修改。

2026-10-24排期：美术并行，样卡/容量与实机质量门禁保持；不等待完整战斗父任务状态才开始可执行素材工作。
<!-- SECTION:NOTES:END -->
