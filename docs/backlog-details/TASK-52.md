# 战后药水独立领取

## 当前修正：按初代奖励列表与选牌页交互

2026-10-24，用户实机指出五种动作同时堆在奖励页、领牌后提示与标题叠字，并明确要求严格参照初代 PC。**本节取代下文旧修复中“药水必须明确放弃后才能离开”和“无药水选牌后自动回图”的方案。** 旧证据保留为历史，不能据此继续保留自创确认规则。

战斗结束先进入条目列表；金币、失金、药水各自点击领取。点击卡牌条目才进入独立三选一页；PC 点牌立即入组并返回列表，没有二次确认。跳过只关闭选牌页，原卡牌条目仍可重开。继续打开地图，不领取也不立即销毁剩余奖励；地图的“返回战利品”可回看，下一房间成功进入后才失效，失败进入保留奖励与地图位置。满槽药水点击拒绝且保留条目，提示从顶部药水入口丢弃旧瓶后重试；Sozu 点击消耗该条目但不入背包。界面不再提供“放弃药水”或“离开并放弃未领奖励”。

### 固定来源与交叉核对

本轮完整重读 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，本地只读副本位于本工作树 `.artifacts/reward-source/`；不部署原版代码。

- [CombatRewardScreen.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/CombatRewardScreen.java)：`setupItemReward` 建立条目列表；`rewardViewUpdate` 只在领取返回 true 时移除条目；`reopen` 恢复列表，不删除 CARD。
- [RewardItem.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rewards/RewardItem.java#L245)：GOLD/STOLEN_GOLD 点击时加钱；POTION 满槽取得失败返回 false；Sozu 分支返回 true，不取得药水；CARD 只打开独立选牌页。
- [CardRewardScreen.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/CardRewardScreen.java#L214)：PC 点牌 `acquireCard → takeReward → closeCurrentScreen`，触屏确认是独立分支，本片不把触屏方案强加给 PC。
- [SkipCardButton.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/ui/buttons/SkipCardButton.java#L64) 只关闭当前页；交叉读 `CardRewardScreen.onClose` 与 [AbstractDungeon.closeCurrentScreen](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L2376) 未见领取或移除 CARD 的副作用。项目内部 `claimCardReward(0)` 保留为旧非 UI 驱动的明确弃牌命令，正常 UI 的“跳过”不调用它。
- [ProceedButton.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/ui/buttons/ProceedButton.java#L104) 普通奖励分支进入地图并保留 previousScreen；首次 FTUE 教学提示是一次性教学，不是逐项奖励确认。本片不增加教学弹窗。Boss 原作转独立宝箱房；项目既有第 17 层地图宝箱接线保留。
- [AbstractRoom.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L306) 先生成金币奖励而非直接加钱。当前固定 15/30/100 金币量及随机链仍未完成同 seed 原版审计；本片修正到账时机，不更改掉落数值、卡池或随机流。

### 实现与离线验收

奖励列表和选牌页互斥。列表继续采用 PR19 颜色/卡面与中央面板，因失金是第四条独立奖励，面板从示例 460 高增加至主题中的 516 高；四行、局部提示和底部继续按钮分别留出文字盒。PC 直接领取遵从用户本轮原作要求，取代原型的选中后二次确认。选牌 subtitle 与跳过按钮补足原生 40 高文字容量。战斗通用 notice 在奖励页隐藏，动作结果显示在列表局部 subtitle；独立控件树守卫要求反馈实际可见，不能靠隐藏反馈蒙混通过。

Run 保存待回看奖励及原战斗/房间身份；宿主返回入口绑定可见性代际、当前局和待领奖励对象；Nodes 只在成功入房提交后清理待回看项。原卡牌/条目数组、药水结果、失金类型/金额和 held/released 输入身份防护保留，并加入页面代际及普通金币状态。没有直接清状态绕开旧触摸测试。原生战斗直属子项保持 60 上限。

新增真实 Run/宿主回归覆盖独立金币、满槽原子性、Sozu、列表/选牌互斥、跳过可重开、旧页 held/released、地图回看、返回入口跨牌库/重开输入、失败入房保留奖励。既有夹具按真实奖励行/继续动作迁移，保留原数值、原子性和身份断言；详细本地命令结果由本轮结构化证据记录。独立可读性守卫与其原始红例见 [UI 根因与守卫](TASK-52-UI-READABILITY.md)。

本片仅源码与本地生成树/回归：**未制作新的 `.gil` 副本、未官方导入、未实机试玩、未通过 `verify:ui`**；任务保持 In Progress。完整组合 check 与最终候选由集成线程执行，不能复用 1847 旧截图认证本片。

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
