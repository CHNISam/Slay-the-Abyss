---
id: TASK-66
title: 完成原创角色查看与最终验收
status: Blocked
assignee:
  - Furinya
created_date: '2026-10-26 07:01'
updated_date: '2026-10-26 09:29'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies: []
ordinal: 113000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
补齐四位原创角色在卡组、商店与升级中的完整规则查看，并完成正常流程和生产回归。技术细节见 docs/backlog-details/task-66.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 四人完整卡池可通过正常流程获取、升级与战斗
- [ ] #2 完整效果可在卡组、商店和升级页面查看且不误触购买
- [ ] #3 生产回归与同候选实机证据分层记录
- [ ] #4 当前提交检查通过并按受控流程合入 develop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
复用已释放切片，补齐只读查看，验证获取与生命周期，冻结候选并受控合并。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
冻结生产源 a2ffb7f；118模块与两份UI清单逐文件hash记录candidate.json。数据/显示/运行时48项与1200逐卡轨迹通过，正常路径固定合法输入重放、隔离获取升级/移牌、600全文及真实Run公共药水/AR战内外边界通过。PC/物理手机/GIL与12流派完整实际关卡仍not_run。最终CI和远端develop合并继续推进，不将离线候选当实机。

四人真实UI按钮出E/回放/结束回合补测先红后绿。Windows全量揭示既有injury/vigor兼容错误，最终由TASK69统一承接必要修复与全部源码；本树将于干净发布头释放，实机缺项仍not_run。
<!-- SECTION:NOTES:END -->
