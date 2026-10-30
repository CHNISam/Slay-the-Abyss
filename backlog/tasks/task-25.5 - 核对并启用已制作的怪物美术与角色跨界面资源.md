---
id: TASK-25.5
title: 核对并启用已制作的怪物美术与角色跨界面资源
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-30 21:58'
updated_date: '2026-10-30 22:53'
labels:
  - playtest-20261030
  - p1
  - gpt
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
parent_task_id: TASK-25
priority: medium
type: task
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner说明：**怪物自制美术目前在实际战斗中一点也没用起来**；旅行者自制美术**已经用于战斗**，但选角页、开局七天神像事件未正确体现。应区分这三件事实，不写笼统「自制美术未启用」。当前候选美术开关缺省关闭，只有开发/发布人员能指定，需与现有性能/资产准入合同一致。GROK负责界面呈现协作。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 已有且获准的自制怪物美术在指定候选中得到真实绑定和展示，尚缺的明确列出；不把官方图库回退当作自制素材。
- [ ] #2 已在战斗可见的旅行者形象保持不退化；选角/开局的自制资产身份与配置可核验。
- [ ] #3 开发开关/候选来源、性能和实际设备验收分开报告，不擅自改变用户已批准的发布安全边界。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 保留完整18资产注册表，候选运行白名单仅acid_slime_m r02。2. prepareMonsterArt先全量合法性校验再按名单派生，统一输入清单、装配和收据，缺省美术关闭。3. 负例与未选零装配定向验证，交主线程集成；官方导入、设备与最终画质仍未验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
完整18资产及原绑定源保留，candidateAssets仅acid_slime_m；prepare先完整合法性校验，再派生实际assets/绑定/输入。完整构建、音频前源码摘要和收据同一路径，不新增远程/玩家开关；默认flags仍false。新白名单回归先红3失败后绿4/4，未知/空/重复/非串及未选非法资产均拒绝；旧无名单fixture仍18资产19绑定。32flag构建/receipt/新测试合计55项，54通过、1 Windows符号链接权限skip、零失败；完整CLI-MCP mock装配1/1通过，实际写入仅1资产1绑定2输入。当前仅准入Alpha测试，不表示官方导入、设备性能、最终美术或神像接线完成。
<!-- SECTION:NOTES:END -->
