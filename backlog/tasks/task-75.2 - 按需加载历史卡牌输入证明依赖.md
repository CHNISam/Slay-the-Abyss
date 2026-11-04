---
id: TASK-75.2
title: 按需加载历史卡牌输入证明依赖
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 20:41'
updated_date: '2026-11-04 20:41'
labels: []
milestone: m-7
dependencies: []
references:
  - docs/SPRINT_EXECUTION.md
parent_task_id: TASK-75
priority: medium
type: enhancement
ordinal: 154000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
普通Lua测试导入会预读并解析仅三个历史手势夹具使用的大型证明链；移除无关启动成本，保留真实历史入口每次新鲜身份验证和原runner合同。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 普通冷暖导入与非历史夹具不加载历史重证明，公开同步API和原runner预算失败传播保持
- [ ] #2 三个历史入口、外部cwd、注入reader、缺失篡改及首次成功后源码漂移均按原合同验证并有真实负例
- [ ] #3 同环境前后启动成本及完整覆盖有证据，独立复审、精确HEAD及合后完整CI通过
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.测量并固定普通导入的历史证明读取开销。2.仅将重证明依赖加载移到原exact fixture/root guard内，保持同步API与call-local reader。3.冷暖轻入口、全部真实历史入口、缺失篡改和关联源漂移回归及前后计时。4.独立复审，完整文件集合与精确HEAD及合后CI。
<!-- SECTION:PLAN:END -->
