---
id: TASK-10.5
title: M1 战斗动态数值与状态详情（P1 本地实现）
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-23 16:29'
updated_date: '2026-10-27 15:04'
labels: []
milestone: m-2
dependencies: []
references:
  - docs/design/UI_DESIGN.md
  - src/lua/abyss_battle_ui.lua
parent_task_id: TASK-10
priority: medium
type: enhancement
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
手牌说明里的伤害/格挡数字一直是构建期静态模板，不随力量、虚弱、易伤、敏捷、脆弱或暴走成长变化；单位状态只有一行“名称 层数”文字，没有批准稿要求的 26 图标网格与完整效果说明。原测试把“除暴走外 37 张牌战斗中永远逐字静态”固化为期望，与原版不符。范围仅本地实现与自动化回归；平台导入/实机显示归 TASK-11.1 与 TASK-4。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 战斗手牌中每个可被修正的伤害/群攻/格挡数字由核心只读预览计算，随力量、虚弱、易伤、敏捷、脆弱与本局成长实时变化；瞄准某敌人时显示对该目标的精确值，未定目标时显示存活目标区间
- [x] #2 玩家与每个敌人显示状态图标与层数（增益/减益语义色，溢出显示 +N），点按状态行或玩家头像打开含名称、层数、增减益与当前效果说明的详情面板
- [x] #3 修正错误的静态卡牌测试，新增回归覆盖多段、群攻、不同目标、格挡、预览只读，以及详情面板在点选与指针两种输入下的隔离（不出牌、不改目标、不结束回合、不触发拖牌）
- [x] #4 复用现有战斗核心算术，不修改数值规则；点选与拖牌原有回归全部通过，npm run check 退出码 0
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核心新增只读 Combat.cardPreview，复用 Actors.attackAmount/blockAmount。2. 渲染器为 damage/damageAll/block 顶层数值保留实时占位。3. 战斗UI每次渲染代入预览；拖牌瞄准时取目标精确值；Body Slam 追加当前值。4. 原生树：单位状态网格 + 共享详情面板（全画布关闭层）；主题新增 statusInfo 令牌。5. 输入隔离：面板打开时下一次按下/点击只关闭面板。6. 修正静态测试，新增 card_preview 回归，跑完整 check。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
离线实现完成（未导入、未开原神、未改正式存档）。证据：npm run check 退出 0——JS 746（628 通过/0 失败/118 按设计跳过）、全部 Lua（新增 card_preview 13 项、battle_ui 51、growing_card_text 11、cultist_ui、sentries_ui 等）、Python 17 OK/1 跳过。预览以核心实际出牌结果为判据（单体两目标、Twin Strike 普通/升级、Cleave/Thunderclap 三敌含易伤、五张格挡牌含敏捷+脆弱、Iron Wave、Body Slam、负力量下限 0、预览不改状态）。变异检查：关闭面板吞点击或预览不走 attackAmount 时 card_preview 均变红。被修正的错误期望：growing_card_text 原断言力量/虚弱/易伤不影响暴走数值、其余 37 张战斗中逐字静态；Python 原断言仅暴走带 combatText。原生树 569 控件、单父最多 52 子（限 60）。平台差异：未取证富文本，数字不着金；共用主题图标的状态（力量/仪式/激怒等）靠详情面板文字区分；悬停/长按降级为点按。实机显示归 TASK-11.1/TASK-4，未验证。分支 feat/combat-dynamic-values 已推送，按用户要求未开 PR、未合并，故保持 In Progress。

2026-10-24 合并复核：已将 develop b2ed278 合入工作树，解决 growing_card_text 的两处冲突，保留 Slimed/Dazed 全 39 张文案覆盖；curl_up_ui/spore_cloud_ui 旧状态控件读取先复现失败，迁移到实际状态详情面板后均通过，保留层数、移除和真实战斗断言。固定源码完整 npm run check 退出 0：JS 966 项（848 pass/118 skip/0 fail）、全部 117 个 Lua 文件、Python 17 项（16 pass/1 skip）；card_preview 13 项通过。日志保存在根 .artifacts/combat-dynamic-values-integrated-check.log。用户本轮已授权创建 PR 并 squash 合入 develop；此前“按用户要求未开 PR、未合并”的说明为历史状态。本切片仅本地实现验收，未构建副本、未导入或实机验证，TASK-11.1/TASK-4 平台验收保留。

负责人字段规范化：原记录 @claude 作为历史执行者信息保留；任务负责人为 Furinya。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
战斗手牌实时伤害/群攻/格挡预览和单位状态图标、详情及输入隔离已完成本地验收。合并 develop b2ed278 后完整 npm run check 退出 0（JS848通过/118跳过、Lua117文件、Python16通过/1跳过），保留39张卡牌和蜷缩/孢子云回归。平台导入与实机UI验收仍归 TASK-11.1/TASK-4。
<!-- SECTION:FINAL_SUMMARY:END -->
