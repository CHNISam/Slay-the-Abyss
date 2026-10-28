# Run 状态与接续职责治理

## 当前组合

当前离线组合以 develop `cec690c1` 和 Nodes `c5974acf` 为基准，保留最新批准稿界面、上游原10组class-choice两片回归、全部UI与Nodes门禁。所有Run生产源码与已审远端 `ebb143f9` 相同；该远端独立提交修正的任务身份TASK-74.4也已保留，没有覆盖其他执行者的记录。

本组合16项政策/API测试、Backlog检查通过；架构240模块/1351边；原生静态936个受门禁测量，60条明确历史告警、零新增。Run158与Nodes167项实测最大15，两个主文件602/670行。重新构建离线UI夹具后，Run旧新完整状态图/双向别名/RNG/返回值差分10检查点通过，奖励来源/所有权守护回归通过。日志为忽略目录run-cec-differential.log和run-cec-owner-guards.log，未操作前台或客户端。当前正式PR还需实际Nodes合入基准上的精确SHA Full CI，不把下述旧组合或旧头成功当成当前通过。

## 432基准组合复核

基于 develop `432eebb1` 与 Nodes 待合版本 `2a1a7bd` 的组合已离线复核。Run 全部生产源码与已审 `261ff804` 字节一致；其它生产 Lua 与 Nodes 版本一致。共享配置保留最新 Node UI/Nodes 全部门禁，仅追加 Run 职责。以下早期基线报告的全仓数量由本节更新：架构239模块/1345边；原生静态936个受门禁测量，60条明确历史告警、零新增；Run158和Nodes167项测量均≤15，两个主文件分别602/670行。16项预算/API/AST政策测试通过。

当前组合的接续、结算、事件战斗、出牌事务和快照归属等10项Node测试最终均通过，内含Nodes72个基线差分场景。首次组合命令9/10通过，奖励所有权项因本地缺生成的theme/layout测试夹具失败；补齐已有build:ui夹具后仅重跑该项通过，未改断言或运行限制。Run另10个旧新完整状态图/别名/RNG差分检查点通过。原始失败与重跑日志均保留在忽略目录 `.artifacts/run-nodes-governance/rebased-*`。没有客户端、前台输入或实机验证。最终PR基准/头与远端Full CI以集成交付证据为准，不能复用旧基准的CI成功。

基线 `1f260a71972b03dae5b63e8d6f12d055973a4c83`：abyss_run.lua 1312物理行，Luacheck 96个测量（含主块）最大复杂度57；初始化44、跨幕回调40、房间进入57、Heart owner49、结算34、药水使用40。基线源码LF SHA256为 `a147a8b632813d6d419f2a1742c866088a88704a1e1ea416702619c41efe188a`。

初始化/目录归属、跨幕接续、房间构造/检查点、结算/永久变化、药水提交分别提取。installer只注册同一个公开API表，私有helper不进入Run API；跨职责调用继续读取该表，保持调用替换及错误注入能力。初始化、边界检查、来源选择、结果发布分别命名并测量，不把热点原样挪到另一个文件。

总控复核修正事件战斗桥服务引用：EventCombat.start接收公开Run，保留事件准备、战斗和奖励依赖。第四幕Boss工厂返回nil时仍通过原roomStreams/startEncounter边界返回false,'unknown_encounter'，没有提前换成无理由拒绝；专项断言及基线差分覆盖。第三/四幕现有代码同样保留并做兼容回归，本次不改变章节范围。

## 门槛与测量

固定Luacheck 1.2.0，Windows二进制SHA256 `0f1c69c4d09f1ebb4d8df14c215e4553e2e639bd4cb7bf3c639b0daa6198317b`。主文件≤1000物理行；整个主Run、本轮模块、既有potion_candidate与未来Run helper每函数≤15。既有独立目录/seed/red-card职责未改，没有借本轮宣称它们已治理。

`npm run check:lua-static` 生成build/lua-complexity.json、responsibility-complexity.json、module-size.json；AST逐函数对应原生工具坐标，缺测量失败。最终Run 158项测量（含7主块、installer、匿名函数），最大15，主文件602行/max14。全仓无新增静态诊断，保留73条明确历史告警，所有受门禁职责576个测量；架构225模块/1286边通过。

## 行为证据

新增tests/lua/run-governance.lua覆盖嵌套拒绝毒化、异常不提交、成功交易图别名、房间构造、无效出牌原引用、受控结算与奖励单领、地图返回/重开奖励引用、第一至第二幕UID/生命/随机游标连续、禁止第三幕，以及缺失历史终局工厂的原错误。tests/run-governance.test.mjs固定全部53个公开方法名与具名参数。

最终新增回归10/10检查点通过；额外差分加载基线源码API与当前API，10/10通过，递归比较完整状态图、返回值、所有RNG与双向别名映射；不把第二份大生产实现提交进测试。基线写入忽略目录build/run-governance-baseline.lua：使用Node execFileSync('git',['show','<baseline>:src/lua/abyss_run.lua'])原始字节保存。运行：

```powershell
node node_modules/fengari-node-cli/src/lua-cli.js -e "RUN_GOVERNANCE_REFERENCE='build/run-governance-baseline.lua';dofile('tests/lua/run-governance.lua')"
```

已通过现有定向回归：

- run.lua 8；event_combat_bridge.lua（构造/所有者/奖励/回滚/烟雾）；inventory.lua当前原分片2，不代表完整库存验收。
- run_turn_reward_rollback、_choice、_retain各2；run_play_transactions 5；run_play_snapshot_owner 9。
- cross_act_checkpoint 3；cross_act_potion_reset 2；competition_two_act 7。
- potion_reward_atomic 4；reptomancer_run_reward_rollback 2；run_room_misc_ownership 2。
- run_prepared_v4_compatibility、run_prepared_profiles_compatibility；ending_route_api 3；ending_route_contracts 5；ending_proceed_nodes 4。
- 总控运行原四项语义变异，4/4 killed_by_assertion；报告build/test-strength/4796a46c-3721-4cc8-b980-928c635efe50/report.json。M4只迁移路径和缩进，原语义/断言不变。
- 行数/完整预算负对照、诊断解析、53项API契约共4个Node测试通过；总控的工程复杂度政策回归11项通过。

competition_two_act有一次并发验证时按原30秒限制超时，前5项通过而整文件未通过，此失败保留。暂停其它重进程后原限制独占重跑7/7通过，22.223秒；没有增加超时、删断言或改原切片。

这是离线源码/受控回归证据。未生成候选、未导入客户端、未取得本轮ready、未做自然玩家通关或实机UI验收；没有使用鼠标键盘。完整当前SHA的Quality仍须独立通过，本切片不合并PR。

## 发布清单调用链适配

PR308在bf897616的完整CI发现发布清单仍要求Run直接require encounter_queue/room_encounters，而实际职责已经提取。原失败日志保留于 `.artifacts/run-nodes-governance/pr308-bf-posix2.log`。没有向生产模块补无用require，也没有删去旧依赖链或放宽门禁。

验证器与launch-content.json同步真实边界：Run facade要求本轮五个helper；initialization/transition要求encounter_queue；rooms要求encounter_queue与room_encounters；settlement/potions要求combat。旧Nodes→Run、room_encounters/combat→encounter_formation、formation/queue→sts_random链保持原样。profiles.encounters.entryPoints仅追加五个真实helper，全部旧入口保留；玩法、数值、渠道和验收状态均未改变。

原依赖校验抽出为validateLaunchRuntimeModules，正式入口继续读取实际Lua源码、实际candidateScriptFiles打包发现集合和真实profile入口，精确核对关系及每条require。五个新增负例组逐helper拒绝清单漏项、打包漏项、源码文件缺失、profile入口缺失，以及facade/helper真实require删除和清单依赖边删除。

完整 `node --test tests/launch-content.test.mjs` 27/27通过（原22项+5组负例），零跳过、20.854秒；包含实际Lua支持池与完整发布检查。verify:backlog、check:syntax、check:architecture（225模块/1286边）、check:lua-static（576测量/73条历史告警、零新增）通过。完整基线diff-check通过。没有运行其它Lua重例、前台或实机；当前SHA远端Quality仍另验。


## 原生逐函数报告

以下含主块和所有命名/匿名函数，位置为Luacheck原始file:line:column；阈值均为15。先列各文件物理行/测量数/最大复杂度：

| 文件 | 物理行 | 测量数 | 最大复杂度 |
|---|---:|---:|---:|
| abyss_run.lua | 602 | 66 | 14 |
| abyss_run_initialization.lua | 134 | 7 | 12 |
| abyss_run_transition.lua | 80 | 8 | 13 |
| abyss_run_rooms.lua | 341 | 31 | 15 |
| abyss_run_settlement.lua | 257 | 19 | 15 |
| abyss_run_potions.lua | 187 | 14 | 14 |
| abyss_run_potion_candidate.lua | 127 | 13 | 10 |

| 位置 | 函数/主块 | 复杂度 |
|---|---|---:|
| abyss_run.lua:1:1 | main chunk | 1 |
| abyss_run.lua:12:7 | function 'find' | 3 |
| abyss_run.lua:21:7 | function 'nestedTransaction' | 9 |
| abyss_run.lua:32:1 | function 'M.transaction' | 10 |
| abyss_run.lua:56:1 | function 'M.freezeMapContext' | 1 |
| abyss_run.lua:57:1 | function 'M.mapContext' | 1 |
| abyss_run.lua:63:7 | function 'relicDefinition' | 5 |
| abyss_run.lua:68:7 | function 'cardDefinition' | 4 |
| abyss_run.lua:71:7 | function 'amount' | 5 |
| abyss_run.lua:72:1 | function 'M.gainGold' | 1 |
| abyss_run.lua:73:1 | function 'M.eventDamage' | 6 |
| abyss_run.lua:76:30 | function | 4 |
| abyss_run.lua:81:59 | function | 1 |
| abyss_run.lua:88:1 | function 'M.eventNormalDamage' | 1 |
| abyss_run.lua:93:1 | function 'M.heal' | 5 |
| abyss_run.lua:100:1 | function 'M.increaseMaxHp' | 4 |
| abyss_run.lua:106:1 | function 'M.decreaseMaxHp' | 9 |
| abyss_run.lua:117:7 | function 'validateCardOptions' | 11 |
| abyss_run.lua:125:1 | function 'M.prepareCard' | 7 |
| abyss_run.lua:138:7 | function 'applyOfferedUpgrades' | 8 |
| abyss_run.lua:149:1 | function 'M.commitCard' | 1 |
| abyss_run.lua:150:30 | function | 13 |
| abyss_run.lua:175:1 | function 'M.obtainCard' | 1 |
| abyss_run.lua:176:30 | function | 2 |
| abyss_run.lua:182:1 | function 'M.removeCard' | 1 |
| abyss_run.lua:183:30 | function | 5 |
| abyss_run.lua:193:7 | function 'publishCombatRelic' | 10 |
| abyss_run.lua:206:1 | function 'M.obtainRelic' | 1 |
| abyss_run.lua:207:30 | function | 10 |
| abyss_run.lua:222:24 | function | 5 |
| abyss_run.lua:227:21 | function | 4 |
| abyss_run.lua:235:7 | function 'relicContextOwners' | 9 |
| abyss_run.lua:250:1 | function 'M.prepareRelic' | 10 |
| abyss_run.lua:269:1 | function 'M.rewardOptions' | 3 |
| abyss_run.lua:274:1 | function 'M.claimCardReward' | 9 |
| abyss_run.lua:280:39 | function | 4 |
| abyss_run.lua:304:7 | function 'validGold' | 5 |
| abyss_run.lua:309:1 | function 'M.claimRelicReward' | 1 |
| abyss_run.lua:310:30 | function | 10 |
| abyss_run.lua:322:1 | function 'M.claimEmeraldKey' | 1 |
| abyss_run.lua:323:30 | function | 1 |
| abyss_run.lua:325:1 | function 'M.canClaimEmeraldKey' | 1 |
| abyss_run.lua:327:1 | function 'M.claimGoldReward' | 8 |
| abyss_run.lua:336:1 | function 'M.claimStolenGoldReward' | 11 |
| abyss_run.lua:348:1 | function 'M.leaveCombatRewards' | 4 |
| abyss_run.lua:359:1 | function 'M.reopenCombatRewards' | 4 |
| abyss_run.lua:367:1 | function 'M.claimPotionReward' | 10 |
| abyss_run.lua:385:1 | function 'M.skipPotionReward' | 5 |
| abyss_run.lua:393:7 | function 'syncBattlePotions' | 9 |
| abyss_run.lua:409:1 | function 'M.chooseCard' | 4 |
| abyss_run.lua:414:34 | function | 5 |
| abyss_run.lua:433:7 | function 'replayCommand' | 14 |
| abyss_run.lua:445:1 | function 'M.play' | 5 |
| abyss_run.lua:453:34 | function | 7 |
| abyss_run.lua:476:1 | function 'M.chooseDiscard' | 5 |
| abyss_run.lua:488:1 | function 'M.choosePile' | 5 |
| abyss_run.lua:501:1 | function 'M.chooseScry' | 5 |
| abyss_run.lua:514:1 | function 'M.chooseHand' | 5 |
| abyss_run.lua:527:1 | function 'M.endTurn' | 4 |
| abyss_run.lua:530:34 | function | 5 |
| abyss_run.lua:549:1 | function 'M.choosePotionStance' | 8 |
| abyss_run.lua:553:31 | function | 4 |
| abyss_run.lua:574:7 | function 'permanentUpgradeContext' | 6 |
| abyss_run.lua:587:1 | function 'M.canUpgradeCard' | 3 |
| abyss_run.lua:593:1 | function 'M.upgradeCard' | 1 |
| abyss_run.lua:594:30 | function | 3 |
| abyss_run_initialization.lua:1:1 | main chunk | 1 |
| abyss_run_initialization.lua:13:1 | function 'M.install' | 1 |
| abyss_run_initialization.lua:16:11 | function 'prepareProfile' | 9 |
| abyss_run_initialization.lua:41:11 | function 'prepareCatalog' | 11 |
| abyss_run_initialization.lua:53:11 | function 'finishCatalog' | 7 |
| abyss_run_initialization.lua:68:11 | function 'initializeRelicPool' | 9 |
| abyss_run_initialization.lua:82:5 | function 'Run.new' | 12 |
| abyss_run_potion_candidate.lua:1:1 | main chunk | 1 |
| abyss_run_potion_candidate.lua:8:1 | function 'M.eventRestricted' | 10 |
| abyss_run_potion_candidate.lua:15:7 | function 'combatEligibility' | 9 |
| abyss_run_potion_candidate.lua:23:7 | function 'eligibility' | 5 |
| abyss_run_potion_candidate.lua:29:7 | function 'definition' | 8 |
| abyss_run_potion_candidate.lua:39:7 | function 'potionEffects' | 8 |
| abyss_run_potion_candidate.lua:51:7 | function 'smokeRestriction' | 8 |
| abyss_run_potion_candidate.lua:59:7 | function 'outsideGeneration' | 4 |
| abyss_run_potion_candidate.lua:74:7 | function 'outsideHealth' | 3 |
| abyss_run_potion_candidate.lua:82:7 | function 'outsideCandidate' | 7 |
| abyss_run_potion_candidate.lua:94:7 | function 'combatCandidate' | 5 |
| abyss_run_potion_candidate.lua:98:34 | function | 4 |
| abyss_run_potion_candidate.lua:114:1 | function 'M.prepare' | 6 |
| abyss_run_potions.lua:1:1 | main chunk | 1 |
| abyss_run_potions.lua:9:1 | function 'M.install' | 1 |
| abyss_run_potions.lua:12:5 | function 'Run.potionCapacity' | 2 |
| abyss_run_potions.lua:15:5 | function 'Run.potionCount' | 3 |
| abyss_run_potions.lua:23:5 | function 'Run.obtainPotion' | 9 |
| abyss_run_potions.lua:41:5 | function 'Run.discardPotion' | 13 |
| abyss_run_potions.lua:58:11 | function 'potionCandidate' | 1 |
| abyss_run_potions.lua:62:11 | function 'commitOutsidePotion' | 9 |
| abyss_run_potions.lua:77:11 | function 'stagePotionBattle' | 14 |
| abyss_run_potions.lua:97:11 | function 'escapePotionBattle' | 8 |
| abyss_run_potions.lua:105:45 | function | 1 |
| abyss_run_potions.lua:117:5 | function 'Run.usePotion' | 14 |
| abyss_run_potions.lua:154:11 | function 'potionAvailability' | 8 |
| abyss_run_potions.lua:168:5 | function 'Run.potionView' | 10 |
| abyss_run_rooms.lua:1:1 | main chunk | 1 |
| abyss_run_rooms.lua:13:1 | function 'M.install' | 1 |
| abyss_run_rooms.lua:15:11 | function 'encounterEnemies' | 12 |
| abyss_run_rooms.lua:44:11 | function 'configureSourceRoom' | 4 |
| abyss_run_rooms.lua:54:35 | function 'options.encounterBoundary.misc.boolean' | 1 |
| abyss_run_rooms.lua:55:33 | function 'options.encounterBoundary.misc.integer' | 1 |
| abyss_run_rooms.lua:58:33 | function 'options.encounterBoundary.visualFloat' | 1 |
| abyss_run_rooms.lua:63:11 | function 'configureEncounterOptions' | 5 |
| abyss_run_rooms.lua:75:11 | function 'validateEncounter' | 11 |
| abyss_run_rooms.lua:86:11 | function 'startEncounter' | 10 |
| abyss_run_rooms.lua:104:31 | function 'options.beforeOpeningDraw' | 3 |
| abyss_run_rooms.lua:111:33 | function 'options.beforeFirstTurn' | 5 |
| abyss_run_rooms.lua:141:5 | function 'Run.startCombat' | 1 |
| abyss_run_rooms.lua:145:5 | function 'Run.roomStreams' | 1 |
| abyss_run_rooms.lua:152:5 | function 'Run.prepareEventEncounter' | 1 |
| abyss_run_rooms.lua:156:5 | function 'Run.startEventCombat' | 1 |
| abyss_run_rooms.lua:157:36 | function | 1 |
| abyss_run_rooms.lua:162:11 | function 'endingQualified' | 11 |
| abyss_run_rooms.lua:168:11 | function 'endingBoss' | 13 |
| abyss_run_rooms.lua:180:11 | function 'endingRoom' | 13 |
| abyss_run_rooms.lua:189:11 | function 'resolveAct3Boss' | 6 |
| abyss_run_rooms.lua:200:11 | function 'resolveAct2Boss' | 5 |
| abyss_run_rooms.lua:210:11 | function 'resolveBoss' | 11 |
| abyss_run_rooms.lua:229:11 | function 'resolveEncounter' | 10 |
| abyss_run_rooms.lua:250:11 | function 'validateRoomBoundary' | 11 |
| abyss_run_rooms.lua:260:11 | function 'validateRoom' | 11 |
| abyss_run_rooms.lua:270:5 | function 'Run.startRoomCombat' | 14 |
| abyss_run_rooms.lua:298:5 | function 'Run.snapshotEncounters' | 1 |
| abyss_run_rooms.lua:302:11 | function 'checkpointFields' | 7 |
| abyss_run_rooms.lua:307:11 | function 'validateCheckpoint' | 15 |
| abyss_run_rooms.lua:320:5 | function 'Run.restoreEncounters' | 12 |
| abyss_run_settlement.lua:1:1 | main chunk | 1 |
| abyss_run_settlement.lua:15:1 | function 'M.install' | 1 |
| abyss_run_settlement.lua:18:11 | function 'combatEndHealing' | 6 |
| abyss_run_settlement.lua:27:11 | function 'heartBattle' | 14 |
| abyss_run_settlement.lua:36:11 | function 'heartFlow' | 13 |
| abyss_run_settlement.lua:44:11 | function 'heartEnemyList' | 6 |
| abyss_run_settlement.lua:51:11 | function 'heartEnemy' | 12 |
| abyss_run_settlement.lua:61:11 | function 'heartOwner' | 12 |
| abyss_run_settlement.lua:73:11 | function 'finishHeart' | 2 |
| abyss_run_settlement.lua:86:11 | function 'prepareGold' | 3 |
| abyss_run_settlement.lua:101:11 | function 'offerCombatRewards' | 15 |
| abyss_run_settlement.lua:129:11 | function 'publishBattleResult' | 4 |
| abyss_run_settlement.lua:143:11 | function 'finishCombat' | 15 |
| abyss_run_settlement.lua:175:11 | function 'applyCardChanges' | 15 |
| abyss_run_settlement.lua:192:11 | function 'applyPermanentChanges' | 6 |
| abyss_run_settlement.lua:202:11 | function 'finishCombatTransaction' | 9 |
| abyss_run_settlement.lua:220:5 | function 'Run.finishCombat' | 4 |
| abyss_run_settlement.lua:229:5 | function 'Run.proceedEnding' | 9 |
| abyss_run_settlement.lua:239:36 | function | 14 |
| abyss_run_transition.lua:1:1 | main chunk | 1 |
| abyss_run_transition.lua:11:1 | function 'M.install' | 1 |
| abyss_run_transition.lua:12:11 | function 'hasEndingKeys' | 5 |
| abyss_run_transition.lua:17:11 | function 'validateTransitionBoundary' | 7 |
| abyss_run_transition.lua:25:11 | function 'validateTransitionRoom' | 9 |
| abyss_run_transition.lua:38:11 | function 'validateTransition' | 12 |
| abyss_run_transition.lua:50:5 | function 'Run.advanceAct' | 1 |
| abyss_run_transition.lua:51:36 | function | 13 |
