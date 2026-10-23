# TASK-13.1：商店卡牌价格证据增量

核对日期：2026-10-23。项目基线：`a6be1b6c7bc2b5f9630151d9bef5edbe7522d4d6`。范围仅为初代 PC / Ascension 0 的卡牌报价，不验收整个商店、奖励概率或删牌系统。不改生产代码、Backlog 状态或既有验收结论。

## 证据等级与边界

- 已实际读取固定提交的 ShopScreen、AbstractCard、Random、MembershipCard、Courier、SmilingMask、StoreRelic、CardCrawlGame 方法体，不以 README 推导规则。镜像为 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`，文件头自述由 Jad 反编译。
- [CardCrawlGame 第 1403–1404 行](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/core/CardCrawlGame.java#L1403-L1404) 声明 `[V2.3.4] (12-18-2022)`。这是镜像中的版本字符串，不是官方构建来源、完整性或对应 PC 二进制的认证。本报告没有原版实机观察；不得把此次资料读取日期写成实测日期。
- libGDX 官方仓库 `1.9.5` 解析为 `3b1fda1fc2e1f6b3c74851471870062d871ed16f`，仅用于解释同名依赖函数的交叉核对；尚未证明这就是目标 PC 构建实际捆绑的依赖版本。其数学语义的置信度高，映射到目标发行版的置信度有条件。未复制或运行原版实现。
- 因此，下述是可落地的**候选规则与验收向量**：镜像内部证据明确，但严格原版一致性仍需合法目标构建/可靠独立来源核验，不能据此勾选 TASK-13.1 完成。

## 逐项规则与固定来源

| 项目 | 读取到的行为 | 固定证据 |
|---|---|---|
| 稀有度基价 | COMMON 50、UNCOMMON 75、RARE 150。按稀有度，不按职业分别定价。BASIC/SPECIAL 的错误哨兵值不是合法商品价格。 | [枚举映射 506–519](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/AbstractCard.java#L506-L519)，[getPrice 2405–2430](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/cards/AbstractCard.java#L2405-L2430) |
| 初次上架职业牌 | 每张使用 merchantRng 的 float 区间调用 0.9F 到 1.1F；基价与结果相乘，float 转 int 截断。不是将最终整数在某范围均匀抽样，也不是四舍五入。 | [ShopScreen 327–342](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/ShopScreen.java#L327-L342) |
| 初次上架无色牌 | 同样先乘抖动，再 float 乘 1.2F，最后才截断；不能先截断职业价格再乘 1.2。正常无色 uncommon/rare 的名义基价为 90/180。这里只核价格，不声称已验证无色库存抽选。 | [ShopScreen 344–356](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/ShopScreen.java#L344-L356) |
| 特价牌 | 职业牌索引 0..4 中抽一张，在已截断的整数价格上除 2，正数向下截断；不是从无色牌中抽，不是 half-up。 | [ShopScreen 358–360](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/ShopScreen.java#L358-L360)，[Random 64–67](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/random/Random.java#L64-L67) |
| 初始遗物折扣顺序 | initCards（含特价）之后，A16 分支在 A0 不生效；先 Courier ×0.8F 并 MathUtils.round，再 Membership Card ×0.5F 并再次 round。不可折成一次 ×0.4 后取整。 | [ShopScreen 300–318](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/ShopScreen.java#L300-L318)，[applyDiscount 452–482](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/ShopScreen.java#L452-L482) |
| 店内购买会员卡 | StoreRelic 获得会员卡后对当前货架调用 ×0.5 的折扣路径，因此已有整数报价再 round，而不是重抽抖动。 | [StoreRelic 97–103](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/StoreRelic.java#L97-L103) |
| Courier 补货 | purchaseCard 对补货调用 setPrice：基价→抖动→无色 ×1.2（若适用）→Courier ×0.8→会员卡 ×0.5，保留 float 到最后一次 int 截断。没有重新半价步骤。初始报价和补货不能共用一个无阶段区别的取整规则。 | [调用点 757–797](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/ShopScreen.java#L757-L797)，[setPrice 837–846](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/ShopScreen.java#L837-L846) |
| Smiling Mask | 将 actualPurgeCost 设为 50，不改卡牌价格。删牌的基数、递增和叠加是另一套状态，不可复用卡价 pipeline 推导。本报告不验收删牌所有遗物组合。 | [ShopScreen 310–318](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/ShopScreen.java#L310-L318)，[478–482](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/shop/ShopScreen.java#L478-L482) |

## Float 与端点：避免错误的开区间断言

1. [镜像 Random 112–115](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/random/Random.java#L112-L115) 表明映射为 start 加上 u 乘 end−start，各操作使用 float。其 u 来自 RandomXS128，而不是 Java 标准 Random 的默认实现。
2. [libGDX 官方 RandomXS128 125–134](https://github.com/libgdx/libgdx/blob/3b1fda1fc2e1f6b3c74851471870062d871ed16f/gdx/src/com/badlogic/gdx/math/RandomXS128.java#L125-L134) 使用 24 位网格 u=k/2^24（0≤k<2^24）。底层 u<1 **不意味着映射后的 float 严格小于 1.1F**。
3. IEEE binary32 运算下，u=1−2^-24 映射为 1.100000023841858，即 1.1F 本身。因此不能将职业普通价格上限写成 54。候选完整边界为职业 45..55、67..82、135..165；正常无色 uncommon 81..99、rare 162..198。区间并不表示各整数价格等概率；本报告没有枚举频数或验证真实种子轨迹。
4. [Java SE 8 JLS 5.1.3](https://docs.oracle.com/javase/specs/jls/se8/html/jls-5.html#jls-5.1.3) 的浮点到整数窄化向零截断，正价格等同 floor；[JLS 15.4](https://docs.oracle.com/javase/specs/jls/se8/html/jls-15.html#jls-15.4) 说明浮点表达式语义。直接用 Lua/JS double 中间值不自动等价于 Java float。
5. [libGDX MathUtils 278–282、307–312](https://github.com/libgdx/libgdx/blob/3b1fda1fc2e1f6b3c74851471870062d871ed16f/gdx/src/com/badlogic/gdx/math/MathUtils.java#L278-L312) 的 round 在此正价格范围采用最近整数、半值向上；先得到 float 乘积，再按该方法取整。不要使用银行家舍入，也不要将初始 int cast 改为 round。

## 确定输入→预期（独立算术验算，非原版运行）

以下已以 Math.fround 对每个 binary32 运算边界进行数值核算。只验证算术，没有运行镜像、原版游戏或项目生产路径。端点 u 测试以已核对的 libGDX 语义为条件；m 输入测试直接注入区间调用的返回 float，不要求对应某个已知种子。

| 输入条件（默认 A0、首次上架、无特价/折扣） | 预期价格 | 要捕获的错误 |
|---|---|---|
| u=0；职业 common/uncommon/rare | 45 / 67 / 135 | 初始取整不是 round（67.5→67） |
| u=0.5；职业 common/uncommon/rare | 50 / 75 / 150 | 名义中点 |
| u=1−2^-24；职业 common/uncommon/rare | 55 / 82 / 165 | 错误地排除 float 上端点 |
| u=0 / 0.5 / 1−2^-24；无色 uncommon | 81 / 90 / 99 | 不应先把 67.5 截断成 67 再涨价 |
| 同上；无色 rare | 162 / 180 / 198 | 无色溢价与上界 |
| 职业 common，m=1.02F，特价 | 25 | 初始价 51 后整数除 2，不是 26 |
| 职业 common，m=1.02F，仅会员卡 | 26 | 初始价 51×0.5，half-up；不同于特价 |
| 职业 common，m=1.02F，Courier+会员卡 | 21 | 51→round(40.8F)=41→round(20.5F)=21 |
| 同上，但为 Courier 补货 | 20 | float 51×0.8F×0.5F 最后截断；不得套用初始流程 |
| 职业 common，m=1.02F，特价+Courier+会员卡 | 10 | 51→25→20→10，特价先于遗物折扣 |
| 职业 common，m=1.02F，仅 Smiling Mask | 51 | Mask 不影响买牌价格 |
| 已有标价 51，店内刚购入会员卡 | 26 | 修改现有价格，不重抽 RNG |

取整、特价、折扣和补货各自应有单独可控输入；实际商店 RNG 状态的序列/存取恢复另行验收，不要把这些定点算术向量包装成种子一致性测试。

## 当前实现差异与承接点

- [rules.json 32–39](https://github.com/CHNISam/Slay-the-Abyss/blob/a6be1b6c7bc2b5f9630151d9bef5edbe7522d4d6/data/rules.json#L32-L39) 的 50/75/150 目前是最终固定售价。它们与候选**基价**相同，不足以证明最终价格一致。
- [abyss_nodes.lua 72–87](https://github.com/CHNISam/Slay-the-Abyss/blob/a6be1b6c7bc2b5f9630151d9bef5edbe7522d4d6/src/lua/abyss_nodes.lua#L72-L87) 遍历 playable 池，直接从 rules 取价格；没有价格抖动、无色溢价、特价、遗物折扣或 Courier 补货。当前单价事务测试不能替代来源一致性测试。
- [data/SOURCES.md](https://github.com/CHNISam/Slay-the-Abyss/blob/a6be1b6c7bc2b5f9630151d9bef5edbe7522d4d6/data/SOURCES.md) 已明确固定商店价是项目配置；[既有 TASK-9.1 review](https://github.com/CHNISam/Slay-the-Abyss/blob/a6be1b6c7bc2b5f9630151d9bef5edbe7522d4d6/docs/reviews/TASK-9.1-reward-review.md) 是历史奖励/事务验收，非本报告价格算法验收。此增量不重复该事务证据，也不否定其原限定范围。
- TASK-13.1 承接价格 pipeline、float/取整与输入向量；遗物运行时触发同 TASK-14.1 协调，不能因为当前遗物未实现就把其原版折扣写成“不适用”。具体发行版本认证、实际依赖版本、原版对照观察、项目修复和独立测试都仍未完成。
