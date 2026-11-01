---
id: TASK-7.3
title: 按荧的官方岩元素设定重做卡牌表现
status: Done
assignee:
  - Furinya
created_date: '2026-10-22 15:08'
updated_date: '2026-10-22 16:06'
labels: []
dependencies:
  - TASK-7.2
parent_task_id: TASK-7
priority: high
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner最终决定本次参赛采用原神荧（Lumine）的岩元素形态，其他元素延后。先核对官方普攻、重击、战技、爆发、天赋与命之座，可直接适配的优先采用；保留单手剑表达，不给所有招式硬加元素词。旧风元素候选已撤回，继续复用本任务与PR10；数值基准和历史交付保留。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 本次主角为荧·岩元素，按普通攻击、重击、战技、爆发、天赋和命之座核对官方资料，来源清楚
- [x] #2 优先适配可用的官方招式，保留独立剑术表达，不机械给所有名称加元素词；37卡效果文案准确，不虚构已实现机制
- [x] #3 源ID与数值保持不变，渲染、数据检查和新方向独立评审通过，再正常PR集成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对官方岩荧普攻/重击/战技/爆发/天赋/命之座，确认可直接适配项。2. 以官方表达和朴素剑术为基础修订卡牌与范围，不硬凑全元素名。3. 核对效果与来源，运行测试及独立评审，更新原PR10后正常合并。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor=dot；隔离工作区 slay-lumine-anemo-integration-20261022；本任务只写表现资源、设计说明及本任务记录，不覆盖TASK8/8.1原执行者。

按Owner明确产品范围同步docs/SCOPE.md及HANDOFF顶部说明：首发风元素荧；历史战士字样仅数值参考，不改原TASK7历史。

Owner进一步否定“异邦”措辞；基础攻击显示名采用“疾风斩”，设计明确它是本作命名而非官方招式名，效果不变。

真实验证：37显示名唯一，74模板逐字符未改；源cards SHA256仍48940083a4e51cb9fb9c6f72b93edf262b72a363e2af0f2276d7f4fcf1b2b222。Python10测试和Node48测试、六表校验通过，doctor无冲突。独立逐卡评审通过；待正常PR集成，未做游戏/存档/动效验收。

交付候选：PR #10 https://github.com/CHNISam/Slay-the-Abyss/pull/10 已转Ready，使用正常CI及squash流程；主线交付以PR实际合并为准。独立审查包含最终疾风斩及两条未实现动效参照；表现资源SHA256 63faf52fd8e6aba57d799c3c33e2b75beb92427bc6550f29c2dfc0aa2f7d31ad，设计说明SHA256 1de7a517dee4b818cd7629d05d60669ab1d4d2394693d945c918becd4b48b335。

Owner 15:36否定全风化命名，要求先核对完整官方技能体系、保留单手剑；15:37明确决定本次改为岩元素荧。PR10已退回Draft，旧风元素名称及审查不构成当前验收，任务重新In Progress。

岩元素版实际合入：PR10，merge e91054fa7b7d2751d7fa151f13c795a60c2eb8d2。最终head b8a7f54a83ef81015314426519cd4d924784a770 的Actions39808928062/check及presentation均成功。canonical回读普通攻击、星陨剑、岩潮叠嶂正确。旧风元素候选未合；本次只完成表现资源及范围说明，非游戏/动作/特效验收。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
荧·岩元素表现已通过PR10合入develop。37显示名保留剑术，优先采用适配的官方技能参照；74模板、数值不变。独立审查、Python11、数据48及真实CI通过，主线回读一致。
<!-- SECTION:FINAL_SUMMARY:END -->
