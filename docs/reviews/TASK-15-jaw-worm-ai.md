# TASK-15 石颚兽（Jaw Worm）生产决策切片

2026-10-23，基线 `origin/develop ed39f46`，分支 `feat/task-15-jaw-worm-ai`。只实现首幕普通模式 Ascension 0 的此敌人。未开原神、MCP、沙箱，未平台编译、写存档、官方导入或实机验证；全池与平台 AC 保留。

## 来源、版本与真实性

优先采用帖子标为开发者回应的 [caseyyano 公开 JawWorm.getMove 方法](https://www.reddit.com/r/slaythespire/comments/1klwcgf/true_jaw_worm_ai/msefy12/)（2025-05 讨论，本轮实际读取）。条件抽样为 `.5625f/.357f/.416f`，不能禁止动作后按剩余权重归一化，也不能把后两参数换成 5/14、5/12。25/55 边界明确；原注释“35% Thrash”与代码不符，以 25–54 共30个整数为准。

数值和顺序实际只读取得固定第三方反编译镜像：

- [ButterflyGame / JawWorm.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/exordium/JawWorm.java)：A0构造常数、takeTurn/getMove；与公开决策方法一致。
- 同提交 [Random.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/random/Random.java)：整数闭区间、`nextFloat() < chance`、RandomXS128。
- 同提交 [RollMoveAction.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/actions/common/RollMoveAction.java)：动作末调用rollMove。
- 同提交 [CardCrawlGame.java](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/core/CardCrawlGame.java#L1403-L1404)：声明V2.3.4 / 2022-12-18；未与正版PC二进制hash核验，不能称官方开源或原作实测。
- 第一镜像缺少AbstractMonster；受并行候选提示，另实际读取 [aeubanks/sts@319009d / AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java)：rollMove先抽random(99)，包括强制首动；setMove记录已选动作，lastTwoMoves检查最后两项。补充镜像同样未认证官方构建，未证明两镜像来源独立。
- [社区wiki / Jaw Worm](https://slay-the-spire.fandom.com/wiki/Jaw_Worm)仅交叉核数值/连续限制，其25/30/45概览不能替代具体条件分支。

实际读取文件SHA256（只读后独立实现，不复制、运行或提交上游程序）：

| 文件 | SHA256 |
|---|---|
| JawWorm | `E6C70FC19A51D5CA0AEE087DA80E6AE93E502864C32C1B1F272C45C0C871A144` |
| Random | `FB2CD1FB97319FE8E1555C614197BC48F7BB8340100160F8D6FAC057396D5427` |
| RollMoveAction | `66C3C07B41AD2971A93888BDB14DFB67EBA3AB6CB0E8FFCDFCDEFAD193476DBF` |
| CardCrawlGame | `0EC95374A3A976AB08F5E270AE0F2860FBAE8E0971A4E61B14B7396843006715` |
| AbstractMonster（补充镜像） | `F95BABA14B00BFFEB6A93E9FCF04CEDAD2A42A803C4B4342C1E017535ACC601F` |

## 独立预期

| 输入/动作 | 预期 |
|---|---|
| A0普通模式 | HP40–44闭区间，maxHp等于采样；没有第三幕hardMode预加力量/格挡 |
| 开场 | 消耗一次主roll，忽略结果，固定Chomp：基础11伤害 |
| Thrash | 基础7伤害，然后5格挡 |
| Bellow | 先3力量，然后6格挡；下一Chomp为14伤害 |
| roll 0–24 | Chomp；若上次Chomp，额外小数小于.5625f则Bellow，否则Thrash |
| roll 25–54 | Thrash；若前两次均Thrash，额外小数小于.357f则Chomp，否则Bellow |
| roll 55–99 | Bellow；若上次Bellow，额外小数小于.416f则Chomp，否则Thrash |
| 其他分支 | 不额外抽小数；Chomp/Bellow不连两次，Thrash不连三次 |

Java binary32参数以数据保存：`0.5625`、`0.3569999933242798`、`0.41600000858306885`；Python标准库struct独立换算。测试覆盖24位小数格点阈值两侧及严格等于阈值，不换成双精度.357/.416或分数。

## 接线与保留差异

2026-10-23后续固定队列来源补充：本文历史毒/荆棘致死回归保护当时项目行为，不构成原作已排队roll认证。有同伴存活时Thorns杀死攻击者仍保留其RollMoveAction，末敌死亡则清队列；共享死亡guard的该差异已另交战斗时序切片。完整方法链、hash和红例见[Spike S账本](TASK-15-spike-slime-s-ai.md)，不得从正常活体抽样通过扩推死后零消费。

独立`abyss_jaw_worm_ai`；EnemyAI仅追加初始化/推进分派；Combat透传已有随机函数。Guardian/Cultist/Lagavulin钩子不重写。`jawLast/jawPrevious`是本实例最后两次已执行动作，动作末选择时与上游已选历史输入等价；平铺字段沿用现有出牌事务回滚。未支持第三幕、升阶或新的插队/重掷机制。

生产仍用现有共享16位LCG，HP/牌堆/AI共用seed；主roll为`random(state,100)-1`，条件小数为`(random(state,65536)-1)/65536`。这不是RandomXS128，独立monsterHpRng/aiRng/shuffleRng、初始种子映射和遭遇创建顺序未接入；模100偏差、16位分辨率与相关性仍在。因此本片只证明受控输入分支、抽样请求数和实际效果，不宣称真实动作概率/同种子轨迹严格通过。强制首动已正确请求一次主roll，也不是整体随机消费流认证。已合RandomXS128原语候选仍未生产集成，本片不擅换全局RNG。

只读对照并行`feat/dot-jaw-policy-candidate ba458fd`：参数、边界与连续限制一致；补充AbstractMonster来源后新增首动消费红测再修复。未复制其候选API，也未改其工作树。

## 回归证据

先见旧生产“40–44 HP range missing”红灯，再实现；补充首动消费测试又见期望1次实际0次，修复后通过。`jaw_worm_ai.lua`13组覆盖800个受控映射、binary32阈值、首动抽样、动作次序、修正伤害、HP全范围、毒/荆棘致死、多实例连续限制与回滚。新增13组schema，与原schema合计85项JS通过。真实原生BattleUI新增jaw_solo用例，展示11开场、Thrash7/格挡5、Bellow力量3/格挡6，详情不改规则。

既有反馈夹具替换整套intents时才关闭不适用的专属AI；真实Jaw不关闭。旧固定下标断言改为受控roll或已执行历史/禁止重复。导航的一点HP夹具同时清掉hpRange，保持其原本导航测试含义，不降低生产数值或冒充真实数值通关。

最终完整Lua套件退出0（`build/jaw-worm-lua-check.log`），18遭遇覆盖152组、23敌人/56意图枚举；JS语法/build:data/build:ui和85项受影响schema通过。未跑本片完整npm check，后续组合与CI由主线程统一。所有平台及全池AC未勾。
