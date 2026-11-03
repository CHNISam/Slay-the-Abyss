---
id: TASK-38.3
title: 复验结算用时修复与异常降级
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-01 02:05'
updated_date: '2026-11-03 12:18'
labels:
  - release-qa-20261101
milestone: m-5
dependencies: []
references:
  - docs/backlog-details/MOBILE-RELEASE-QA-20261101.md
  - src/lua/abyss_game_ui_menu_view.lua
parent_task_id: TASK-38
priority: high
type: bug
ordinal: 135000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-11-01移动端上线前验收：IMG_1255.png的失败结算页“用时”显示3074457345。用户明确要求上线前紧急处理；暂时无法保证准确时可隐藏该项或显示N/A、暂不可用，不能向玩家显示错误时间。截图候选版本尚未关联，不据此猜测计时根因。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 可靠计时时显示正确且可读的本局用时；不可用、非法或无法保证准确时隐藏该项或显示N/A／暂不可用，不展示3074457345等异常数值，也不用伪造0时长冒充真实数据。
- [x] #2 沿实际共用用时路径定向复验失败、胜利、退出结算和重新启程；旧局时间不污染新局，降级显示不阻断重新启程或结束并结算。
- [ ] #3 保留异常计时输入与正常计时的回归，并在同一候选实体手机结算页取证；记录源码、候选和设备，未实测不得勾手机验收。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对远端568da4e4中PR442计时生产路径与定向回归。2. 独立离线复验正常与非法计时及结算重开边界。3. 记录本轮证据；同候选手机未测保持未完成。

本轮补真实原生OnStart/OnUpdate、实际战斗失败结果页与退出按钮＋不可用时钟组合，覆盖取消/重启归零、发送失败重试及去重；设备AC3保持未完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR #442 已合入结算用时修复及定向回归；投稿已完成，后续保留同候选设备复验，不再作为投稿前阻塞。

2026-11-03 基于远端568da4e4独立复验PR442：计时安全JS1/1、真实GameUI16例及退出两片15例通过。官方入口强制暂不可用，不拿模拟计数证明官方准确时间；正常/非法值、胜败退出及新局边界已验。AC1/2据本轮离线证据勾选，AC3同候选实体手机NOT_RUN，整体仍In Progress。详见docs/backlog-details/TASK-38.3-REVERIFY-20261103.md。

2026-11-03 补齐退出按钮＋不可用时钟直接组合：生产Host真实开局与首房敌人致死，原生退出触摸链取消/重启、ServerSignal抛错后取消重开重试与单次发送；新增JS包装本轮1/1通过。AC2退出缺口已补证，AC3手机仍NOT_RUN。原exit专项本轮30秒超时保留、不计通过，详见TASK-38.3-REVERIFY-20261103.md。
<!-- SECTION:NOTES:END -->
