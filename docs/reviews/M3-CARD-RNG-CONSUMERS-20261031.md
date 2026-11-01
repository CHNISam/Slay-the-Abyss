# cardRng 完整身份与重复消费的独立消费者证明

基线 `b4f88a1f574b403f4cc68d54ee37565f3012b5ad`（已合并develop），独立工作树 `/workspace/m3-cardrng-consumers`。本片标记 **TEST_ADDED**：真实生产结果符合新独立预期，没有生产数值差异；不修改游戏Lua、池、概率、旧golden、旧hash、预算、Backlog或冻结PR437。

## 本片补的证据差集

旧 `tools/sts1-card-rng-oracle.py` / `tests/card-random-state.test.mjs` 的228 wrapper、148 rarity证明仍原样保留。它们明确省略身份抽取和重复重试；身份插在下一槽rarity之前会改变全部后续状态，不能仅凭核心投影推出完整消费者相同。

新 `tools/oracles/sts1_card_consumers.py` 只读取已冻结的原版注册/牌池目录，复用独立XS128解释器。**不导入生产Lua、本地卡定义或生产clone来计算预期。** 以源cardID比对全部20/36/16张职业奖励池、各稀有度/类型的完整商店池及20/15张无色商店池；不是对已观察结果构造一个受限池。奖励允许Feed/Reaper；Neow/商店无色允许Bandage Up，不能误用战斗Discovery的HEALING排除池。

本轮逐份读取固定 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的11个源文件，SHA256全部记录在新fixture。关键调用链：

- `AbstractDungeon.getRewardCards`：每槽先roll rarity并更新偏移，再按原奖励池序列抽身份；重复只重抽身份。全部身份结束后，才为每张非rare抽升级boolean；Act1概率0也消费float，rare不消费。
- `Merchant` / `CardGroup`：五个职业货架用原cardID排序的类型子池。相邻同类攻击/技能重复时，**重抽rarity及identity两者**；Power落common时按原空池回退到uncommon。两张无色按各自稀有度排序子池抽身份。商店不改rarity偏移。
- `Orrery.onEquip`先加四个CARD RewardItem，`CombatRewardScreen.setupItemReward`再加默认一组，合计五组；五组顺序延续同一cardRng和偏移。
- `PrayerWheel`在普通战的默认CARD之后加第二组；精英不加。Question Card改变每组数量，Crown再减少两项。
- `NeowReward.getColorlessRewardCards(false)`：rarity属于私有Neow RNG，身份属于共享cardRng；本例初始无色恩赐的三张均从uncommon池选择，重复重试保留该槽稀有度。

这是社区反编译镜像源解释，不是正版PC二进制认证。

## 一条真实公开入口链

固定seed49由独立解释器选作两个重试分支的受控输入；没有从生产筛选期待值。同一Run连续执行：

| 阶段 | 实际入口/结果 | 累计cardRng counter | rarity偏移 |
|---|---|---:|---:|
| Neow无色 | 真实Nodes.beginNeow/chooseEvent；控制history资格，领取一张真实牌 | 3 | 5 |
| Orrery | 真实Run.obtainRelic；公开modal五组卡奖/逐组跳过 | 49 | -7 |
| shop | Nodes.enter真实商店prepare及owner提交，随后合法离店 | 63 | -7 |
| Wheel + Question | Nodes.enter普通战/真实finishCombat，双组各4牌 | 87 | 5 |
| elite + Crown + Question | 真实精英结算，单组2牌，不误触Wheel | 93 | 4 |

每个wrapper的类型、bound、返回值、前后双64位word/counter逐项比较；每阶段还核最终偏移、所有源身份、稀有度及升级位。源向量确实包括两个奖励identity重试及一个商店重试。领取、跳过、收起Orrery都不重抽；cardRng跨事务副本与各来源正确提交。

测试只在观察层标记实际card owner跨生产transaction图复制和clone的身份，以区分merchant/potion等其它流；不替换RNG、返回值、牌池或选择。历史资格、下一房型及敌人终局HP是显式受控输入，地图没有可信冻结上下文，不能把它说成自然路线或新地图恢复证明。首次原型把改房型夹具与严格trusted-context地图混用而正确遭`invalid_snapshot`，已修夹具；没有把它记作生产RED。

## 精确负变异及预算

临时模块只跳过第一次“重复身份后的重试draw”，从同一原池第一项取一个任意候选；其它rarity、身份和升级代码保留，原源码不写。新独立合同在Orrery第三组第三张实际`Anger`与源预期`Thunderclap`处拒绝。它证明不会把少一次identity消费当作仍然正确。

使用共享helper及三个薄JS入口，Lua均原默认30秒，JS预算不改：

- `tests/card-consumers-source.test.mjs`：独立fixture逐byte再生+公开链，整file **2.77秒**。
- `tests/card-consumers-source-mutation.test.mjs`：精准少一次retry draw必须失败，整file **1.63秒**。
- `tests/card-consumers-checkout.test.mjs`：真实Git `core.autocrlf=true` checkout，整file **0.13秒**。未固定control确实CRLF，generator/全部raw-hash输入和fixture仍LF精确同字节，`--check`通过，所有source/input键为POSIX。

运行日志是本轮外部附件 `/workspace/cloud-reports/m3-card-consumers-{source,mutation,checkout}.log`。新文件精确LF属性、已有输入LF合同及原始byte hash保持，不做全局normalize。未重复全量测试。

## 验收边界

这条链补齐了过去“只核rarity、漏identity/retry插入”的具体差集，属于TASK-16.1 #5/#6及道具消费者组合的纯离线证据。没有自行勾整个AC。未认证后续幕升级概率、Nloth倍率、PrismaticShard的额外shuffle-long、Courier的unseeded MathUtils身份路径、Neow其它恩赐/诅咒、所有RNG或全部模组。其它域原有专项保持；本片未把这些机制写成未实现。

没有自然取得/真实战斗通关或官方导入、ready、PC/实体手机证据；不存在新Host重开结论。原三cohort与PR437工作树完全未动。Backlog由主控统一归账，仍Furinya/In Progress。
