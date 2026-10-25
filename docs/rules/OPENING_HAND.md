# 首手先天布置：纯数据切片

交付仅`abyss_opening_hand.lua`、`tests/lua/opening_hand.lua`和本说明。共享Combat/Run未修改；未提交、推送、全量测试或平台验证。

## 固定依据

社区反编译源[aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。逐份只读核对后独立实现，不复制Java方法体。该镜像不是官方开源、正版二进制认证或本轮原作运行证据。

| 源文件 | 原始字节SHA256 |
| --- | --- |
| cards/CardGroup.java | 03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8 |
| characters/AbstractPlayer.java | 2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95 |
| actions/GameActionManager.java | a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3 |
| actions/common/DrawCardAction.java | 67d02ba84c1d7e60fbb2a4a83f2b2d3ebbd81a84d29c16ccb98ecc9dd1a17e18 |
| rooms/AbstractRoom.java | 020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05 |
| rooms/MonsterRoom.java | a64c3528c61506c07ade91a7ad591efbb9941c301a888769cbd487bb871dc5c6 |
| rooms/MonsterRoomElite.java | c5207d745f383e1de615e613da8e5c8f832e237444c3b757d85a61f8b3f5ee3f |
| rooms/MonsterRoomBoss.java | 0e6e49235af6fbcfa3047c204ccde983f6152eac8fc845c47c2d36d63b0c8d21 |
| cards/green/InfiniteBlades.java | 94c99d3332efcd8e570afcb31ca8408e9e604e7588baa1d34f0c33fb323baa87 |

Infinite Blades升级在固定源仅增加isInnate，不改变费用或数值。本引擎用`innate`表示该标记，需宿主正确映射升级定义；本切片不自行修改该牌。

## 先洗牌，再稳定分区

CardGroup.initializeDeck先复制永久牌组，再对完整副本调用一次shuffle。随后依洗牌后数组顺序遍历，普通牌依次加入draw，先天牌依次暂存，再把暂存依次追加draw。源数组尾是顶部。因此布置等价于稳定分区：**普通序列→先天序列**，均保留洗牌后的数组相对次序；抽牌时从数组尾部逐张取出。

例如已经洗好的数组`[普通A,先天1,普通B,先天2,普通C]`变为`[A,B,C,先天1,先天2]`，实际抽取顺序是`先天2,先天1,C,B,A`。不能再洗先天牌、依永久牌组顺序重排，或为保持视觉排序把它们反转。

先天牌总数K超过`masterHandSize`时，仅额外排入一笔Draw(K-masterHandSize)。等于时不补抽，低于时仍正常抽足普通首手，缺额由普通牌补充。extra不能在布置模块按10裁剪，真正执行DrawCardAction时才按当前手牌空位裁剪；多余先天保留在draw顶部，不能塞入弃牌堆。

## 额外抽牌的精确开局时点

不能只看到GameActionManager优先actions、其次preTurnActions，就断言额外抽牌在正常首手之后。还须沿AbstractRoom的开局waitTimer分支判断什么时候首次首手actions才会加入：

1. AbstractPlayer.preBattlePrep清空manager，initializeDeck排入preTurnActions额外抽牌；敌人prebattle动作及Wait1秒加入普通actions；之后调用遗物atPreBattle。
2. 普通、精英、Boss房onPlayerEntry均把waitTimer设为0.1。
3. waitTimer>0期间，只要manager.currentAction非空或普通actions非空，房间仍调用manager.update，不递减waitTimer。
4. 最后一个普通prebattle动作执行完成时，currentAction仍非空，下一次update的getNextAction会立即消费preTurnActions额外抽牌；直到它也完成、currentAction清空，房间才开始递减waitTimer。
5. waitTimer到0后，房间才加入能量准备、atBattleStartPreDraw动作、正常首手Draw(gameHandSize)、启用结束回合及atBattleStart等动作。

因此正常源链中，额外先天抽牌在**prebattle普通动作排空之后、正常首手抽牌和atBattleStartPreDraw之前**执行。宿主现有同步结构可把它放在敌人prebattle及beforeFirstTurn(atPreBattle)完成后、startPlayerTurn的正常开场抽牌和preDraw回调之前。不能合并成一笔加大的Draw5；抽牌钩子、手牌容量、Pure Water生成牌的位置与观察帧均可能不同。

例：K=7、masterHandSize=5，先额外抽2张先天，随后正常Draw5取剩余5张先天，蛇之戒Draw2再抽2张普通牌。K=12配Pure Water时，额外Draw7先取7先天，随后生成Miracle占第8槽，正常Draw5只再抽2张先天；手牌10，仍有3先天在draw顶部。此顺序是源码静态方法链结论，不是本轮正版客户端实测。

## 纯模块API与边界

`Opening.stage(shuffledDraw,catalogCards,masterHandSize)`返回`orderedDraw,extraFirstTurnDraw,summary`：

- 输入必须是完整、已经完成一次shuffle的战斗实例数组，不是永久牌组或已经抽过首手的剩余draw。
- 返回新数组，保留每张实例原引用，不修改输入数组、实例、目录、随机状态；模块没有RNG依赖或调用。
- summary仅含innateCount、ordinaryCount；调用者必须自行消费额外抽牌一次，并负责每战重建。
- `definition.innate`及已升级实例对应`definition.upgrade.innate`决定有效标记；显式布尔`instance.innate`可覆盖，表示宿主已经规范化的实例属性。
- 只支持规范字段innate。未转换的isInnate直接拒绝，避免静默漏掉源标记。
- 目前**不支持瓶装**。inBottleFlame、inBottleLightning、inBottleTornado或bottled任一真值，在实例、定义或升级元数据中出现都拒绝；即使同卡也是先天也不冒充已完整支持瓶装存档语义。
- 非密集数组、未知ID、重复UID、非布尔标记、非整数masterHandSize及元表输入拒绝，全部验证完成后才生成返回结果，没有部分写入。

SourceRandom.shuffle自身先从shuffleRng取一个nextLong，作为Java Collections.shuffle的局部种子。既有共享实现即使空牌组/单张也消费一次此源调用。stage不能替代这笔shuffle，更不能对分区再调随机；模块也不改旧legacy LCG的消费契约。

## 定向验证

`node scripts/test-lua.mjs tests/lua/opening_hand.lua`：10组通过，`OPENING_HAND_PASS 10`；`git diff --check`通过。

覆盖稳定分区及原实例身份、升级先天、有效实例覆盖、0至12张先天与5张普通首手的边界、prebattle额外抽牌/蛇之戒顺序、生成牌占位与10手牌上限、真实SourceRandom先洗后分区的counter和words均不再变化、空/单张源洗牌消费保持、全部瓶装拒绝和非法输入。分区测试使用独立数组规则预期；抽牌容量由真实Combat.draw执行，没有修改共享核心。

此结果是纯模块及源规则轨迹验证，尚不是Combat.new自动先天接入、正式职业初始卡牌全部先天效果或平台验证。自然获取升级后的Infinite Blades及正式完整流程仍须宿主接入后单独验证。
