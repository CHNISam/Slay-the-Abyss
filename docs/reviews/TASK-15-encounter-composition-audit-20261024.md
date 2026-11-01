# 两种遭遇组合仍要修正，M3不能因此收口

2026-10-24只读审计。**现有`medium_slimes`两只中型软泥的组合缺少本轮原版依据；`gremlin_gang`固定五只也与已核对来源不符。两项归TASK-15及首发清单TASK-47后续必须处理。** PR174只修`small_slimes`，即使它合并也不关闭这两项，不应把“18组数据均可开战”当作首发遭遇已经合规。

本轮只保存来源、差异与下一步方案，没有更改数据、生产代码、随机池、既有测试或任务状态。没有自动把`medium_slimes`改名或等价为原作另一种遭遇，也没有新建Backlog任务。

## 这次实际查看了什么

- [PR174](https://github.com/CHNISam/Slay-the-Abyss/pull/174)当前头为`231dd0ff8a1438b245cb5dd549c575cc47006363`，读取时仍OPEN；正文明确另外两项编组仍留TASK-15。该头的`abyss_run.lua`、`abyss_nodes.lua`、`enemies.json`和专项账本已逐文件只读下载。
- [PR168](https://github.com/CHNISam/Slay-the-Abyss/pull/168)已合并，合入SHA为`ee9c40d9ee2b9badaab84af8aaa6b9ddc2551f9c`。下一实现基线应采用包含两PR最终整合结果的develop，不能从本地图候选的旧基线重复搬代码。
- 游戏依据为固定社区镜像[MonsterHelper](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java)，blob `a81763abf681642be66cbd935cc99d2126e822f4`，内容SHA256 `e6a60cdfa7af881d5f128a9532664ea33f32e71239cda49f3983fceac95a10e1`。同时读取相同提交的[Exordium](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/Exordium.java)普通池清单与五种小魔类。
- 原始API响应、PR174文件、五种小魔源文保存在根`.artifacts/m3-encounter-audit-231dd0ff/`。这不是正版PC构建认证或实机观察；未复制、运行第三方实现。

## 当前差异

| 遭遇 | PR174头的实际内容 | 固定来源与结论 |
| --- | --- | --- |
| `small_slimes` | 一次misc Boolean选“小棘刺→中酸液”或“小酸液→中棘刺” | 与MonsterHelper.spawnSmallSlimes的两种身份/顺序一致；本审计复用174机制，不重做它。全流、AI和实机仍按其账本界限。 |
| `medium_slimes` | 固定`acid_slime_m, spike_slime_m`，层4..14仍能进入正常池 | MonsterHelper没有“Medium Slimes”独立遭遇，Exordium弱/强池也没有此名；本轮未找到这对中型软泥作为固定普通遭遇的依据。不能因两种敌人各自AI正确就证明组合合法。必须在TASK-15/47清单中明确处理，暂不能算合法首发组合。 |
| `gremlin_gang` | 固定Mad→Sneaky→Fat→Wizard→Shield，五种同时出现 | MonsterHelper.spawnGremlins生成**四只**。从有序多重池Mad、Mad、Sneaky、Sneaky、Fat、Fat、Shield、Wizard中逐次抽一个并移除，保留抽取顺序；允许前三种重复，Shield/Wizard各最多一只。不是五种里等概率抽四种。 |

原作另有`Lots of Slimes`：MonsterHelper.spawnManySmallSlimes从三只小棘刺、两只小酸液的五项池逐次无放回排列，最终仍是五只小软泥。它是独立的已核对遭遇，**并不证明当前`medium_slimes`就是它的正确映射**。应先在TASK-47决定当前ID的合法归属及对应获取/移除方案；不能偷偷替换后沿用旧快照、旧概率和旧实机记录。

## 下一批可以独立实现的小魔修复

来源已明确，可在PR174整合后做一个完整切片；本轮不实施。

1. 在`data/enemies.json`为`gremlin_gang`显式描述“按顺序从多重池无放回抽4只”，池保持上表八项顺序；`scripts/validate-data.mjs`校验固定编组与动态池互斥、成员存在、count不超过池长/战场容量，不能留一个错误五人fallback。具体字段名在实施时统一，避免为此引入通用脚本执行器。
2. `src/lua/abyss_run.lua`复用174的`nextMiscRng=cloneState(run.miscRng)`和成功后提交。新增受限组装函数，四次调用`EventRandom.randomInt(nextMiscRng,7/6/5/4)`，每次取当前池索引后移除；交`Combat.new`的数组按抽取顺序。四种闭区间调用的wrapper counter应精确+4，底层拒绝采样另由既有原语决定。不能用全池shuffle代替四抽，不能取Combat的HP/AI/洗牌流。
3. 174的`src/lua/abyss_nodes.lua`已经在暂存run中先开战再提交，并使用`stagedRun.miscRng`，因此原则上无需再写一套Nodes事务。测试必须证明直接Run与真实Nodes入口都保留四次新消费，构造失败/抛异常/开场遗物失败和重试不提前提交。五个小魔类原文没有直接miscRng调用，但构造/HP/AI的全流等价仍不能由此替代生产验证。
4. 先红后绿覆盖受控索引轨迹、重复个体/Shield-Wizard上限、每个槽位、四次边界及精确state；保留174的18组small_slimes与开战失败负例。对其他16组固定遭遇做direct/Nodes整状态差分，不能为了新组装改动它们的随机消费。
5. 现有`fat_gremlin.lua`、`mad_gremlin.lua`、`sneaky_gremlin.lua`、`shield_gremlin.lua`、`wizard_opening_roll.lua`、`queued_enemy_status.lua`和`battle_ui.lua`多处把该Run入口当作必有五种敌人的夹具。迁移为可证明包含所测敌人的受控合法四人组，按身份取槽；继续保留真实Run、伤害/队列/回滚断言。尤其Shield固定第5槽的断言必须迁移，不能直接删掉。`encounter_coverage.lua`要验证动态成员与合法重复，不能只遍历原静态数组冒充运行覆盖。

小魔编组预计为数据/Run/校验器3个生产文件加上述专项夹具和新集成测试；Combat、敌人AI与Nodes无需预设修改。真正落地后仍需全组合离线检查、同源副本编译/读回与新平台实机；旧M2通关不覆盖改变后的四人组。

## 中型软泥与首发清单的处理门槛

TASK-15/47必须先决定`medium_slimes`的合法归属：提供可信原版依据，或把缺依据的现有组合从合法池移除并按冻结清单处理相应覆盖/存档；若要新增正确的`Lots of Slimes`，应作为有自己ID/清单依据的内容明确实现与验收。没有来源时不补一个随机分支假装对齐，不把这项隐藏在“数量够了”下面。

当前只读审计没有解决编组、出现范围、普通早晚队列/权重/重复限制，也没有新编译或游戏证据。**这些必要缺口在修正和验收前继续阻止M3整体Done。**
