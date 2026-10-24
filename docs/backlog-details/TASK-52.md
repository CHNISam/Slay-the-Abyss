# 战后药水独立领取

2026-10-24。用户打完整局，直到三个槽满才知道何时得到药水。根因是 `Run.claimCardReward` 在普通战后选牌/跳过时调用 `claimPotionReward`，随后回图；既有测试把自动收取写成正确行为。

## 修复

只要存在药水条目，普通战后也保留独立奖励页。选牌/跳卡只处理卡牌；领取/放弃只处理药水；前往地图结束本次奖励。待处理的瓶子阻止离开，要求明确领取或放弃。无药水和失金的奖励沿用既有快进，不扩大金币与卡牌掉落审计。

药水栏从数据定义读取名称、效果、×1。满槽提示点顶部药水槽丢弃旧瓶再领取或放弃；现有宿主支持reward阶段丢弃，本轮未改其控制器。按钮仍验证奖励对象、渲染版本、卡牌数组、药水结果及输入归属；满槽领取的原子拒绝、物理槽位与同种瓶替换保护保留，选牌不再被满槽阻塞。

## 本轮实际重读的固定来源

`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`下载副本只保存在本树`.artifacts/potion-source/`，不部署原版代码。

- [RewardItem.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rewards/RewardItem.java#L245)：POTION与CARD独立；药水调用obtainPotion，取得失败返回false，卡牌分支没有领取药水。
- [AbstractRoom.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L582)：40加修正，0..99严格小于阈值掉落；掉落减10、不掉加10，不截断。已有至少4条奖励或普通房全部怪物逃跑时阈值归0，仍消费掉落roll。
- [MonsterRoomBoss.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/MonsterRoomBoss.java#L13)及[战后调用](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L317)：第一幕Boss继承MonsterRoom并调用药水奖励。最终幕例外不在单幕范围。
- [AbstractDungeon.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L805)及[PotionHelper.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/PotionHelper.java#L61)：65/25/10稀有度；战士池不含Silent专属毒药水；从有原始顺序的全池反复抽至匹配稀有度。

镜像是方法规则依据，不认证正版构建。当前受限池仍为五普通、一罕见、无稀有，本次不增删首发内容。项目同稀有度桶排序抽样与原版全池拒绝抽样耗随机量不同；同seed完整药水链、与商店连续流及完整内容概率未认证，不能据65/25/10通过宣称完全一致。

近邻差异留TASK-13.1：Sozu原版点击后消耗药水条目但不取得，项目拒绝并要求显式放弃；金币在finishCombat直接到账，无瓶奖励选牌后回图；金币/卡牌/精英遗物完整规则不由本切片证明。原版直接离开允许丢掉未领条目，本项目保留显式药水放弃保护，作为输入确认差异记录。

## 证据边界

新增真实Run红测试先报`card choice must never acquire a potion`；生成UI红测试报选牌偷偷收药及缺数量。修复后新Run三组、UI两组及原药水七组/UI三组/失金组合十组通过。工程回归最终计数见任务备注；认可自动领取的旧断言改为独立事务，不删除重复请求、旧触摸或失败原子性检查。

### 旧夹具迁移收尾

首次169个Lua文件收集中有27个失败，大多在选牌后立即进入下一战或完成地图节点。仅在这些夹具的有效选牌后调用测试辅助函数，显式领取药水（满槽、未实现内容或Sozu时显式放弃），再调用`leaveCombatRewards`；原有卡牌/数值/随机流/原子性断言保留。宿主导航夹具使用真实`skipPotion`、`continue`操作，不直接清奖励或改phase。药水手势专属断言改为检查卡牌已处理、药水仍未领取，保留原触摸身份要求。

第一次定向迁移26个文件通过，剩余`looter_potion_ui.lua`发现真实输入回归：普通有药水页开始设置`manualContinue`后，原本无失金页可跨越的纯重绘触发了失金页的渲染版本失效策略。修复只将渲染版本边界继续限定在失金页；所有页仍逐项比较奖励/卡牌/药水身份及处理状态。该原测试修后通过，失金页的旧输入保护也通过held/released两组。

- 原27个失败文件均有定向修后通过证据；最后9个相关奖励/输入文件全部通过（含上述重绘回归）。没有重新跑169文件全集，也没有改超时预算。
- `node --test tests/reward-potion-layout.test.mjs tests/game-ui.test.mjs tests/map-ui-layout.test.mjs`：13项通过，含真实宿主与地图Lua控制器。
- `npm run validate:data`、`npm run check:syntax`通过；完整CI和组合候选由集成线程执行，不用本地定向通过代替。语法检查首次受限沙箱拒绝Node子进程，同命令在允许子进程的宿主权限下通过。
- 初始失败、迁移及最后定向日志保留在本树`.artifacts/potion-lua-failures.json`、`.artifacts/potion-lua-migration-results.json`、`.artifacts/potion-related-closeout-results.json`，哈希和fixture列表见[结构化记录](../evidence/potion-reward-independence-20261024.json)。

没有新编译副本、导入、当轮ready/日志/截图或verify:ui通过。此前其他候选的买/丢/用药水证据不认证本轮。

免费DeepSeek短只读委派被自动审批拒绝：向外部OpenCode/DeepSeek发送AGENTS和测试源码缺少具体出境授权。该委派未执行，没有模型成果或收费回退，Codex接管；额度节省未知。
