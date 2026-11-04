---
id: TASK-98
title: 启用独立评审后的原生自动合并并收口遗留PR
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 02:34'
updated_date: '2026-11-04 03:42'
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

独立深审已修旧run写状态覆盖、master适用范围及真实GitHub合后空PR关联三项问题，并补同run attempt下界。Node24授权/交付/Full发布器70项全过，另CI汇总历史合同3项通过；schema2/3原验证保持。

PR502首轮Windows第6片：Sapphire冻结21组中15-21片在原30秒总预算内超时，已按15-18/19-21重新分片，冻结正文hash和所有21组不变。另按gh2.96官方源码核验，pending路径改为显式GraphQL enablePullRequestAutoMerge，避免--auto在CLEAN/UNSTABLE时改走直合。新路由21项、原生请求/分片32项通过，完整Sapphire预算实测在途。

Sapphire全部21组本轮7+4项合同回放通过；分片3/5原始入口8596/6105ms。卡牌全部11组分为1-3/4/5-8/9-11，原body hash与30秒不变；原始入口6909/7565/14159/9583ms通过。路由/源合同93项通过。所有auto请求显式enable；CLEAN兜底须fresh Full、原生六项、inventory Actions最新run/attempt/HEAD再验证，71项相关合同通过。
<!-- SECTION:NOTES:END -->
