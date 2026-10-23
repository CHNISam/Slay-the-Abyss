---
id: TASK-10
title: M1 战斗界面：手牌/能量/血条/格挡/敌人意图
status: In Progress
assignee: []
created_date: '2026-10-22 13:47'
updated_date: '2026-10-22 21:23'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM /root feat/task-10-battle-ui/.worktrees/battle-ui，实际UI实现中并独占MCP/GUI；真实源规则交互与布局自动测试通过。2026-10-23已将8个Lua模块和界面写入工作区存档副本，scene_check_client errors0/warnings0；正在真机验证，尚未AC验收。

2026-10-23 本会话/root功能复核：f7d5d75视觉版有两项阻断回归，原HUD回血显示重新读取combat旧HP，且选防御后点敌人会错误出牌；非作者content_review原负例均exit1。派quality_gates在独立TASK10.4/feat/task-10-4-ui-regressions修复，仅controller/tests，禁止共享battle-ui未提交树。批准主题minimum14优先，不新增18px硬线。MCP实际导入目前因game/editor高完整性0x3000而此会话输入进程中0x2000阻断，已问用户统一权限；本会话暂停GUI输入，未宣称实机通过，正式存档前后hash一致。

2026-10-23 原两项视觉回归已由TASK10.4 PR35修复，content_review按准确0ab57f1独立复验，原冻结负例不改转绿，86JS（6权限skip）/70Lua/Python11（1skip）完整门禁通过。PR23最终cc0ebfa记录修复后无剩余离线阻断；原实机AC仍未勾。

2026-10-23 用户要求代办权限并配合，已实际通过Start-Process -Verb RunAs启动一次有界管理员测试助手，IsInRole=True且runtime实际GUI步骤前进；不再要求用户重启游戏或Agent应用。助手固定候选/live0、任务后退出，无新持久管理员服务。当前屏幕为用户/另一工作线已导入ART小样，显示与点击通过截图已记录到TASK10.1；本会话不重复导入或争抢当前试玩。后续自动导入/焦点稳定性仍待验证。
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @opus
created: 2026-10-22 16:06
---
拖牌和甩牌：用户希望做到。实现顺序是先做 C 档点选（必须有），再按 UI_DESIGN.md 第 4 节试 B 档假拖动（CursorDown 抓起，在敌人上 CursorUp 打出），最后试 A 档跟手（要求 CursorDrag 能拿到指针位置）。出牌命令不变。
---
<!-- COMMENTS:END -->
