---
id: TASK-11.2
title: M1 修复荆棘伤害错误绕过格挡
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-22 23:24'
updated_date: '2026-10-22 23:27'
labels: []
milestone: m-2
dependencies: []
references:
  - >-
    https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java#L158-L185
  - >-
    https://github.com/fadedwind/refgameSource/blob/462da73b934eaf8a833791f3cab74dc792fdeeb6/Slaythespire.src/com/megacrit/cardcrawl/core/AbstractCreature.java#L164-L165
parent_task_id: TASK-11
type: bug
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户要求沿用初代STS规则、不另设计数值。TASK-11历史直反伤说明及旧测试错误地将THORNS等同HP_LOSS；两份第三方V2.3.4反编译镜像均显示只有HP_LOSS绕过格挡。本任务仅纠正荆棘格挡契约，不改强度、999封顶、UI或平台任务；证据非官方源码认证。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 荆棘先消耗攻击者格挡，只对不足部分造成HP损失；双方适用，事件amount为实际HP损失。
- [x] #2 保留无力量虚弱易伤修饰、不递归、每次正攻击一次、原攻击全挡和致死仍反伤；0伤害不触发；多击死亡中止及双方死亡处理不变；毒仍绕挡。
- [x] #3 纠正旧断言并保留先红后绿和全套回归证据；不宣称平台导入或实机通过。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
先修正错误绕挡断言并新增全挡/部分挡/无挡/多击/致死测试看红；再仅修改actor荆棘分支扣挡；保留既有status_damage及实际HP损失语义；回归所有本地测试并独立审查。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor: dot；独立目录 slay-thorns-block-fix-20261023；主actor唯一写者。查重时开放PR仅Draft37，无同范围；TASK11.1保留平台显示；TASK3.1及主题导出作者不受影响。基线develop1217abb。

TDD：旧actor下纠正断言与4个新增组共5组失败；最小荆棘分支扣挡后31状态组通过。事件仍status_damage，amount是实际HP损失，全挡发0；无新增字段，src消费者无status_damage专用依赖。全套系统Lua5.4共165组通过，已含14原子出牌组及31状态组；此前179误将14原子组重复相加，现已按日志逐组核对纠正。Python13通过；syntax/数据验证/build:data/build:ui/build:theme/git diff --check通过。仅核对原directDamage和毒逻辑未变，不宣称不存在的独立HP成本API已验证。

npm run check已真实执行，JS123通过、7项因缺fengari-node-cli失败；不声称Fengari或正式CI通过。任务保持In Progress/AC未勾，等待独立审查和父级远端CI。

父级转交独立审查结果：2430个独立断言在候选全通过，旧Actor负对照459失败；状态31、战斗23、原子14、库存10组通过。审查确认来源限制及HP_LOSS边界。AC按本地证据勾选，仍保持In Progress，正式CI与集成由父级继续。
<!-- SECTION:NOTES:END -->
