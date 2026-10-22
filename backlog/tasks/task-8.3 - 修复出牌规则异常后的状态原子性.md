---
id: TASK-8.3
title: 修复出牌报错后仍扣能量和丢牌
status: Done
assignee:
  - Furinya
created_date: '2026-10-22 21:41'
updated_date: '2026-10-22 21:54'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/29#issuecomment-6351642696'
parent_task_id: TASK-8
type: bug
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Public API 构造 strength=2147483647 后打出真实 inflame，canPlay 为 true，但规则溢出仍扣能量、丢手牌并追加 play 事件。正常15层到达此数值未证明，本任务不声称常规坏档。仅修复 Combat.play 执行异常边界，不扩效果或平台范围。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 规则执行抛错时原状态、对象引用、事件、随机数和牌UID完全保留，继续原抛错约定
- [x] #2 成功出牌顺序、效果次数、正常返回和牌堆行为不变，覆盖单目标、多目标、抽牌洗牌与真实数据溢出回归
- [x] #3 现有Lua、JS、Python测试已运行并区分本地Lua5.4和正式Fengari CI证据
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对最新 develop、任务和开放 PR，确认独占写入边界。
2. 新增原子性红例，覆盖真实状态溢出、多目标部分执行及抽牌洗牌失败。
3. 在 Combat.play 局部保存原对象，失败原地还原并重抛；成功效果仅执行一次。
4. 运行全套回归，冻结文件供独立审查和正式 Fengari CI 验证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Executor：dot。基线 develop dcc4ce19；实现仅 src/lua/abyss_combat.lua、tests/lua/atomic_play.lua。
- TDD：14组中10红4绿 → 14绿；本地系统 Lua5.4 全套153组、Python13通过。本地JS缺Fengari的7项失败由正式CI另行验证。
- 正式CI：PR41最终head a7029d14，Windows JS130项中124通过、0失败、6符号链接权限跳过；Fengari153组（含原子性14组）通过；Ubuntu Python13通过。https://github.com/CHNISam/Slay-the-Abyss/actions/runs/39860609778
- 独立审查无阻断：153组、608组差分、Run/root引用与重试、PR37效果组合均通过。
- 已合并PR41，merge 77744e2a4c6c2dad3bab4541ef40dcac35b79051。仅证实public API极限边界，不代表正常15层可达；未平台编译、导入或游戏验证。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已合并PR41/77744e2：修复出牌报错后仍扣能量和丢牌，失败原地恢复原对象，成功效果只执行一次。原子性14组、正式Fengari153组、JS124通过6权限跳过、Python13及独立审查通过；最新CI39860609778双项成功。未平台验证。
<!-- SECTION:FINAL_SUMMARY:END -->
