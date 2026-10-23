# TASK-15 小型酸液团（Acid Slime S）A0 切片

2026-10-23，在`feat/continue-blue-slaver`连续开发，增量基线`ade3bb5`。只实现普通遭遇中的小型酸液团，无分裂、子怪生成或继承中毒机制；未开原神、沙箱或MCP，未平台编译、写入副本、官方导入或实机。TASK-15全部全池与平台AC保持。

## 固定来源与真实性

本轮完整只读核查 [AcidSlime_S.java / aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/AcidSlime_S.java)。UTF-8内容SHA256：`57CF3CB408A2DAC4E96A30B01E4EE3860BE173FB9157D0AE55EC7EB2D45C21DF`。

另完整读取同提交 [random/Random.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java)，SHA256 `476BE7D8AF2080B6B52F6CECC78C35F01904C18DBACC7EA795A361E600F05172`：无参randomBoolean增加一次counter并调用底层nextBoolean，不是传入概率参数的nextFloat分支。首动getMove之前的主整数抽样来自 [AbstractMonster.rollMove](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java)，已实际读取hash延续[Nob账本](TASK-15-gremlin-nob-ai.md)。

这些文件声明为社区反编译镜像，未与正版PC构建号/二进制hash认证，不能称官方开源、原作PC实测或原作概率认证。只读后独立实现本项目Lua规则，没有复制、执行或提交上游程序。

## A0 独立预期

| 条件 | 规则 |
|---|---|
| HP | 从8–12闭区间实际采样，maxHp等于采样；固定展示值保留10；A7+9–13不适用 |
| Tackle | 保留基础3攻击；A2+4不适用 |
| Lick | 保留玩家Weak1，不攻击 |
| 首动抽样 | rollMove先抽0–99主整数；getMove忽略该值，另抽一次Boolean；true选Tackle，false选Lick |
| 后续动作 | takeTurn直接选择另一动作，因此Tackle/Lick严格交替；没有RollMoveAction，无后续AI抽样 |

这不是每回合按50%重抽，也不是首动受主整数50边界决定。A17+的getMove分支不同，本片不支持升阶。上游构造允许携带poisonAmount用于其他生成场景；本片当前普通遭遇没有分裂入口，不擅自增加中毒或子怪生成。

新增独立`abyss_acid_slime_s_ai`与EnemyAI初始化/推进分派；HP范围与policy来自数据，原两个动作payload、遭遇编组、共享Combat/Actor/Inventory和UI均未改。原生打包断言加入新模块。后续交替依据本实例已执行intent选择另一条，无需额外保存或消费随机数。

## 随机与集成边界

生产仍用共享16位LCG；首动请求`random(state,100)`并忽略返回值，再请求`random(state,2)`，以整数域1/2映射false/true。这个适配不是原版RandomXS128.nextBoolean；真正布尔生成算法、原版独立aiRng/monsterHpRng与种子映射未接生产。共享流相关性也可能使多敌开场关联，不能据受控消费次数宣称原作概率或同种子轨迹一致。

此工作树暂依赖Nob/Blue的提交链，没有主线程正在整合的共享Weak轮末修复。本增量没有修改或恢复Actor/Combat的任何版本，整合时保留主线程的新调度。测试只对本敌人施加Weak1的动作及当前入口执行断言，不认证整个Weak存续规则或新整合版本；最终组合检查由主线程完成。

## 实际验证

`tests/lua/acid_slime_s_ai.lua`新增9组，修复前5失败、4通过（首个明确失败为缺HP范围，另见开场只能攻击与缺少Boolean请求），修复后9组通过：

- 128种子覆盖8–12所有HP端点、maxHp与重复种子。
- 主整数0/99交叉两个Boolean结果，按顺序只请求HP5域、主roll100域、Boolean2域。
- 两种开场各跑10次行动严格交替，动作末没有额外AI随机请求。
- 自然Tackle3与Lick Weak1无伤害、多实例不同开场与独立推进。
- 毒死不行动/不推进、荆棘致死后队友继续、不额外抽样；失败卡牌事务保持意图、HP、seed和事件。
- 真实Run.startCombat进入small_slimes，保留两成员与原数据动作，实际回合造成3+5伤害。

新增8项schema；与已有Blue/EnemyAI/Jaw/Nob和原生打包校验合计61项JavaScript通过，0跳过/0失败。既有Blue9组、Nob12组再次通过。原`encounter_coverage.lua`保持不改，18遭遇在256种子样本全部出现；23敌人/53意图/18遭遇、124组通过。原固定循环契约按既有规则跳过新增stateful敌人，动作独立预期由本专项覆盖，未删除或放宽可达断言。

`build:data`、`validate:data`、受影响JS语法与`git diff --check`通过。未重跑本片完整npm check；定向日志在本地`build/acid-s-schema.log`与`build/acid-s-encounters.log`，不作为原作PC或平台证据。
