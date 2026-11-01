---
id: TASK-4.5
title: 修复格挡数字裁切，并按原版核实伤害预览
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-24 12:17'
updated_date: '2026-11-01 02:05'
due_date: '2026-10-24'
labels:
  - awaiting-live
  - release-qa-20261101
  - release-blocker
milestone: m-5
dependencies: []
references:
  - docs/reviews/USER-PLAYTEST-20261024.md
  - docs/M3-NUMERIC-LIVE-20261024.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/backlog-details/MOBILE-QA-20261028.md
  - docs/backlog-details/MOBILE-RELEASE-QA-20261101.md
parent_task_id: TASK-4
priority: medium
type: bug
ordinal: 86000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户实机发现格挡10只显示1，需要完整显示多位数字。伤害预览按核实后的原版语义验收：普通手牌包含玩家修正，瞄准敌人时加入目标易伤，取消或状态移除后恢复。具体证据和相邻排查见docs/reviews/USER-PLAYTEST-20261024.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 玩家及敌人的格挡1、10、99、100和999均完整可读，不遮住血条或相邻敌人。
- [x] #2 普通手牌按玩家修正显示，瞄准具体敌人时才加入易伤；取消或状态移除后恢复原版数值。
- [x] #3 保留旧数字裁切和预览问题的自动红绿回归，现有布局与预览专项通过。
- [ ] #4 以当前统一格挡位置版本的同源候选实机截图确认格挡与预览两项修复。
- [ ] #5 分别实测点选和拖动瞄准目标的预览及结算，记录实际差异。
- [ ] #6 无其他修正的基础6普通攻击进入明确待出牌目标状态后，易伤敌人的当前牌面在出牌提交前显示9，切至普通敌人显示6、切回显示9；不能只在结算时正确，也不能把同一目标修正套到整手牌。
- [ ] #7 同候选分别记录手机点选与实际拖动、PC点击携牌／拖放、已支持手柄选牌切目标的预览和确认顺序；按固定源核实映射，保留取消、移出目标、切牌和状态变化后的数值恢复，预览不扣能量、不移牌、不造成伤害。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
保留原版普通手牌/瞄准/取消区分，撤回尚未提交的整手牌目标修正试改。格挡按位数拓宽，窄敌列采用不挤压生命数字的排布；同根因状态层数和抽弃牌行高补统一门禁。保留旧版证红、定向回归与同候选实机证据。

用户追加要求格挡位置一致：移除窄列搬至头像分支；参照固定AbstractCreature.renderHealth/renderBlockIconAndValue的血条左端锚定关系，扩大敌人行可用跨度，列内预留三位格挡区域；增加1到5敌人/首领多位数字、同高、无重叠回归。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
用户随后要求先核实原版。固定AbstractPlayer.renderHand 1678-1715证明calculateCardDamage目标后渲染，随后applyPowers还原；普通手牌不直接算敌方易伤是正确语义。补瞄准/取消/目标状态移除/玩家力量虚弱恢复回归15组通过。格挡旧版真实树证红hero clips Block10；首次拓宽又被相邻生命容量契约证红enemy1 clips HP while showing Block10，改窄列放入画像下角，保留完整生命带，55组UI含动画均绿。全项实机尚未复验，不勾AC。

本轮76bbefa数字视觉夹具官方导入1846，29号新日志24条含两次ready/六阶段/complete/正式结算。玩家及五敌1/10/99/100/999、Boss100与240/240、状态和牌堆10实际截图完整；用户帮助启动，自动启动失败保留。仅数字显示复验，预览/普通奖励及整体UI未验。详见docs/M3-NUMERIC-LIVE-20261024.md。后续develop拖牌同步b6d3cbe另有15预览/53UI回归通过，截图不认证全部新组合。

2026-10-24 用户追加一致性修正：移除窄列搬格挡到头像分支，按固定AbstractCreature血条左端锚定；敌人行-192～512，固定预留三位格挡空间，生命位置不随格挡变化。先红后绿；53战斗UI、15预览、10反馈及13主题/布局回归通过。源码依据与验证边界见docs/reviews/consistent-block-layout.md；未导入/实机，不勾AC。

2026-10-26全面复核：本轮53个原战斗UI用例和card_preview通过，已交付布局/领取/跳过/预览条款补勾；当前版实机截图与设备条款仍保留。

2026-10-26将原混合AC2分成自动回归已通过和当前版实机待验，原要求完整保留。

负责人字段规范化：原记录 @Codex 作为历史执行者信息保留；任务负责人为 Furinya。

PR #304：手机反馈瞄准易伤目标时伤害未更新；离线拖动对照预览及结算均为9，用户实玩时实际瞄准状态未确认；PC和手机分别复验，勿先断言公式错误。

2026-10-29 详细验收承接附件§6：触屏点选、明确目标、实际拖动瞄准、目标变化与取消分别核验。普通整手牌仅有玩家修正，当前待出目标牌在明确瞄准时才显示目标修正并与结算一致，取消恢复；不把一个默认target套整手牌、不先改伤害公式。调查中的Strike6→拖瞄9→结算9只证明该受控链路，不等于用户那次状态或新候选实机已通过。

2026-11-01 Bug3：用户要求直接按固定STS1源码完成选牌／选目标／出牌前数值预览，重点是手机点选与拖动。已复核aeubanks/sts@319009d5：鼠标有携牌后确认及拖放，手柄切换hoveredMonster后renderHand会先计算目标伤害再绘制；源码含触屏分支。当前2d06741卡面currentAim只接moving gesture/carry，手柄目标Focus仅更新owner.target，存在明确非拖动目标接线缺口；不将其冒认为本次手机现场完整根因。源位置与对照见新附件；本镜像renderHand准确行号1730–1766（核心1761–1764），旧排版行号保留历史。原离线AC与尚未完成实机AC保持。
<!-- SECTION:NOTES:END -->
