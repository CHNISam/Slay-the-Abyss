# TASK-15 怒焰巨魔（Gremlin Nob）A0 离线切片

2026-10-23，分支 `feat/continue-enemy-parity`，基线 `52f35dd`。未启动原神、沙箱或 MCP；未编译平台逻辑、写入存档、官方导入或实机验证。TASK-15 全池与平台 AC 保留。

## 来源与真实性

本轮只读核查固定社区反编译镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)：

| 文件 | 实际读取 UTF-8 内容 SHA256 |
|---|---|
| [GremlinNob.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/GremlinNob.java) | `ACD8A81E3D185239951B2A7FE07A42C3782A764A52E403AAE141C2BD321280BC` |
| [AngerPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/AngerPower.java) | `DE4F8627846678561216502DFC950790E6DEB571BF0E65895ECA9F4867F18E4A` |
| [AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `F95BABA14B00BFFEB6A93E9FCF04CEDAD2A42A803C4B4342C1E017535ACC601F` |
| [AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `2720BA8DD7A216781A3B2FCB709F5EC67DC9B2559AF25F7F6B89DF1EF0947D95` |
| [UseCardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/utility/UseCardAction.java) | `90213939AF6D7EC83DEA01BB2FEEF4BA762A93400DC1535732E2EEBCDB6CAB0F` |

镜像文件声明 CFR 反编译；没有本轮正版 PC 构建号、二进制 hash 或原作直接观察证据，不能称官方开源、官方 PC 验证或全版本严格一致。未复制、执行或提交上游程序，只根据可复核方法行为独立实现本项目 Lua 规则。

## 独立预期与实现

| A0 输入/动作 | 核查结果 |
|---|---|
| HP | 82–86 闭区间；运行时实际采样并设相同 maxHp；固定展示基线取区间中点84 |
| 开场 | 强制 Bellow，仍消耗一次 0–99 主 roll；给予 Enrage2，不直接给予力量、不攻击 |
| Skull Bash | 基础6攻击，然后施加玩家易伤2；同一行动，不另占一回合 |
| Bull Rush | 基础14攻击；使用已有力量、虚弱、易伤及格挡修正 |
| 后续 roll 0–32 | Skull Bash，可连续；没有额外条件抽样 |
| 后续 roll 33–99 | Bull Rush；若此前两次均为 Bull Rush，则改 Skull Bash |
| Enrage | 施加后每张成功打出的技能牌使活着的拥有者获得等量力量；攻击/能力牌不触发；不衰减 |

`GremlinNob.getMove` 的 A18 分支与 A0 不同，本片只实现 A0；不把高升阶的固定节律套入 A0。只支持普通精英构造的 `canVuln=true`，不新增禁易伤特殊构造。

`AbstractPlayer.useCard` 先调用卡的 use 排入动作，然后构造 UseCardAction；其构造函数调用敌人 power.onUseCard。AngerPower 对 SKILL 使用 addToTop 添加力量，因此力量先于已排队技能效果结算。当前 Combat 在事务快照后、牌效果前调用 EnemyAI.cardReactions，本片复用该入口调用 Nob.beforeCard，无需改 Combat。多个拥有者按逆序处理，匹配循环中重复 addToTop 的效果顺序。原有 Guardian 对攻击牌的抓取/牌后反应保持。事件中的力量帧在当前 `play` 帧之前，是复用既有前置钩子的表现时序；战斗效果先后已覆盖回归，未声称原作动画队列一致。

新 `enrage` 状态有只读说明与层数；主题沿用现有力量图标 `103047`（仪式也复用该图标），不更改批准稿的颜色、字号、间距或布局。正式平台显示仍待实机。

## 随机流与剩余缺口

2026-10-23后续Spike S取证补充：历史“开场及每次行动抽样”仅覆盖当时项目的活体正常调度；死亡保护断言不证明原作已排队roll消费。固定RollMoveAction/DamageAction/GameActionManager链表明，有同伴存活时死于Thorns的攻击者仍执行已排队roll，末敌死亡则清掉。当前切片基线统一跳过死体advance存在共享缺口，已交独立战斗时序切片；最小红例、完整hash与两路径见[专项账本](TASK-15-spike-slime-s-ai.md)。毒在行动前致死未排动作，不能与Thorns路径合并称“死敌零消费原版通过”。

生产仍使用本项目共享16位LCG，HP/AI/洗牌共用seed，主roll取 `random(state,100)-1`。不是原作 RandomXS128，也没有拆分 monsterHpRng/aiRng/shuffleRng；模100偏差、种子映射和真实消费流继续保留。因此900个受控输入证明选招边界与历史规则，不证明实际原作概率或同种子轨迹一致。

原作完整动作队列、dontTriggerOnUseCard、自动出牌/特殊牌等尚未由本项目此入口支持，不据本片宣称这类机制通过。其他敌人、所有精英难度对照与整局通关仍归 TASK-15 未完成范围。

## 验证

新增 `tests/lua/gremlin_nob_ai.lua` 12组；先见旧生产11组失败（首个明确错误为HP范围缺失），再实现并全绿。覆盖：全部HP端点、开场、技能触发和叠层、攻击/能力排除、非法出牌不触发、触发后失败原地回滚、攻击→易伤次序、伤害修正、900个受控roll/历史组合、33边界两侧、开场及每次行动的抽样请求数、多实例/死敌、毒死不行动与32种子12回合连续限制。长轨迹测试只给玩家额外生命避免提前结束，是规则诊断夹具，不是原数值通关或难度证据。

`tests/gremlin-nob-data.test.mjs` 10组覆盖契约和错误字段/引用/阈值/Enrage开场。原生打包断言包含新AI模块；集成检查曾明确捕获缺少enrage图标，再修主题映射。完整 `npm run check` 完成：JavaScript 594项（479通过、115既有条件跳过、0失败），全部Lua回归完成，Python16项（1项Windows符号链接权限跳过）。`git diff --check`无错误。检查日志保存在本地生成目录`build/nob-check.log`，不提交为平台或PC实测证据。
