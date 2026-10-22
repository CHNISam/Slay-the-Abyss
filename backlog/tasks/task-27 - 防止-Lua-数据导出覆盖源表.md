---
id: TASK-27
title: 防止 Lua 数据导出覆盖源表
status: Done
assignee:
  - Furinya
created_date: '2026-10-22 15:43'
updated_date: '2026-10-22 16:19'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/5#issuecomment-6344069207'
priority: high
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已合并构建器允许将输出设为六表自身或文件别名，导致源数据被 Lua 文本覆盖。仅修复导出写入边界，不改数值或战斗机制。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 直接、相对、符号链接、硬链接指向任一源表时拒绝写入，六表字节不变
- [x] #2 正常新建和覆盖生成文件仍成功，原有数据测试不回退
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 独立复现 canonical 的 24 类别名覆盖。2. 写入前检查路径和文件身份，加入原生 Node 回归。3. 复验正常输出与原有测试，提交独立 PR 交接集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor=dot；基线047b7456；独立目录 slay-lua-export-fix-20261022。原TASK-8.1已Done，PR5由PR7替代，当前未见修复；不占用原作者分支。

本地验证：修复前25项保护测试24失败1通过；修复后25/25通过0跳过。联合原48项数据测试73/73通过0跳过；构建器2项无Lua依赖测试通过；syntax、validate:data通过；Python表现11/11通过。六表Git blob保持canonical原值。未发现可复用Fengari安装，未安装依赖；完整npm check及Lua执行待正式CI，不声称已通过。未做Windows、平台编译、存档写入、游戏验收。候选尚未发布/合并，保持In Progress。

独立评审通过：73项保护/数据测试、16项额外文件系统边界、2项无需Lua构建器测试、Python11项均通过；父级复跑73项和Python11项通过。只声明输入别名安全，不声明恶意并发竞态防护。完整Lua与Windows等待真实CI。

保持In Progress：当前仅本地候选及独立评审通过，正式CI、PR合并尚未完成；不能计作已交付。

实际交付：PR17已squash合入develop，merge986a1798f6e2d44197a1a0934dd324d957950573；最终head8da3978的CI39810872368/check及presentation成功。Windows完整Node79项：73通过、6symlink权限skip；Lua combat15/map10/run8/status26通过。Linux独立保护25项0skip补足别名验证。旧待CI说明为历史，现据真实运行收口；未做平台/存档/游戏验收。

2026-10-23 合并PR #19后发现与美术任务重号，经backlog doctor --fix --yes自动将源表保护任务由TASK-24改为TASK-27。美术任务及五处美术引用保留TASK-24；PR17历史编号不改写。保留PR21已验收的Done状态与交付证据。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PR17已合并，输入自覆盖缺陷修复。写前路径/realpath/dev+ino检查保护六表；25保护测试、独立边界测试及最新完整CI通过，Windows6项权限skip如实记录，Linux对应项已实跑。
<!-- SECTION:FINAL_SUMMARY:END -->
