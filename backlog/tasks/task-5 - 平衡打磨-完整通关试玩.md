---
id: TASK-5
title: M5 同一Release Candidate完整回归与冻结验收
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-24 02:07'
due_date: '2026-10-29'
labels: []
milestone: m-6
dependencies:
  - TASK-17.3
  - TASK-12.5
  - TASK-17.2
  - TASK-47
  - TASK-12.4
  - TASK-13.1
  - TASK-13.1.2
  - TASK-14.1
  - TASK-15
  - TASK-16
  - TASK-16.1
  - TASK-4
priority: high
ordinal: 2
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
M5在M2正常通关、M3首发内容齐备和M4正式品质均有证据后，对同一Release Candidate进行最终回归与冻结。初代PC A0规则、数值、概率、AI与结算顺序贯穿相关任务，发现差异回归所属专项修复，不自行调平衡。10/29仅回归、必要修复及物料冻结，10/30人工投稿不因扩展延期。保留历史P0证据及In Progress状态，但不把旧候选拼接成当前RC通过。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 同一候选以原版数值从开局完成核实的17层第一幕、Boss后奖励和正式胜利结算，无脚本异常/卡死；记录种子/逐层资源/卡组/用时/日志录像，不用低HP夹具或调值通关。
- [ ] #2 失败、新局/平台重新挑战、同局跨节点状态与合法多构筑可复核；鼠标/触摸出牌、命中/受击/音效/停顿节奏按TASK-4/30原作观察清单实机验收。
- [ ] #3 逐项复验M2地图经济、M3卡牌/AI/Boss/遗物药水/算法对照账本，PASS/差异/待核实/平台限制分列；关键差异未闭合不声明严格一致性通过，问题退回所属任务修正，绝不重新平衡。
- [ ] #4 数据完成、独立原版预期自动测试、平台编译/副本导出、官方导入和千星实机分层报告，附SHA/hash/种子/日志和截图录像，不能互相替代。
- [ ] #5 10/29同一RC覆盖成功/失败、核心规则、交互、音画和稳定性，冻结SHA/hash及证据索引；发现必要修复后候选变更必须重验受影响路径，不拼接不同候选冒充通过。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
P0真实回归：用户使用v4原数值跑至第15层Boss后战败；摘要15/15、HP0/80、金币4、卡组14、遗物4，重新启程返回新局正常。尚非胜利通关，未提供完整逐层资源账本或本轮新日志，AC不勾选。暂停非必要美术扩量和研究，继续补Boss胜利及资源逐项回归。

2026-10-23规则规划不打断P0：旧15层到Boss失败仍为有效历史证据；M4严格验收排队，禁止从该失败反推应调平衡。
<!-- SECTION:NOTES:END -->
