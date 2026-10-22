---
id: TASK-25.1
title: 首发卡牌框与图标制作（实机门槛后）
status: In Progress
assignee:
  - art-card
created_date: '2026-10-22 16:36'
updated_date: '2026-10-22 22:31'
labels:
  - art
  - launch
dependencies:
  - TASK-10.1.1
references:
  - docs/art/PIPELINE.md
  - docs/art/CARD_PRODUCTION.md
parent_task_id: TASK-25
type: task
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
电脑单卡原生图片/文字路线已实机通过（v2、透明短框高度40），先制作同结构的通用卡框/卡背/类型图标。完整可玩卡池批产及十张同屏/长文案/目标设备装配验收继续受限，不等待无关肖像/场景路线。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 只采用TASK-10.1已实机通过的卡框和原生文字流程；记录尺寸、控件预算、模板绑定和对照截图
- [ ] #2 按data/cards.json及已批准表现清单交付首轮卡框、卡背、图标；不改核心玩法或重复实现TASK-10控制器
- [ ] #3 独立feat分支与PR；离线检查和平台导入/真机证据分开；主Agent审查后集成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
干净art_card_production在独立feat/art-card-production分支仅交付4种稀有度框、1卡背和3类型图标；复用CARD_PRODUCTION与固定上游，不改核心UI/规则。框的文字槽不能在装配时叠加，主Agent复核控件预算和差异，再统一实机验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23：干净Session /root/art_card_production 已启动，独立worktree art-card-production；依赖TASK-10.1.1只批准电脑单卡制作配方，容量由TASK-10.1.2单独验收。

PR42共享小套已独立复审（39哈希、8上游导出逐字节一致）并集成；新资产组装/官方实机尚未执行。
<!-- SECTION:NOTES:END -->
