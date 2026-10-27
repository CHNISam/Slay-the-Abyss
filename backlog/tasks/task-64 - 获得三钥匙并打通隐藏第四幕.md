---
id: TASK-64
title: 接齐三钥匙真实获取与第四幕盾矛心脏
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-26 05:06'
updated_date: '2026-10-27 06:10'
labels:
  - required
  - sts1
  - acts
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-62
references:
  - docs/rules/CROSS_ACT.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/backlog-details/BACKLOG-UPDATE-20261027.md
priority: medium
type: feature
ordinal: 109000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
隐藏第四幕早已纳入M3。已合入52营地→53商店→54盾矛→55心脏固定地图及资格/缺钥匙拒绝边界。剩余：真实三钥匙取得、历史资格持久化、盾矛与心脏完整机制、正式入口及四职业自然通关。边界测试构造钥匙不当作真实取得。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 三职业历史胜利资格与本局三钥匙都通过真实路径获得，营地和宝箱替代奖励正确且不重复领取
- [ ] #2 52营地、53商店、54盾矛精英、55心脏固定路径及完整特殊机制正确，心脏胜利后才进入真结局
- [x] #3 未满足资格或缺钥匙不能进入终幕，非法请求拒绝且不改变资源
- [ ] #4 四职业分别合法连续通关，持久资格的平台能力缺口单独记录，保留同源日志和截图
- [x] #5 终幕52至55固定地图及已有资格/三钥匙门的拒绝边界已合入PR213，并有本地事务回归。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-27继续保留真实资格阻塞：宝箱新多奖励蓝钥匙只牺牲关联基础遗物，金币/额外遗物独立；已有红钥匙不重做。跨局历史、燃烧精英及终幕自然完整链仍未认证，不用测试给定history当自然解锁。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26状态整理：PR213已合入终幕固定52至55地图与门边界，真实三钥匙获取、历史资格持久能力、盾矛/心脏机制及正式通关尚未完成，仍To Do。不得用测试构造的三钥匙视为正常获得。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-26原AC3按已合入且本轮通过的cross-act非法/缺钥匙门边界事务回归勾选；真实钥匙、历史持久资格、心脏机制及自然通关仍保留未勾。

接入Ruby Recall与Sapphire宝箱选择，沿用Nodes核心命令、来源令牌、真实永久牌/遗物后果及旧手势拒绝，兼容空所有者菜单与Start失败/重试。实现见src/lua/abyss_nodes.lua、abyss_node_ui.lua、abyss_run.lua；回归见tests/lua/ruby_recall.lua、ruby_recall_ui.lua、ruby_nested_refusal.lua、sapphire_treasure.lua、sapphire_treasure_ui.lua、m3_v2_keys_darkstone.lua及m3_current_owner_event_keys.lua。本地相关回归通过，完整Quality以PR当前提交检查状态为准。受控导航与钥匙资格不是自然获得证明；完整三钥匙隐藏结局、历史生产/持久化、全源池及原生四职业连续四幕仍待验收。 本轮基于最新develop增量整合，保留原版来源拖牌/持续选目标、共享卡面装配与卡牌ID美术接线；未引入新的同步反应结算。

2026-10-27合并状态更新：Ruby Recall、Sapphire宝箱选择及相关边界已随PR232合入develop fc51f1987130e398538e9663b736d66090dfdd07；精确接受HEAD为4a14598c8cd5284e210917bb7818d02c9100bf68，完整Quality 40441075319与Licenses 40441075355均成功，合并树与该HEAD相同。这不是三钥匙/终幕整体验收：剩余真实钥匙全路径、历史资格持久化、盾矛/心脏完整流程、完整来源池、官方平台和自然四职业连续四幕仍需完成；受控导航或测试构造钥匙不算自然取得。保留原状态、负责人、全部AC与历史，不标Done；后续输入整合须另跑新HEAD完整Quality。

2026-10-27最新边界：PR232已合入的Ruby Recall/Sapphire宝箱及钥匙核心/UI属于已交付代码；不能等同三钥匙自然取得、历史资格持久化或盾矛心脏完整实机通关。PR238同步fc51f198尚未提交，当前SHA完整CI不存在；四职业隐藏结局与同源平台日志截图仍缺，不新增勾选。
<!-- SECTION:NOTES:END -->
