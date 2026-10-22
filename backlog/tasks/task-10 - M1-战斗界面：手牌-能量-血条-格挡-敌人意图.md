---
id: TASK-10
title: M1 战斗界面：手牌/能量/血条/格挡/敌人意图
status: In Progress
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 16:27'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-8
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用客户端 Lua 或节点图实现战斗界面，保证信息可读。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 手牌可见可选，出牌后即时刷新
- [ ] #2 能量、血量、格挡、敌人意图显示正确
- [ ] #3 手机画布下 UI 不出屏
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复用 PR19 已批准主题、坐标和组件规范，保留已有 Run/Combat 适配；生成 stage 及全屏底色、主题卡牌、单位血条格挡意图、能量与四态按钮。2. C档点选改为先选牌，再点目标或同牌确认；能否出牌只调用Combat.canPlay，意图只显示核心提供基础值并标注缺口，禁止界面计算伤害。3. 自动化验证多设备等比缩放、安全区与十牌可点、核心状态刷新、禁用与胜败流程；运行npm run check。4. 在BATTLE_IMPLEMENTATION.md记录已对齐与合理降级，A/B拖动、导入与真机均待主Agent验证，不勾手机实机AC。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM /root，feat/task-10-battle-ui/.worktrees/battle-ui；边界新UI脚本、布局、UI构建工具及对应测试。独占MCP/GUI主Agent持有。正式存档杀戮深渊已只读确认22101字节；Lv2用户确认，文字显示待实测。

实现真实Run/Combat驱动点击界面，56JS+52Lua（3UI+15core+8run+26status）及Python10pass1envskip通过，所有控件在1280x720内。八模块已写入工作区副本，scene_check_client errors0/warnings0。首轮真机在导入前前台切换失败，无截图日志；不计实机通过。独立审查与多设备预览进行中。

2026-10-23 /root/battle_design 独立接手批准方案对齐；仅 battle-ui 树。已读 battle/drag/boss 截图和主题；合入origin/develop，仅package.json脚本列表冲突并保留build:ui及build:theme。不用MCP、GUI或存档。

2026-10-23 批准方案战斗表现切片已实现：共享abyss_theme、stage等比缩放/全屏底色、主题卡牌/能量/血条格挡/意图图标、四态按钮、C档两次点选/目标确认、胜败反馈。npm run check通过：JS80pass/6symlinkskip，Lua68pass（UI9/core15/map10/run8/status26），Python10pass/1symlinkskip。控件树+真实Run/Combat适配测试覆盖十牌旋转及选中安全区、五敌点击区、首领头像、胜败奖励与重开。意图只标基础值，核心缺最终修正只读预览；A/B拖动、事件动效及长按未实现。详见docs/design/BATTLE_IMPLEMENTATION.md。本轮平台编译/导入/多设备预览/游戏实机均未执行，无MCP/GUI/存档操作；保留全部AC未勾选，尤其手机实机。
<!-- SECTION:NOTES:END -->
