---
id: TASK-3.3
title: M1 全平台游玩中主动退出本局
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-23 13:10'
updated_date: '2026-10-23 13:23'
labels: []
milestone: m-2
dependencies: []
parent_task_id: TASK-3
priority: high
type: bug
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户61425e4实机反馈：手机没有Esc，电脑玩家也可能不知道Esc；游玩中无可发现的退出入口，只能等战斗结束或杀进程。当前游玩流程必须有可点击触摸的主动结束方式。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 战斗、奖励、地图、节点及牌库均有可发现的触控鼠标退出入口，不依赖Esc，战斗反馈播放期间仍可唤起
- [ ] #2 退出需明确确认；取消恢复原局且不触发底层出牌交易，陈旧重复手势不误确认退出
- [ ] #3 确认后只发送一次正式结束请求，失败可重试；平台结算可离开当前关卡，不必等待战斗胜负
- [ ] #4 布局使用批准主题，常见画布入口与确认按钮可触达，保留既有出牌奖励结算回归
- [ ] #5 记录同一新候选编译写副本实机分层证据，PC点击及手机触控未测项如实保留
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
定位宿主仅结果页允许settle的限制；补生成控件与模态退出，复用ABYSS_LOSE正式结算；先写真实控件交互回归复现，再实现全检；独立读回新副本后实机验退出。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
实现常驻退出与模态确认，复用正式结算，不伪造战斗死亡。新增15项真实宿主回归通过；UI集成/主题/布局12项通过。独立审查捕获并修复异触点授权、孤立触摸首Click、foreignExit、旧held跨弹窗代际/resize阻塞；缺Up/回调失败/重入/动画恢复已覆盖。首轮完整JS检查1项结果按钮动画回归，已修并用既有15项GameUI复验通过。接下来固定提交并叠加原614玩法源，完整集成检查后写独立新副本；正式导入和PC/手机退出仍未验，AC保持未勾。
<!-- SECTION:NOTES:END -->
