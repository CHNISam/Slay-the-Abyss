---
id: TASK-36
title: 修复节点按钮中断手势误执行新动作
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 09:28'
updated_date: '2026-10-23 09:44'
labels: []
milestone: m-2
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/75#issuecomment-6361780399'
documentation:
  - docs/reviews/TASK-36-node-gesture-ownership.md
modified_files:
  - src/lua/abyss_node_ui.lua
  - tests/lua/node_ui.lua
  - tests/lua/node_ui_gestures.lua
  - docs/reviews/TASK-36-node-gesture-ownership.md
priority: high
type: bug
ordinal: 47000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
离线真实控件回调复现：触点 A 按住商店确认按钮时，触点 B 改变同一按钮的动作；A 随后抬起并点击会执行新动作。反向场景会在 A 从未按下删除时删牌扣款。仅修复 NodeUI 手势与当前动作的归属，不改玩法数值、布局或平台验收状态。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 旧手势在取消、重绘、隐藏或按钮动作变更后不能执行替换动作，覆盖删除转离店及离店转删除并保持金币卡组与节点状态。
- [ ] #2 新的有意按下抬起点击、同触点复用和仅点击兼容路径保持可用；已有悬停按压与多触点视觉隔离不回退。
- [ ] #3 增加先红后绿的真实控件回归，运行节点和宿主相关测试并独立复审；平台事件顺序及实机未测明确保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 在固定 develop 源验证双向旧手势红测和正常点击对照。
2. 最小化绑定触点生命周期与按下时动作身份，独立保留点击兼容和视觉反馈。
3. 跑新增回归、原节点测试、宿主及规则测试，执行负控和独立评审。
4. 仅交付根线程发布；合并前保持 In Progress，平台验收仍未做。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
固定源 0ded765；新增真实控件手势回归先红（1 pass/12 fail），初版修复13/0；复审发现隐藏时 Down 恢复后可生效，补红测13/1后修复14/0。原节点25组断言保留；仅将有意点击夹具补为受支持的 Down→Up→Click，不让取消手势退化成无归属点击。独立复审及更广回归进行中，未实机。

已合入最新源6014746的49项并逐Git blob校验，未覆盖他人变更。独立复审补齐隐藏Down与Up后Exit取消；最终新增手势15组、原NodeUI25组、全部67个Lua5.4补充套件、20项布局JS、Python16项通过。当前源负控只还原NodeUI即1 pass/14 fail。npm check的JS阶段605 pass/40 fail，全部因Fengari模块不可用；未安装依赖，不将Lua5.4替代为正式全检。报告docs/reviews/TASK-36-node-gesture-ownership.md；待根线程发布、当前head CI及最终复审，保持In Progress和未勾AC，不影响平台关口。

最终601组合冻结独立复验通过：新增15组、原节点25组、独立边界19项及全部67个Lua套件，无剩余源码阻塞。主线程另跑15组通过；待发布及当前head CI，合并前保持In Progress。
<!-- SECTION:NOTES:END -->
