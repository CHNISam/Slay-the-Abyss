---
id: TASK-59.3
title: 完成正式开局和八种角色选择
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-28 06:32'
updated_date: '2026-10-28 08:14'
labels:
  - required implementation-gap
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/TASK-59.3.md
parent_task_id: TASK-59
priority: high
ordinal: 121000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
玩家从主菜单启程，选择四名原创角色或旅行者元素，查看真实初始信息后确认冒险；不再直接开局或播放旧序章。按固定原版源码独立实现，保留并行卡框、拖牌和战斗成果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 正式原生入口统一显示五名角色及旅行者四元素，选择时只更新详情与单选高亮，确认后仅创建一次正确的Run。
- [x] #2 返回、取消、重开、鼠标触摸与手柄输入隔离通过离线回归；默认不播放旧序章，Neow、地图及战斗兼容。
- [ ] #3 原生构建与现有必要门禁通过，最新develop同步后提交并合入PR；实机和设备未验收范围如实记录。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对319009d5七份原版源码及现有数据；复用职业适配构建只读选角信息和正式原生选择页；拆分选择/元素/确认并保留输入代次；补八形态和旧序章退役回归；同步PR267后跑门禁、构建、PR合入及清理。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已完成正式原生选择/确认分离，八形态真实初始数据、Neow、结果手势和故障恢复专项通过。Node24.18.0下逐行证明旧79475条渲染写入全部保留，新增1703条仅选择页、无Run菜单重绘与隐藏choicePanel；12项历史/负例/当前轨迹门禁通过，30秒原预算保留。Node22部分全量记录含两项不支持test-isolation参数的环境失败，未冒称完整通过。未启动子代理/OpenCode，未占用键鼠。完整CI、GIL读回及最终集成待完成。

完整Quality实际发现旧Start即建局断言和冻结原文绑定不兼容。已保留原哈希/全部断言/原预算，添加仅开局步骤的精确可逆迁移；7项定向门禁与3组28项重开旧输入回归通过。当前原生角色/元素按钮共12项通过。PR290持续收口，未将旧头失败冒称最新通过。

按用户最新明确要求停止扩项并尽快合入。已同步e46bd5dd，保留全部卡框/拖牌/战斗UI与正式campaign入口；解决5处冲突。组合原79689条原生写入全部保留，仅新增1703条，16项组合合同通过。原生启动生命周期单独通过；整组本地冒烟末段60秒超时保留，不放宽预算。此前GIL及221模块读回通过仅属于合流前版本；合流后未重新打包或实机。完整CI与最终合并记录随后以PR290为准。
<!-- SECTION:NOTES:END -->
