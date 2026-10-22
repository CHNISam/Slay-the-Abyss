---
id: TASK-27.1
title: M1 修复Lua导出器实际路径输入保护
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-22 23:18'
updated_date: '2026-10-22 23:23'
labels: []
milestone: m-2
dependencies: []
parent_task_id: TASK-27
priority: high
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
主题导出器未使用已交付的数据导出保护，输出可别名指向主题或六表。1217abb临时副本21个direct/symlink/hardlink负例全部静默覆盖。仅修主题构建写入边界，不改布局、数值或平台文件。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 主题与数据两个Lua导出器拒绝任何输入的直接、相对、软硬链接及软链父级遍历输出别名，写前拦截且所有输入字节不变
- [x] #2 正常新建、覆盖及不指向输入的软硬链接/父级遍历输出仍成功，生成字节和既有测试不回退
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 真实文件系统TDD覆盖两个构建器的路径别名、软硬链接与软链父级遍历。2. 按实际读写路径检查native realpath及dev/ino，不用lexical equality误判。3. 验证正常输出字节、保护回归、独立评审及完整check，等待正式CI与合并。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor dot；隔离workspace slay-available-m1-task-20261023；基线1217abb；父级核对最小范围，远端集成由父级处理。

TDD红灯38项：35失败、3正常输出通过；修复后38/38通过0skip，七输入每次均逐字节检查未变。增加目录软链别名，以及正常非输入输出软/硬链接可写。实现只变scripts/build-ui-theme.mjs和新增保护测试，无共享布局/数据改动。完整npm run check实际尝试，Fengari缺失导致相关Lua调用失败；不声明完整门禁或平台验收通过。

独立评审发现首版遗漏目录软链后接/..的内核路径语义，已补8项真实文件系统回归：首版46项40通过6失败，修复后46/46通过。output和theme输入按原样stat及native realpath；六表按loadContent的resolve路径匹配。不声明恶意并发竞态防护。旧38项证据为首版历史，以本次46项为准。

独立评审进一步复现buildLuaData同源父级软链遍历漏洞，父级批准同一任务最小扩展两个导出器。另移除纯字符串resolve相等的误拒绝，判断以实际文件身份为准；不改序列化/数值。

最终验证：新增路径语义8项修前全部失败，修后作者保护79/79、联合数据156/156通过0skip；独立评审主题49/49与数据41/41通过，两次评审阻塞均关闭。npm run check实际184项177通过7因缺Fengari失败，不报完整门禁通过。syntax、build:ui、build:theme、validate:data及Python13项通过；系统Lua5.4加载生成主题通过。生成数据与1217abb字节一致SHA256 9cc0aaf4285a2210ce7478295add82c2e3c0f76dd3c0602a2479dc504f2a996b；主题一致e4401da8b3e165896d90cbbe465b491c73518de2e6ab00d7e763798ec49550af。AC按本地真实证据及独立评审勾选，保持In Progress等待正式CI与真实合并；未执行Windows/官方平台/存档/游戏验收。
<!-- SECTION:NOTES:END -->
