# TASK-15.9 · 菌兽死亡后的易伤

## 有限范围与实际行为

基线 `02e2f75767ca03ca67d7e37c8ab8264d6b36213a` 已有蕈甲兽的22–28生命、攻击6、增力3及选招历史，但没有死亡能力。本片补齐现有合法 `fungi_pair` 敌人的这一个规则缺口，不新增敌人、遭遇、卡池或数值平衡。

- 每只蕈甲兽开场具有2层 `spore_cloud`，玩家名称独立写为“菌雾”，说明为“倒下后使玩家获得等量易伤；战斗结束时不触发”。既有状态视图展示层数/说明，主题复用已在项目内使用的千星图库编号103059，不复制原作素材或文案。
- 每次真实存活→死亡只排一次对玩家的易伤应用。再次伤害尸体不重复；不存在持久死亡队列或跨战斗标记。下一场战斗重新初始化，玩家易伤不带入。
- 原作死亡能力的 ApplyPower 来源为空，但 Vulnerable 的构造标记明确为怪物来源。这是两个不同事实。本片保留事件的空来源，另显式传递怪物时点：玩家回合新施加会在本轮敌方结束减1；敌方行动/预回合毒伤中新施加会跳过第一次轮末递减；已有易伤只是叠层，不重置既有抑制标记。
- 复用现有 Artifact 应用关口，一次死亡应用消耗一层阻挡全部2易伤，不按易伤层数消耗。玩家已死时取消，不消耗 Artifact，也不新增易伤。

## 必须保留的动作边界

`Actor.damage` 将受击增力、荆棘及死亡能力放进当前伤害动作的局部反应批次，逆入队顺序结算。死亡能力在受击钩子之后入队，因此同一个被击杀菌兽的易伤应先于其荆棘反击；即使该反击随后杀死玩家，也不能把已经生效的易伤抹去。单体伤害结束后排空，范围伤害则先完成全部目标，再排空；每次多段伤害分别结算自己的批次。

`Effects` 仅替换原有范围伤害的反应排空入口，并仍把荆棘伤害交给 `Combat.retaliate`，保留 Guardian 的生命损失钩子。普通单体攻击仍由 Combat 原有前后生命快照处理该钩子。毒伤完成损血和中毒减层后，才处理死亡能力，且在下一名敌人的预回合动作或出招前处理。没有改 Combat 调度、Inventory、随机接口或完整动作管理器。

| 场景 | 源方法链推导并由真实入口验证 |
| --- | --- |
| 杀死菌兽，另有活敌 | 排入易伤，按当前伤害动作的 TOP 顺序处理 |
| 杀死最后一个敌人 | `isBattleEnding` 已成立，不排死亡易伤，不消耗 Artifact |
| 范围伤害先杀菌兽，随后同一击杀光敌人 | 早先排入的 POWER 被战后清理移除，不能提前生效；仍保留已排 THORNS/DAMAGE |
| 范围伤害先杀菌兽，后一个目标的荆棘杀死玩家 | 后目标荆棘先执行，较早死亡的易伤因目标已死而取消 |
| 范围伤害后杀菌兽，较早目标有致死荆棘 | 后目标死亡易伤先执行，然后较早目标荆棘杀死玩家 |
| 两次独立伤害或两次独立毒伤，最终杀光敌人 | 第一动作已经生效的易伤/已消耗的 Artifact 不因第二动作的胜利倒退；不等同一击范围清场 |
| 菌兽攻击时被玩家荆棘杀死，有同伴 | 易伤在同伴攻击前生效；当前已排选招随机消耗沿用既有规则 |
| 毒伤在出招前杀死菌兽 | 无该菌兽动作或其选招，但死亡易伤在存活队友动作前生效 |
| 后续卡牌效果抛错 | 原地恢复生命、状态/标记、Artifact、事件、牌堆和对象引用；下次合法出牌仍只触发一次 |

这是一段已核实的同步局部队列适配，不是原作完整 GameActionManager。逃跑/半死、其他未实现死亡能力、全局 Power 优先级、完整遗物钩子、零层 Power 对象等仍未认证。原共享LCG、独立随机流缺口及其他敌人的严格缺口未改，不声明同种子原作整局一致。TASK-15、M1和全部平台关口不因本片关闭。

## 固定来源与字节身份

只读核对社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。以 GitHub base64 原始字节核对 Git blob和SHA256，不对展示文本补/删换行；源文件仅留审计工作区，不提交第三方源码。该镜像没有与正版PC发行二进制做hash认证，不是官方开源或原作客户端实测。

关键方法：FungiBeast.usePreBattleAction；AbstractMonster.damage/die；SporeCloudPower.onDeath；AbstractRoom.isBattleEnding；MonsterGroup.areMonstersBasicallyDead；DamageAction/DamageAllEnemiesAction/PoisonLoseHpAction.update；GameActionManager.addToTop/getNextAction/clearPostCombatActions；VulnerablePower构造与atEndOfRound；ApplyPowerAction.update；ArtifactPower.onSpecificTrigger；ThornsPower.onAttacked。

| 固定文件 | Git blob | SHA256 |
| --- | --- | --- |
| [SporeCloudPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/SporeCloudPower.java) | `06354f7b5a8f6290a161db7815ee50c895fdfe38` | `c46ccba50ce667bf5d9a00c8ade4c190bacace7a9a2a7f3a9bf43adc14cd05bd` |
| [MonsterGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java) | `7096970a151840489a3fba89806e6391e0d82d76` | `535770201b8aa8de01b52b185979af537f11ad0862e7d3e71ebb20cc64234221` |
| [AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `4784e38e7afff5980736e2b5c718e62a0c838c47` | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [VulnerablePower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/VulnerablePower.java) | `b640e3a168668ec3967c513946a620689be0252f` | `354b0dffa4f9763b9933266e3dfa96f561841b96c251f3f336693991a91dd191` |
| [ApplyPowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java) | `1a6af352c02e06ecec4db87dd5e2f57d43d35b91` | `f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47` |
| [DamageAllEnemiesAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAllEnemiesAction.java) | `13cc91e59ae21b8173468c4235849c6677ea3f55` | `3562ea16a19d0951b36198a4191fd48358c7cb408595ef2c503fc4b7763ec123` |
| [ThornsPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThornsPower.java) | `e898e2f525a6eb49664eadb847dacb681f2931fe` | `78ce7c63874a3539f03c50a9cdfdf8bcfba7b47e73bce18c10672e5bad3ae87a` |
| [PoisonLoseHpAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/PoisonLoseHpAction.java) | `338fa49aa56a439a934cfe2310c905b09be7238a` | `43fcf2e88d5295fdf12781cf6980a93941e9814aa0a98a7a9a8b47af0413ba1a` |
| [AbstractRoom.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java) | `c2a1a029a9f59b1b94026dff46d4155824b85f86` | `020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05` |
| [FungiBeast.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/FungiBeast.java) | `3fcd45984ac1f78834d31642bbdf2542df6c231a` | `cdec8d58bd0a0476c8dab7b9deb9846bdd9b6c07557c905487909f9aa9188e71` |
| [GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `1662da8de2aeb42044b385f03d0c801750904b13` | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| [DamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java) | `ea89aeab60af8a7c297495de3cd8eb82d7130232` | `c5649fc04cbcadffa617e5c52f1a6f879f88cb1a90a543d5a0a05ebf950578ec` |
| [ArtifactPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ArtifactPower.java) | `affdd504cd849ea3260734b13a39bf8083e03425` | `7f0c3a5df2f204c6f0fa3fb152a807895b330f26b0f0970f4ef060ee9b919ac7` |

## 验证与未通过项

- 生产修改前的真实Lua23组：17项预期失败、6项负例通过。新schema/主题10项中5项失败；真实生成控件UI因缺少死亡状态定义失败。原始红例保留，不把本已通过的负例说成新修复。
- 完成后专项Lua27组全部通过；包括真实C.play、C.endTurn、Run火瓶和下一场战斗入口、单体/范围/多段、全部死亡顺序、Artifact、空来源时点、已存在易伤、重复尸体调用及原地事务回滚。UI测试修正了测试自身误用的玩家控件路径后，通过实际按钮操作验证“菌雾2”与“易伤2”、队友状态不串写和只读刷新，没有因此修改生产UI。
- 完整当前远端树107份顶层Lua测试和4份支持模块均已物化且与基线Git blob一致；新增两份后109份顶层原生Lua测试全部通过。支持模块由测试加载，不另算4个测试文件。用正确LUA_PATH及原战斗布局wrapper，宿主Lua5.4，不冒充生产Fengari或千星运行时。
- 421项相关JavaScript和17项Python测试全部通过，无零发现。数据/界面/地图布局/主题生成、数据校验及JavaScript语法检查通过；实际候选脚本发现器仍为38模块，唯一包含菌兽策略，不是平台编译。
- 另实际执行 `build-lua-data.test.mjs`：4项因缺少 `fengari-node-cli/src/lua-cli.js` 失败（UTF8往返、六表加载、失败/超时传播、全Lua发现/遇错停止），2项通过。没有安装依赖、没有执行完整 `npm run check`，不会用原生Lua和定向JavaScript替代当前发布SHA的正式Quality。
- 独立预写19组探针在基线13红后于候选全部通过；独立变异验证检测到缺钩子、错层数、FIFO、漏范围清理、错来源标记、重置已有易伤、跳过Artifact、删除荆棘保留8类缺陷。最终独立审查和当前SHA CI以PR记录为准。

未启动原神、千星沙箱或MCP，未平台编译/存档写入、官方导入、实机或发布；状态图片的本片平台观感仍未验。此结论只覆盖已列死亡能力及可执行离线边界。
