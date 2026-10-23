# TASK-15.8 · 蕈甲兽生命与两招选择

## 有限修正，不是整只敌人验收

固定基线 `28c2aaf17d9210f177c69f3aae89bd24a9225c4f` 的合法 `fungi_pair` 遭遇已有蕈甲兽，但仍使用固定26生命、攻击/增力交替。本片只修正其普通生成生命与A0选招，不新增敌人、遭遇、卡池、数值平衡或玩家文案。

- 普通生成生命按22–28闭区间抽样；在当前战斗入口，生命抽样先于该敌人的开场主roll，再进行初始牌组洗牌。原26只保留为数据中的范围内静态代表值，不再是实际生成固定生命。
- 开场与每次已执行动作末各消耗一次0–99主roll。0–59选择基础6伤害攻击，但前两次均为攻击时改为增力；60–99选择自身力量+3，但上次已增力时改为攻击。
- 保留现有两个动作的内部ID、基础伤害6、力量3及既有意图显示。每只敌人保存独立动作历史，不共享实例状态。
- 攻击被荆棘反杀后，有同伴仍存时已排roll继续执行；末敌死亡清队列，行动前被中毒击杀不行动、不排roll。复用既有共享队列边界，没有扩大死亡来源、状态或伤害接口。

**Spore Cloud死亡易伤仍未实现。** 固定 `FungiBeast.usePreBattleAction` 会赋予该能力2层，`SporeCloudPower.onDeath` 在战斗未结束时把对玩家的Vulnerable应用排至队首。当前生产代码没有这条被动及其UI、死亡时机、Artifact与末敌清队列验收。本片不改变Actor/Effects/死亡钩子，不把它伪装成现有循环的一部分。该缺口仍属TASK-15的现有可玩敌人严格规则缺口，不能作为永久简化获准，也不能据本片称蕈甲兽完整复刻。

## 固定来源与真实性边界

只读核对社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。从GitHub base64响应解码原始字节，分别复算Git blob与SHA256，不给展示文本补换行。只提取规则事实并独立实现，不提交第三方源码、素材或原文案。该镜像未与正版PC发行二进制做hash认证，不是官方开源、原作客户端观察或千星实测。

| 固定文件 | Git blob | SHA256 |
| --- | --- | --- |
| [monsters/exordium/FungiBeast.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/FungiBeast.java) | `3fcd45984ac1f78834d31642bbdf2542df6c231a` | `cdec8d58bd0a0476c8dab7b9deb9846bdd9b6c07557c905487909f9aa9188e71` |
| [monsters/AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `4784e38e7afff5980736e2b5c718e62a0c838c47` | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [actions/common/RollMoveAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RollMoveAction.java) | `01731f966b9b6f8c3815b246cd02cf75eb5d2153` | `c938d4b4a9183b39e91c1c54c79085ddf7b2bea082af14895b9a1a00a100fc50` |
| [powers/SporeCloudPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/SporeCloudPower.java) | `06354f7b5a8f6290a161db7815ee50c895fdfe38` | `c46ccba50ce667bf5d9a00c8ade4c190bacace7a9a2a7f3a9bf43adc14cd05bd` |

`FungiBeast` 的普通构造、A0 `getMove` 和 `takeTurn` 提供生命、两招、60边界、连招限制与roll排队事实。`AbstractMonster.init/rollMove/setMove/lastMove/lastTwoMoves` 明确开场抽样及动作历史；`RollMoveAction.update` 本身无拥有者死亡拦截。共享末敌清队列依据延续 [既有队列来源账本](../rules/QUEUED_ENEMY_ROLL_AFTER_DEATH.md)，本片不修改该逻辑。

当前仍使用项目共享LCG，不是原作独立HP/aiRng随机流或RandomXS128分布。新增生命和主roll消费会改变当前后续洗牌、奖励等轨迹。只声明受控roll下的决策和调用次序，不声明同种子整局、精确总体概率或原作随机流一致。A7生命、A2/A17增力差异不混入A0。

## 回归与门禁

- 生产修改前新Lua13组：11项预期失败、2项通过；失败覆盖固定生命、缺开场roll、60边界、固定循环、死亡后已排roll及真实Run双敌入口。新schema17项全部红。原始红绿日志留在交付工作区。
- 最终专项Lua14组通过，包括9种独立历史×100个主roll的900次真实AI分派；生命端点/64种子覆盖、59/60边界、禁三连攻击/禁连续增力、增力后9伤害、格挡/虚弱、双实例隔离、反伤/中毒死、真实Run入口及失败出牌回滚。新增格挡组保留转为状态AI后原通用循环测试不再覆盖的实伤断言。
- 新schema17项及相关JavaScript共360项通过，覆盖缺失字段、错类型、非法范围、错动作种类/引用与未声明字段。实际候选脚本发现器唯一收录新策略，总38模块；这不是平台编译。
- 完整远端树的106份顶层原生Lua测试、4份Lua支持模块、57份JavaScript测试与4份Python测试均已在本地；初始已物化文件逐一匹配远端Git blob。新增本片后顶层Lua107份，全部通过；4份支持模块由既有测试加载，不冒充4个独立测试。正确LUA_PATH与真实战斗布局wrapper下执行，宿主Lua5.4，不等同生产Fengari或千星运行时。
- Python实际执行17项全部通过，零发现不作通过。数据/界面/地图布局/主题生成、数据校验与JavaScript语法检查通过。
- 另执行 `build-lua-data.test.mjs`，其中UTF8往返、六表Lua加载、runner失败/超时传播、全Lua发现/遇错停止4项因缺 `fengari-node-cli/src/lua-cli.js` 失败，明确不是通过。未安装依赖、未执行完整 `npm run check`。原生Lua与定向JavaScript不能替代完整发布SHA的Quality；远端CI须由主线程核验。

未启动原神、沙箱或MCP，未编译/写入平台存档、官方导入、实机或发布。M1、全池原版规则及随机流、Spore Cloud和全部平台关口均保留。独立复审及发布SHA的CI结果以对应PR为准。
