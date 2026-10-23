---
id: TASK-10.1.2
title: 卡牌多实例与长文案实机容量验收
status: To Do
assignee: []
created_date: '2026-10-22 21:55'
updated_date: '2026-10-22 22:50'
labels:
  - art validation
  - queued-after-M3
milestone: m-5
dependencies:
  - TASK-10.1.1
references:
  - docs/art/CARD_PRODUCTION.md
parent_task_id: TASK-10.1
priority: low
type: spike
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已完成电脑单卡显示与点击，仍缺少相同底图基线、多卡和正式长文案的容量证据；先提供少量独立验收样本，避免未经验证扩大全卡池。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 交付固定上游与已通过40高原生文字路线的基线及1/5/10卡、长文案样本，记录实际控件总数与独立容器布局
- [ ] #2 主Agent分别记录官方导入、试玩显示、点击、10秒dt及重复进入退出；无实机结果的格子保持未测，不能用离线检查冒充
- [x] #3 独立分支PR和复现步骤可审查，不重写战斗控制器或导出器；手机主机另测
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
干净UI Agent复用CARD_PRODUCTION与原上游导出制备独立小样；主Agent审查后绑定副本并组织一轮实机验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23：干净Session art_ui_capacity PR43（d06b79b+13e68d1）交付0/1/5/10卡和42字长文独立样本；独立复审发现旧成功索引失效P2并已修正，三路失败注入通过。主Agent正调用实际MCP准备副本；运行时仍未测。

2026-10-23 用户P0指令：暂停独立卡牌小样，优先完整游戏集成冒烟；保留既有产物，不将卡牌实验当成正式可玩游戏。

主Agent实际运行五份容量副本准备，底图SHA保持2f2248a3...，同runId03a6a22c-83f2-4651-9506-a9fed8c1acac，MCP静态全部0错0警告。验收短路径位于art-pipeline/build/art-acceptance。官方导入/试玩仍未测，AC2保持未勾。

用户要求本轮合并清理并结束。已交付样本和复审通过统一PR30合入develop ecb69b8，子PR43关闭；实际多卡/长文/设备官方试玩未做，AC2保持未勾，不追加测试。
<!-- SECTION:NOTES:END -->
