---
id: TASK-13.1.1
title: M2 P0 未知房转类与六事件受限池离线闭环
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-23 15:54'
updated_date: '2026-10-27 15:04'
due_date: '2026-10-26'
labels:
  - p0
  - required
  - rule-parity
milestone: m-3
dependencies: []
parent_task_id: TASK-13.1
priority: medium
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户已确认首批交付六种完整事件的明确受限池；完整目录和抽选模型另测，其余事件依赖继续P0，不改变M1主冲刺。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 四类真实路由及独立持久随机流，拒绝重复不消费状态
- [x] #2 原版完整目录与三池资格抽选及去重可测试；用户批准的六种生产受限范围明确
- [x] #3 六事件完整选项及UI事务通过全量check，副本构建和源码读回有固定SHA及hash证据；官方导入和实机独立保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对来源，先红后绿；复用随机候选接真实入场与三池模型；实现六事件与UI；完整检查、候选构建、复核及CI后合并；实机和严格PC缺口独立留证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
用户已明确批准受限六事件首批；已实现真实四类路由，保留完整目录模型。来源8个blob已匹配；规则14组、UI29组、地图19组专项通过。全量首次失败为第14层遭遇数据缺口，已红绿修复；地图新增用例计数旧断言亦已更新。完整最终检查/构建/CI进行中，不勾平台或PC严格一致性。

最终本地npm run check exit0：JS747/629pass118skip，Lua91文件全过，Python17/16pass1skip。候选固定96b80a7，GIL 74e4da99bad6f1fe3c7dd699790c48ac7c1ede88d32b7d32d4631c8bc618ad96；35模块源码同源（1仅换行），1695控件max51，22节点完整载荷通过，static0error16warning。PR123当前CI排队等待在线busy runner，尚未合并；官方导入/平台/UI门禁未验。

按AGENTS将本地实现、平台验收与集成流程分层：本任务只关闭用户批准的离线六事件切片；Git当前SHA Quality全绿后squash合并仍为必须执行的PR门禁，不以任务Done代替。平台归TASK-12.3，完整池与PC核验归TASK-13.1.2。此刻远端check仍排队，未声称CI或合并通过。

最终集成更新：同步develop PR121/122/124后保留M1实机记录；4项旧超时断言失败复用PR125提交d8d3d1a修复（cherry-pick 02fa504，未改运行器政策）。验证头02fa504完整check exit0：JS755/637pass118skip、Lua92文件全过、Python17/16pass1skip。新游戏源ba1c2fa与02fa仅差测试文件；新GIL ee71a3a347960e954fae1316cca6cdba8978e3576666de2323c665446b0a12a7，35模块/1695控件max51/22节点完整载荷及static0error16warning通过。旧96仅保留历史；本候选未官方导入/实机，最终CI与merge看PR123。

负责人字段规范化：原记录 codex 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
用户批准的离线六事件受限池及真实未知房四类路由已完成；完整npm run check exit0（JS629pass118skip，Lua91文件全过，Python16pass1skip），候选96b80a7/74e4da99通过35模块、1695控件max51和22节点完整载荷读回。离线本地完成不代表平台或严格PC一致；集成以PR123最终SHA的Quality及实际合并记录为准。
<!-- SECTION:FINAL_SUMMARY:END -->
