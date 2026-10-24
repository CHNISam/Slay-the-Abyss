# 战后金币使用准确范围和独立随机流

2026-10-25，TASK-13.1，基线 `d037c4b`。本片接正式普通/精英/Boss战后金币，继续由原有独立金币条目显式领取；不改卡奖励算法、药水概率、UI、地图、Nodes或遗物池。`rules.rewards` 的15/30/100只留给历史显式ID夹具，正式房间不再读取这些固定中值。

## 固定来源与准确算法

本轮重新读取 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的 AbstractRoom、AbstractDungeon、MonsterGroup、RewardItem、AbstractPlayer、GoldenIdol和Ectoplasm。完整URL模板、原字节SHA256及计算所得Git blob见[机器记录](../rules/evidence/sts1-combat-gold.json)。原字节只在忽略的 `.artifacts/gold-source/`；没有部署原作源码、文案或素材。这是固定社区反编译镜像的规则解释，不是正版PC构建认证或本轮原作客户端观察。

| 规则 | 固定方法依据与本片行为 |
| --- | --- |
| 普通 | [AbstractRoom:309–315](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L309)：非Daily，`treasureRng.random(10,20)`，两端包含。只有本组全部敌人escaped时不创建Gold、也不抽这次随机。 |
| 精英 | [AbstractRoom:292–307](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L292)：非Daily，`treasureRng.random(25,35)`，两端包含。精英分支在普通逃跑判断之前。 |
| 第一幕Boss | [AbstractRoom:276–287](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L276)：非Daily A0为 `100 + miscRng.random(-5,5)`，即95–105。**它不使用treasureRng**；A13倍率、Daily固定100及后续幕特殊结局不在本片目标。 |
| 全逃与部分逃跑 | [MonsterGroup:119–125](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java#L119) 的 `haveMonstersEscaped` 要求每个成员escaped；并非“有一个逃走”。部分死亡、部分逃走的正常胜利仍抽普通金币。当前有效遭遇非空。 |
| 流初始化 | [AbstractDungeon.generateSeeds:377–392](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L377)：treasure从原始signed64局seed创建，和其他流各自独立；[换层:1727–1731](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L1727)只重建HP/AI/shuffle/cardRandom/misc，**不重建treasure**。Run.new新建treasureRng；普通/精英续同对象状态，Boss使用已按层重建并消费了构造选择的run.miscRng。 |
| 生成与领取 | [AbstractRoom.addGoldToRewards](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java#L612)创建/合并条目；[RewardItem.claimReward](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rewards/RewardItem.java#L246)点击才gainGold。胜利只固定报价和随机状态，领取不抽数；重复点击/完成拒绝。普通全逃用现有gold=0且goldClaimed=true表示无Gold行。 |

修饰已核实但不扩内容：RewardItem构造时保存基础goldAmt，非TreasureRoom的Golden Idol另加 `round(base * 0.25F)` 到bonusGold；它不改变随机抽取。`STOLEN_GOLD`走theft分支，不套该奖金。Ectoplasm在AbstractPlayer.gainGold点击时阻止到账，不在报价或RNG生成时拦截。Midas/MonsterHunter是模组修饰。当前13遗物不含GoldenIdol/Ectoplasm，首发不是Daily/模组/A13，本片不添加ID、效果或假造其获取路径。未来纳入时必须在正确时点实现并独立验收。

## 最小实现和原子性

`abyss_gold_rewards.prepare`只克隆选中的STS随机状态、按上述准确参数抽一次并返回报价和后置状态；不就地推进调用者。`abyss_run`只对有正式 `combat.roomSeed` 的路径使用它，历史显式 `Run.startCombat`维持原固定夹具边界，不能拿后者宣称原版掉落一致。

金币先准备，其他奖励全部成功后才发布选中流。新真实失败用例发现原finishCombat遇非法RNG时已写lastResult；正式finishCombat现暂存Run标量/新奖励，并隔离原有shopRng容器，再一次提交。失败保留原HP、卡牌/金币/RNG进度、全部原对象和旧奖励状态。该暂存不改变其他随机算法。已有显式claimGoldReward的整数/溢出与重复领取拒绝保留；偷回金币、选牌和药水仍为独立条目。

## 红绿和可执行防线

独立 `tools/oracles/sts1_combat_gold.py` 用Python整数解释XS128/拒绝采样和源调用，不读生产JSON、不导入生产Lua。7组raw局seed（含0、超16位、大整数和signed64两端）×6步=42步，逐步比较普通/精英连续treasure与第16层Boss misc的数值、双words和counter；普通全逃无抽样。调用监视另核准确的10/20、25/35及-5/5参数、一次消费与正确owner；HP/AI/shuffle/cardRandom及非Boss misc不受金币影响。

第一轮fixture出现JSON null不能传toLua的测试传输错误，改为缺省字段后重新运行：3项Node中身份自检过、2项行为失败；rawseed0首普通战原实现15，独立预期11。接流后42步向量通过，事务用例再真实失败于 `lastResult`提前写入；正式暂存修复后全部通过。

13个Lua组覆盖三类各11个真实受控XS128状态（含每个闭区间端点）、全逃/部分逃跑、精英/Boss分支优先级、raw局种子与换层不重置、未结束/战败、非法状态、后续药水commit异常、已有共享流按引用恢复、致死药水完成后异常/拒绝、领取溢出/重复、停放再开与失金独立领取、legacy边界。终局HP/逃跑标志或注册药水的夹具只核事务，不冒称自然战斗获取或实机胜利。

八个隔离负变异全部检出：Boss错用treasure、普通上界排除20、每房重置treasure、全逃仍给金币、胜利自动到账、漏提交金币流、绕过正式事务暂存、别名写入已有药水共享流。只改 `.artifacts/gold-mutations/` 副本，正式生产文件未为变异改写。

实际验证：

- `node --test tests/combat-gold.test.mjs tests/reward-flow-parity.test.mjs tests/event-random.test.mjs`：5项通过，0失败，含42向量、13组新Lua及既有奖励生命周期/STS原语。
- `run.lua`8组、`potion_reward_atomic.lua`4组、`looter_potion_rewards.lua`10组、`potion_rewards.lua`7组、`looter_rewards.lua`5组通过。
- 既有Boss领奖事务、稀有度128seed与两段各64seed确定性回归通过；它们的历史固定金币断言明确仍走legacy显式入口。
- 独立向量可从oracle重生；生成器身份按规范LF文本核验，兼容Windows CRLF。`git diff --check`通过。

## 保留缺口与交接

treasure流目前只迁移战后普通/精英金币。原作的随机箱型、宝箱金币与其他treasure消费者尚未接通；因此经过这些节点后不能宣称整局同seed金币轨迹。Boss当前misc能继续同房状态，但其余事件misc消费者的广义一致性仍按原任务待验。卡奖励/偏移/全局遗物队列仍未完成。

没有改rules/schema，保留旧数据常量的夹具用途。没有运行完整check、GUI、MCP、平台编译、存档导出、官方导入或千星实机；没有push/merge，不勾TASK-13.1或M3整体AC。原先依赖固定金币中值的正常路线须由主线程在最终组合重跑，不能机械改证据结果。
