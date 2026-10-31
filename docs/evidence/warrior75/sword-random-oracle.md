# 飞剑回旋逐击随机选敌证据

能力标记：`TEST_ADDED`。本补丁只增加独立期望和验证，不修改生产行为，不声称发现或修复生产缺陷；原 150 个基础/升级案例和 49 个边界案例不变。

## 固定原版解释

原版镜像固定为 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。逐文件 URL、Git blob、SHA-256 和字节数在 [source receipts](../../../tests/fixtures/sts1-sword-random-sources.json)。没有把旧 warrior75 矩阵另一个镜像的字节等同此镜像，也没有把 Java 副本加入项目资产。

- `cards/red/SwordBoomerang.java`：伤害 3，基础 magicNumber 3，升级增加 1。`use` 逐次 `addToBot(new AttackDamageRandomEnemyAction(...))`。真实动作是 **AttackDamageRandomEnemyAction**，不是名字相近的 DamageRandomEnemyAction；后者另行锁定并核读以避免混用。
- `actions/common/AttackDamageRandomEnemyAction.java:update`：每个动作重新从 `cardRandomRng` 选敌；非空目标重新算伤，再 `addToTop(DamageAction)`，该伤害先于下一次选敌结算。
- `monsters/MonsterGroup.java:getRandomMonster(null,true,rng)`：全体 basically dead 则返回 null；其余按原列表顺序收集非 halfDead/isDying/isEscaping 的目标，空集合返回 null，否则 `rng.random(0,size-1)`。单个目标仍调用 `random(0,0)`。
- `random/Random.java:random(int,int)`：每次包装调用 counter 加一，再由 XS128 做有界整数抽样；不是用旧 LCG 或视觉 MathUtils 随机数。
- `AbstractMonster.die` 把敌人标为 isDying。`DamageAction.update` 伤害后若全体 basically dead，调用 `GameActionManager.clearPostCombatActions`。后者不保留这个未设置 DAMAGE actionType 的随机攻击动作（`AbstractGameAction.actionType` 默认为 null）。因此清场后剩余攻击不再抽数。
- `AbstractDungeon` 初始化流用 Settings.seed，自然进入房间则用 Settings.seed+floorNum 重置。这里使用生产 **显式 replay encounter** 入口，它明确用 runSeed；测试没有冒称自然第六层流。第六层只是受控 elite_sentries 入口条件。

独立 Python 生成器只导入既有独立 Python XS128 模型 `sts1_potion_pool.Stream`，不读取生产 Lua、牌效果或本地目录定义来构造期望。原语出处见 [固定 RNG 审核](../../reviews/TASK-16.1-random-wrapper-candidate.md)。生成器、固定来源收据和共享模型 raw SHA 都写入 fixture；相关 `.gitattributes` 强制 LF，避免 Windows checkout 改变哈希。

## 验证投影

4 个 seed（0、1、42、-1），每个基础/升级各验证 3 个 HP 前置，共 24 个案例：

| 受控 HP | 要证明的行为 |
| --- | --- |
| 30,30,30 | 基础 3 击 / 升级 4 击，每击独立重新选敌，可重复命中同敌 |
| 3,3,3 | 伤害先结算，下一击从余下存活集合重选，bound 依次 2/1/0 |
| 3,3,0 | 最后敌人死亡后基础/升级余下攻击都不再耗数，精确 2 次调用 |

每个案例先通过公开 `Run.obtainCard` 取得真实永久 UID/升级状态，经 `Run.startCombat` 取得对应 deckUid 实例；只控制手牌、HP、状态和能量等前置；初始 0 HP 的敌人同时明确置 isDying，表示已经死亡而非未结算的致命伤。出牌和胜利奖励阶段转换使用真实 `Run.play`。逐击观察包装调用的 bound、value、完整前后 XS128 words/counter、实际目标和结算 HP；另核 1 能量消耗、弃牌一次、永久牌身份不变、重复 UID/未知 UID 原子拒绝及无关战斗流不变。

另一个真实 Host/BattleUI listener fixture 以拖放提交无目标随机攻击，断言独立目标/终态向量；旧触点 up/endDrag/重复 click 不选择或打出下一张牌，下一次新触点仍可正常打防御。该 UI 前置显式替换战斗牌组/敌人，不是自然获得路径或真实设备输入。

三个负控在临时 Lua 环境中分别固定首敌、跳过单敌抽数、清场后额外抽一次；都必须失败，生产源码不改。

执行：`node --test --test-concurrency=1 tests/sword-random-oracle.test.mjs`，使用原 runner 默认每片 30 秒预算。

不覆盖：有 powers/block/反伤/复活/逃跑的伤害重算、自然取得并打出基础/升级牌、自然房间 seed 生命周期、官方候选/PC/手机/手柄。完整 75 证据边界另见 `/workspace/cloud-reports/m3-card-75-evidence/{matrix.json,report.md}`，不能用本补丁关闭其余设备或自然证据缺项。
