# TASK-15.6 · 中型棘刺团与可清除的黏滞状态牌

## 有限可玩缺口

基线 `7b09fdb835e932e6b0b2c6509f1fddf0e33310a2` 的 `medium_slimes` 已包含中型棘刺团，但原来固定30生命、固定攻击/脆弱交替，并遗漏攻击后的Slimed。这里独立实现现有敌人的 A0 行为，以及使其生成牌真正可用的最小接口，不增加新敌人、遭遇或奖励牌。

- HP按28–32闭区间抽样。继承开场 `rollMove`，主roll为0–99。
- roll0–29倾向攻击，30–99倾向施加脆弱；同一动作不允许连续第三次，强制改招仍消费一次主roll。A17的单次Frail限制不属于A0。
- 攻击为基础8伤害，然后在弃牌堆创建1张Slimed；满格挡也照常生成。另一动施加脆弱1，沿用已验证的共享轮末与Artifact接口。
- 每次执行后的roll使用本敌人独立历史。新实例没有其他实例历史。死亡前未执行动作不选招。
- Slimed内部ID保留以核对规则，玩家名称为本项目的“黏滞”。状态牌、普通稀有度、费用1、目标SELF、真正空use、打出消耗、非虚无、不可升级。玩家文字独立撰写，显示费用从源数据插值；没有复制原版长文案或素材。
- 抽到黏滞后可无目标打出，扣1能量并进入本场消耗堆；零能量拒绝且原子性不变。未打出的黏滞正常弃牌/洗回，不在轮末自动消耗。它不是技能，不触发Nob的技能反应。
- 奖励/商店仍按状态牌排除；营地/升级神龛不提供或接受其升级。临时实例UID独立，永久牌组和下一场战斗不携带它。

## 必要的窄接口

`Effects.supported({})` 仍为false，普通牌与任意未知状态都不能凭空effects通过。Combat只对白名单 `slimed` 的完整状态/费用1/消耗/非虚无/无升级/无条件/无特殊费用/真空table组合接受空use；schema对同一契约拒绝偏差。没有增加虚构的零伤害或零格挡效果。

`SpikeSlime_M.takeTurn` 先排Damage，再排MakeTempCardInDiscard，最后排RollMove。后两种动作都没有“来源已死亡则跳过”的检查，所以荆棘杀死此敌人但仍有队友时，已排的黏滞和roll必须继续。这里仅开放已核实的 `makeTempCardInDiscard` 通过共享解释器的dead-source分支，其余未核实的dead-source操作仍不执行。最外层仍要求这是已排敌方动作且战斗未结束；公共直接调用的死亡来源不生成牌。末敌被荆棘杀死时，既有 `clearPostCombatActions` 映射会清掉card manipulation和roll，保留PR129的末敌取消，不绕过它。

PR135的全组清盾→全组开始状态→动作顺序不变。敌人在行动前毒死时，既不攻击、生成牌，也不消费行动后roll。

## 固定来源及证据等级

2026-10-23 UTC只读核对 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 社区反编译镜像方法体；GitHub base64内容按原始字节复算Git blob和SHA256，没有通过展示文本增补换行。该源未与正版PC发行二进制做hash认证，不是官方开源、原作客户端观察或平台实测。只提取行为事实并独立实现，没有把第三方源文件提交到本仓库。

| 固定文件 | Git blob | SHA256 |
| --- | --- | --- |
| [monsters/exordium/SpikeSlime_M.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SpikeSlime_M.java) | `d9ec26a2fa740ee4f1ccecb800b3a7f0b8e7984d` | `6eb1991db8ac36b1037871537c8669b135a58705ab2b33ca74550dcf84cad707` |
| [cards/status/Slimed.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/status/Slimed.java) | `e6509c4be248eb11f679752b29c890f9fc411b59` | `dda4ce76e76f8c7bf46e2034a1cc3fd261c38eb1a6c117961dc3a051ab927737` |
| [actions/GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `1662da8de2aeb42044b385f03d0c801750904b13` | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| [powers/FrailPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/FrailPower.java) | `0791c733baf9c9c37a5184d718271b55cc0bdc74` | `9530396be8c2e748a11fa9cff66be4b94c39a5fad3bfcd52fa98fd1a76ba5c96` |
| [monsters/AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `4784e38e7afff5980736e2b5c718e62a0c838c47` | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [actions/common/RollMoveAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RollMoveAction.java) | `01731f966b9b6f8c3815b246cd02cf75eb5d2153` | `c938d4b4a9183b39e91c1c54c79085ddf7b2bea082af14895b9a1a00a100fc50` |
| [actions/common/MakeTempCardInDiscardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/MakeTempCardInDiscardAction.java) | `f4f3cc0d88d8c4124ef070ccb9e0852c3cfc83f7` | `78eeca2eeeaf22de9146148cdcb015b7bdd335f0529a6f62fdadba3dd4d28efd` |

`SpikeSlime_M` 的普通构造与A0 `getMove/takeTurn` 是本片数值、30边界和动作顺序依据；`Slimed` 构造/use/upgrade是空使用、费用、卡种与消耗/不可升级依据；`AbstractMonster.init/rollMove/createIntent`提供首动抽样和历史记录接口；`RollMoveAction`与`MakeTempCardInDiscardAction`核对死后已排动作无owner guard；`GameActionManager.clearPostCombatActions`核对末敌清队列。`FrailPower`只复核现有脆弱接口，没有重写共享持续状态。

## 测试与交付边界

- 先红：新增Lua20组在原7b09fdb基础为7过13失败，明确暴露固定HP/首动、错误固定循环、缺状态牌和排队生成。新schema24项也在原版上失败；原始日志保留于交付工作区。
- 后绿：22组真实Combat/Run回归，内含9种独立历史×100个受控主roll，共900个纯决策输入；另验证HP全端点、动作次序、满格挡生成、毒死、荆棘死后队友/末敌两分支、实例隔离、原子回滚、真实生成抽牌并打出、零能量、不虚无、未知空use拒绝、奖励/商店/营地/神龛与永久牌组隔离。
- 真实生成控件：敌人8伤害与黏滞详情→结束回合真正塞牌→抽到费用1的“黏滞”→两次点选无敌人目标打出→能量2与消耗堆→重复陈旧Up/Click不二次执行。复用既有状态牌主题与图标，不变更批准的视觉方向。
- 新schema27项及当前已物化的相关JS共191项通过。全105份现有/新增native Lua fixture通过（包含专用battle_ui布局wrapper及正确LUA_PATH）；该测试使用宿主Lua5.4，不把它等同生产Fengari或平台运行时。原Lua growing_card_text排除Rampage后的固定数量从37改为38（36职业牌加Dazed/Slimed），原来逐牌基础/升级文案一致性断言保留，并覆盖新状态牌；并不是新增职业牌池。
- `build-lua-data`、`validate-data`、`build-ui`、`build-ui-theme`、`map-ui-layout`及变更JS语法通过；native候选脚本发现器确认新增AI恰好注册一次，总36模块。不是实际平台编译/导出。
- 未执行完整 `npm run check`，最终准确SHA的完整CI由主线程统一核验。初始快照没有Python测试，零发现不作通过；追加从固定基线取回相关测试后，真实红例发现两处38张总数假定及原型缺Slimed条目，已修正为39总卡/37非状态职业卡，并只追加原型中的Slimed行。原有逐牌、唯一名、非状态牌数量和原型精确ID集合断言全部保留；相关16项Python最终通过。另补验原Dazed和native脚本发现15项JS通过。额外theme加载桥接因本快照未安装Fengari未运行成功（MODULE_NOT_FOUND），其真实native Lua主题夹具已通过，但不替代最终Fengari/CI。独立复审在隔离快照验证17份相关Lua与6个定向变异，均有效；并指出Tackle schema仅检查存在性不能约束先攻击再塞牌。随后新增逆序/缺攻击/重复塞牌3个红例，将本策略验证收紧到damage→单张Slimed二元队列，修后全绿；该修订仍需复审最终字节确认，不能把自测当作最终复审。

仍保留：共享16位LCG与原作独立monsterHpRng/aiRng/shuffle流、种子映射及总体随机概率一致性；其他大软泥分裂/继承中毒分支与遭遇编组；未纳入卡/遗物/Power的通用动作队列；认证PC构建、全池严格一致性、M1与所有平台关口。新增主roll/HP抽样会改变共享LCG后续洗牌及奖励轨迹，只声称调用顺序与受控决策，不能声称同种子整局与原作相同。本片没有启动原神/MCP、官方导入、实机、写入存档或发布。
