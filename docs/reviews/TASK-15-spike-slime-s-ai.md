# TASK-15 小型棘刺团（Spike Slime S）A0 切片

2026-10-23，`feat/continue-blue-slaver`连续增量，基线`e660e76`。仅交付HP范围、固定攻击及活体roll消费；另独立暴露已排队roll在反伤死亡后的共享调度差异，交由战斗时序切片修复。未开原神/沙箱/MCP，未平台编译、写入副本、官方导入或实机；全部全池与平台AC保留。

## 固定来源与真实性

本轮实际读取固定社区镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，UTF-8内容SHA256：

| 文件 | SHA256 |
|---|---|
| [SpikeSlime_S.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SpikeSlime_S.java) | `3EBDA589DC277D9D0A5F0A59AB3FB03783CB4E74EE0F03A1A9F40CA9126302B5` |
| [RollMoveAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RollMoveAction.java) | `C938D4B4A9183B39E91C1C54C79085DDF7B2BEA082AF14895B9A1A00A100FC50` |
| [DamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java) | `C5649FC04CBCADFFA617E5C52F1A6F879F88CB1A90A543D5A0A05EBF950578EC` |
| [GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `A47D1EE9C6B2E194B7D3EF311328F2A15E38F5630330689E438E46685B94D6C3` |
| [ThornsPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/ThornsPower.java) | `78CE7C63874A3539F03C50A9CDFDF8BCFBA7B47E73BCE18C10672E5BAD3AE87A` |
| [MonsterGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/MonsterGroup.java) | `535770201B8AA8DE01B52B185979AF537F11AD0862E7D3E71EBB20CC64234221` |
| [AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `F95BABA14B00BFFEB6A93E9FCF04CEDAD2A42A803C4B4342C1E017535ACC601F` |

镜像声明为反编译，未经目标正版PC构建号或二进制hash认证；不是官方开源、原作PC或平台实测。只读核查后独立实现规则，未复制、运行或提交上游程序。

## 普通遭遇A0规则与本片改动

| 条件 | 核查结果 |
|---|---|
| HP | 10–14闭区间，运行时实际采样，maxHp取样值；展示中点12保留；A7+11–15不适用 |
| Tackle | 每次基础5攻击，无减益；A2+6不适用 |
| 首动 | getMove忽略主roll并固定Tackle，但AbstractMonster.rollMove仍先消费一次0–99主整数 |
| 动作末 | takeTurn在伤害后排入RollMoveAction，即使动作固定仍消费一次主整数 |
| 历史限制 | 无其他动作，无禁止重复或条件抽样；不是跳过roll的单动作循环 |

新增数据policy `rolled_attack`（attackIntent/rollRange），EnemyAI内共享一个极小rollAttack函数用于初始化与推进，不增加独立模块。当前只将有固定来源证据的Spike S配置为此policy，不推断其他单动作敌人是否同样消费roll。基础5动作、编组、Combat/Actor/Inventory、Acid S的无后续roll策略均未改。构造中的poisonAmount继承场景及分裂/生成子敌人不在本片普通遭遇范围。

## 已排队roll与死亡：独立发现，交共享切片处理

本轮方法调用链支持两条不同路径：

1. Spike takeTurn先排DamageAction再排RollMoveAction。玩家ThornsPower.onAttacked向队首排THORNS DamageAction，先于后方roll执行。
2. THORNS伤害杀死攻击者后，DamageAction仅在MonsterGroup.areMonstersBasicallyDead为真时调用clearPostCombatActions。该判断逐个检查isDying/isEscaping。
3. 若仍有同伴存活，队列不清；RollMoveAction.update无条件调用monster.rollMove，没有dead guard，所以死者仍消费已排队主roll。
4. 若是末敌死亡，clearPostCombatActions删除非Heal/GainBlock/UseCard/DAMAGE动作，RollMoveAction在删除范围内，所以该roll被清掉。

这属于同一未认证镜像的明确调用链证据，不是原作运行观察。毒在敌人行动前致死不曾进入takeTurn，与已经排入队列后死于Thorns不同。Acid S是takeTurn直接setMove，无排队RollMoveAction，不套入死后roll规则。

`e660e76`生产Combat的死亡guard统一跳过EnemyAI.advance，错误地把两条反伤死亡路径都视为零roll。已先写并运行独立最小真实入口探针：

```powershell
node scripts/test-lua.mjs scripts/probes/queued-roll-on-retaliation.lua
```

探针用已实现随机AI的Blue Slaver，将该敌人设1HP并明确选择Stab、给予玩家Thorns1，只比较行动后的100域请求数：末敌路径期望0/实际0通过；有Cultist同伴路径期望1/实际0失败，退出1。该探针明确保留为共享修复前红例，未混入本片全绿测试，也不通过改变预期掩盖差异。共享修复由`combat_order`独立负责，后续组合应让此探针两条路径均通过。此处不改Combat/Actor或自行增加afterAction钩子；本片只注册rolled_attack的正常advance，供共享修复复用。

## 随机与调度边界

生产依旧是共享16位LCG，主roll请求`random(state,100)-1`，存在模偏差、HP/AI/洗牌相关性及原版独立流/种子映射差异。消费一次的活体行为不等于原作RNG同种子一致。反伤死后roll在本增量基线尚未修复，不能称Spike全部死亡分支或Blue/Nob/Jaw真实消费认证；相关旧账本已追加限定。

当前分支没有主线程最新Weak轮末整合，本片不触碰共享状态文件，不会将旧版本带回；最终统一检查由主线程完成。

## 实际验证

- `spike_slime_s_ai.lua`8组：修复前5失败/3通过，首个错误为HP范围缺失；实现后8通过。覆盖128种子全HP端点与重复性、主roll0/99均选固定攻击、10次活体行动每次只消费一主roll、全格挡/零伤仍消费、修正伤害、多个实例、失败出牌回滚、真实Run small_slimes两成员与伤害。
- Acid S9组兼容通过。新增Spike7项schema与已有相关校验共68项JavaScript通过，0跳过/0失败。
- 既有18遭遇在原256种子样本全部出现，23敌人/53意图/18遭遇、121组通过。契约枚举按原规则跳过新增stateful敌人的循环断言，独立动作预期由专项补充；可达断言未改。
- `build:data`、`validate:data`、受影响JS语法与`git diff --check`通过。没有运行本片完整npm check；独立来源探针如上为已报告FAIL，不包装为全绿。

本地定向日志`build/spike-s-schema.log`、`build/spike-s-encounters.log`不作为平台、PC或严格全池验收。
