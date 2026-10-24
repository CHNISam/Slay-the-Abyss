# 原版卡牌目录与初始抽样池

本切片只交付事实元数据、独立初始池 oracle 和定向验证，不接生产奖励或实现牌效。基线 eb4e8af；用户已选择补齐首发真实入口的原版内容池，以保持概率。目标为全解锁 Ironclad、A0、第一幕、无每日修改器；其他职业作为可选角色不在本切片，但合法跨色抽牌不能排除。

## 目录与规模

- registration.json：固定镜像的全部 370 条注册，保留原始 cardID、class、cost、type、color、rarity、target、HEALING 等标签、直接卡片依赖及逐文件 SHA256。全库注册顺序为红75→绿75→蓝75→紫75→无色56→诅咒14。
- pools.json：完整 HashMap 遍历、红奖励原序、typed 商店与无色店排序、src 副本反序、独立诅咒库顺序、PrismaticShard 跨色候选与直接 special 依赖。
- coverage.json：eb4e8af 本地数据与首发记录的缺项快照，区分“有定义”和“已列首发”；不代表牌效或平台验收。公共 data/cards.json 未改。

|入口|全解锁源规模|基线覆盖差距|
|---|---:|---|
|红牌|75（基础3、common20、uncommon36、rare16）|首发30，缺45；其中7已有数据定义|
|普通无色店/生成池|35（uncommon20、rare15）|35均缺|
|状态|5|已有Dazed/Slimed，缺Burn/Wound/Void|
|普通随机诅咒|10|已有Regret，缺9|
|PrismaticShard 战后候选|320（common76、uncommon160、rare84）|红72+其他色213+正常无色35；不可删其他色|
|注册special|16|正常池不含；其中12由常规牌的直接生成依赖闭包得到|

全解锁红牌不能套新账号锁牌表。新账号锁9张，全解锁全部加入。Guardian-unseen 与卡牌解锁互不推出。

## 源与复现边界

固定来源为 [aeubanks/sts@319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。CardCrawlGame 声明版本为 [V2.3.4] (12-18-2022)。这是固定反编译源解释，并非原 PC 二进制认证。提取器只在内存读取固定公开 ZIP，检查 CRC，保存派生事实；不落完整原文、方法体或归档，不执行下载的代码。

[CardLibrary](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/CardLibrary.java) 先把所有色卡放入默认 HashMap，再 entrySet 遍历过滤。独立模型按 [OpenJDK8 HashMap](https://github.com/openjdk/jdk8u/blob/jdk8u472-b08/jdk/src/share/classes/java/util/HashMap.java) 的 String 哈希传播、16初始桶、0.75负载、尾插及保序扩容构造。370项最终512桶，整个构造最长链4，无树化；14项诅咒单独构造另一个 HashMap。

[CardGroup](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java) 的 addToTop 实际尾加，addToBottom 实际头插。[AbstractDungeon.initializeCardPools](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java) 因此使红奖励池保留全库 HashMap 遍历，而 src 副本反向。普通奖励原序不是注册序、字母序或本地 snake_case 序；typed 店池及无色按原 cardID.compareTo 排序。

CardLibrary.getCurse 从独立 curses HashMap 遍历，排 AscendersBane/CurseOfTheBell/Necronomicurse/Pride。与地下城 curseCardPool 的候选集合相同，顺序不同；两个入口不能共用同一向量。

独立 Java helper 实际使用本机 Temurin17 的 HashMap/Collections，与 Python oracle 比较573项全部一致（370全库+14诅咒库+10随机诅咒+72红奖+72typed店+35无色店）。helper 编译为 Java8 目标字节码；这不等于在 JDK8 或原 PC 执行过。需要原版认证时补原 PC/JDK8 实际向量，不得把当前源解释升级成实机证据。

这里的池是初始化向量，不是完整可变池状态机。源还存在 srcTransformCard、returnColorlessCard 等重排或删除/补回入口；后续应逐真实调用移植与快照，不能每次抽样都重建初始池。

## 必须保留的合法入口

[PrismaticShard](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/relics/PrismaticShard.java) 为 SHOP 遗物。getAnyColorCard(rarity) 从全库收集对应稀有度，含正常无色；先用 cardRng 做一次 Java shuffle，再过滤排序并用 cardRng 抽身份。typed 重载排 HEALING，shuffle 使用 cardRandomRng，身份仍使用 cardRng。即使最终排序抵消了洗牌顺序，随机数消耗不能省略。

常规池直接 special 依赖为 Beta、Omega、Insight、Miracle、Safety、Shiv、Smite、ThroughViolence、BecomeAlmighty、FameAndFortune、LiveForever、Expunger。该闭包只证明直接构造关系；动态工厂与战斗/事件/遗物入口还须后续逐项核。

其余注册 special 为 Ghostly（Apparition）、Bite、J.A.X.、RitualDagger，不能直接全塞第一幕普通池。A0 [NoteForYourself](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/events/shrines/NoteForYourself.java) 可在第一幕出现，读取跨局 NOTE_CARD/NOTE_UPGRADE，默认 Iron Wave。固定新 profile 可用默认值；若承接历史 profile，允许继承的卡也需表示，不能在无证据时直接断言这些 special 第一幕绝不会出现。普通池不含四张特殊诅咒不代表其他合法遗物/事件可不实现其获得入口，例如 Calling Bell 的 CurseOfTheBell。

状态牌的普通奖励排除与战斗生成分开：本目录记录 Burn/Dazed/Slimed/Void/Wound。牌效与敌人入口的具体获得和结算时序仍归后续实现。

## 先后与最小分组

先做共享 cardRng+偏移的可克隆状态机及正式原池查询；生产只在合法结果牌效齐备后接入，不可重抽或换成受限桶。商店/奖励/诅咒/跨色须共享源规定的 RNG；cardRandomRng、merchantRng 与外部 MathUtils 不可合并。

缺红45可按机制分为四片，每张只列一次，组内仍需逐卡原文核牌效：

1. 数值、牌数与条件8：Heavy Blade、Perfected Strike、Pummel、Sword Boomerang、Intimidate、Spot Weakness、Limit Break、Clash。
2. 手牌/牌堆选择与升级10：Armaments、Headbutt、Warcry、True Grit、Burning Pact、Exhume、Second Wind、Sever Soul、Fiend Fire、Dual Wield。
3. 生成、自动打出、X费与特殊成长11：Immolate、Power Through、Wild Strike、Reckless Charge、Infernal Blade、Havoc、Whirlwind、Blood for Blood、Searing Blow、Feed、Reaper。
4. 持续触发与重复施放16：Berserk、Brutality、Combust、Corruption、Dark Embrace、Demon Form、Double Tap、Evolve、Feel No Pain、Fire Breathing、Flame Barrier、Juggernaut、Metallicize、Rage、Rupture、Sentinel。

无色35、特殊依赖12、其他色213应另按同一机制复用分组；不通过增开可选角色来实现跨色卡。coverage 中 Whirlwind 源 cost=-1，本地 cost=0+costMode=all_energy 是表示差异，此目录没有把它自动判定为牌效错误。

## 定向验证与命令

- node --test tests/card-pool-catalog.test.mjs：6项通过。
- python tools/oracles/sts1_card_pools_jdk_check.py：573项实际 JVM 对照通过。
- python tools/oracles/sts1_card_catalog_extract.py --output data/reference/sts1-card-pools/registration.json：联网重取事实目录。
- python tools/oracles/sts1_card_pools.py：离线重建初始池与本地缺项快照。提取与重建均显式运行，不加入生产 build。
- 未跑 full/check，未改生产数据、Lua、UI或公共测试预算。
