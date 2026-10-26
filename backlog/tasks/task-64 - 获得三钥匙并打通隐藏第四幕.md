---
id: TASK-64
title: 获得三钥匙并打通隐藏第四幕
status: To Do
assignee:
  - '@Furinya'
created_date: '2026-10-26 05:06'
labels:
  - required
  - sts1
  - acts
milestone: m-4
dependencies:
  - TASK-62
references:
  - docs/rules/CROSS_ACT.md
priority: high
type: feature
ordinal: 109000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户已将隐藏第四幕明确纳入M3。实现原版历史资格、本局三钥匙及终幕，不以自动解锁或调试跳关代替真实路径。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 三职业历史胜利资格与本局三钥匙都通过真实路径获得，营地和宝箱替代奖励正确且不重复领取
- [ ] #2 52营地、53商店、54盾矛精英、55心脏固定路径及完整特殊机制正确，心脏胜利后才进入真结局
- [ ] #3 未满足资格或缺钥匙不能进入终幕，非法请求拒绝且不改变资源
- [ ] #4 四职业分别合法连续通关，持久资格的平台能力缺口单独记录，保留同源日志和截图
<!-- AC:END -->
