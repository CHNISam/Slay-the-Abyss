---
id: TASK-98.1
title: 修复迁仓后的自动合并仓库身份校验
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 05:26'
updated_date: '2026-11-04 11:27'
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
- [x] #3 当前SHA独立复审、Required CI和合后实际身份有证据，未验证部分保持未完成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对仓库ID、最新develop、规则与开放PR并隔离工作树。2. 最小修复启用/暂停的规范路径与身份校验，不重写历史证据。3. 用迁仓、旧路径、身份缺失/不符及暂停负例回归，并跑原交付合同。4. 独立复审后报告，PR及CI另行验证。

PR510身份元数据、无witness旧Full与当前操作文档覆盖由PR508接续，避免同一工具切片重复基线验证；保留510原分支和提交，待508实际合入再关闭接续PR。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已核实固定ID与规则，修复canonical路由及暂停身份。Node24三组定向77/77、治理41/41、doctor/backlog/guidance与diff检查通过；新增迁仓夹具在旧源码复现25失败。独立只读复审通过并独立重跑77项。完整CI、当前最终SHA复审绑定与合后身份尚待验证，保持In Progress。

本切片由PR504接续：采用固定ID numeric canonical和head/base ID、sameAdmission、迁移witness；保留原PR506记录，补三个CLI入口及身份失败不写远端、旧review拒绝负例。组合83项通过；实际新HEAD CI仍在queued，AC3保持未完成。

本轮504原授权合后verify:delivery=merged_passed，真实PR Full41782457368、push Full41794339270与固定ID、实际squash父/tree、不可变收据均匹配。摘要docs/evidence/pr504-merged-delivery-20261104.json。核心迁仓AC已验收；510补充测试仍待当前SHA CI和正常合入，暂不将该补充宣称完成。

吸收PR510原6f0b873a及CRLF修复132a96c2：保留现有TASK98.1验收、In Progress及已核验AC3，新增44组身份零写入负例、无见证旧Full拒绝和操作文档LF/CRLF覆盖。PR510尚未接续关闭，当前整合HEAD独审与CI另验。

PR510的CRLF问题已先红后绿修复，当前接续保留原504迁仓验收及已勾选AC3；510新增覆盖的独立复审、精确整合HEAD完整CI与实际合入仍另行核验，不将历史验收扩大为新覆盖已交付。

510有效增益已完整随508最终675ce59f独审、107项定向和精确HEAD完整CI通过合入；PR Full41804489286及push Full41810232029、固定ID、实际squash父/tree和不可变收据核验merged_passed。510已接续完成关闭，原历史保留。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
固定仓库身份与迁仓覆盖由504/508完成接续；两轮实际合后merged_passed，510补充覆盖已落地并关闭，原授权/收据身份不改写。
<!-- SECTION:FINAL_SUMMARY:END -->
