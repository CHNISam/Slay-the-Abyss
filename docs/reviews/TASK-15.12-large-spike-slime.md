# TASK-15.12 · 大型棘刺团有限纠正与致死后队列停止

## 边界与已实现规则

基线 `ef721480a48bad549b797d21b8f205fac92e1afa`，只修改现有 `large_spike` 遭遇内的 `spike_slime_l`，不新增敌人、遭遇或奖励牌。本切片**不是完整大型软泥实现**：半血分裂、替换/生成中型敌人、相关状态与新敌时序仍是 TASK-15 的必要缺口，不能由此关闭父任务或声明整只敌人一致。

- 普通直接生成时从闭区间64–70抽取HP，maxHp取本次结果；继承原项目逐只构造、全组首动、牌库洗牌次序。构造范围7，首动主roll范围100，均真实消耗现有随机源。
- A0主roll0–29为攻击、30–99为脆弱；两招都不能连续第三次，强制历史分支仍消耗一次主roll。该分裂前决策与现有中型策略逐分支相同，复用 `abyss_spike_slime_m_ai`，不复制模块；大型保留不同AI kind与独立实例历史，以免暗示已支持分裂。
- 攻击16后向弃牌堆加入两张独立UID的真实Slimed。攻击被全挡也塞牌；脆弱2沿用已核对的整组轮末时序。Slimed继续费用1、消耗，不进入永久卡组、奖励或商店。
- 来源死亡但玩家与同伴仍活时，已排Slimed/主roll继续；末敌死亡继续按既有胜利过滤清除。行动前中毒致死不生成牌或抽行动roll。
- 真实生成控件显示16伤害、两张黏滞的弃牌说明与脆弱2；实际敌方动作生成两张不同卡，并能以真实点击付1能量消耗一张。仅离线原生树验证，不是千星实机视觉验收。

## 本次发现并修复的共用致死缺口

实现后新增边界暴露：玩家被真实攻击致死，`Effects.apply` 仍会执行本次payload后续的污染牌和敌方自盾。中型棘刺、中型酸液与Jaw Thrash也可独立复现；不是大型专属问题。

固定源链是 `DamageAction → AbstractPlayer.damage → DeathScreen` 将 `isScreenUp=true`，普通战斗阶段 `AbstractRoom.update` 不再调动作管理器，后面的独立动作不执行。它不同于胜利时的 `clearPostCombatActions` 选择性清理。对应最小修改是在每个新effect开始前检查玩家HP<=0并停止。没有改变当前伤害内的Angry/Thorns/Spore反应、末敌胜利保留Block/Damage、已死来源且活玩家的队列特例、Curl Up尾部清理或同死优先判负。没有引入复活能力；现有可玩范围未包含复活药水/遗物。

## 固定来源与身份

2026-10-23至24 UTC只读核对社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。下列11文件通过GitHub的base64内容解码，逐字节重算Git blob与SHA256；未使用经过展示规范化的文本恢复文件。Spike M/L的A0 getMove分支相同；AbstractMonster的setHp/init/rollMove确认生命范围与开场主roll。Slimed与MakeTempCardInDiscardAction确认两张临时牌，DamageAction/RollMoveAction/GameActionManager确认已排动作与胜利边界。仅提取规则事实独立实现，没有复制第三方源码、素材或长文案入仓库。

该来源未与正版PC发行二进制hash认证，不是官方开源、原作客户端实测或千星实测。另只读交叉 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f` 的SpikeSlime_L得到相同A0数值/分支；其版本声明也不能代替正版真实性证明。

| 固定文件 | Git blob | SHA256 |
| --- | --- | --- |
| [monsters/exordium/SpikeSlime_L.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SpikeSlime_L.java) | `a013282e75bde7d4a0088182558a016992a10650` | `a6a6976050a4f16507e0bbda75d4946f5eee3bbfc3d9787bc4e7a99f1d22269c` |
| [monsters/AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `4784e38e7afff5980736e2b5c718e62a0c838c47` | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [actions/common/RollMoveAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RollMoveAction.java) | `01731f966b9b6f8c3815b246cd02cf75eb5d2153` | `c938d4b4a9183b39e91c1c54c79085ddf7b2bea082af14895b9a1a00a100fc50` |
| [actions/common/MakeTempCardInDiscardAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/MakeTempCardInDiscardAction.java) | `f4f3cc0d88d8c4124ef070ccb9e0852c3cfc83f7` | `78eeca2eeeaf22de9146148cdcb015b7bdd335f0529a6f62fdadba3dd4d28efd` |
| [actions/common/DamageAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DamageAction.java) | `ea89aeab60af8a7c297495de3cd8eb82d7130232` | `c5649fc04cbcadffa617e5c52f1a6f879f88cb1a90a543d5a0a05ebf950578ec` |
| [cards/status/Slimed.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/status/Slimed.java) | `e6509c4be248eb11f679752b29c890f9fc411b59` | `dda4ce76e76f8c7bf46e2034a1cc3fd261c38eb1a6c117961dc3a051ab927737` |
| [monsters/exordium/SpikeSlime_M.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/SpikeSlime_M.java) | `d9ec26a2fa740ee4f1ccecb800b3a7f0b8e7984d` | `6eb1991db8ac36b1037871537c8669b135a58705ab2b33ca74550dcf84cad707` |
| [rooms/AbstractRoom.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/rooms/AbstractRoom.java) | `c2a1a029a9f59b1b94026dff46d4155824b85f86` | `020f4a0fc3a564f6e45604e5dba582a773a5b9fdb471f8488a2bf8c2354d3a05` |
| [characters/AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `dc0f077c70ff36bad5d602f2128be1db1a0ee5b7` | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| [screens/DeathScreen.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/DeathScreen.java) | `310e687d4b63406d405db6019b6dde9a59244120` | `9d7b6c9cc73d8fe74a94e058ce096a72ef047fbf8a46134ed9f6edb28d537b0b` |
| [actions/GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `1662da8de2aeb42044b385f03d0c801750904b13` | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |

## 先红后绿与最终验证

- 生产修改前大型核心17组为3通过/14失败；数据/校验21项为1通过/20失败；真实UI失败于缺少两张Slimed说明。保留原始红日志，没有把原本通过的否定例当作新功能覆盖。
- 大型修正后核心17/17通过，其中600种受控主roll/历史组合通过真实Combat动作入口；128种子覆盖全部HP端点和中间值。生成UI、实际Run遭遇、两张UID、付费消耗、实例隔离及原地事务回滚通过。
- 共用致死8组在保护前为3通过/5失败，之后8/8。明确验证真实中/大型棘刺、中型酸液攻击，Jaw Thrash、保留死亡前已发生效果、非致命完整payload、胜利保留Block和同死优先判负。
- 核对远端完整测试清单：113份顶层Lua、4份Lua支持文件、61份JS和4份Python均已物化，无遗漏。新增3份Lua后**116/116顶层原生Lua全通过**，包括中型策略、末敌保留动作、死源/活玩家队列、同死、Spore Cloud、Curl Up和所有既有UI。
- 不依赖缺失Lua桥接的受影响JS组**441/441通过**；Python实际17/17通过。build:data、build:ui、地图/主题生成、validate:data与check:syntax通过。
- 较大JS组实际451项，446通过、5失败。五项均因缺少 `fengari-node-cli/src/lua-cli.js`：`build-lua-data.test.mjs` 中UTF8实际Lua往返、六表载入、runner失败/超时、自动发现四项，以及 `game-ui.test.mjs` 的真实Lua集成一项。相同Lua脚本已在原生套件通过，但不代称Fengari桥接已绿。
- 初次自建运行器遗漏tools/LUA_PATH和battle-ui注入，出现15个Lua及Python/界面工具路径错误；补齐与远端hash一致的工具并按项目运行器准备环境/真实布局后，重跑全部116 Lua和Python得到上述最终结果。初次失败保留，不作为生产回归或最终通过证据。
- 未安装依赖、未执行完整npm check；原生Lua5.4不等于Fengari或千星。独立评审、最终发布SHA与完整Quality结果由PR记录，不能用本地定向通过代替。

## 必要保留缺口

大型软泥分裂仍未实现，范围含半血打断、分裂时捕获生命/生成/清理、不得提前胜利和新敌行动顺序；这是首发父任务必要工作，不是可选简化。另大型酸液/窃金客等各自尚未修正的内容、合法遭遇编组继续保留。

生产仍为共享16位LCG与现有洗牌，不是原版独立monsterHpRng/aiRng/shuffleRng、RandomXS128、Java洗牌或原版种子映射。新HP/AI抽样会改变后续共享轨迹；受控输入/阶段一致不等于统计分布或整局一致。未实现完整动作管理器、复活能力、A2/A7/A17或所有能力组合。

没有启动原神/沙箱/MCP，没有平台编译、写存档、官方导入、实机或投稿。全池、完整第一幕、平台及父任务关口不关闭。
