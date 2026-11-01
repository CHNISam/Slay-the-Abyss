# Awakened One：A0 三敌遭遇与两阶段源码切片

## 范围与来源

本切片基于 PR238 已推送但当时未接受的 `0a773c1c8e736b564514c2c61adeaa6af541f023`。开工只读核实了更新后的 PR238 `2535527608630e37510cdf6a54d643d830d592a7`，其 `abyss_act3_bosses.lua` 仍只有 Donu/Deca，未重复实现 Awakened One。远端整合、当前完整 Quality、Backlog 和发布由主集成负责。

唯一行为基准为 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，按需读取了 37 个相关文件，没有下载源码归档。每个返回文件的 Git blob SHA 和 SHA256 均从原始 UTF-8 字节重算核对，见 [来源身份](../evidence/awakened-one-source.json)。这是社区反编译镜像，**不是官方开源、经认证的 PC 二进制或本轮原作实测**。运行时为独立 Lua 实现，没有复制第三方代码、素材或原版长文案。

主要源调用链：

- [MonsterHelper 的三敌构造顺序与位置](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java#L582-L585)。
- [AwakenedOne 构造、开场 Power、所有招式和 Rebirth](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/beyond/AwakenedOne.java#L97-L229)。
- [两形态 AI、damage 覆盖、最终 die](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/beyond/AwakenedOne.java#L232-L369)。
- [AbstractMonster 的伤害、死亡与选招历史](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java)、[MonsterGroup 的 halfDead 入队与整组回合末 Power](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java)。
- [Curiosity](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/CuriosityPower.java)、[Regenerate](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/RegenerateMonsterPower.java)、[Shackled](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/GainStrengthPower.java)、[ClearCardQueueAction](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/ClearCardQueueAction.java)。

## 已实现的规则合同

| 边界 | 本切片行为 |
| --- | --- |
| 正常遭遇 | 按顺序创建两只普通 Cultist，再创建 Awakened One，位置分别为 `(-590,10)`、`(-298,-10)`、`(100,15)`。Cultist 不标仆从；复用已有 A0 HP48–54、仪式3与基础6攻击。没有修改来源队列、概率或缺项守卫。 |
| A0 开场 | Boss300 HP；依次获得 Regenerate10、Curiosity1、Unawakened。保留 Unawakened 源 `-1` 无数字哨兵；不加入 A4 的2力量或 A19 的15再生/2好奇。 |
| 第一形态 AI | 首动 Slash20，仍消费开场主 roll。后续每次消费一个0–99主 roll；`<25` 倾向 Soul Strike6×4，但不能连续；其余倾向 Slash，但不能三连。不追加重抽。 |
| 第二形态 AI | Rebirth 的排队 RollMove 仍消费一次主 roll，固定预告 Dark Echo40。真正执行 Dark Echo 后解除首动标志。之后 `<50` Sludge18＋Void1，否则 Tackle10×3，各自最多两连；无重抽。 |
| 第一阶段致死 | 真实 HP 降至0后，清零致死直接失血留下的旧格挡并进入 `halfDead`，不是死亡终局，也不是伪造 HP1。照源执行已有死亡 Power，再移除 Debuff、Curiosity、Unawakened、Shackled；保留正力量与永久再生。即时预告 Rebirth，同时将 ClearCardQueue 放在 TOP、SetMove(Rebirth) 放在 BOTTOM。 |
| 重生行动 | 允许明确的 halfDead Boss 进入怪物行动队列；Rebirth 清除 halfDead，依次排队 Heal300 和 CanLose，已有 RollMove 仍在它们之前。正常目标选择、伤害、药水瞄准仍要求 `isActive`，重生准备时不能被攻击。 |
| 最终死亡 | 真正死亡；若致死直接失血留下旧格挡，第一次父类死亡 Power 访问仍看旧格挡，随后清零，再执行覆盖方法的第二次访问。随后普通 Cultist 只排队逃跑，不假装被击杀或额外记死亡奖励。固定源 `super.die()` 与 `damage()` 覆盖在最终形态均访问死亡 Power；有 Cultist 存活时保留两次访问及其间的 Escape 队列顺序。整场仅由现有 Run 结算一次。 |
| 卡牌/反应 | Feed、Hand of Greed、Ritual Dagger 的原 halfDead 击杀收益门继续生效；第一形态不给最终击杀收益。毒伤、反伤、InstantKill 使用同一死亡接点。Poison 被同步清理后不被 tick 重新写回。Corpse Explosion 在清理之前快照并进入原队列，不能把半死 Boss 当作最终清场。 |
| Power 顺序 | Curiosity 与 Choked 按真实取得顺序建造 onUse 动作，能力牌原生效果在前、UseCard 清理在后。Regenerate 与后取得的 Shackled 在整组回合末按取得顺序建造原队列动作；只跳过该 Boss 的旧 Colorless 即时归还路径，避免重复归还。 |
| Void | Sludge 在攻击后往抽牌堆随机位置生成一张 Void；非空时消费一次 card RNG，空堆不抽；不使用洗牌流。复用现有抽到失去1能量、不可打出和虚无消耗路径。Void 只在该遭遇缺定义时补充，不进入牌池。 |
| 事务 | 沿用现有原生/高级出牌与整回合快照。新 boss 使 endTurn 选择既有原子回合边界；错误恢复原 actor、手牌、Power 历史、队列、RNG 与输入状态，不引入新行动管理器。 |

## 共用边界为何需要改变

`Actor.isActive` 继续只代表可作用的存活目标。新增 `isPresent` 只用于战斗是否终止、已核实的 halfDead 怪物行动、以及只读展示/帮助。After Image、弃牌收益、Mantra、Loop、回合能力、Combust、Corpse/Stasis、Scry/手牌/牌堆/弃牌选择、Dark Embrace、Red Skull/Centennial Puzzle、充能球及 Mayhem 自身牌自动打出 不能因为 Boss 暂时0 HP就被误判为战后；实际目标集合仍调用 `isActive`。

显示层把0/300的半死 Boss 保留在场上，提供未知/Rebirth 意图和只读详情，且不播放最终死亡坍塌。第二阶段真死仍走原死亡反馈。Sludge 采用现有“攻击主图标＋削弱角标”的设计，详情列出 Void、抽牌堆与抽牌失能量；没有替换批准美术或另造控件。

Actor 的非 Awakened 死亡仍只调用一次原有 Stasis/Corpse/Act2 died 顺序；新增双访问只在固定源 Awakened 最终死亡。已有死亡顺序、晚失败回滚、Donu/Deca、Act1 Boss 与生成控件回归已实跑。

完整 grep 审核另外区分了以下边界：伤害/药水/随机目标集合继续要求存活目标；Poison 的目标运行门没有扩展；无生产调用者的旧 `Shivs.startTurn` 与原创角色的自定义歌者规则未改。无存活目标时，闪电激发不抽目标 RNG，Frost/Plasma/Dark/生成充能球仍可执行。真实 Vault 跳过半死 Boss 的回合后，Mayhem 允许以空目标自动打出自身牌，仍保持源“普通抽牌先于 PlayTop”的既有队列顺序。

**尚缺的共享能力边界**：本仓目前没有通用的 `Relic.onMonsterDeath` 分发器。本切片保留了已实现的死亡 Power 顺序，但**没有声称 Gremlin Horn、The Specimen 等尚不可领取遗物的全部互动已经完成**，也没有为了抽到它们改池或删守卫。固定源在第一形态调用遗物死亡钩子一次、最终形态两次；未来共享遗物分发器必须遵守该次数及 Power→Relic→ClearCardQueue 顺序。当前并行遗物切片只涉及 Snake Skull、Data Disk、Damaru，不新增该分发器。

固定 Luacheck 未增加豁免：Feedback 新增一行依赖使9条既有诊断行号平移1，每条均核实原/新源码行相同、code/column/语义相同；只更新精确位置。

## 证据层级与未证明事项

- **组件/规则**：`tests/lua/awakened_one.lua` 的38组（含原生和高级两个真实派发器、完整阈值枚举、异常回滚、卡牌击杀收益、队列清理与当前牌继续）通过。
- **半死期间非目标结算**：`tests/lua/awakened_one_presence.lua` 的13组实际 `C.play/choose*`、消耗/遗物/充能球与 Vault→Mayhem 通过。明确验证 Sunder 依固定源只判断 HP≤0而仍退能量，不能把 Feed/Greed/Dagger 的 halfDead 收益门套给全部“击杀”效果。
- **正式 Run API 组件**：通过 `Run.startRoomCombat(...,'boss')` 的第三幕 Boss 入口，验证三敌构造、HP/AI随机流计数、两阶段和一次奖励。该用例明确构造第三幕50层边界，**不是第一至第三幕自然连续路线**。
- **生成控件离线**：`tests/lua/awakened_one_ui.lua` 使用真实生成的按钮/鼠标事件与 Host/Run/Combat；验证0/300可见、重生/状态详情、无首形态死亡坍塌、重生300/300、Sludge混合意图与最终一次结算。战斗 HP 是明确的受控边界夹具，**不是自然获取或原神运行时**。
- **测试敏感性**：独立原基线应在来源 resolver 断言变红；18个真实源码变异须由指定原测试断言杀死，单夹具仍保留原30000ms时限；原源码 hash 必须不变。实际结果在验证清单记录，不以语法错误或超时冒充 kill；其余不可作用目标的判断未改。
- **仍未证明**：完整四职业四幕自然路线、当前整合 SHA 的全部 Quality、新GIL候选、官方导入、实机启动日志、PC/手机与 `verify:ui`。本切片不把这些层级提升为通过，也不宣称 M3 整体完成。

本轮没有键鼠或前台占用，没有推送、PR、合并、Tag、发布、依赖/CI修改或 Backlog 写入。
