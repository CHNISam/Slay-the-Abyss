---
id: TASK-88
title: 修复本轮合并后阻挡测试版的检查失败
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-30 11:45'
updated_date: '2026-10-30 12:05'
labels: []
dependencies: []
priority: medium
ordinal: 130000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
10月30日集中合并后，以当前develop真实CI定位并修复beta阻塞，保留旧失败证据。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 当前合并组合的必要CI全部成功
- [ ] #2 修复经独立复审并保留精确源码证据
- [ ] #3 明确候选构建与平台实测尚缺的证据
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.核对最新develop CI原始失败。2.修复已证明原因并运行专项检查。3.独立复审、提交PR并核对完整CI。4.交付beta候选及剩余实机项。

定位本地组合回归：保留原PR372/379证据，补精确分目标源码投影，不修改历史黄金；修复入口怪物开关从script字段误读为GetParam并补真实入口回归。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
基线ef7b3e80：Licenses 41048769101真实失败为catalog来源哈希滞后。审查38f4dd8a仅新增identityDirection说明，未改素材；归一化hash已校正。check-license及原有7项回归、Backlog与指引门禁通过。独立复审/root/review_beta_license通过；Quality 41048768667仍排队，不当作通过。

补充技术证据见docs/backlog-details/TASK-88.md。真实候选抓到入口直接读取script参数的UNKNOWN_API，已改GetParam并通过实际OnStart四边界回归。组合4项、架构/入口3项通过；feature7项逻辑通过，2项本机symlink EPERM未认证。独立复审指出的真实源码根及清理原子性缺口已修。此前完整回归仅作发现日志，最终SHA全量CI尚待。
<!-- SECTION:NOTES:END -->
