---
id: TASK-28
title: 清理已合并分支并收敛待合并PR
status: Done
assignee:
  - Furinya
created_date: '2026-10-22 21:29'
updated_date: '2026-10-22 21:39'
labels: []
dependencies: []
type: chore
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户指出约40个分支持续积压，增加集成和维护负担。核实PR、提交与工作区状态后清理已交付分支，保留未提交工作和未完成候选，并启用合并后的自动清理。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 已合并且未新增提交的远端分支清理完毕，保留可追溯审计
- [x] #2 本地可安全删除的分支和干净工作区已清理，未提交内容保留
- [x] #3 剩余PR已核对合并条件并记录处理结果，自动删分支已启用
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 保存分支、PR及工作区快照和bundle。2. 依据精确head及合入链清理已完成分支。3. 审查就绪PR并验证后合入develop，保留草稿和在途内容。4. 复核数量、未提交内容与自动删除设置。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23完成核验：清理前远端41分支，最终git ls-remote --heads为7：develop/master及5条草稿候选（PR25/26/27/30/37）。手工清理29条已交付历史分支；PR29/39在本轮由其他会话合入，来源分支自动删除；本会话审查并合入PR32/33/40，均在精确head双CI成功后squash，自动删分支生效。PR40将同会话清理分支和干净worktree写入AGENTS.md，保留旧CI分支唯一遗漏的TASK23收尾。
本地34→12分支，worktree30→11，保留主目录及6个子worktree的未提交工作，4个美术实验worktree继续对应草稿PR。主目录develop有既有未提交记录，仍停留旧提交，未强制切换或覆盖。
备份/审计：build/branch-cleanup/ 包含清理前完整bundle、整合后bundle、refs与PR/工作区快照、逐项处理计划及最终数量；两bundle验证通过。远端archive/cleanup-20261023/*标签保留33个已交付分支tip。本轮批量删除最初被自动审批拒绝，补充逐项验证的远端归档标签后重新审核通过，无历史丢弃。
PR33合并最新develop后的完整npm run check退出0：130JS（124pass/6权限skip）、139Lua通过、13Python（12pass/1权限skip）。PR32/33/40最新head双CI通过。最终gh repo view确认deleteBranchOnMerge=true。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
远端分支41→7，本地34→12，worktree30→11；完成已合并分支归档清理和PR32/33/40合入，保留5个草稿候选及所有未提交工作。自动删分支已开启，及时清理纪律已通过PR40写入AGENTS.md；Git引用、PR、工作区计数及备份完整性均已实查。
<!-- SECTION:FINAL_SUMMARY:END -->
