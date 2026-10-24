# TASK-15.5 · 护盾小魔的队友保护与独处攻击

## 有限可玩缺口

基线 `8d9a37f5419b21c13a31f889aad1b269bbc8b358` 的合法 `gremlin_gang` 已包含护盾小魔，但此前固定14生命、只给自己7格挡，并每隔一轮攻击6。本片修复该既有敌人的 A0 行为，不新增敌人、遭遇、逃跑系统或独立原版随机流。

- 生命按12–15闭区间抽样；继承的开场选招消费一次主roll，首动始终Protect。
- Protect执行时按敌人列表顺序列出非自己、非死亡、意图非ESCAPE的目标。列表非空时以 `aiRng.random(count - 1)` 选择，包括仅有一名队友时仍消费一次；空列表不消费目标随机，改为给自己7格挡。不是monsterRng或cardRandomRng。
- Protect选后续动作时，有其他活着且未在逃离的敌人则继续Protect，否则改为Bash6。已选Bash后一直Bash，不再因为出现队友回到Protect。初始独处或队友刚被杀仍先执行当前Protect，不能提前替换当前意图。
- Protect使用固定7格挡并保留共享999上限，不使用来源或接收者的卡牌敏捷/脆弱修正；UI紧凑值与详情一致。

## 必要的敌方回合顺序修复

`MonsterStartTurnAction` 调用整个 `MonsterGroup.applyPreTurnLogic`。该方法同步清除各活体敌人的旧格挡，但 `PoisonPower.atStartOfTurn` 只是把伤害加入动作队列。`GameActionManager` 先清空动作，再处理monsterQueue。因此顺序是：全部旧格挡清除 → 全部已支持的回合开始状态按敌人顺序结算 → 敌人动作。不能简单把原 `Actor.startTurn` 搬到一个预循环，因为它会即时扣毒，造成第一个毒伤画面仍保留后排的旧格挡。

本片将已有Actor的清盾与开始状态分成 `resetBlock` / `startTurnEffects`，保留原 `startTurn` 包装；Combat使用两个组级预循环后再执行已有动作循环。该顺序保证前排护盾小魔给后排的格挡不会被后排自己的行动前再次清除，也保证已被本轮毒死的后排不会成为Protect目标或假装保留战斗。

这仅对当前支持的开始状态作等价调度，不宣称实现原作任意Power/遗物/召唤的通用动作队列。`EnemyAI.hpLost/flush/finish` 仍逐个支持状态结算，末敌毒死会在首个敌方动作前结束。Barricade保盾、玩家回合入口与轮末Ritual/Weak等时序保持。

## 固定来源与身份

2026-10-23 UTC只读核对社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。GitHub contents base64原始字节逐份复算Git blob与SHA256；没有以展示文本的换行代替原始字节。该镜像自述V2.3.4/2022-12-18，未经正版PC构建hash认证；不是官方开源或本轮PC实测。仅独立实现行为事实，没有提交第三方源码或复制原版文案/素材。

| 固定文件 | Git blob | SHA256 |
| --- | --- | --- |
| [monsters/exordium/GremlinTsundere.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/GremlinTsundere.java) | `83a2e75ff02446a721e77c099f220ff38e6dcda9` | `1ba7d0c1c1c0d12b38a41671382cb7e7fed9c7b3c8a5296bdf8c4c8f7179ce06` |
| [actions/unique/GainBlockRandomMonsterAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/GainBlockRandomMonsterAction.java) | `5732363bbc50f69d572f0fb81a8b8c3a1e393daf` | `7aadeb12b7ca53fd696fee24a616ae7e9a7d3816fbbaaff3c52c2df25a4d81e2` |
| [monsters/MonsterGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java) | `7096970a151840489a3fba89806e6391e0d82d76` | `535770201b8aa8de01b52b185979af537f11ad0862e7d3e71ebb20cc64234221` |
| [actions/common/SetMoveAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/SetMoveAction.java) | `3d06fd9e29345de1c7c9d35c473543a2c7f041e3` | `2b6c9200a4574d514674214d342a24993d6bd7f9ce1ac81306fd308adb443666` |
| [actions/GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `1662da8de2aeb42044b385f03d0c801750904b13` | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| [powers/PoisonPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/PoisonPower.java) | `775cbbc50947b9465c4013d93bcdeeade5c9abac` | `b4269eafb2a23282142e9c5460510e4a876d7abb3c62ae6d7a2211b5826ac6c2` |
| [actions/unique/PoisonLoseHpAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/PoisonLoseHpAction.java) | `338fa49aa56a439a934cfe2310c905b09be7238a` | `43fcf2e88d5295fdf12781cf6980a93941e9814aa0a98a7a9a8b47af0413ba1a` |
| [random/Random.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java) | `c4b71d5645688f6e764c46c593223eb91a5249bc` | `476be7d8af2080b6b52f6cecc78c35f01904c18dbacc7ea795a361e600f05172` |
| [core/AbstractCreature.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java) | `bee5f7d0d955528b69007376cc0465ed60e577c6` | `3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b` |
| [actions/common/MonsterStartTurnAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/MonsterStartTurnAction.java) | `c80b4792ac95728e8941a119f2e72643698b4389` | `33e46ecb50f3776a631b9b9ba3f3abccf7cb54147671aee8bb7342d19e8dc05d` |

`GremlinTsundere`提供A0常数、Protect/Bash转换与继承开场行为；`GainBlockRandomMonsterAction`提供候选过滤、aiRng、空列表回退与addBlock；`Random`证明单元素请求也推进计数；`AbstractCreature.addBlock`不是卡牌applyPowers，不加Dex/Frail。其余文件提供组级预回合、Poison排队、队列优先级和SetMove非随机转换的调用链。开场继承 `AbstractMonster.init/rollMove` 的固定来源身份沿用同提交 [TASK-15.4账本](TASK-15.4-mad-gremlin.md)。

## 离线验证

- 先写真实Combat/Run专项20例：基线6过14败；实施后全部通过。独立复核增加的两项“后排毒死使Fat反伤成为末敌、取消排队Weak/roll”和“前排致死玩家不应省略后排的预回合毒伤”已纳入，最终22例通过。
- 来源预期覆盖：12–15每整数HP、开场/洗牌消费、零/一/二队友目标消费、敌人顺序、死人/ESCAPE意图过滤、先Protect后永久Bash、实际Strike杀队友、毒死/反伤死、双护盾实例、固定Block999、真实Run五小魔、异常出牌回滚。
- 原生生成控件树验证Protect7与Bash6、随机队友/无队友回退详情、只读查看及真实两轮变换。复核发现Dex/Frail预览错误，补独立红例后只对random_ally传fixed标志，普通Block预览不改。
- 新schema15例通过，相关数据/schema共164例通过。拒绝错意图、非法roll、丢失目标选择器，以及把敌方队友格挡用作玩家牌/药水/遗物效果。
- 103个现有及新增Lua顶层夹具以系统Lua5.4逐个执行，103通过。包含全部状态、Ritual/Cultist、Lagavulin、Guardian、毒/反伤队列、库存、原生UI与遭遇覆盖。单体battle_ui仍使用原测试器要求的已生成布局注入；未删例或放宽原限时。
- 初次整理缩进造成的语法失败被保留并修正；后续102/103的唯一失败是旧Wizard五敌入口固化“四个主roll”。已按新增Shield的来源改为五个，保留其它断言，再全套通过。
- 独立审查另外20例、15个schema例和16个重点Lua文件通过，八个故意破坏语义的变异全部被测出；独立UI证明普通格挡仍应用Dex/Frail，而Protect固定7。最终七个生产文件hash与审查冻结清单相同，无阻断发现。
- build:data、build:ui、build:theme、validate:data与相关JS语法通过。没有运行完整npm check，远端精确SHA的Quality由主线程核对；系统Lua5.4不冒充Fengari或平台Lua通过。

## 保留边界

- 生产仍使用项目共享16位LCG，不是原版aiRng/monsterHpRng独立流，随机算法/跨流种子映射仍待TASK-16.1；仅证实当前调用位置、范围和次数。
- 当前第一幕没有Gremlin Leader、escapeNext或实际逃离状态；不新增第二幕入口。源代码的“正在逃离”和“已有ESCAPE意图”是不同条件，不能把本片的死亡/意图过滤扩称完整逃跑机制。当前活体数等价仅适用于无实际逃离状态的已支持内容。
- 五小魔固定编组仍非原版遭遇抽取；它仅作为当前合法可玩入口的集成夹具。本片没有借修一个敌人宣称全遭遇或整个第一幕一致。
- 未平台编译、导出、官方导入或游戏实机。TASK-15全池/原版版本认证/平台AC、M1/M3和完整通关关口全部保留。
