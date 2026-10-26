---
id: TASK-64
title: 接齐三钥匙真实获取与第四幕盾矛心脏
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-26 05:06'
updated_date: '2026-10-26 13:18'
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
priority: high
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26状态整理：PR213已合入终幕固定52至55地图与门边界，真实三钥匙获取、历史资格持久能力、盾矛/心脏机制及正式通关尚未完成，仍To Do。不得用测试构造的三钥匙视为正常获得。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-26原AC3按已合入且本轮通过的cross-act非法/缺钥匙门边界事务回归勾选；真实钥匙、历史持久资格、心脏机制及自然通关仍保留未勾。
<!-- SECTION:NOTES:END -->
