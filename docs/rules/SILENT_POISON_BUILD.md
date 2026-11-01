# Silent 毒流首个组合切片

TASK-56.1；仅实现固定公开源可核实的 Catalyst、Bouncing Flask、Noxious Fumes 的有限规则。独立编写的 `abyss_poison.lua` 复用真实Actor状态和独立 `cardRandomRng`，没有第二份毒层或并行战斗引擎。卡定义由 `abyss_silent.withFoundationCards` 显式加入独立数据副本。不是完整毒流、完整职业或实机验收。

## 固定来源及事实

固定社区反编译镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，声明 V2.3.4 / 2022-12-18；未经正版PC二进制核验。只读取方法链事实，不保存原方法体。

| 卡牌 | 基础版 | 升级版 |
| --- | --- | --- |
| Catalyst | 1费技能，消耗，当前毒层翻倍 | 当前毒层三倍 |
| Bouncing Flask | 2费技能，随机目标共3次，每次3毒 | 共4次，每次仍3毒 |
| Noxious Fumes | 1费能力，玩家获得2层能力；下次及以后玩家回合抽牌后对每敌施加对应毒 | 获得3层能力 |

Catalyst动作执行时读目标当前P，新增P或2P，不是在点击时缓存毒层，更不是直接覆写。无毒时不产生ApplyPower，Artifact不消耗；有毒时一次Artifact挡整次新增毒，已有毒保持。固定源新 `PoisonPower` 对象构造时把amount上限设9999；已有毒堆叠采用 `ApplyPowerAction.stackAmount` 原量，不能把当前毒或新增量全部简单cap9999。例：已有9999毒的升级Catalyst得到29997毒；首次应用20000毒只得到9999，已有1毒再应用20000得到20001。

Flask初始目标在卡的use中抽取。后续BounceAction先抽下一目标，再将当前ApplyPower动作压在它前面，所以当前毒应用前，下一目标RNG已被消费。候选按怪物列表顺序，排除死亡、半死、濒死及正在逃跑目标。单候选也调用独立cardRandomRng，正常3/4跳各消耗3/4次计数；不使用legacy seed、怪物AI或地图随机流。每跳独立施毒，因此Artifact逐次阻止3毒，不能合并为一次9/12毒。

Fumes属于玩家BUFF。打出能力本回合不会立即施毒，随后每次玩家回合的post-draw钩子按敌列表顺序分别施毒，逐敌Artifact生效；NoDraw不会取消此能力钩子。毒伤仍是各敌回合开始时伤害并减1，没有把“施毒”与“毒伤”混成一次。能力本身没有首次跳过标志；不能在正确的下回合钩子上再额外跳过一轮。

## 源文件SHA256

以下均为固定提交的完整原字节经HTTPS读取所得，版本证据等级仍是社区镜像：

| 路径 | SHA256 |
| --- | --- |
| cards/green/Catalyst.java | `710f945951fa80cece3975afd8e1daf60b680f96d122f9b4e05f6fa8fca2a553` |
| actions/unique/DoublePoisonAction.java | `2fa089c6c33a13d85789a704f02c4561beeb56395d34849aa80712633dabd2cf` |
| actions/unique/TriplePoisonAction.java | `dce256cac6efb137ecba050ae892ce79a293d0ead281ea3eb4eda473e3b1a5ad` |
| cards/green/BouncingFlask.java | `bf606475661941c60e09271bfc6d2532c77e5ebc264d3bc94eb77f58177d5903` |
| actions/unique/BouncingFlaskAction.java | `3dd61c8b76ce1894284d814cb4b66fd652caee959b10fd3167d41df9e958c096` |
| cards/green/NoxiousFumes.java | `4ffeb50c62e1a8481289617b1ea9a2b495baad1c1b0e706329b720762da4c20d` |
| powers/NoxiousFumesPower.java | `add060dc8068d0b706b5503f52f72b73be92a70870e38d3587a98eabd7403559` |

辅助方法链：`monsters/MonsterGroup.java`的带Random参数getRandomMonster；`random/Random.java`的包含端点random；`powers/PoisonPower.java`、`actions/common/ApplyPowerAction.java`的构造与堆叠、Artifact门禁；`actions/GameActionManager.java`和`core/AbstractCreature.java`的post-draw能力分发。

## 共享接口与验证

- `multiply(state,target,factor,api)`：factor仅2/3，target必须来自本战斗敌人列表。
- `flask(state,count,api)`：count仅3/4，要求存在合法独立cardRandomRng，没有LCG降级。
- `postDraw(state,api)`：读取玩家noxious_fumes，对敌逐个调用Actor.applyPower。共享Combat在常规抽牌后调用；能力刚被打出时不调用。

api参数保留供共享dispatcher统一调用，所有状态应用由真实Actor执行。本模块不自行建立卡牌/回合事务；共享出牌事务必须保存actor/statuses及cardRandomRng嵌套原对象，失败后恢复原引用、内容和能源。postDraw调用方也应在需要原子性时提供整个回合事务，不能只回滚本模块单个动作。

定向命令：`node scripts/test-lua.mjs tests/lua/silent_poison_build.lua`。21组通过、退出码0：真实基本/升级出牌，Artifact和无毒分支，单/双目标及逐跳lookahead随机计数，候选排除，首次/已有大毒层，Fumes首回合与下回合、NoDraw，错误RNG以及第一跳已施毒后故意异常的完整出牌回滚。

## 明确保留边界

未支持Snecko Skull（源ID Snake Skull）、其他onApplyPower钩子、全部毒牌、受保护媒体、正式UI、自然奖励/商店池或千星实机。既有Poison tick的来源归属仍须共享Actor专项核对。

运行时支持非负有符号32位安全范围；乘法原量或叠加结果超界会拒绝并由外层回滚，不擅自截断成9999，也不声称等价模拟Java整型溢出后的负毒边缘行为。后续要扩极值范围必须单独取证并测试。
