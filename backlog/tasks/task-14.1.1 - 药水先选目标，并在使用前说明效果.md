---
id: TASK-14.1.1
title: 药水先选目标，并在使用前说明效果
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-24 17:09'
updated_date: '2026-10-27 15:04'
labels: []
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/POTION-TARGETING-20261025.md
parent_task_id: TASK-14.1
priority: medium
type: bug
ordinal: 92000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按2026-10-25研究包修复默认目标误用与使用前状态说明，复用既有帮助和触摸保护。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 目标药水先瞄准，明确选敌后才消耗；取消、失效和旧触点不误用。
- [x] #2 药水使用前有可发现的只读说明，卡牌与状态共用准确数值、时间和范围解释。
- [x] #3 红绿及完整本地检查通过，保持原版数值与职业池，证据分层交付。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
审计最新develop；先写瞄准与说明红测；最小修改UI并复用组件；定向与全量验证后记录证据提交。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
独立695d94d快照12组交互回归1过11败；最终定向12组全过，状态规则/说明10组全过。复用既有statusInfo与输入归属；新增显式目标策略与每槽说明入口。同步develop35fc111后全量JS1108过118跳过；Lua旧Shockwave文案断言需由层改为回合，定向2过，完整门禁重跑中。最终隔离候选48模块、0静态错误/32警告；尚未官方导入或实机，保持live write=0。

固定实现951c2bb，候选7d978a1独立读回48模块逐byte一致、2391控件/max59、UI/模板/结算图身份一致，读前读后hash不变。首两项仅按本地切片验收；完整门禁仍在复跑，第三项未勾，父任务与原神/手机验收不关闭。

最终npm run check退出0：JS1108过/118跳过、180个Lua文件全过、Python21过/1权限相关跳过。原型与展示文本一致性回归通过。源码哈希核对不变；完整日志、红绿证据、13场景零裁切离线预览和候选独立读回均已归档。未官方导入、实机、物理手机或verify:ui验收；32条静态警告原样保留。

负责人字段规范化：原记录 @codex 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
本地切片完成：目标药水先瞄准、选敌才耗瓶，失效/取消与旧触点不误用；药水说明与卡牌/状态共享准确数值、时间及适用范围。实现951c2bb通过完整本地门禁，候选48模块逐byte读回一致。证据见关联附件；父任务的原版全量与平台验收继续保留。
<!-- SECTION:FINAL_SUMMARY:END -->
