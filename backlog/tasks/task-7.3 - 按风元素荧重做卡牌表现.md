---
id: TASK-7.3
title: 按风元素荧重做卡牌表现
status: Done
assignee:
  - Furinya
created_date: '2026-10-22 15:08'
updated_date: '2026-10-22 15:17'
labels: []
dependencies:
  - TASK-7.2
parent_task_id: TASK-7
priority: high
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner 2026-10-22 明确主角是原神荧（Lumine），本次参赛只做风元素；PR6通用行旅剑术表达不准确，需要按风荧设定修订，其他元素留后续。保留已合入的数值基准和历史交付，不冒充原神技能机制复刻。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 主角与本次参赛范围明确为荧·风元素，设定依据可追溯，其他元素不纳入
- [x] #2 当前37卡名称与74份文案保持实际效果准确，并形成可辨认的风元素荧主题；不把未实现的扩散、牵引、元素伤害写成已生效
- [x] #3 渲染、数据检查与独立评审通过，源数值和ID不变，正常PR集成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对官方风荧设定与37卡真实效果。2. 修订表现资源和短设计说明，记录原版设定与卡组改编边界。3. 运行现有数据和表现测试、独立逐卡评审，再正常提交合并。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor=dot；隔离工作区 slay-lumine-anemo-integration-20261022；本任务只写表现资源、设计说明及本任务记录，不覆盖TASK8/8.1原执行者。

按Owner明确产品范围同步docs/SCOPE.md及HANDOFF顶部说明：首发风元素荧；历史战士字样仅数值参考，不改原TASK7历史。

Owner进一步否定“异邦”措辞；基础攻击显示名采用“疾风斩”，设计明确它是本作命名而非官方招式名，效果不变。

真实验证：37显示名唯一，74模板逐字符未改；源cards SHA256仍48940083a4e51cb9fb9c6f72b93edf262b72a363e2af0f2276d7f4fcf1b2b222。Python10测试和Node48测试、六表校验通过，doctor无冲突。独立逐卡评审通过；待正常PR集成，未做游戏/存档/动效验收。

交付候选：PR #10 https://github.com/CHNISam/Slay-the-Abyss/pull/10 已转Ready，使用正常CI及squash流程；主线交付以PR实际合并为准。独立审查包含最终疾风斩及两条未实现动效参照；表现资源SHA256 63faf52fd8e6aba57d799c3c33e2b75beb92427bc6550f29c2dfc0aa2f7d31ad，设计说明SHA256 1de7a517dee4b818cd7629d05d60669ab1d4d2394693d945c918becd4b48b335。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
按Owner最新角色范围重做37卡显示名称：风元素荧，疾风斩/风涡剑/风息激荡。74模板及数值不变；10项Python测试、48项Node测试、六表校验与独立评审通过。仅离线表现交付，游戏和动效未验收。
<!-- SECTION:FINAL_SUMMARY:END -->
