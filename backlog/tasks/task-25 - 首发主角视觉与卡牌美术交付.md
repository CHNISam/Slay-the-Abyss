---
id: TASK-25
title: 完成首发角色和卡牌美术
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 15:58'
updated_date: '2026-10-26 16:30'
due_date: '2026-10-28'
labels:
  - art
  - launch
milestone: m-5
dependencies:
  - TASK-10.1
  - TASK-25.2
  - TASK-10.1.2
references:
  - docs/backlog-details/TASK-25.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/art/CARD_RUNTIME_PORT.md
  - docs/evidence/card-runtime-port-20261026.json
  - docs/evidence/card-live-20261027.json
type: task
ordinal: 27000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
沿用你批准的视觉方案，完成首发角色、卡图、卡背和必要图标。先确认一张高质量样卡，再考虑批量制作。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 角色和卡牌样张已交你审阅，素材来源和使用权限清楚。
- [ ] #2 首发实际可用的卡牌都有对应美术，缺的明确列出。
- [ ] #3 图片规格和导入方式可行，放进游戏后在目标设备上清楚可读。
- [ ] #4 先确认一张完整样卡的质量、性能和多卡显示，再决定是否批量做；没实测不能算通过。
- [ ] #5 本任务负责人完成肖像、卡图、共享卡框卡背和图标在正式战斗、牌库及节点卡面的装配；控件和内容绑定正确，无重复文字槽，保留生产占位清单及替换依据。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
按用户本轮要求，先对照固定原版卡牌装配和渲染流程迁移可复用结构：统一战斗、奖励、牌库和节点卡面的组件生成，保留现有主题和控件路径；卡图按卡牌ID绑定原生图库资源并保留明确占位降级。复用现有生成和导出工具，不导入外部图片，不重造导出器。先打通一张既有样卡的资源绑定和各屏装配，以回归及副本读回验证；不以此放行批量精修或实机品质验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮按固定原版按卡牌ID索引及共享卡面装配结构落地：新增共用卡面生成组件，战斗及奖励、牌库、节点复用；提取前后三棵完整原生控件树逐项一致。统一卡图解析先查真实卡牌ID，再走明确的牌型图标占位；战斗、牌库和真实商店节点绑定、缺图回退、拒绝外部图片路径的回归已通过。现有cleave登记仍标占位，不宣称精修插图或全卡美术完成。继续复用既有主题、ImageEditor稿和导出工具，不增加图片导入通道、不批产新卡图。26项布局及主题回归已通过，更多运行时专项和新副本读回在继续；实际观感、容量、设备和官方实机条款未勾。

本地卡牌装配移植与组合副本核对已完成，现已按用户明确授权推送草稿PR231。入口参数缺项也已修复。精修插图仍有占位，实机、容量和设备验收继续保留；完整结果见开发附件与组合证据。

新组合候选已在电脑真实首场战斗显示原生图标卡面、卡名、费用与说明，并取得本轮日志和脚本读回。只验这场战斗的基础显示，不把它当作精修美术、牌库商店、容量或手机通过，原验收保持。详情见卡牌装配移植记录。
<!-- SECTION:NOTES:END -->
