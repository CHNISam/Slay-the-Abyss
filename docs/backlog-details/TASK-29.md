# TASK-29 开发附件

任务首页只保留好理解的目标。下面保存原始技术要求、执行方案和已有证据；这些要求继续有效，开发时须一并遵守。


## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
复用批准稿主题参数与同步核心，增加只读表现队列及原生UI基础反馈。M1立即实现本地闭环；平台验收衔接TASK-3.2导入与TASK-3实战。M4精修继续由TASK-4承接。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 真实出牌命令驱动攻击飞牌、命中/飘字/血条，格挡获取与吸收、状态、死亡和胜负过渡；本地控件集成可复核
- [x] #2 敌方回合按行动者和意图顺序展示，多段/多敌/群体/持续伤害/反伤不跳过
- [x] #3 自动回归验证规则结果与RNG不变、事件仅消费一次、输入恢复及表现故障恢复；控件复用有界；npm run check和CI通过
- [ ] #4 同一候选经TASK-3.2导入后完成TASK-3基础反馈实机截图/日志或录像；音效编号及听感以平台验证为准，未验证明确记录
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 保留核心同步事务，补齐有序只读表现事件与轻量状态快照，复用已有主题时序。2. 原生UI增加复用的飞牌/命中/盾牌/飘字/血条残影/震动/死亡和回合横幅，host等队列结束才切结果。3. 真实Run命令集成测试覆盖三主场景及多段、多敌、群体、状态、反伤、胜负、故障和重入；比较完整规则状态和RNG。4. npm run check、独立代码自审和CI后提交PR，符合门禁集成develop；构建同SHA存档副本，衔接TASK-3.2/TASK-3实机，未验证分层记录。

2026-10-23 用户确认选型并授权合并：普通攻击接A3=40313，死亡接D1=20092；A6保留岩系候选，D2/D3待按类型降音量复听。保留原生试听工具与会话证据，修复缩放参数并显示联动组合；全量检查、复核diff、当前SHA CI全绿后squash合develop。只改表现绑定，不写正式存档，实机AC保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
真实Run命令的攻击/格挡/敌回合、群体、多段多敌、中毒/荆棘、死亡及宿主过渡回归通过；6种子序列比较运行状态与RNG。准备/控件/音效故障、重入、切局与消费帧释放均有回归。保持In Progress：同候选平台实机与音效听感未验。整体变更复核已按large-change-review完成，发现并修复药水槽被快照重建、准备失败后重绘与切局残留等边界。

最新代码ca202b8ca57a459f97b220db4cc57e5463b9f2c5，本地npm run check通过（JS180通过/14权限相关跳过，Lua189通过，Python12通过/1跳过）；正式Quality 39880758640的check/presentation均success。PR52。实际候选20Lua模块静态0错误/12自定义方法警告，结算图22节点/编辑器计数72编译写副本通过。候选SHA256 DB50892159B6F2FB3C059E3EBC1285BC451893E84EA448E873050F3BE53E7C24。首次playtest_start返回DESKTOP_BUSY（美术工作树正在使用GUI），未启动导入或试玩，不抢占。

实际官方自动试玩run 49a81efb-1911-404b-922f-35001a793e82于18秒failed：无法把窗口切到前台game；steps空，无本轮日志/截图/录音，官方导入未证实，不勾AC4。按既有P0流程不循环重试焦点。可手动导入候选F:/New folder/.worktrees/combat-feedback/build/abyss-feedback-ca202b8.gil；源码/证据层次与M4缺口见docs/COMBAT_FEEDBACK.md。

2026-10-23用户已实际导入并明确确认：攻击、格挡、敌方逐次行动三种反馈都看到了，音效尚未确认。MCP list_maps复读新官方存档1073741834、名称abyss-feedback-ca202b8。20个external_lua_file文件与交付代码仅差官方增加的UTF-8 BOM，去除BOM后全部内容一致。当前截图build/feedback-platform/captures/3c0ebc2e-72e6-4022-b74e-fb3ebc2bc13f.png显示真实战斗胜利及三卡奖励（生命80/80、金币114、本场+15），是静态结果证据，三项动态反馈以用户现场确认为准。音效、完整多设备/性能和特殊场景实机未验；没有新日志，仍只有06:29旧故障日志，不冒用。AC4与状态保持未完成。

本轮选型接入：Theme.sound.hit=40313、enemy_die=20092；A6和D2/D3分型方案保留记录，暂不绑定。新增可重建的独立原生试听工具，三参数缩放回归及联动组合可见；无CMD依赖，未写正式存档。npm run check退出0：JS746项/628通过/118既有条件skip/0失败，全部Lua通过，Python17项/16通过/1既有权限skip；专项8项通过。自审确认runtime改动只有两个表现ID、BGM仅更新已试听状态，不改规则/RNG。完整游戏新音效混音/连续播放及UI实机AC继续保留。

PR121门禁补充：c5c0ee5首次CI因Git TLS/earlyEOF未进测试；后两次分别在既有game_ui 15秒及battle_ui 30秒预算超时。保留断言与其他脚本15秒上限，只将两重型UI默认预算改为30/60秒，显式调用timeout仍优先。Lua runner错误传播/有限超时与试听工具7项通过；两重型用例复跑battle_ui 51项/30.08秒、game_ui 15项/13.18秒全部通过。此为测试执行预算，不代表性能验收通过。

a77fee0的CI已通过battle/game UI，但又在encounter_coverage旧15秒预算超时，连续三种不同脚本说明不能只逐个补UI例外。最终统一独立Lua脚本30秒、完整battle树60秒，显式timeout仍优先，CLI增加逐脚本耗时。未删/改任何断言，整作业超时仍保留，不计性能验收。错误传播/显式200毫秒超时/首错停止/试听回归7项通过；encounter覆盖23敌人54意图18遭遇、105组在5.60秒通过。最终新SHA需重新跑CI全绿再合并。

2026-10-24路线图：现有已勾本地AC及记录保留；剩余表现实机AC归M4，不阻塞M1基础战斗。
<!-- SECTION:NOTES:END -->
