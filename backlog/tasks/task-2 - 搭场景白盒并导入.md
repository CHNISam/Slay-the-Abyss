---
id: TASK-2
title: M2 战斗场景白盒与镜头/出生点
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-23 12:40'
due_date: '2026-10-26'
labels: []
milestone: m-3
dependencies:
  - TASK-1
priority: high
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
搭建战斗场景白盒并锁定镜头与出生点，为卡牌战斗提供稳定的 3D 舞台。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 scene_build_blocks + scene_import_assets 导入成功
- [ ] #2 镜头 fixedView 锁死、出生点与复苏点已设、玩家数设为 1 到 1
- [ ] #3 阵营仅玩家与敌人敌对，己方单位不打自家物件
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-23 本轮执行：1. 只读核验61425e4已交付副本的镜头、出生/复苏、玩家数及阵营。2. 仅在独立scene-safe副本将镜头按既有规范锁至yaw0/pitch55、敌对仅1/3，并让复苏点引用已有出生预设点1073741825；保留Lua/UI/节点图、职业开关及复苏数值。3. 写前后读回并逐字节核对脚本/UI/图未变；不导入或操作GUI，原614首轮测试继续。4. 出生/复苏地形安全及实际镜头观感保留待实机，不据离线配置勾AC。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23 执行身份：Codex subagent /root/native_candidate，协调人为主Agent，任务负责人@Furinya。根与远端原assignee均为空，本轮按主Agent授权记录负责人；不覆盖其他任务或旧开发工作树。已从stdio MCP读取workflow/platform-rules，保持MILIASTRA_ALLOW_LIVE_WRITE=0。614原副本只读hash为af2e1060c40d1eb9e6f9f2a017384c2cd590bf1867178d2d829984da9ac8b5cc；1-1玩家已设，现镜头自由、三阵营互敌、无复苏点；原出生点(0,0,0)地形安全未测。

负责人更正：主Agent随后明确原负责人为空时不新增@Furinya，本轮执行负责人改记@Codex（scene代理/root/native_candidate）。此前notes中的@Furinya为已撤销的执行分配说明，不代表原始元数据。根任务保留原M2里程碑字段；最新develop文档中此最小配置属于M1关口，本轮不做旧任务迁移。

2026-10-23 配置副本已准备（未导入/未试玩）：.artifacts/live-acceptance-61425e4/scene-safe/abyss-scene-safe-61425e4-v2.gil，SHA256 2911ed9484cce2bd43d961a519da53f1eb5fb0cac1d60ef6f23ac6f8da4ddfad。源614原副本hash保持af2e1060c40d1eb9e6f9f2a017384c2cd590bf1867178d2d829984da9ac8b5cc。副本已读回fixedView yaw0/pitch55/ignoreCollision=true、只1与3敌对、复苏点1引用出生预设1073741825(0,0,0)，玩家1-1保持。32模块、UI、结算图及挂载逐byte不变；职业移动开关、出生位置/朝向与复苏数值不变。静态0error/17warning。首次审计发现MCP还同步更新player prefab复苏列表（section4），停止后扩展精确审计：section4/5仅复苏点列表改变，section11仅阵营/复苏列表、section18镜头；其余节原字节保留。完整证据scene-safe-evidence.json及preservation-readback.json。地形支撑/复苏安全/真实镜头观感未知，不勾AC；首轮用户仍测试原614，后续如导入派生副本须另记测试身份。
<!-- SECTION:NOTES:END -->
