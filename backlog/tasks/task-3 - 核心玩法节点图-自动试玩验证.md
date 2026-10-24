---
id: TASK-3
title: M1 真实平台完整战斗闭环
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-24 02:02'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-3.2
  - TASK-11.1
priority: high
ordinal: 1
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
对已完成的战斗系统做三层分离验证：编译通过、写进存档、游戏里真的能打。三件事分开报告，不得互相冒充。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 同一候选在真实游戏完成至少一场完整战斗：抽牌/出牌/能量/目标/结束回合/敌人行动/胜利奖励，日志和截图可复核
- [x] #2 真实画面中手牌、血量/格挡/能量/敌人意图及中文可读可操作；与核心状态一致
- [x] #3 记录候选SHA、导入存档与runId；失败和脚本错误如实列出，CI/替身控件不能代替
- [ ] #4 同一实机战斗完成胜利奖励处理并回到地图，核心信息与状态一致；打击感精修不作为本项阻塞，历史已勾AC保持原样。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-23 M1并行收口：独立审计TASK29.2与41的已合修复、九状态及本轮真实证据；从15f62a6隔离工作树重建统一候选，复用scene-safe v2场景配置，独立读回源码/UI/结算载荷与场景；不自动开游戏，不混用历史候选验收。

并行develop41d7eca合入后复查退出与新横滑；257ba09探针实际发现旧卡片触摸误购，复用现有PR118最小修复，冻结b76b6cc重建并全检；不重复实现、不交付已知失败候选。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
原AC1构建/写副本拆至TASK-3.1，原AC2导入拆至TASK-3.2；实战仍M1必要关口。本轮主存档无战斗脚本/UI，未运行战斗，不勾选。

P0用户优先级覆盖既定串行排期，沿用任务避免重复建项。v4完整候选实机完成菜单→地图→出牌/敌人行动→胜利奖励/跳过→回图→商店离开并推进至15层Boss失败；v5用户确认HP/MaxHP、意图与受伤更新正常。原始截图/候选SHA及故障修复在docs/P0-SMOKE.md。本轮新日志仍缺，九状态未逐项实测，AC保持未完成。

本轮固定origin/develop=15f62a61ebd1635a93a5f1cc98cbcc4e6d2602dd。四个独立代理已领取离线审计；根未提交UI/theme/测试保留。新候选在.worktrees/m1-closeout构建。

2026-10-23并行证据审计已确认新日志345打印/4胜1败及失败结算重开，不再重复列为缺新日志。15f62a6已无冲突集成退出修复为76c93d7；16项退出/宿主/审计相关JS全过。初次完整check与集成重叠，旧布局缓存造成exitPanel缺失，记录失败、不计最终证据，固定集成源须重跑。

固定bbc6b09完整check实际exit0：JS697/579pass/118skip/0fail，全部Lua发现套件通过，Python16/15pass1skip。真实首版编译写副本及图载荷/场景挂载通过，但同源audit检出底图遗留red_slaver/sentry两AI模块，拒绝交付，保持失败证据并修构建清单。新提交只变builder/tests将再跑专项及最终SHA CI。

最终统一候选源12647ab已构建/同源审计通过：30模块逐byte匹配、1664树控件/max50、22节点启用结算图完整载荷匹配，静态0error/17warning，BGM关闭；独立场景+清单23断言通过，底图不变。交付.artifacts/m1-handoff-12647ab/abyss-m1-12647ab.gil，hash c7db532b36af66a2e1b6c516e23d4b7ae34d56d0b0414f38a391b08e8116fb0f。首次污染候选及失败审计保留；新候选未导入/实机/UI门禁，AC不外推。

最终组合b76b6cc独立46项通过；旧shop/relic/picker触点跨退出取消均拒绝，fresh正常。三项有限离线任务当前正确编号29.2/41/43均Done，手机38及手柄40未误改。

当前交付冻结源b76b6cc，文件.artifacts/m1-handoff-b76b6cc/abyss-m1-b76b6cc.gil，hash95d0b52996cd2204a314391a156f930045c5b8e3a81aa3c89e05da3eb0ee7920。30模块逐byte同源、1664控件、22节点完整载荷，0静态error/17既有warning，独立场景/清单23项通过，原底图不变。仅编译/副本/离线审计通过，未导入/实机/UI门禁；原126历史副本和257误购失败版均保留。

2026-10-24同候选5165实机最小战斗三AC已有独立16图/64打印证据：官方save1838，run9bb0abe3，日志hash9190f386685e52c16bd66f9781e637a7859a51b15e2e0e22b0b00f1add9953c8，ready1/victory1，HP80到74到73到战后79、金币99到114、奖励卡组10到11、格挡5抵消6攻击只伤1、易伤2与虚弱2到1、点选/拖牌和敌回合均可复核。该900秒run末自动中断不作为主动退出成功；后续短run8f623503在17.3秒主动结算有独立日志证明。完整九状态等必要依赖未完成，本TASK保留InProgress，M1不整体关闭。详情docs/M1-LIVE-ACCEPTANCE.md及结构化证据。
<!-- SECTION:NOTES:END -->
