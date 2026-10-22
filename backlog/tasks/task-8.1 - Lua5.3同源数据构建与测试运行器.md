---
id: TASK-8.1
title: Lua5.3同源数据构建与测试运行器
status: Done
assignee:
  - Furinya
created_date: '2026-10-22 14:33'
updated_date: '2026-10-22 15:23'
labels: []
dependencies: []
parent_task_id: TASK-8
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
战斗核心直接使用平台Lua53，离线验证必须执行同一源码，避免JS和Lua双份规则漂移。只做数据转码与测试运行，不实现战斗规则。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 JSON六表确定性生成Lua模块，失败输入不可构建
- [x] #2 使用成熟Lua5.3运行器执行真实生产Lua模块的测试并接入有限时CI
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 六表先经validateContent校验再确定性转码Lua模块。2. Fengari成熟Lua53运行器执行同源生产模块与有限超时，补转义/负例/roundtrip测试。3. 与质量门禁集成、独立PR待主Agent审查。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM 子Agent quality-gates；负责人Furinya；分支feat/task-8-1-lua-harness；worktree .worktrees/lua-harness；修改仅构建/运行器/对应JS测试/package/CI/gitignore，不修改src/lua和tests/lua/combat.lua。

已实现构建器、Lua运行器及JS测试初稿；node --check三份源码通过。尚未安装依赖或宣称测试通过，等待PR1进入develop后合入最终package配置。

验证：53项JS测试通过0失败0跳过；build:data、syntax、六表校验通过；跨combat-core工作区只读执行同一src/lua生产模块与tests/lua/combat.lua，15项Lua测试通过。发现并修复fengari-node-cli位置参数脚本抛错仍exit0，改用-e dofile路径并验证运行/语法/缺文件错误均非零，200ms无限循环被终止。CI接入npm ci --ignore-scripts和完整check，依赖生产Lua集成后远端复验，AC2暂留。dev依赖fengari-node-cli@0.1.0锁定；npm audit同一sprintf-js格式化精度DoS链3 moderate，暂无上游可用修复，离线测试限制15s/1MB。无游戏验证。

实现提交5c5c7f4；草稿PR https://github.com/CHNISam/Slay-the-Abyss/pull/5 base develop，待主Agent独立审查与生产Lua集成后的完整门禁。

主Agent独立审查构建/runner及退出码负例，并在combat-core完整集成复验：53JS+15Lua全通过。PR7 Actions run39802353979/check通过10秒，CI包含真实生产Lua及表现Python门禁；PR5将由整体PR7替代后关闭，未单独合入缺生产源码的分支。

最终集成补充：默认自动发现tests/lua/*.lua并按序串行，空/缺目录或首错均非零，新增suite负例，JS总54通过；专用runner合入后Windows check:rules先npmciignore-scripts，Python独立Ubuntu presentation，本地check串联两者。未参与实现的Agent已独立审查并复跑54JS+15Lua+Python10通过1环境skip，无阻断。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
六表确定性生成Lua模块并使用锁定Fengari执行同一生产Lua；错误/语法/缺文件/超时非零回归通过。整体PR7本地和远端CI通过；仅离线规则验收。
<!-- SECTION:FINAL_SUMMARY:END -->
