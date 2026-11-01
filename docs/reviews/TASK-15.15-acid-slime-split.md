# TASK-15.15 · 大型酸液团半血分裂

## 有限实施

固定主线基线为 `976fc950f4366dec57ad2f2fd924c1a94eb07978`。只接现有 `large_acid` 遭遇中的大型酸液团分裂，不增加敌人池、玩家数值或界面布局。TASK-15.14 的普通生成、三招、概率与 0.4f 值保持不变。

- 有效 damage 回调后，活体 HP 不高于最大 HP / 2 时立即切为分裂意图，只中断一次。覆盖 65–69 奇偶上限、零伤、全格挡与毒伤；普通轮初没有伤害时不能凭低血触发，致死时不生成子体。
- 行动时读取剩余 HP，生成两只真实 `acid_slime_m`。显式 HP 构造不抽中型常规 HP，不继承父体状态或 AI 历史，ID 与状态表独立。
- 保持死亡父体原对象与位置模型，左子体、死父体、右子体占三槽。旧行动队列按 actor 对象快照执行；前后队友各动一次，子体本轮不行动。父体非伤害死亡不触发死亡 Power，生成完成前不判胜；杀完两子体才结算一次奖励。
- 真正执行酸液分裂只消耗左右子体两次初始化 roll，不消耗父体 roll。尖刺保留第三次父体 roll。Combat 把开始执行的 intent 传入 afterAction，不能由结束时 intent 或 splitTriggered 猜测动作类型。
- 普通吐液被荆棘打到半血，仍完成已排 Slimed2 和一次 roll，然后恢复分裂；roll 读到的是 split 历史，不回填旧吐液历史。普通吐液致死但有队友时，已有已排效果规则不变。
- 复用共享半血回调和中型酸液选招算法。schema 仅接受两类大型 slime 的固定分裂声明，限制真实中型子体、数量2、除数2、空效果与五槽容量。详情读取真实子体名称，保留原控件、图标与身份安全逻辑。

## 固定来源

社区 CFR 反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。本轮复算以下11份原始 UTF-8 的 Git blob 与 SHA256，全部与固定索引一致；第三方 Java 不随仓库提交。这不是官方源码或正版 PC JAR 发行构建认证。

| 文件 | Git blob | SHA256 |
| --- | --- | --- |
| [monsters/exordium/AcidSlime_L.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/AcidSlime_L.java) | `274b3d4be405c9aaedda6c2e3aaaa22abff0165d` | `56eaec2de1c6344701613e5643f3161c5acf6591890b7859f062f420a692dd72` |
| [monsters/exordium/AcidSlime_M.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/AcidSlime_M.java) | `b8d5ee4d71b7084624a19b73cf0c7b4df38a54d0` | `34fe1c1000d351ffd3ee1e5902a0af14ebb10fe3885bd181feeb75c1942cb400` |
| [monsters/exordium/SpikeSlime_L.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SpikeSlime_L.java) | `a013282e75bde7d4a0088182558a016992a10650` | `a6a6976050a4f16507e0bbda75d4946f5eee3bbfc3d9787bc4e7a99f1d22269c` |
| [monsters/AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `4784e38e7afff5980736e2b5c718e62a0c838c47` | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [actions/common/SetMoveAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/SetMoveAction.java) | `3d06fd9e29345de1c7c9d35c473543a2c7f041e3` | `2b6c9200a4574d514674214d342a24993d6bd7f9ce1ac81306fd308adb443666` |
| [actions/common/SpawnMonsterAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/SpawnMonsterAction.java) | `fe2929d4752e0afc396fad7cffb1c866a564d5c1` | `731309c39e9d0143f187cc4c2b391cca1983d915aa53e84b95e4ec6907fedb4a` |
| [actions/common/SuicideAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/SuicideAction.java) | `2d97ded6ee65a90e883197bd47927728069a5cae` | `66dbf76651c6499205c340d7f9304b031b19fd69cfd596475af209b21aeabd04` |
| [monsters/MonsterGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java) | `7096970a151840489a3fba89806e6391e0d82d76` | `535770201b8aa8de01b52b185979af537f11ad0862e7d3e71ebb20cc64234221` |
| [actions/GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `1662da8de2aeb42044b385f03d0c801750904b13` | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| [actions/unique/CannotLoseAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/CannotLoseAction.java) | `737eac1b33accedc6428aac5ab5c1d7d981d3d85` | `65fc4b39c8ec5b8b33c97ff770fe0d1409caf2e1cfc56c54191f852db2d624dd` |
| [actions/unique/CanLoseAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/CanLoseAction.java) | `8990f85c6cb54a5007ed3297359a30ae23ab32ec` | `21ac8e1233dfe1f1eacc9213c4758f2bfc3295d737a66d335eefa12771b6a53a` |

关键顺序来自 AcidSlime_L.takeTurn/damage、AcidSlime_M 显式 HP 构造、SpawnMonsterAction.update、AbstractMonster.init/setMove、SuicideAction 和 MonsterQueueItem 方法链。酸液分裂没有父体 RollMoveAction；SpikeSlime_L 在 switch 之后统一排该动作，这是必须保留的差别。视觉位置/动画的 MathUtils 抽样不混入战斗 RNG。

## 本地验证

- 基线原始合同 9红2绿；加入五槽与既有事务回滚后 12红2绿。最终15组合同在原基线复验13红2绿，在实现后15/15；同构 Spike 对照15/15。四个独立变异（多算父roll、误删中断roll、回填吐液历史、显示错误子体名）均被真实测试捕获。
- 新增20项 schema 检查通过，正例为现有真实数据及一大型加两队友，负例覆盖缺/错引用、非法子体或子策略、错数量/阈值、非空效果、中小型递归、双大型超过五槽。相关 Acid/Spike 数据套合计135项通过。
- 新增生成 UI 测试通过：酸液详情真实名称、三/五槽可见性、死亡父身份、旧父延迟输入不攻击子体、真实新子体和旧队友仍可选中。既有 Spike UI 与所有其他 Lua 回归保留。
- 完整原生 Lua 138文件全部退出0。包含大型酸液28组与三个未缩减的2600历史矩阵入口、中酸21组、尖刺M/L/split与共享战斗/Run/UI。执行器是既有 ctypes/liblua5.4 helper，不是 Fengari 或千星宿主。
- Node 全入口真实执行1066项：1005通过、61失败，61项均因本地缺少 `fengari-node-cli/src/lua-cli.js`，没有其他错误；不安装依赖，不改测试发现、运行器或预算。首次运行另缺两份 lore 输入，按基线blob补齐后已消除该输入错误。不能据此称完整 npm check 通过。
- JavaScript syntax、validate:data、build:data、build:ui、地图布局与 build:theme 成功；Python17/17。正式发布SHA的 Quality 和独立评审另由对应 PR 核验，不用本地原生结果冒充正式CI。

## 回滚与未验证边界

本片的回滚保证是既有 Combat.play 与 Run.usePotion 事务：失败时新增的 split 标志、意图、HP、seed、事件、牌与原引用完整恢复，成功重试可正确触发。没有新增整轮或 spawn 事务。

受控注入第二个子体初始化异常，在 Acid 与原有 Spike 路径均观察到父体已归零、首子体已插入、phase仍为enemy；这是既有共享流程的异常边界，本片不声称 endTurn 或分裂步骤异常原子。合法固定 schema 与原生 RNG 未观察到该故障；不为掩盖此边界改变源码规定的 init/插入顺序。

生产随机仍是共享16位LCG，不是原作独立 monsterHpRng/aiRng/shuffleRng 或 RandomXS128；此片只声明受控行为与请求顺序，不声明完整概率、同seed整局或PC版本认证。未构建平台.gil、写存档、官方导入或实机验收，不关闭父任务或任何平台关口。
