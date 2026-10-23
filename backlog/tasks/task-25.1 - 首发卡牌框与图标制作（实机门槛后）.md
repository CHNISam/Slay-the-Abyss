---
id: TASK-25.1
title: 首发卡牌框与图标制作（实机门槛后）
status: Done
assignee:
  - art-card
created_date: '2026-10-22 16:36'
updated_date: '2026-10-22 22:50'
labels:
  - art
  - launch
dependencies:
  - TASK-10.1.1
references:
  - docs/art/PIPELINE.md
parent_task_id: TASK-25
priority: low
type: task
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
电脑单卡原生图片/文字路线已实机通过（v2、透明短框高度40），先制作同结构的通用卡框/卡背/类型图标。完整可玩卡池批产及十张同屏/长文案/目标设备装配验收继续受限，不等待无关肖像/场景路线。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 只采用TASK-10.1已实机通过的卡框和原生文字流程；记录尺寸、控件预算、模板绑定和对照截图
- [x] #2 按data/cards.json及已批准表现清单交付首轮卡框、卡背、图标；不改核心玩法或重复实现TASK-10控制器
- [x] #3 独立feat分支与PR；离线检查和平台导入/真机证据分开；主Agent审查后集成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
干净art_card_production在独立feat/art-card-production分支交付4种稀有度框、1卡背和3类型徽记，PR42；只复用固定上游与已验证单卡参数。框含4空文字槽，不能重复叠加。主Agent独立复审并集成，组装后官方实机另验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM：已验证单卡门槛单独完成，待启动干净art-card-production Session；不得把此依赖调整视为十卡/手机性能或全卡池批产通过。

2026-10-23：PR42 commit24dc524已交付；独立只读复审无P1/P2，8份上游重导出逐字节一致、39项哈希匹配，空文字槽h40保留。主Agent已纳入PR30集成分支；新资产尚未实机，维持InProgress。

2026-10-23 P0：暂停非必要美术扩量，保留既有交付。资源优先完整游戏冒烟，TASK-3通过后再恢复。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
首轮4稀有度卡框、1卡背、3类型徽记交付并经主Agent复审，统一由PR30 squash合入develop ecb69b8。39项哈希和8份固定上游Lua重导出匹配；原生文字槽、尺寸、预算、来源及降级已记录。电脑单卡配方已实机验证；新组合、多卡及目标设备实测保留在既有验收任务，不冒充完成。
<!-- SECTION:FINAL_SUMMARY:END -->
