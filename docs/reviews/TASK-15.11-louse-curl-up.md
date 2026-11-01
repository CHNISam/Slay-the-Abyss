# TASK-15.11 · 红绿虫一次性蜷甲

## 有限范围与规则

基线 `bf0602bcca592322a068069c417a246dbc0d4f3a` 已有两虫的HP/咬击/选招，本片仅补齐现有可玩敌人的A0 Curl Up。没有增加敌人、遭遇、卡池或自创数值。

- 两虫各自在开战阶段抽取一次3–7，并以独立的「蜷甲」状态显示；不是预先获得格挡。受控调用阶段为：每只HP后咬击、全部开场选招、牌库洗牌、按编组顺序逐只抽蜷甲、开场钩子与抽牌。四牌双虫测试请求范围是 `6,3,7,3,100,100,4,3,2,5,5`。
- 普通攻击实际穿透格挡且不致命时，立即锁定一次。0伤害、全挡、致命、固定药水伤害、毒及反伤不触发。现有正常伤害入口要求有效的存活来源；本片不增设空来源伤害入口，也不开放玩家蜷甲或任意重新获得该能力的通用机制。
- 蜷甲的增盾/移除是**队尾**，不是Angry、Thorns或Spore的队首反应。多段与同卡后续效果先完成，随后已有Sharp Hide与使用牌去向，再按实际触发顺序执行蜷甲。范围攻击两目标的蜷甲顺序不能反转。
- 增盾使用触发时捕获的固定数值，不吃敏捷或脆弱，仍受999格挡上限。先获得格挡再移除状态。后续已排攻击杀死拥有者时，两步都不执行，原状态与已触发锁保留；最后敌人死亡时，保留的GainBlock同样因目标死亡而无效。玩家被荆棘或尖刺甲壳反杀后，剩余蜷甲队尾停止。
- 非出牌的公开伤害/效果调用在外层边界结算；出牌保留原地事务回滚。错误效果不会留下锁、队尾、扣费、弃牌或事件。敌方动作边界在当前敌人已排动作/选招之后、下一敌人行动之前，不把队尾拖到整组结束。
- 状态名、说明与现有格挡反馈均使用本项目表现；图标复用共享主题内已有的图库编号103066。真实生成界面回归核实独立数值、只读查看、点击出牌后格挡及被动移除，不据此声称官方客户端视觉验收。

## 固定来源与身份边界

只读核对社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。新增文件从GitHub公开API的base64 JSON解码；复用的原始文件重新核算Git blob。全部19份相关源码均与固定树的blob一致，未给展示文本猜补换行。仅提取规则事实并独立实现；第三方实现、素材、动画和长文案不进入仓库。该镜像没有正版PC发行二进制hash认证，不是官方源码，也不是原作客户端或千星实测。

关键来源链：

- `LouseNormal/LouseDefensive.usePreBattleAction` 确认A0 3–7；`MonsterRoom.onPlayerEntry → MonsterGroup.init → AbstractDungeon → AbstractPlayer.preBattlePrep → CardGroup.initializeDeck → MonsterGroup.usePreBattleAction` 确定全组构造/选招、洗牌和被动阶段。
- `CurlUpPower.onAttacked` 确定非空来源、NORMAL、正伤害、小于受击前生命、立即一次锁定及三个BOTTOM动作。CLOSED仅为原作演出状态，本片没有复制或声称实现原作蜷缩动画。
- `GainBlockAction`、`RemoveSpecificPowerAction`、`AbstractCreature.addBlock` 确定死亡guard、固定增盾与上限；`GameActionManager` 确定TOP/BOTTOM、当前动作优先于下一敌人及战斗结束清理例外。
- `AbstractPlayer.useCard`、`UseCardAction`、`SharpHidePower` 确定卡效果/反伤/使用牌去向；`DrawCardAction`及`DropkickAction`核实抽牌、洗牌续动作和条件连击仍先于蜷甲。`AbstractPlayer.damage → DeathScreen`及`AbstractRoom`证实玩家死亡后动作管理器停止。

关键文件身份见下表，其余完整链的固定路径均在同一提交内；不把镜像版本误报为认证PC构建。

| 固定文件 | Git blob | SHA256 |
| --- | --- | --- |
| [GameActionManager.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java) | `1662da8de2aeb42044b385f03d0c801750904b13` | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| [GainBlockAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/GainBlockAction.java) | `ce4c481797045d55a17b133289e2e070431eacdf` | `e48f437c06b42dda312446a4b536aca54570d637e53087ac16f736d84bb5df4f` |
| [RemoveSpecificPowerAction.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RemoveSpecificPowerAction.java) | `5869c5cae5f539b88d2e52223628beca9ea14cba` | `c6262b3ce8528f75045f9610026d524a8ae63c526547593e4549f7c5a01a1ad8` |
| [CardGroup.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/CardGroup.java) | `546405eea9d7dcbd855fe47471c55c92d086987c` | `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8` |
| [AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `dc0f077c70ff36bad5d602f2128be1db1a0ee5b7` | `2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95` |
| [LouseDefensive.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/LouseDefensive.java) | `83dc2dad1247ef33c5ef76ec5ca5cdbc5ced8def` | `48a0b5c54a745c1842d10f61754edf0ea28efeb676816efa5a131bce1a7a5bd0` |
| [LouseNormal.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/LouseNormal.java) | `f56e24b37816f256bd058184c1b54a49584092a7` | `b9a875b240236ac28e5c427584f56af1751604b7781bc6c1a5535fa888f9775f` |
| [CurlUpPower.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/CurlUpPower.java) | `5bbbfd5b627b6cab2b5aa3e7c11411692c156351` | `82ae7c5809cd06d58c0280a0ceebf642977635e0fe2d2d33f85006c552b4116d` |
| [DeathScreen.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/screens/DeathScreen.java) | `310e687d4b63406d405db6019b6dde9a59244120` | `9d7b6c9cc73d8fe74a94e058ce096a72ef047fbf8a46134ed9f6edb28d537b0b` |

## 先红后绿与验证

- 修改生产前28组真实核心测试为6通过/22失败；新数据19项为14通过/5失败，真实生成UI因缺少状态定义失败。负向无触发例通过不被冒充功能覆盖。
- 实现后核心28/28、既有Louse26/26、新数据及既有AI schema52/52、真实生成UI通过。覆盖128种子数值端点、阶段请求序列、实例隔离、正常/固定/毒/反伤/全挡/致死、同卡多段、范围FIFO与队首反应、同卡后续状态、Sharp Hide、拥有者与玩家死亡、固定增盾/999上限及原地回滚。
- 测试中曾将Iron Wave写成攻击后格挡，真实运行指出其既有规则是格挡后攻击；仅修正测试预期，不改动正确生产顺序。原生Lua数值4.0与界面整数4的格式差异也仅修正测试断言。
- 已核对远端完整测试清单：基线111份顶层Lua、4份Lua支持文件、60份JS、4份Python均无遗漏；新增后113份顶层原生Lua全部通过。Python实际执行17项全部通过。数据/UI/地图/主题生成、数据校验、JavaScript语法检查通过。
- 不含缺失桥接依赖的受影响JS组431/431通过。另一个扩大选择实际执行437项，433通过、4失败，均在 `build-lua-data.test.mjs`：UTF8真实Lua往返、六表Lua载入、runner错误/超时、自动发现Lua文件；原因均为环境缺少 `fengari-node-cli/src/lua-cli.js`。单独主题组4项中3通过，`built theme loads in Lua with converted colours and without the design note`也因同一缺失失败。这些失败保留，不作全绿声明。
- 未安装依赖，未执行完整 `npm run check`。原生宿主为Lua5.4，不等同Fengari/千星。独立评审与发布SHA的完整Quality结果以PR为准。

## 尚未完成

生产仍使用共享16位LCG及当前洗牌算法，不是原版独立 `monsterHpRng/aiRng/shuffleRng`、RandomXS128或Java洗牌。同一受控输入的范围与阶段可验证，不等于原版种子映射、总体概率、完整开战顺序或整局一致。新增蜷甲抽样会改变后续共享随机轨迹。

本片只增加所需的有限队尾，不宣称完整动作管理器、任意能力组合、任意能力重获、原作CLOSED动画、A2/A7/A17或全敌人机制一致。未启动原神、沙箱或MCP；没有平台编译、写入存档、官方导入、实机或发布。父任务及随机流、全量规则、所有平台关口继续保留。
