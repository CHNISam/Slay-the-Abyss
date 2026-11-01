# 固定源码的职业卡池顺序重建

## 结论与证据边界

固定 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 可以重建一个**明确依赖 Java 实现假设的完整初始卡池候选**：370个全局注册键经过 JDK8+ 标准 String HashMap，筛选四职业，再按源码初始化与 src 克隆构成顺序。它不是注册顺序、字母序或当前已实现子集的顺序。

交付：

- [完整候选manifest](evidence/source-card-pools-319009-jdk8plus.json)：全局370键的 HashMap 遍历序，以及四职业各75张完整元数据、tmp/普通稀有度桶/src稀有度桶、战斗中普通及按类型生成候选序。
- [独立Java交叉检查](evidence/source-card-pools-319009-java21-check.json)：在本机真实 OpenJDK `21.0.12.1+1-1-deb13u1-Debian` 用 HashMap 插入全部370键，逐位置与独立 JavaScript 模型比较，370/370一致。
- [重建脚本](../../scripts/source-card-pool-audit.mjs)：只读锁定注册元数据并导出事实；可选独立 Java source launcher，不执行游戏代码，不改runtime。

候选 runtime profile 为 `jdk8plus-default-string-hashmap-no-tree-bins-v1`。Java HashMap API **不保证遍历顺序**，固定反编译源码只写 `new HashMap()`，没有记录原版客户端实际 bundled JRE。Java21交叉检查验证本机实现与模型一致，不能认证原版运行时，也不是 Java8 客户端实测。原版 JRE、实际解锁、每日模组或外部模组不明时，消费者必须保持“未认证候选”标记，不能静默当作已认证 sourcePool。

本候选假设：普通run、四职业和卡牌全解锁、A0、无每日/外部mods、CardLibrary从完整固定注册初始化、src池尚未被运行中代码改动。A0用于明确场景，不声称职业卡池在所有难度下一定不同。没有读取用户的游戏存档或解锁偏好文件。

## 原始注册与HashMap模型

[CardLibrary.java:395、410–417](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/CardLibrary.java#L395-L417) 定义默认 HashMap，并依次注册 Red、Green、Blue、Purple、Colorless、Curse。`add` 最终在 [940–941](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/CardLibrary.java#L940-L941) 以 cardID 为键 put。顺序是75+75+75+75+56+14=370；370个键均唯一。本轮把保存的 registrationIndex/group/class 与固定源六个注册方法的实际调用逐项比较，并重新核全部370个逐卡SHA-256。

独立实现的模型步骤：

1. 对每个字符串的 UTF-16 code units 计算 Java `String.hashCode`：32位有符号 `h=31*h+char`。
2. 计算 JDK8+ spread：`h ^ (h >>> 16)`；记录无符号32位值。
3. 默认首次分配16桶，loadFactor=0.75；同桶新键接到链尾。size超过threshold时容量翻倍，原链按 oldCapacity 位分成 low/high 两段，各段保留相对顺序。
4. 按最终桶号从小到大、每桶沿链遍历。全部370键都参与，不能只插某职业或只插已实现牌。

实际扩容在 size 13/25/49/97/193 时到32/64/128/256/512，最终370键、512桶、threshold384。全过程及最终的最长链都只有4，没有 tree bin；脚本对未来达到树化边界的输入直接拒绝，未伪造树化实现。全局遍历序按每ID一行的SHA-256：`704cf04aede6daf0d2a84105fbc47c3742b53b059aa49f1bb6cec122860f03b9`。

JDK7的补充hash、链插入及resize实现可能产生另一顺序，本交付没有将它当作同一profile。当前并未认证原版采用哪一个运行时。若要提升证据等级，最小补充是从目标合法运行环境记录JRE版本与初始化后的370个cardID遍历序，逐项比对；仅比对集合或数量不足。

## 从CardLibrary到src池：不是一次筛选结束

[CardLibrary.getCardList:1079–1121](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/CardLibrary.java#L1079-L1121) 按 HashMap.entrySet 遍历后依颜色筛选，没有排序、没有排BASIC，也没有在这些分支按locked过滤。因此75张 `libraryOrder` 不是战斗生成候选数组。

角色 `getCardPool` 调用颜色对应的 `CardLibrary.add*Cards(tmpPool)`：Ironclad126–137、TheSilent129–140、Defect126–137、Watcher160–174。以 [addBlueCards:1158–1165](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/CardLibrary.java#L1158-L1165) 为例：按同一个 HashMap.entrySet 顺序，排除非蓝色、BASIC，以及未被 treatEverythingAsUnlocked 覆盖的 locked 牌。不是根据“见过该牌”筛选。

[AbstractDungeon.initializeCardPools:1115–1180](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L1115-L1180) 的普通路径：

1. 清空普通/罕见/稀有等池，构建tmpPool；无Diverse时取player.getCardPool。Colorless Cards、Diverse和各色每日mods会改变候选与追加顺序，此候选不包含这些分支。
2. 遍历tmpPool，按rarity加入对应普通池（1140–1151）。
3. [CardGroup.addToTop:438–439](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java#L438-L443) 实际是数组append，所以普通rarity桶保留tmp的相对顺序。
4. 然后新建src池（1160–1164），遍历每个普通桶，把同一个卡对象 `addToBottom` 到src（1171–1178）。addToBottom是 `insert(0)`，因此**每个src rarity桶反转**。此处复制容器顺序，没调用makeCopy去复制卡对象。

初始化这段路径没有 shuffle，也没有消费 cardRng、cardRandomRng 或shuffleRng的调用。CardGroup确有shuffle方法（544–549），它用shuffleRng.randomLong构造java.util.Random，但initializeCardPools没有调用它。不能由“CardGroup可以shuffle”推定卡池初始化洗牌，也不能由此声称全局CardLibrary构造、UUID或动画完全没有其他随机行为。

## 战斗生成的精确候选与RNG调用

[AbstractDungeon:916–958](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L916-L958) 的入口必须区分：

| helper | 依次收集的候选 | 抽样 |
| --- | --- | --- |
| returnTrulyRandomCard | srcCommon→srcUncommon→srcRare，不过滤HEALING | 1次cardRandomRng.random(N-1) |
| returnTrulyRandomCardInCombat() | 同上，但先去掉所有HEALING | 1次cardRandomRng.random(N-1) |
| returnTrulyRandomCardInCombat(type) | 每个src桶依原序先去掉非type及HEALING，再合并C→U→R | 1次cardRandomRng.random(N-1) |

没有先随机rarity，没有按稀有度概率加权，没有“抽中HEALING重抽”，也没有针对玩家已经持有的卡排除或防重复。无type的InCombat版本还会对所有入选候选markCardAsSeen（928–939）；typed版本没有这段mark调用。`Random.random(int)` 在 [49–51](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java#L49-L51) 将counter加1，再调用底层nextInt(range+1)，所以N-1表示从0到N-1。一次包装调用与底层XS128拒绝采样可能消耗的状态步数不能混淆；本manifest只提供候选顺序，不替代既有RNG认证。

`returnRandomCard`（903–913）另有rollRarity，使用cardRng决定稀有度，再以cardRandomRng取该src桶，不能与Truly入口共用上述“一次且无rarity roll”的预算。CardGroup.getRandomCard(type,...)（523–535）还会显式Collections.sort临时数组，它也是另一个入口，不能拿来替代Dungeon的typed生成函数。

| 调用者 | 源码位置 | 选牌时点与次数 |
| --- | --- | --- |
| InfernalBlade | cards/red/InfernalBlade:25–28 | card.use同步选1张ATTACK，然后copy、临时费用0、BOT生成动作 |
| Distraction | cards/green/Distraction:25–28 | card.use同步选1张SKILL，然后copy、setCostForTurn(-99)、BOT生成；AbstractCard1986–1994把非负费用牌的新负值压成0，X/不能打出的负费不被该setter改写 |
| WhiteNoise | cards/blue/WhiteNoise:25–28 | card.use同步选1张POWER，然后copy、临时费用0、BOT生成 |
| CreativeAIPower | powers/CreativeAIPower:31–35 | atStartOfTurn构造阶段每层同步选1张POWER、copy并BOT生成，不等到生成动作执行才消费RNG |

因此满手导致生成溢出、后续死亡取消生成，不能追溯撤销原本已合法发生的选择调用（宿主整体事务失败回滚另论）。这些入口从全源池选择，不能为了“当前实现卡可玩”悄悄删掉候选、重新抽牌或用默认牌替换。若消费端不能完整表达某个可能选中的源牌，应明确拒绝该生成能力或标未支持，不能把subset标成全源池。

普通全解锁A0、无mods假设下的数量：

| 职业 | 注册含基础 | 非基础src合计 | InCombat去HEALING | ATTACK | SKILL | POWER |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| ironclad | 75 | 72 | 70 | 28 | 28 | 14 |
| silent | 75 | 71 | 70 | 26 | 33 | 11 |
| defect | 75 | 71 | 70 | 23 | 34 | 13 |
| watcher | 75 | 71 | 69 | 24 | 33 | 12 |

职业HEALING排除项来自逐卡源tags：Feed、Reaper、Venomology(Alchemize)、Self Repair、LessonLearned、Wish。不能只按“文字描述回血”过滤；例如Self Repair是POWER，White Noise/Creative AI均不能从此函数生成它。

本profile的蓝POWER有序源ID为：`Defragment, Capacitor, Heatsinks, Static Discharge, Loop, Hello World, Storm, Biased Cognition, Machine Learning, Electrodynamics, Buffer, Echo Form, Creative AI`。这里保留完整13张，与当前实现多少张无关；这仍是指定HashMap/JRE假设下的候选顺序。

## 运行中变异与明确未认证项

[Dungeon.srcTransformCard:860–882](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java#L860-L882) 对COMMON/UNCOMMON/RARE会从src桶remove被转换ID，随机选后再把原卡copy addToTop，留下桶顺序变化。其入口是 [HandCardSelectScreen:67–72、100–105](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/select/HandCardSelectScreen.java#L67-L72) 的战斗内forTransform路径。尚未证明当前本地正常可达卡集会调用它；它与普通transformCard840–857不是同一个方法。普通transformCard调用returnTrulyRandomCardFromAvailable，不能把所有普通转换都说成修改src。

所以本manifest只代表初始化后、尚无这些变异的池。后续绑定必须保存/复算真实有序src状态或验证无变异的前提；不能每次从初始manifest重新排序来抹掉合法运行历史。开启Diverse/Colorless/各色每日mod、部分解锁、自定义CardLibrary注册、未知JRE或其他修改池的代码时，要重新构建相应证据。

本次没有完成：游戏bundledJRE认证、实际存档unlocks捕获、每日/外部mod顺序、源Colorless/CURSE完整生成manifest、Discovery交互及重复候选重试的整个逐帧RNG生命周期、商店/奖励概率或平台实机。不能把本manifest的完整4×75元数据等同于这些范围也认证。

## 最小重建与绑定方法

```sh
node scripts/source-card-pool-audit.mjs
node scripts/source-card-pool-audit.mjs --verify
node scripts/source-card-pool-audit.mjs --verify --java-check --java-evidence docs/rules/evidence/source-card-pools-319009-java21-check.json
```

消费者读取时：先验证source.commit、registration SHA、runtimeProfile、candidate状态及场景假设；选 `classes[classId].sourceRarityPools` 保留C/U/R各桶，或精确选 `inCombatAny` / `inCombatByType.TYPE`。索引使用源0基计数；不得再排序、shuffle、裁剪或将不同helper的候选混用。manifest不确定或缺失必须显式拒绝，不能fallback到当前subset。

当前候选JSON SHA-256：`d71234050ae5c9000268e8dff42ff8391e841eefcbf0212238a8d63e458269fd`。输入registration JSON SHA-256：`f2a387be3b963ba9fac36a0305ef5add76862666f6055a1d8e058d8f33a53308`。本轮仅执行源事实核对、独立顺序重建与Java370位置比对，没有运行全量、提交、Backlog改动或修改任何runtime/shared文件。

## 源文件SHA-256

registration保留全部370个逐卡hash；本manifest保留其中300张四职业元数据。本轮重新校验全部370个文件。关键入口如下：

| 文件 | SHA-256 |
| --- | --- |
| helpers/CardLibrary.java | `ac123d5376862fb1d1d382284e14a9dc0e955395f415265ae29f9aa8a2b6237a` |
| characters/AbstractPlayer.java | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| characters/Defect.java | `b327b7beaab109df7d638a9320d173e56e0be29bbbf667851c74b9f33b6656c0` |
| characters/Ironclad.java | `6fc9b761251a96f9e3a8e31adb3698f87dbaca07a7d3f0b931c9a9ea0bbcf132` |
| characters/TheSilent.java | `905a13833d41785d9ad98fd1d882903e039d95676f60cdd723b8a10475b5b3f2` |
| characters/Watcher.java | `14e466207588f1f7e747f86c32d7a00319f96dd3fbec7798996f4490b5255e17` |
| dungeons/AbstractDungeon.java | `8fa0712818487a360c72950d053fe77e1a35efa967080723d15c69037092fd26` |
| cards/CardGroup.java | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| random/Random.java | `476be7d8af2080b6b52f6cecc78c35f01904c18dbacc7ea795a361e600f05172` |
| cards/blue/WhiteNoise.java | `32f77f0b7ad71fb553587018d468b7c74a93697e859b07da2b4e6c89c2f838a4` |
| cards/red/InfernalBlade.java | `5bf131e649935ea41eb2194f63c3606b37ca3524fbabd8dfa33441117e0380a2` |
| cards/green/Distraction.java | `b2a74e503dc402e5c5bf46bfa906e6f5938b9060e85ca9dd1833265b63864ecb` |
| powers/CreativeAIPower.java | `de09e60e7413debf133d85e98ef544ab3d504bb09142a40c814bd77453ede549` |
| cards/AbstractCard.java | `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61` |
