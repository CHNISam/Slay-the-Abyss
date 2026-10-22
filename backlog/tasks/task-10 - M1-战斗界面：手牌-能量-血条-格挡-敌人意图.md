---
id: TASK-10
title: M1 战斗界面：手牌/能量/血条/格挡/敌人意图
status: In Progress
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 21:27'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-8
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/29'
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
1. 保留develop批准稿战斗UI及回归修复，接回完整GameUI宿主、七节点和库存命令。2. 保留新版滚动地图及单独构建入口，统一嵌入式stage/缩放/更新接口，恢复双边有价值测试。3. 真实控件树验证完整局、药水、导航锁、胜败重开；清空build生成物后实跑统一门禁并独立复核。4. 推送解决冲突的PR29，等待精确head的两项CI通过后squash合并develop，核实远端结果；平台AC仍不虚勾。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM /root，feat/task-10-battle-ui/.worktrees/battle-ui；边界新UI脚本、布局、UI构建工具及对应测试。独占MCP/GUI主Agent持有。正式存档杀戮深渊已只读确认22101字节；Lv2用户确认，文字显示待实测。

实现真实Run/Combat驱动点击界面，56JS+52Lua（3UI+15core+8run+26status）及Python10pass1envskip通过，所有控件在1280x720内。八模块已写入工作区副本，scene_check_client errors0/warnings0。首轮真机在导入前前台切换失败，无截图日志；不计实机通过。独立审查与多设备预览进行中。

2026-10-23 /root/battle_design 独立接手批准方案对齐；仅 battle-ui 树。已读 battle/drag/boss 截图和主题；合入origin/develop，仅package.json脚本列表冲突并保留build:ui及build:theme。不用MCP、GUI或存档。

2026-10-23 批准方案战斗表现切片已实现：共享abyss_theme、stage等比缩放/全屏底色、主题卡牌/能量/血条格挡/意图图标、四态按钮、C档两次点选/目标确认、胜败反馈。npm run check通过：JS80pass/6symlinkskip，Lua68pass（UI9/core15/map10/run8/status26），Python10pass/1symlinkskip。控件树+真实Run/Combat适配测试覆盖十牌旋转及选中安全区、五敌点击区、首领头像、胜败奖励与重开。意图只标基础值，核心缺最终修正只读预览；A/B拖动、事件动效及长按未实现。详见docs/design/BATTLE_IMPLEMENTATION.md。本轮平台编译/导入/多设备预览/游戏实机均未执行，无MCP/GUI/存档操作；保留全部AC未勾选，尤其手机实机。

用户2026-10-23明确要求处理冲突并合并；/root在既有干净工作树runtime-integration推进。冲突Backlog版本先采用develop，再由CLI补回PR29集成计划与验证记录；保留最新批准战斗/地图视觉，接规则而不回退成过渡面板。

2026-10-23 PR29 冲突整合最终验证：保留 develop 批准稿战斗/C档操作/扇形手牌及滚动地图，接回统一宿主、七节点与库存。干净 Lua 产物重建后独立 test:lua 通过；最终 npm run check：JS101（95通过6权限跳过）、Lua139通过、Python12（11通过1权限跳过）。药水目标和效果提示已修，独立复审通过，战斗UI19项再次通过。平台编译、写档和实机未执行，不勾选平台验收。日志 build/merge-final-check.log。
<!-- SECTION:NOTES:END -->
