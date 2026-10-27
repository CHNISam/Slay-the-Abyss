# Transient 独立遭遇

本片仅实现第三幕普通遭遇 Transient。原母队列、权重、拒重和其它未实现遭遇的明确拒绝保持；未增加 Darklings、Boss 或其它正式编队。固定来源为本地只读第三方反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是官方源码或原版PC二进制执行。

[来源锁](../../tests/fixtures/act3-transient-source-lock.json)记录 ZIP 与21个原始成员的逐字节 SHA256；[独立 Python 模型](../../tools/oracles/sts1_transient.py)不导入生产 Lua 或游戏数据，生成[三条五行动向量](../../tests/fixtures/act3-transient-vectors.lua)。生成器和向量按LF归一化锁定，ZIP成员不归一化。

| 固定方法 | A0实现合同 |
| --- | --- |
| `Transient` constructor、`AbstractMonster` constructor | superclass常量HP999，没有setHp；monsterHpRng零次抽样。monster.gold初始1，但该字段不决定普通房间奖励。 |
| `AbstractMonster.init/rollMove`、`Transient.getMove/takeTurn` | 开场一次0..99 AI抽样；攻击基础值依次30/40/50/60/70。takeTurn直接设置下一招并递增count，没有后续RollMove。提前设置下一招时复制意图图，旧frame不被改写。 |
| `Transient.usePreBattleAction`、`AbstractPower` | 先施加Fading5，再施加Shifting；两者BUFF、默认priority5。Shifting源amount不显示，核心用none叠层的存在标记表示。没有使用A2/A17值。 |
| `AbstractMonster.damage`、`ShiftingPower.onAttacked` | 回调收到格挡和伤害修改后的正damageAmount，发生在实际HP扣减/钳制前；不是按实际损失HP计算。没有伤害类型或owner过滤，NORMAL、THORNS、HP_LOSS与毒均可触发，完全格挡/零伤害不触发，Intangible先减为1。 |
| `ShiftingPower.onAttacked`、`ApplyPowerAction`、`GainStrengthPower` | 回调时检查Artifact：存在则不排恢复Power，负Strength由Artifact抵挡。否则两个TOP动作逆序执行，先GainStrength/Shackled再负Strength。沿用真实Shackled ID、DEBUFF与999上限；致死后ApplyPower动作取消。 |
| `GainStrengthPower.atEndOfTurn`、`MonsterGroup.applyEndOfTurnPowers`、`GameActionManager.getNextAction` | 所有怪物行动完毕后，才执行怪物owner-end恢复与移除Shackled，早于atEndOfRound。仅将Transient从两个旧提前恢复入口延后；玩家ordinary阶段和其它怪物不改。 |
| `FadingPower.duringTurn`、`AbstractCreature.applyTurnPowers`、`SuicideAction` | takeTurn先排攻击，duringTurn随后排倒计时/自毁。第五次攻击后自毁，早于怪物owner-end；Suicide置gold0与HP0并die(true)，不调用伤害回调，不设置escaped。保留死亡Power通知。玩家先死则败北，不追加胜利。 |
| `AbstractRoom.update`、`MonsterGroup.haveMonstersEscaped` | 自毁不是逃跑；普通房间仍抽treasureRng的10..20金币，并派发正常卡牌、药水奖励。没有用monster.gold0删奖励。 |
| `CardGroup.shuffle` | 空初始牌组仍先取一次shuffleRng.randomLong；空牌堆后续完全空抽请求不凭空增加洗牌。独立向量核对HP/AI/shuffle完整words与counter。 |

核心接线仅涉及既有Act3数据/AI/能力、Actor目标Transient伤害反应和死亡通知，以及Combat的本怪装配/阶段。raw Core缺少Shackled时登记同源定义；已登记时只核ID、kind、stack、decay、priority和已有sourceId兼容，保留已有定义与显示。此核验仅在构造Transient时执行，不给其它遭遇增加条件。没有新核心模块，既有架构分类继续覆盖这些文件。

Shifting反应载荷捕获真实目标与回调金额，现有TOP批次执行它；没有在玩家最终减伤路径重复实现Tungsten或Buffer。Host沿用拆分的意图和状态呈现，实际显示999HP、30→24→40意图、Shifting/Fading帮助及倒计时，不新增UI布局或前台操作。

## 验证过程

最小真实红例在seed4原第三队列项返回`act_content_unavailable`；接入后HP999、HP零抽样、AI开场一次均绿。第一轮10个行为组7红，锁定缺失Shifting/Fading行为。随后增加第19组同伴动作观察，真实抓到力量提前归还`0 ~= -6`；继续观察玩家Blur实际RemovePower动作，又抓到归还晚于atEndOfRound的`-6 ~= 0`（`build/transient-blur-red.log`）。归还最终位于所有怪物动作后、Blur等round-end动作前，两种派发器均验证。测试期间另校正了领奖API名、Potion流所有者及空初始牌组的一次洗牌预期，没有将这些夹具前提错误报告为生产缺陷。

最终同树命令：

```sh
node --test --test-concurrency=1 tests/act3-transient.test.mjs tests/act3-orb-walker.test.mjs tests/act3-shapes.test.mjs tests/act3-maw-growth.test.mjs
node scripts/check-architecture.mjs
node scripts/check-lua-static.mjs
```

- Transient19组及来源锁通过，14.807秒；默认30秒预算未改。
- 19组覆盖源队列、五次真实攻击、所有伤害类型、Artifact/Intangible/零伤害、TOP顺序/叠层上限、死目标、Fading与Corpse Explosion、玩家先死、全怪owner-end、三独立向量、共享定义拒绝、公开奖励及金币/卡牌UID领取、真实Host、构造/打牌/自毁/晚奖励throw与reject的全图/原引用回滚和重试。
- 既有Maw/Growth18组8.525秒、Orb Walker12组4.665秒、Shapes17组6.368秒通过；七项JS全部通过、零skip。最终日志为本树`build/transient-final-closeout-green.log`。
- 架构156模块/904边通过；固定Luacheck1.2.0保留105项历史警告，无新增诊断，所有受管UI方法仍在原绝对门槛内。Act3三模块与Actor单独检查零警告/错误，diff检查通过。未修改静态baseline。
- Orb旧拒绝测试原seed4强遭遇已变为本片实现的Transient，仅迁其输入至固定源独立队列模型核出的seed15：前缀Orb Walker、3 Shapes、Jaw Worm Horde。保留全部拒绝、RNG、资源、原引用断言，并加精确源名断言；未改旧来源锁。

Act2定向另有基线失败：`tests/lua/act2_enemies.lua:165`将已移除的plated_armor期待为0，实际nil。以精确`f59b1503`的Actor、Combat、Act3三模块在独立fresh Lua加载重跑，仍在相同位置同值失败；本片未改Act2生产或测试，也未声称该34组全绿。

## 证据边界

长算式夹具使用1000玩家HP以观察五次攻击，不是自然通关。其它用例明确使用受控已有Power或低HP边界来核上限、过量伤害与致死；不将它们称为来源初始状态。真实Run/Host保留原角色80HP与初始牌组。公开第五轮奖励/回滚用例只调用已有Core格挡API隔离存活边界，不改HP、能量、牌组、敌人HP/倒计时、队列、随机流或奖励输入；它证明实际公开命令及事务，不是五轮自然生存证明。

没有全Quality、同SHA远端CI、原版PC运行、整幕自然路线、平台导入或实机验收。本片不进入当前RC，不以该单遭遇或目录存在宣称M3齐备。
