---
id: TASK-10.1.2
title: 卡牌多实例与长文案实机容量验收
status: To Do
assignee: []
created_date: '2026-10-22 21:55'
updated_date: '2026-10-22 22:45'
labels:
  - art validation
  - queued-after-M3
milestone: m-5
dependencies:
  - TASK-10.1.1
references:
  - docs/art/CARD_PRODUCTION.md
parent_task_id: TASK-10.1
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
主Agent在集成分支实际运行prepare-card-capacity.ps1，五项副本prepared同runId03a6a22c-83f2-4651-9506-a9fed8c1acac，MCP静态全部0错/0警告、底图SHA未变。VM从生成的build入口复跑通过。官方导入/实机/目标设备仍未测，AC2保持未勾。

用户2026-10-23明确要求本轮合并清理并结束，不再追加实机测试。样本交付和独立审查已完成；仅官方导入/运行时AC2未测，按M4留待后续，不阻塞本次交付收口。
<!-- SECTION:NOTES:END -->
