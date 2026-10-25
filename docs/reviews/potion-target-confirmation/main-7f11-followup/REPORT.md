# 药水目标确认：主线复核与最小补丁

基线：`7f11cc2f589b676d10a494edd6b79f1167254c63`，游戏实现：`951c2bb47bda3ce62d66272447bb4eb81ecdd624`。2026-10-24 18:28 UTC 只读复查，develop仍为该基线。

## 结论

主线已实现“先瓶后明确选敌”、库存/回合/对象失效、取消、独立说明入口及状态文案。旧`4154e321`候选的大部分功能已被替代，不应整包合入或覆盖主线说明。本次只补两处输入归属缺口，不改变药水数值、事务、文案、布局或当前EndDrag取消语义。

1. 首次敌人事件只有Up或EndDrag，随后Click：主线尚未记录敌人已使用指针事件，因此误走click-only降级，实际消费火瓶并造成20伤害。
2. 结束回合Down或Down→Up发生在选瓶之前，Click延后到新瞄准之后：旧动作仍推进回合。建立新瞄准时未清空旧action token。

最小生产差异仅`src/lua/abyss_battle_ui.lua`新增2行：`releaseEnemy`入口记录`enemyPointerObserved`；建立新瞄准前调用`cancelActionInputs()`。另新增7组独立回归`tests/lua/potion_target_input_ownership.lua`。标准补丁为`minimal.patch`，基线`git apply --check`退出0。

## 本轮实跑

- 新7组：未修主线3通过/4失败；最小候选7/7通过。4个红例来自上述2类根因。
- 独立自然获取probe18组：主线15通过/3失败；候选18/18通过。火瓶经seed4真实战斗和领奖取得，再通过Run.startCombat进入small_slimes；不是完整地图或平台实机证据。
- 两次mutation分别撤销一处修复，均准确回到5通过/2失败；另一处对应回归仍通过。
- 候选既有16个Lua文件174组通过，另加新7组和probe18组，本轮候选Lua合计199组通过。Node布局12组通过。
- 明确保留：当前目标EndDrag取消后必须重新选瓶；纯Click宿主、Down→Click无Up宿主；同槽同ID真实丢弃/补回不能继承旧手势；旧卡牌token不干扰新瞄准；真实事务溢出与演出准备失败均原子拒绝，重新选瓶/选敌后可成功。

既有Lua范围：potion_targeting(12)、potion_status_rules(10)、battle_ui_potion_gestures(9)、battle_ui_potion_ownership(9)、battle_ui_potion_compatibility(11)、battle_ui_potion_independence(2)、battle_ui_action_gestures(8)、battle_ui_action_ownership(8)、battle_ui_click_ownership(11)、battle_ui_gestures(11)、game_ui_potion_discard(10)、potion_reward_effects(6)、potion_reward_atomic(4)、potion_slots(6)、potion_discard(4)、battle_ui(53)。

证据：`targeted-main-red.log`、`targeted-candidate-green.log`、`probe-main.log`、`probe-candidate-green.log`、`mutation-no-enemy-observed.log`、`mutation-no-action-cancel.log`。独立probe及fixture保留为`probe.lua`、`natural_fixture.lua`；未套用旧39组的字段或取消协议断言。协调者另独立重跑新7组，结果7/7。

## 身份与边界

按最新Git树逐blob校验1073个已物化源文件；271个与本次验证无关的资产/历史证据未物化，不宣称完整仓库归档。候选仅上述2个owned文件不同。生产UI SHA256：`84472890e0c7992c9879ed2db6e3f63991a9b07e9f164573b3d846fa762041e0`；新增测试：`dcf448631e06f2254121fa61a9b092ce921edd3ec367cf84617d606509829cf7`；补丁：`3bd2fc472ecf23b15e394e5058090c08d5688de094bc5d9c055991dc18bd89a4`。

全部本轮Lua使用现有native liblua5.4 runner，不代表Fengari预算或完整npm检查通过；未运行被禁止的完整npm命令，未安装依赖，未使用用户Codex。未官方导入、未验证物理输入/手机、未发布、未合并、未改变Backlog认领或验收。主线既有完整检查记录归属951c2bb，不借用于此新补丁。PR193/194不在本次交付范围，不能据此称已合并。
