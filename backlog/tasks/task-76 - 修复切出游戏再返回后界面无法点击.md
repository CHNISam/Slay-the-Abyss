---
id: TASK-76
title: 排查手机战斗和奖励页面输入阻塞
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-28 09:38'
updated_date: '2026-10-29 01:55'
labels: []
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/TASK-76.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/304'
  - docs/evidence/backlog-merge-20261029.json
priority: high
type: bug
ordinal: 121000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
问题由手机实玩发现：拖牌后奖励或动作可能不能点击，关卡组后也曾无法操作。离线诊断复现混合Click抑制；卡组关闭后原生输入锁根因未确认。PC是否受影响待分别验证。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 根因定位并最小修复
- [ ] #2 跨界面切回正常交互且不误触
- [ ] #3 回归通过并经PR合入develop
- [ ] #4 真实拖牌后奖励、结束回合及纯点击入口继续可用，无需退出确认恢复。
- [ ] #5 卡组关闭后战斗、奖励和地图首个合法操作正常，手机留证。
- [ ] #6 分别记录手机触屏和PC鼠标的复现或未复现条件；不能以离线模拟代替真实设备。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
追踪平台焦点与手势；最小实验验证；修复与回归；实机与PR集成。

新增丢失释放后再次点卡的真实处理器回归，并核对同指针恢复、多指归属与迟到事件不误出牌。

本轮复现真实拖牌后Click-only奖励入口被持续抑制，修复各事件能力入口的所有权回收；不猜原生焦点回调，卡组原生遮挡仍待实机。

2026-10-29实机阻断：用户新包进游戏后点卡组，update报GetChild invalid object。先使用会销毁/替换grid item的原生生命周期替身复现，检查bindings缓存与卡面动画；修正实例所有权而非吞错，补开关/刷新/滚动回收和旧动作回归，再用旧已审计完整包作底替换同源修复模块并独立读回。没有键鼠窗口，不操作客户端。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮隔离工作树 .worktrees/ui-focus-return，基线 origin/develop d2e0baa3。已读入口 abyss_ui、共享 GameUI、Controller、BattleUI、ChoiceUI、NodeUI 及平台官方客户端 API。入口仅启动/逐帧更新；官方生命周期未列窗口焦点回调，不能直接套用 Unity OnApplicationFocus。UI 根 showCursor/blockKeys/blockCursor 恒为 true。战斗 down 在 self.gesture 存在时不清 suppressClick；dragLayer 在 moving gesture 存在时启用 hit 并拦截穿透。因此丢失 Up/EndDrag 后残留手势/遮挡为待验证假设，尚无本轮实机证据，不能定为实际根因。选牌、地图、节点、菜单已有不同的手势所有权防护，不能粗暴清空所有输入或刷新整界面。已请求本轮10分钟键鼠窗口，未获确认，未发送输入。尚未修改生产代码、运行修复回归或创建PR。

用户补充：不切出也会突然无法选牌，点击退出本局等按钮后恢复；不再以窗口失焦为必要触发条件。继续离线排查丢失释放事件后 self.gesture 永久拒绝新 Down 的路径。

已用真实UI处理器红绿复现缺失Up导致卡牌永久锁定；最小修复18行及针对性回归已实现。候选只替换PR290底图的BattleUI模块，实机待用户自行验证。详细边界、测试与失败记录见附件。

2026-10-28队列复核（基线77c2d5e6）：中断按压修复已进入集成源码，但跨界面故障与同候选平台实测尚无完整验收；继续High/In Progress，原0/3验收保留。作为前两幕输入阻塞关联M4并列入排期，负责人统一Furinya，不把本地红绿或实验模块包当作用户故障已彻底解决。

本轮两个输入缺陷已修前RED修后GREEN；子树新增回归与原地图35组、动作8组通过。当前集成独立复验中。地图背景drag漏Up可恢复；node自身漏Up及卡组原生遮挡仍未证明修复，任务保持进行中。

2026-10-29用户实机点卡组/遗物均报update GetChild invalid object，旧066包已标失败保留。销毁式Grid替身真实复现deck_ui225旧缓存问题；生产在GetChild前查官方readonly alive并清无效绑定，update/close共享，旧回调空值/失效拒绝。原生生命周期及移除保护负对照纳入现有check:native-ui-contract；最终相关10/10，旧卡组6组20.466秒/原30秒、牌堆4组、相关17项通过。首次旧卡组超时保留，优化替身私有引擎查表后原预算完整通过。语法/架构/73旧静态警告门禁过；无实机通过，替换包在构建。

生命周期修复替换包已交付：根.artifacts/M3卡组遗物修复-4ad01d49.gil，游戏源4ad01d49082edbcd8c7c2e3b85f5246595479391，SHA256 ff2a667d94404a122e1adfbae656da81e77aff046fcc88e24cb0cdbdbf667423。独立226模块同源、8454控件/max60、BGM及参数核对通过，静态0错误103警告未逐条人审。首轮全量UI重写工具120秒超时保留；改为整份JSON/模板与已审计旧包严格相同才复用原UI，最终完整检查不省略。新包官方导入/ready/设备仍待用户复验，原AC不勾；旧包用户失败记录已同步。

合流双方完整metadata、AC、计划和实施notes见docs/evidence/backlog-merge-20261029.json；当前角色范围按旅行者单角两幕，雷电未来任务原81因上游重号经原生doctor改为TASK-85。所有原已勾AC不改，未验不勾。
<!-- SECTION:NOTES:END -->
