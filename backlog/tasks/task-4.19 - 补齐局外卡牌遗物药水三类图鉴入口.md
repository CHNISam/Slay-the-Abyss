---
id: TASK-4.19
title: 补齐局外卡牌遗物药水三类图鉴入口
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-31 10:47'
updated_date: '2026-11-02 02:27'
labels: []
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLANNING-CONSOLIDATION-20261031.md
  - docs/backlog-details/STS1-DELTA-20261031.md
parent_task_id: TASK-4
priority: medium
type: feature
ordinal: 133000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR409确认局内查看已有，缺未开局的卡牌、遗物和药水目录入口。仅展示Production开放内容，不依赖跨局存档，不绑雷电下一版本。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 未创建Run可浏览当前公开卡牌及只读基础升级预览、遗物和药水中文详情。
- [ ] #2 不创建假Run、不发物品、不消费随机流、不公开未开放职业。
- [ ] #3 三入口可返回主菜单，电脑手机可操作；不扩成事件图鉴或收藏解锁。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-11-02 先实施独立非设计工程切片：局外只读卡牌/遗物/药水 catalog provider、Production 范围过滤与基础/升级预览数据；不创建假 Run、不消费随机流、不发放物品。由 dot 在独立云端目录实现和测试，本切片不含布局或动效。完整入口、返回主菜单及 PC/手机交互尚未验证，AC1/3 不勾完成；后续新增视觉/交互设计按 TASK-4.22 分层批准推进。
<!-- SECTION:PLAN:END -->
