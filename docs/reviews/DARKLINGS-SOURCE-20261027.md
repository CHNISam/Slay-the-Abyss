# 共生暗影：A0 三敌正常遭遇源码切片

## 来源与边界

本切片基于本地 `17cca68cd3e0ecb464d5bf47e526199b14c83306`（`ff08e7f` 加已独立审查的 Awakened R2 依赖）。交付差分只含 Darklings，不重复该依赖的42文件，不包含并行 Time Eater、Nemesis、Reptomancer 或其他内容切片。

唯一行为基准为 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。这是社区反编译镜像，**不是官方开放源码、经认证的正版二进制或本轮原作实测**。只新增定向读取 Darkling/Regrow 两文件；死亡、队列、构造及随机包装复用已核实的本地同版本缓存。14文件的 Git blob SHA、SHA256 与字节数见 [来源锁](../../tests/fixtures/darklings-source-lock.json)。Java 原文只留工作区审计目录，没有复制进产品。Reincarnate 不是新 Action 类；行为在 Darkling.takeTurn 中，针对 `actions/unique/ReincarnateAction.java` 的单次查询为404。

主要来源：
- [Darkling 构造、选招、Regrow/Reincarnate、damage/die](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/beyond/Darkling.java)。
- [RegrowPower 的 Life Link 身份](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/RegrowPower.java)、[AbstractPower 的 -1 无数字哨兵](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/AbstractPower.java)。
- [MonsterHelper 三个构造位置与顺序](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/MonsterHelper.java)、[MonsterGroup 的半死行动与终局判断](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java)。
- [AbstractMonster 伤害后的格挡清理及最终 die 回调](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java)、[GameActionManager](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java)。

## 已实现合同

| 边界 | 对应规则 |
| --- | --- |
| 正常来源入口 | 复用原 `3 Darklings` 队列名称，不改权重、章节池或队列推进规则。按 `(-440,10)`、`(-140,30)`、`(180,-5)` 构造三个共生暗影。构造参数保持源值；源动画自身的视觉纵向偏移不混入来源坐标。 |
| 每槽构造随机 | monsterHpRng 依次抽 HP48–56、Nip7–11，再构造下一槽；三槽合计6次。所有构造完成后才按槽序各抽1次开场 AI。美术/音效 MathUtils 不消费游戏流。 |
| A0 选招 | 开场 `<50` Harden12格挡，否则 Nip。之后 `<40` 仅原组下标偶数的两外侧可选 Chomp8×2，且不能连续；不合格用 `40..99` 重抽。`40..69` Harden 不能连续，否则改 Nip；`>=70` Nip不能三连，不合格按 `0..99` 重抽。原中心下标1永不 Chomp，无替代权重或有限重抽兜底。 |
| 首次归零 | cannotLose 压制父类 die；父类伤害仍清除旧格挡；进入真实 HP0/halfDead，随后访问已实现的死亡 Power，再清除全部 Power。即时预告 Regrow，同时将 SetMove(Regrow)放原队列 BOTTOM。不伪造HP1，不终止战斗，不给半死击杀收益。 |
| 两步复生 | Regrow 行动不攻击，只通过原 RollMove 消费主AI并预告 Reincarnate。下一次行动按队列依次 Heal(floor(maxHP/2))、REVIVE清halfDead、重新获得Life Link，然后原 RollMove 重新选招。不是最大生命减半，也不重置开场标志；正负力量、毒等旧Power不保留。 |
| 致死反应队列 | Chomp两次攻击独立入原队列；首击反伤致死会取消第二击。既有 RollMove 先运行，而死亡回调追加的 SetMove(Regrow)在后，可覆盖该次选出的Reincarnate；不提前串行执行或新增行动管理器。 |
| 全组终局 | 最后一只进入halfDead时释放cannotLose，仅将该只halfDead清false，按源组序die()所有怪物。先前的halfDead标志仍在，但isDying是真终局，不能被通用isPresent当成永生怪。Run仍是一次战斗奖励的唯一所有者。 |
| 可作用/可展示 | isActive排除halfDead/isDying，治疗与REVIVE之间的短暂HP>0也不是合法目标；isPresent仅排除真死/逃跑，保留休眠实体。真实五槽UI显示中文“再生/复生”、0HP、帮助和Life Link无数字哨兵；不新增控件或视觉方向。最终致死帧包含整组die状态，反馈按present→absent让已0HP的另两只也正常坍塌。 |
| 事务 | 复用已有出牌快照、Run开战私有流、原生/高级endTurn原子边界；构造、半死变化、晚RollMove和复生失败恢复原actor/手牌/队列/Power历史/RNG别名。不重复独立的Run.play通用事务修复。 |

## 共享死亡钩子现状

与既有 Awakened R2 相同，当前基线**没有通用 Relic.onMonsterDeath / onSpawnMonster 分发器**。本切片保留当前已实现的 Stasis/Corpse Explosion/Act2 死亡接点，按源维护半死访问与清空Power后的全组die访问；没有宣称 Gremlin Horn、The Specimen 等未接可领取遗物的互动已经完成，也没有改池放出它们。未来共享遗物接点须保留：每次半死 Power→Relic→清Power；最后一次再按组序die的Relic访问；Reincarnate.takeTurn 构造时的onSpawnMonster须先于排队Heal真正执行。此共享缺口不是本切片偷偷发明替代机制的理由。

## 验证方法与未验证范围

独立 Python 模型不导入产品 Lua/内容数据，复用已有独立整数RNG模型与字面量序列化，锁定6种子×7整轮的每槽HP/Nip、招式、伤害、格挡以及完整随机流字。Lua另外覆盖全部开场/后续AI阈值及重抽参数、真实普通来源入口、非终局半死、两步复生、回调、反伤/毒/InstantKill/Feed、失败回滚和一次奖励；生成控件另测中文意图、无效目标、半死不坍塌及全组三次最终坍塌。Awakened两阶段、presence与现有death-order继续单独回归。

实际命令、输出、精确差分/树/文件hash和独立审查记录留在工作区 `m3-darklings-evidence/`，不把自报结论当成证据。本切片没有执行完整CI、官方构建/导入、原神、桌面输入、四职业自然三幕通关或M3整体验收；最终集成的当前SHA Quality由主集成承担。
