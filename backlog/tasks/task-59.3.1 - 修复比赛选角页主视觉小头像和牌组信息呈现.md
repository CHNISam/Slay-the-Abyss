---
id: TASK-59.3.1
title: 修复比赛选角页主视觉小头像和牌组信息呈现
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-30 21:58'
updated_date: '2026-10-31 17:02'
labels:
  - playtest-20261030
  - p1
  - grok
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/PLAYTEST-20261030.md
  - docs/backlog-details/MOBILE-QA-20261029.md
  - docs/evidence/m3-visual-20261031/README.md
  - docs/evidence/m3-completion-20261031/
parent_task_id: TASK-59.3
priority: medium
type: enhancement
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner截图：选角页圆形大底叠黑色矩形包裹立绘，底部小头像被截半、缩在大框中且浮在中间，左侧全部/攻击/技能/能力/状态/诅咒筛选按钮堆积。根因涉及素材尺寸/裁剪/布局多方面。无法低成本用原版高清巨幅背景图，允许在性能边界内自主设计；最大程度复用原作成熟的选角信息架构。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 岩系旅行者主视觉、头部小头像与容器关系自然，头像不会悬空或不当裁切。
- [ ] #2 首发角色初始生命、金币、遗物、牌组信息一眼可读，主次符合选角任务；保留 Production 仅旅行者入口。
- [ ] #3 交付可与批准设计/原版交互对照的界面证据，平台约束和自设计取舍如实注明。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 以最新develop隔离接续PR389选角成果。2. 用完整身份绑定外层inverse恢复旧源码，保持历史门禁。3. 定向验证并交独立复审，实机保持未验。

补充本轮Simulator实测窄修：原生头像控制器从真实normal/bust宽度取得display，验证72px与旧32px，不改资产或布局。

2026-10-31 M3整批收口：以批准设计对照真实模拟器静帧，记录装配/素材限制，再验证官方同候选视觉与初始信息。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
接续PR389原选角改动，补充完整身份外层inverse，旧历史fixture与hash不变；完整文件/漂移负例通过，选角/头像/比赛入口组合定向验证进行中。尚无官方导入或实机验收。

进一步按391实际历史隔离设计复核：competition-roster旧合同在98fef固定历史输入回放，未改develop直接调用旧public inverse也拒绝当前源码；无需额外迁移旧inverse。已移除新投影层以避免无效耦合，保留391完整历史层与保护。当前真实Lua deck_browse_filters四组、hero_visual_slots、competition_roster_ui通过，prepared UI两片33用例通过。

2026-10-31：原389选角有效成果由394接续并进入396；最终去掉多余inverse层，保留391历史隔离。已修真实GIL颜色编码并补来源登记；本轮仅源码及候选读回证据，尚未合入develop或完成同候选设备验收，所有AC保持未勾。

本轮Simulator实际发现：attach host使用72/96，但runtime avatar controller仍硬编码32/96并覆盖。新增真实宽度72断言在未修源码失败，32对照通过；修为读取normal/bust.sizeDeltaX后完整肖像生命周期16/16通过，包含72/32释放重建及原失败/取消/销毁边界。素材、布局和原始fixture不改；尚待重建候选与同候选设备验收。

2026-10-31 M3最终事实核对：本轮真实Simulator Host选角/牌组/遗物/牌详情/退出共五张PNG已实看，源码e8eb723、1600×900/frame0；选择页生命金币遗物牌组及单角入口有局部文字证据。#1头像自然关系无法确认：本导出未装配可选portrait模板，不能把fallback认作正式缺陷；#2整体可读与#3批准对照最终证据仍受OSS CONNECT403缺纹理影响，且无官方PC/手机同候选证据。保留回执assetWarnings，不用HTML或离线截图冒充设备验收。
<!-- SECTION:NOTES:END -->
