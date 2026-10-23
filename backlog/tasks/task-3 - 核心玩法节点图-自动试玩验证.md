---
id: TASK-3
title: P0 完整游戏集成冒烟（构建/副本导入/实机最小闭环）
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:32'
updated_date: '2026-10-23 13:00'
due_date: '2026-10-24'
labels: []
milestone: m-2
dependencies:
  - TASK-8
  - TASK-9
  - TASK-10
  - TASK-11
priority: high
ordinal: 1
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
对已完成的战斗系统做三层分离验证：编译通过、写进存档、游戏里真的能打。三件事分开报告，不得互相冒充。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 完整游戏客户端Lua与原生UI构建、静态检查通过并写入独立测试存档副本，保留构建日志
- [x] #2 测试副本可导入为新存档，编辑器可打开，正式存档未修改
- [ ] #3 实机跑通启动→地图选路→战斗出牌→敌人行动→胜利奖励→返回地图，截图与客户端日志无阻断故障
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
同步最新develop并构建完整游戏，仅导入测试存档副本；验证启动、地图、战斗、奖励回图最小闭环；记录截图日志、修复并回归；自动化受阻转现有人工流程。

2026-10-23恢复实机：以冻结61425e4及其hash为首轮，记录新增存档、源文读回、首战奖励回图及新日志；并行准备TASK2配置副本、TASK11.1状态方案、TASK12.3节点账本。通过证据逐项收M1，不把既有离线完成或历史v4-v6等同本轮通过。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
P0 2026-10-23：基线 origin/develop 77744e2；独立修复分支 fix/p0-integration-smoke，.worktrees/p0-integration。完整18模块和控件树已写工作区副本 .artifacts/p0/mcp-workspace/scenes/saves/abyss-p0-full-game.gil，MCP scene_check_client 0 errors/9自定义方法warnings。实际发现并修复地图单容器超60子控件导致完整导入被拒：分组并更新控制器/回归。npm run check通过（125 JS pass/6 skip，Lua全通过，13 Python/1 skip）。官方导入run 1dcd9bd1-4bd5-4ee7-b749-212faba58cbb在14秒报无法切前台，无实机截图/日志，未勾选AC；已转人工导入。

人工实测更新：用户已导入首版，list_maps确认新增测试存档1073741828 abyss-p0-full-game；用户截图menu-broken.png显示顶部其他面板透出、说明为空，点启程无响应。已读取沙箱日志窗口，存在abyss_map_…客户端错误，详情待展开。官方Color API带静态方法，已用可调用对象复现原function断言中断初始化；修复类型限制、非菜单面板默认隐藏并补回归，第二版完整副本 .artifacts/p0/abyss-p0-v2.gil 已写，hash C2DC61791A6DA56C247A3FA660FD645A9A5ED2D516B47EAB8D98CED38CED7470；等待实机复验。

正式实机日志现已取到并归档：.artifacts/p0/official-first-fault.gia / .json；2026-10-23_06-29-31，第1秒 abyss_map_ui:23 map UI needs client Color and imageSource，调用 abyss_game_ui:18→abyss_ui:11 OnStart。确认启动断言中断而非正常菜单或仅鼠标焦点问题。原始日志SHA256 0fdaed600a95cd30a2842cb4f962488a09faf7508994552332d45f441e96fc83。第二版待实际重跑。

第二版人工复验失败：顶部串画面消失，但说明仍为空且启程无响应；用户截图 .artifacts/p0/menu-v2-broken.png。MCP确认导入为新测试存档1073741829 abyss-p0-v2，external_lua_file已核对新版Color修复存在。该新存档日志订阅清空（沙箱显示暂无日志），已请用户在新版重新订阅客户端脚本后重试；未用首版旧日志充作第二版错误。

用户要求错误转机制：第三版将模块加载/初始化/更新纳入保护，测试界面直接显示异常并隐藏无响应按钮，已由用户截图实测通过诊断。实际错误 SetImage(3 expected, got4) 已定位为地图 icon:SetImage(source,assert(id,message)) 的Lua多返回值展开；严格SetImage替身成功复现旧代码失败，修复局部iconId后正在完整检查/第四版构建。自动构建入口--playtest始终clientScriptLog:true，新增本轮目录/日志时间/ready/异常证据门禁与7类失败注入；不再把每次手动开日志交给用户。自动订阅路径受Windows阻断尚未实机通过，如实保留。

修复已保存本地提交 acec3d3，分支现为 feat/p0-integration-smoke，工作树仍 .worktrees/p0-integration。第四版 .artifacts/p0/abyss-p0-v4.gil，SHA256 CF3EF983BB210350E95241E3CA9521EE0B453B53FEE6335DE671E4BB4D06D5D5。npm run check实际通过：126 JS pass/6 skip，Lua含地图15项/宿主6项全部通过，13 Python/1 skip。完整候选写入与静态检查通过；用户正在重跑真实菜单进入地图，尚未宣称最小闭环通过。

第四版用户实机确认：已进入地图，可以选路；截图menu-v4-working.png证明菜单说明已显示、顶部无串画面。Color初始化断言及SetImage多返回值启动阻断现已实机跨过。正在首战/敌人行动/奖励回图最小闭环，不提前勾选AC3。

主Agent直接截屏新增真实证据 first-battle-victory-v4.png：第四版已到战斗胜利/三选一卡奖励，生命80/80、金币114，奖励横幅金币+15，三张奖励卡与中文说明可见。仍待领取回图及敌人行动明确确认。画面战斗标题残留“战斗演练”列为文案缺陷，不把整个完整游戏当实验。

实机标题“战斗演练”已在源码修成“杀戮深渊·战斗”，不要求用户为小文案重新导入或重置当前真实运行；下一候选统一纳入。当前继续使用hash CF3E…第四版追踪。

真实最小闭环功能现已由用户连续多战/奖励/商店及15层到Boss失败摘要证实；失败重开用户亦确认正常。继续区分证据：本轮新客户端日志仍在查找，尚不关闭含日志要求的AC3。

第五版已构建：HP/MaxHP、名称、格挡、状态、牌类型原生短框恢复到theme40高；敌人意图紧凑数值，点选才显示完整修正说明；商店五卡货架+独立价格。完整check 129 JS pass/6 skip、Lua battle20等全过、Python13/1skip，MCP静态0 errors/9自定义方法warnings。v5 hash0472AA395B919F9197CCDD483033AB9E1FDD9FB51F3237DD65F0BDCA71A6BCFC，待实机复验。用户明确要求跨屏按Opus稿还原/成本可控；已完成PLATFORM_PARITY逐屏缺口审计，新增verify:ui候选hash/批准稿/实机截图/关键字段门禁与失败注入，当前故意不通过验收。未恢复非必要开发。

第五版用户实机复验明确通过：生命数字与意图正常，受伤会更新。P0具体HP/MaxHP缺失与意图截断两项现已实机修复通过。商店五卡货架仍待实机。用户无需再手动开日志，界面自诊断已在第三版实际定位原生参数错误。

本轮实机恢复：用户已进入沙箱并导入61425e4，list_maps只读确认新测试存档1073741835。导入gil及external_lua_file的32模块均与冻结副本匹配（仅BOM/换行规范化），report位于.artifacts/live-acceptance-61425e4/import-readback/report.json；导出副本hash仍af2e1060c40d1eb9e6f9f2a017384c2cd590bf1867178d2d829984da9ac8b5cc。实时截图见首场战斗：80/80生命、2/3能量、5格挡、两敌意图3和5。首战完成、奖励回图、本轮新日志仍待证据，未勾AC。SESSION.md记录本轮身份及状态；根任务为旧本地版本，仅追加本轮证据、不覆盖历史拆分。

用户本轮人工确认：61425e4菜单正常，点击启程已进入地图。继续验首战取胜、选牌回图、第二场首次出牌；预期首战金币99→114、选1卡卡组10→11。尚无完整首战及新日志证据，AC保持未新增勾选。

2026-10-23用户反馈：还行吧，我已经玩起来了。记为当前61425e4实际游玩确认；未提供首战奖励/第二战/具体数值结论，不据此勾选完整闭环AC。本次只读截图因原神未在前台而未执行，无新截图，不把该情况当作游戏故障；新日志目录仍仅有历史文件。
<!-- SECTION:NOTES:END -->
