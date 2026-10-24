# TASK-15.4 · 狂怒小魔的受击增力与真实出招

## 有限生产缺口

基线 `5913a3fa9b2d93ce41ecda85c2a6b4e916ab20e8` 的合法 `gremlin_gang` 已包含 `mad_gremlin`，但该敌人固定22生命、交替攻击4与主动获得力量2，没有受击被动。这不是原版 A0 行为。本片修复既有可玩敌人的完整有限策略，不扩充敌人池，不继续逐个拆分已修好的开场随机消费。

修正为20–24生命范围、开场获得狂怒1、每回合攻击4。一次普通攻击穿透格挡并损失生命后，排队获得等同狂怒层数的正力量。多段分别触发，范围伤害先打完所有目标，再逆目标次序处理顶层反应。致死目标的力量应用被取消；伤害全灭则不残留力量应用。仅开场选招请求一次主随机数，后续固定攻击使用已有直接设置策略，不添加回合末或死后随机调用。

复查当前所有12种已接线 AI 策略发现开场调用均已有对应实现；Acid S、Sneaky、Wizard、Guardian 的直接设置后续动作不应擅加随机请求。本次没有改这些策略的规则或宣称全部敌人一致。

## 固定来源与精确身份

2026-10-23 UTC 只读核对社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。使用 GitHub REST contents 返回的 base64 原始字节逐份复算 Git blob 与 SHA256，不以展示文本多出的换行代替原始字节。版本自述 `[V2.3.4] (12-18-2022)`；未经正版 PC JAR/hash 认证，不是官方源代码、原作录像或本轮 PC 实测。只依据功能事实独立实现，没有提交或移植第三方实现、原版玩家文案或素材。

| 固定来源 | 核对事实 | Git blob |
| --- | --- | --- |
| [GremlinWarrior.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/GremlinWarrior.java) | A0 HP20–24、伤害4、战前Angry1；固定攻击后SetMove；没有额外主动增力回合 | `c21c6e7ff4159f74c158b6e5f23dbe425c6da6e9` |
| [AngryPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/AngryPower.java) | onAttacked要求非空伤害来源、正伤害，排除HP_LOSS/THORNS；正Strength加到队列顶部 | `a840a8396e44cf8ef6dd82b5117ea735544c4b9c` |
| [AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | 先扣格挡，再onAttacked，再扣HP/死亡；init继承rollMove | `4784e38e7afff5980736e2b5c718e62a0c838c47` |
| [ApplyPowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java) | 死亡目标取消应用；正力量不走Artifact减益拦截 | `1a6af352c02e06ecec4db87dd5e2f57d43d35b91` |
| [DamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java) / [DamageAllEnemiesAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAllEnemiesAction.java) | 单次伤害动作完成后处理顶层反应；范围伤害先迭代全部目标；末敌死亡清理后续非保留动作 | `ea89aeab60af8a7c297495de3cd8eb82d7130232` / `13cc91e59ae21b8173468c4235849c6677ea3f55` |
| [AbstractPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/AbstractPower.java) / [ThornsPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThornsPower.java) | 两者默认priority5；比较只看priority；普通Mad先有Angry，后添加Thorns时逆队列先Thorns后Angry。isPostActionPower不改变damage的迭代 | `70347e8e642e8c45e6c6aadbe6e34f0472220c18` / `e898e2f525a6eb49664eadb847dacb681f2931fe` |
| [FirePotion.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/potions/FirePotion.java) / [ExplosivePotion.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/potions/ExplosivePotion.java) | 火瓶使用THORNS；爆炸瓶为NORMAL但来源null，均不触发Angry；当前合法药水池无爆炸瓶 | `fafc0b92d3aa8e285a8d7750a45e8bc7c8f0dab9` / `4c7b5e9feec9c057a8b5cc8d1379867d0afc12ac` |

GremlinWarrior SHA256：`3b329caeee4d853c8a29e1fc83bb1786f176d439f984684d1cfadd9ce3aea034`；AngryPower SHA256：`40315ca3eff392e524b39c9ff72881a3793e707dab225e3b4c5cffe51d1639e3`。

## 实现边界

- 新的 `mad_gremlin` 数据策略复用固定攻击选择，不为未支持的第二幕Gremlin Leader/逃跑行为增加入口。
- `Actor.damage` 仅从当前NORMAL攻击路径产生Angry反应；毒、真实火瓶、荆棘与固定伤害不会触发。伤害API已有来源非空约束，本片不增加无来源攻击ABI。
- 范围伤害沿用既有反伤收集队列，增加可识别的正力量反应。先完成全部目标伤害，再逆序处理；仍调用已有ApplyPower死亡/Artifact/封顶门禁，不改PR128/129已修正的末敌取消与死后敌人排队效果。
- 狂怒使用独立、原创中文状态名与描述。共享主题映射复用既有力量类平台图标103047，未改布局、交互或美术方向。通用状态视图自动读取新定义。
- 保留现有动态UI分支的独立所有权；本片不修改其Combat.cardPreview或UI组件。共享theme仅新增独立status映射。

## 真实入口负例与验证

`tests/lua/mad_gremlin.lua` 25组从真实Combat/Run执行。旧生产代码9过16败，失败分别定位固定HP、假增力回合、缺少被动、开场消费及范围队列。修后25/25通过。覆盖：

- 20–24范围、64种子覆盖每个整数、0/99开场端点、HP/AI/洗牌请求顺序；五回合连续攻击而不主动增力或追加抽样。
- Strike、Twin Strike、Body Slam；全挡/零伤/部分格挡；多段每次穿透各自加1力量。
- 两只Mad范围受击后逆序加力；一只死亡只取消自己的应用；全部死亡不加力；Thunderclap先结算Angry再施加Vulnerable。
- 毒、荆棘、真实Fire Potion不触发；致死目标不加力；正力量跨负数不消耗Artifact；999上限保留。
- 只读预览、拒绝操作、抛错卡牌原地回滚，真实合法gremlin_gang入口仅Mad持有狂怒。

新增13项schema检查在旧代码全部失败，修后通过；新增主题映射检查先失败再通过。连同已有AI/Cultist/Lagavulin/Guardian共56项JS检查通过。旧Wizard合法gang回归明确从3次开场主draw调整为4次，增加Mad而保留所有Wizard动作和次序断言；不是减少断言或改生产以迎合旧夹具。

最终数据、UI与地图布局前置构建、数据校验、修改JS语法检查通过；完整101个原生Lua5.4 fixture通过。第一次完整运行发现新增状态漏图标导致theme构建失败，已补最小映射；第二次运行10个fixture因本地runner漏LUA_PATH未能加载模块，修正执行环境后101/101重跑全过。失败日志保留，不冒称第一次即通过。

没有安装依赖、运行受限的完整npm check，原生Lua5.4不等于Fengari或正式CI。独立完整评审、当前SHA正式CI及合并结果以PR记录为准。本片无平台编译、候选导出、官方导入或千星实机证据。

## 保留的未完成项

生命、AI、洗牌仍共用项目16位LCG；新增合法HP/开场draw会改变项目后续牌序和队友行为，但不是原作独立流、RandomXS128或种子重放一致。任意Power插入历史、未实现敌人特殊机制、完整动作队列/玩家死亡后调度、原版二进制真实性、官方平台与全池严格一致性仍未认证。该切片不关闭TASK-15整体或任何平台AC。
