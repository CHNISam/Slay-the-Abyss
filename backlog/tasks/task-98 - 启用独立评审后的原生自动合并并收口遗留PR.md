---
id: TASK-98
title: 启用独立评审后的原生自动合并并收口遗留PR
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 02:34'
updated_date: '2026-11-04 02:49'
labels: []
milestone: m-7
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/496'
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/498'
priority: medium
type: chore
ordinal: 140000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner确认保留并启用PR496的自动合并目标，修复当前冲突、完整回归与准入边界；同时接续PR498设计稿并清理遗留分支。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 审查通过后可在完整CI未结束时启用原生Auto-merge，Fast或缺失失败取消的Full回归不能放行
- [ ] #2 新HEAD或过期基线不能沿用旧审查授权；暂停能真实取消Auto-merge并读回
- [ ] #3 当前精确HEAD完整CI、独立复审、Ruleset读回与真实PR自动合并演练有对应证据
- [ ] #4 PR496和498成果完成合并接续，旧PR及无新工作分支收口，未提交内容完整保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 接续PR496并补Full放行与严格基线、暂停合同。2. 定向负例和独立深审。3. 正常CI合入启用规则。4. 用PR498设计稿实测自动合并并核对合后Full与清理清单。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已重放PR496并修复冲突；Node24上64项授权/验收定向测试通过；新增Full发布器保留27作业、严格基线与显式pause。CI历史投影保留旧hash，当前仅余汇总命令提取适配，尚未远端启用。
<!-- SECTION:NOTES:END -->
