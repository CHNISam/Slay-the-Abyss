# TASK-15 蓝衣束缚者（Blue Slaver）A0 选招切片

2026-10-23，分支`feat/continue-blue-slaver`，暂依赖已提交Nob切片`2a86eaa`。仅追加独立AI选招；既有PR86动作值与HP范围保持。不启动原神、沙箱或MCP，不做平台编译、存档副本写入、官方导入或实机；全部严格全池与平台AC保留。

## 固定来源与真实性

本轮完整只读取得 [SlaverBlue.java / aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SlaverBlue.java)。UTF-8内容SHA256：`A523E2AE8A5B598AD19AF3460A28F13B8BC47152501F9B4E61F46F732D869206`。文件标为CFR反编译；没有与目标正版PC构建号/二进制hash认证，不能称官方开源、原作PC实测或跨版本完全一致。只读核查后独立实现规则，未复制、运行或提交上游程序。

首动和每次动作末的主roll消费依据同提交 [AbstractMonster.rollMove](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java)，其已实际读取内容hash及setMove记录历史的说明延续[Nob账本](TASK-15-gremlin-nob-ai.md)。先前动作片使用的另一固定镜像与数值见[BLUE_SLAVER_ACTIONS](../rules/BLUE_SLAVER_ACTIONS.md)，不把两个镜像视为已证明相互独立。

## A0 独立预期

| 条件 | 预期 |
|---|---|
| HP | 保留既有46–50闭区间实际采样，maxHp等于采样；A7+48–52不适用 |
| Stab | 保留基础12伤害，不施加Weak；A2+13不适用 |
| Rake | 保留基础7伤害后施加Weak1；A2+8和A17+Weak2不适用 |
| 首动 | 没有强制动作；消费一个主roll，0–39选Rake，40–99选Stab |
| 非两连历史 | 同样按40边界选择，不追加小数或重抽 |
| 前两次均Stab | 下一次强制Rake，无论主roll值；主roll仍消费 |
| 前两次均Rake | 下一次强制Stab，无论主roll值；主roll仍消费 |

上游A0分支是先检查roll>=40且未两连Stab，随后检查未两连Rake，最后Stab。本片独立实现等价的“先限制两连，再按阈值选择”；900个roll/历史组合按独立预期逐一验证。A17+的Rake限制不同，本片不支持升阶或换用其策略。

新增`abyss_blue_slaver_ai`，EnemyAI只加初始化/推进分派；`blueLast/bluePrevious`平铺在各实例，遵循现有原地事务快照。数据追加policy与阈值/意图引用，动作payload、HP、遭遇编组、Combat、Actor、Inventory、主题与UI均未改。原生脚本打包断言要求包含新模块。

## 证据与限制

生产主roll仍用本项目`random(state,100)-1`，共享16位LCG，不是原作独立aiRng/monsterHpRng/洗牌流，也没有原作种子映射。存在模100偏差和相关性；受控边界通过不能换算为真实原作概率或同种子轨迹通过。HP范围本片只复核并保留，不宣称原版HP随机流一致。

共享Weak的justApplied/轮末调度尚未严格对齐，本片只证明Rake的动作内“伤害7→Weak1”及当前运行时可执行，不将完整Weak存续认证归入本片。复合攻击沿用已有attack意图类别，正式客户端复合图标/状态显示仍待验。

`tests/lua/blue_slaver_ai.lua`新增9组：修复前7失败、2通过，首个明确失败是缺少专属policy；另见roll39首动错误和缺失历史。实现后9组通过，覆盖首动39/40两侧、全部900个受控输入、双向两连轨迹、每个历史强制分支仍只消费一次主roll、自然攻击效果顺序、毒死不执行、不推进死敌、多实例16种子12回合、失败出牌回滚。长轨迹只给玩家额外HP避免测试提前结束，不作为原数值难度或通关证据。

实际定向验证（没有重跑本片完整npm check，由主线程整合后执行）：

- `npm run build:data`通过。
- 新AI9组、既有`blue_slaver.lua`动作9组通过；旧动作测试与其断言完全保留。
- Blue9项、既有EnemyAI/Jaw/Nob及原生脚本打包校验合计53项JavaScript通过，0跳过、0失败。
- 既有`encounter_coverage.lua`通过：23敌人/53意图/18遭遇，129组；原256种子样本中18遭遇全部可达，未修改覆盖断言。专属AI采用独立预期套件，既有契约枚举按原规则跳过stateful敌人的固定循环断言。

日志位于本地生成目录`build/blue-schema.log`与`build/blue-encounters.log`，不作为平台、正版PC或严格全池验收。
