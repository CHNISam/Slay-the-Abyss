# 潜行小魔：首幕 A0 生命范围切片

2026-10-23。TASK-15 独立离线候选，保留 @Codex 负责人及全部全池/平台验收。基于 develop `ed39f4653ddb555391c0dfe5a4507d1f58387171`，依赖 PR86 `192efa4bf63c61a99ba61bd121d8ecbf516bf9be` 的通用 hpRange 遭遇测试；其迟缓小魔数据及回归原样保留。仅新增潜行小魔 hpRange10–14，不修改其他条目、共享内核、地图、RNG、名称或任务元数据。

## 固定只读来源

核对构造、takeTurn、getMove：

- [aeubanks/sts GremlinThief](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/GremlinThief.java)，Git blob `90d7e7fbe683a08f1ae41b832d33b15d9cfbb2a2`。
- [purewhitelove/ButterflyGame GremlinThief](https://github.com/purewhitelove/ButterflyGame/blob/fc379c875c11e008e9c10548ac8e394c301c532f/杀戮尖塔原码/monsters/exordium/GremlinThief.java)，Git blob `139ea8fa79f76ba4bce939e106709817dcb7db86`。
- [AbstractMonster.setHp](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) 将采样值赋给 currentHealth 和 maxHealth；[Random.random(int,int)](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java) 的范围包含两端。对应 Git blob 为 `4784e38e7afff5980736e2b5c718e62a0c838c47`、`c4b71d5645688f6e764c46c593223eb91a5249bc`。

两份敌人镜像均给出 A0 HP10–14、基础伤害9、首动及通常后续动作都是一次攻击。A2伤害10、A7生命11–15不适用于本切片。现有伤害9单意图循环已经正确，保持不变；旧固定hp12只作静态代表值，实际战斗使用已有 hpRange 入口采样并保存实际 maxHp。

镜像是社区反编译文本，非官方发行物或认证PC二进制；两份一致不证明独立来源。未执行上游代码、安装依赖、复制原程序或玩家可见文案。测试预期由上述方法体独立归纳，不是原版客户端观察。

## 验证与限制

新增 tests/lua/sneaky_gremlin.lua：8组固定预期，包括128种子及Run真实遭遇入口的HP10–14全值可达、maxHp/可复现/状态隔离；六回合每次单击9；格挡、现有力量/虚弱/易伤修正；两实例行动及毒杀抑制；真实Strike扣除采样生命。旧固定12会使两个HP覆盖组失败，其余六组保持通过。Run测试直接设floor5作为入口夹具，不声称走完整地图。

PR86通用遭遇回归未另作修改或弱化，固定HP敌人断言和行动前后HP不变断言保留。当前五小魔编组是否合法仍未核实，不因入口测试通过而认证。第二幕首领死亡联动与逃跑、全局队列/反伤致死顺序均不在本次范围。

新增HP采样推进本项目既有LCG并可能改变后续洗牌；不认证原版随机算法、独立随机流、分布、种子映射或抽样时序。系统Lua离线测试不替代Fengari/Windows当前SHA CI、千星编译/官方导入/实机或TASK-15整包验收。Runner临时下线时不得声称正式CI通过。
