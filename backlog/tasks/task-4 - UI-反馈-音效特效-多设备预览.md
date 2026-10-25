---
id: TASK-4
title: 把界面、音画和操作打磨到正式作品水平
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-25 07:41'
due_date: '2026-10-28'
labels: []
milestone: m-5
dependencies:
  - TASK-29
  - TASK-29.1
  - TASK-30
  - TASK-34
  - TASK-25
  - TASK-38
  - TASK-42
  - TASK-36.1
  - TASK-38.1
  - TASK-4.1
  - TASK-2.1
  - TASK-10.1.2
  - TASK-4.2
references:
  - docs/backlog-details/TASK-4.md
  - docs/backlog-details/TASK-4.2.md
  - docs/DELIVERY-CLOSEOUT.md
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按你批准的设计打磨整款游戏。看得清、点得准、打得有感觉，手机和电脑都要真正玩过。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 攻击、受击、格挡和状态变化都有合适的画面与声音。
- [ ] #2 手机和主机的界面不会超出屏幕。
- [ ] #3 生命、格挡、能量和敌人意图清楚可读。
- [ ] #4 战斗、地图、各类房间和结算符合批准的设计；有区别的留图说明。
- [ ] #5 出牌、命中、掉血、受伤和死亡衔接自然，参考原版节奏，不编造测量结果。
- [ ] #6 群攻、多段、中毒、反伤和死亡等表现完整，实际听过声音并检查设备性能。
- [ ] #7 保存同一个版本的测试与试玩记录，分清本地做好和游戏里验过。
- [ ] #8 按已定界面检查表逐屏验收，音画和手机电脑操作达到你批准的标准。
- [ ] #9 本任务负责人核对所有已交付首发资产与本地切片的正式装配、平台导入和实机结果；占位或缺测均有承接任务、责任人和下一动作，不用子任务Done代替整体验收。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
PR171整合切片：保留develop最新商店原子交易和战后独立选牌界面，解决开场与商人对话冲突；对话框避让全部商品价格；完整本地检查和当前SHA双Quality通过后squash合入develop，保留平台实机验收。

地图金币缺失修复：复用节点页顶栏的生命/金币图标与位置，在地图常显真实局内资源；补选路前可见、归图更新及布局避让回归，记录本地与实机边界。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24用户明确删除首页层数流程及拖牌教学两行；源码e116ca7已修，15组界面回归和4组布局/控制器检查通过，修正版副本独立读回通过，尚未导入。原计划及记录完整保存在本轮Git stash与.artifacts/m1-live-sprint/backlog-changes-preserved.patch。

PR171开场与商人离线整合：已接上最新商店按槽买卡、药水交易及独立选牌台；修复价格行遮挡和新局同编号商店不播旁白。JS全量950通过/118环境跳过，商店Lua35项与开场10项回归通过；完整检查与最终SHA Quality继续核实。平台导入、电脑手机及UI门禁未验收。

用户第9层截图确认地图漏显示金币与生命。已在地图左上补真实资源，复用房间顶栏主题；两项新回归及药水栏两项避让检查通过，语法通过。完整check进行中；尚未新副本/官方导入/实机，保持整体验收未勾。

修复PR187（a03d633）：地图资源专项2项、药水避让2项、宿主6项通过；新增UI门禁回归7通过2环境跳过，源码语法通过。完整本地check在无关build-ui-input-protection的大目录重复复制中长时间无输出后停止，不记全绿；最终SHA的Quality仍排队/运行，未合并。新增实机门禁要求地图gold与hpAndMaxHp，尚未游戏导入。

手机横屏左右露底按P1在TASK-38推进，共享背景层修复；正式发布前须核对所有主要页面。离线几何、候选读回、官方预览、真实手机和性能证据分开记录，未经本轮输入时间协调不启动GUI测试。
<!-- SECTION:NOTES:END -->
