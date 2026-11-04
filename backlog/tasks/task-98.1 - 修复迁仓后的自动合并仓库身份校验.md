---
id: TASK-98.1
title: 修复迁仓后的自动合并仓库身份校验
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 05:26'
updated_date: '2026-11-04 05:55'
labels: []
milestone: m-7
dependencies: []
references:
  - 'https://github.com/FurinyaWorks/Slay-the-Abyss/rules/25870651'
documentation:
  - docs/backlog-details/TASK-98.1.md
parent_task_id: TASK-98
priority: medium
type: bug
ordinal: 141000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
仓库ID1429751262已迁至FurinyaWorks/Slay-the-Abyss，启用和暂停入口仍写旧路径，导致合法PR被拒。只修仓库身份入口，不接管TASK-98其他交付或TASK-99收据继承。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 启用和暂停使用新规范仓库路径，并校验不可变仓库ID；旧路径、异仓和缺失身份继续拒绝
- [x] #2 既有严格基线、独立评审、Full回归与失败撤销门禁保留，迁仓正负例及原合同定向测试通过
- [ ] #3 当前SHA独立复审、Required CI和合后实际身份有证据，未验证部分保持未完成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对仓库ID、最新develop、规则与开放PR并隔离工作树。2. 最小修复启用/暂停的规范路径与身份校验，不重写历史证据。3. 用迁仓、旧路径、身份缺失/不符及暂停负例回归，并跑原交付合同。4. 独立复审后报告，PR及CI另行验证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已核实固定ID与规则，修复canonical路由及暂停身份。Node24三组定向77/77、治理41/41、doctor/backlog/guidance与diff检查通过；新增迁仓夹具在旧源码复现25失败。独立只读复审通过并独立重跑77项。完整CI、当前最终SHA复审绑定与合后身份尚待验证，保持In Progress。

本切片由PR504接续：采用固定ID numeric canonical和head/base ID、sameAdmission、迁移witness；保留原PR506记录，补三个CLI入口及身份失败不写远端、旧review拒绝负例。组合83项通过；实际新HEAD CI仍在queued，AC3保持未完成。
<!-- SECTION:NOTES:END -->
