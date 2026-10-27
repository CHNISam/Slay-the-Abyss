# 事件战斗：敌人构造与开战分离

固定来源仍为初代 PC A0 的社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。来源锁与独立8种子向量见 `tests/fixtures/event-enemy-preparation-source.json`。不将社区镜像或本地受控测试称为原版 PC 二进制认证。

MysteriousSphere 构造事件时已经创建 `2 Orb Walkers`，依次位于 `(-250,32)` 和 `(150,26)`。OrbWalker 每只先为父构造参数抽一次90–96，再以 `setHp(90,96)` 抽一次，故进入事件时消费4次 monsterHpRng；放弃事件不会撤销已发生的构造。此时尚未执行 `MonsterGroup.init`，没有AI、成长、牌组洗牌、遗物或发牌。选择Fight并经过其确认阶段后才调用组初始化；每只的 `AbstractMonster.init` 调用一次 rollMove。组preBattle才施加成长3。

MindBloom的构造时点不同：选择Fight并shuffle选定第一幕首领后，才构造该首领；预排金币和稀有遗物发生在敌人HP构造之后、AI开战之前。两类事件共同需要保存构造结果，而不是提前创建整场Combat。

## 公共接口与保存格式

`Combat.prepareEncounter(data, options)` 只准备敌人，options必须提供原始 `roomSeed`、`roomStreams.monsterHpRng`，以及 `sourceEncounter` 或显式 `enemies` 两者之一。来源组装使用原有 `encounterBoundary`；固定双机关只需其 `misc` 表，不调用任何misc/视觉回调。动态组装的回调仍由调用方提供私有事务owner，语义与旧普通路径相同。

返回对象字段：`version=1`、`roomSeed`、`sourceEncounter`或`enemyIds`、`actorIds`、`actors`、`monsterHpRng`、`catalogAdditions`。其中 `monsterHpRng` 是 **`{words,counter}` 快照，不是live RNG**；父桥可用 `SourceRandom.restore(prepared.monsterHpRng)` 建立构造后流。新加入的构造期定义单独保存，例如Awakened One为虚空定义的准备；不保存玩家、AI、shuffle、misc、手牌或遗物状态。

`Combat.new(data,{preparedEncounter=prepared,roomSeed=...,roomStreams=..., ...})` 复用准备结果。此调用禁止同时传入 `enemies`、`sourceEncounter`；来源身份来自prepared并由父事件包装核对楼层/原始runSeed。Combat校验房间seed、构造态身份和未初始化状态，复制actor并绑定到最终状态目录，恢复构造后HP流，然后继续既有AI、shuffle、preBattle及玩家开战路径。缓存不被初始化或后续战斗修改。

**misc使用本次传入的最新流。** Sphere在prepare之后仍会消费Fight金币抽样；父桥应克隆当前run.miscRng放入 `roomStreams.miscRng`。prepared没有misc快照，不能撤销已选择的金币/稀有遗物。AI与shuffle仍从正确房间初始owner开始，各初始化一次。

## 职责和证据边界

`abyss_combat_enemy_setup`共享敌人/状态目录注册、原makeEnemy的构造抽样与意图验证、来源组装及构造快照复制。`Combat`仍拥有所有开战、玩家牌堆、遗物、回合及动作队列。普通路径和召唤/分裂继续走同一构造实现，没有另一套OrbWalker算法。

受控测试覆盖4次HP构造、独立源向量、没有提前调用整场Combat/AI/发牌、准备后与普通完整开战状态一致、选项后的misc不回滚、三个第一幕首领、混搭/错seed拒绝、构造及开战失败不改输入、动态虚空定义保留。首次运行在无API处明确RED，补底座后通过；未放宽30秒预算。

2026-10-28实际结果：专有Lua9/9、JS来源合同1/1通过；同机串行执行，Lua专项约3秒。另将精确基线 `0c07e3dc` 的原Combat装入独立旧实例，与新普通路径对比10场完整初始battle graph，逐字段相同（3.685秒）。矩阵包括cultist、Guardian、Hexaghost、SlimeBoss、Transient、SmallSlimes、3Shapes、AwakenedOne、Reptomancer、3Darklings，覆盖原生显式ID、源构造顺序、随机候选、特殊共享定义和开战状态；不是10场自然游玩。差分探针及基线文件仅在 `build/event-enemy-*` 取证，不把整份旧实现加入产品或长期测试依赖。当前三个生产Lua及专有测试Lua语法解析、`git diff --check`通过。

此组件尚不代表Sphere/MindBloom正式事件桥、奖励、全职业自然通关、原生候选或实机UI验收。事件注册与Run/Nodes桥由集成线程负责；不关闭TASK-62/M3。
