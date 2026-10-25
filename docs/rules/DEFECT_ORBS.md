# 机器人充能球：独立规则切片

本切片独立实现四类基础球及集中，尚未开放机器人职业或完整卡池。只做离线模块，不声称平台、实机或整职业完成。

## 来源

采用仓库既有固定来源 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，镜像版本字段为 V2.3.4 / 2022-12-18。社区反编译资料未经正版二进制认证。本轮只读核对方法行为，未复制原实现、素材或长文案。最初参考的 ButterflyGame 镜像不作为本切片固定证据，以下均重新核对既有319009来源。

相对源路径与本轮下载原始字节SHA256：

| 路径 | SHA256 |
| --- | --- |
| orbs/AbstractOrb.java | 958dcb8ffa9c66c506aff886a7969c8e22366c2764166052ed1f613227bc5168 |
| orbs/Lightning.java | 16458980840cc41d788b6d92c69e8f547aa8208eb34a37ee610dfbb7bdebe62e |
| orbs/Frost.java | 74c6f567c91c526b0fd2b9b8040888bab54eab329d099251ad94f81dadeb1439 |
| orbs/Dark.java | 610fccbaf45b74bf4c151982e07c599f940a295027271e478a4e8b3e46def373 |
| orbs/Plasma.java | 3758d5402fd24491fae363bf64fc4e871e917f5f89d44d2265840c96db648cce |
| characters/AbstractPlayer.java | 2720ba8dd7a216781a3b2fcb709f5ec67dc9b2559af25f7f6b89df1ef0947d95 |
| actions/common/DarkOrbEvokeAction.java | 7df164454e63c346ecaf75af87baa876aae2205ef2626640fc08938c74145404 |
| actions/defect/TriggerEndOfTurnOrbsAction.java | a229b6abed98cbbdb0f211633d2c47c826ec7b5812ef08e41ff08483864976c2 |
| cards/blue/Dualcast.java | 1f08c372558b65869566bb13fef25ded3af0f21c88e003217e74955bb566f7b0 |
| monsters/MonsterGroup.java | 535770201b8aa8de01b52b185979af537f11ad0862e7d3e71ebb20cc64234221 |

## 已实现语义

闪电被动3/唤起8伤害，冰霜被动2/唤起5格挡，各自加集中并钳制到0；黑暗初始储伤6，轮末增长max(0,6+集中)，集中不重算既有储伤；等离子回合开始1能量/唤起2能量，完全不受集中。固定伤害和格挡借用真实Combat API，不套用力量、弱化、易伤、敏捷或脆弱，不触发普通攻击专属反刺/Curl Up。

球位有序、0位不能生成；满位先唤起首球再生成；Dualcast对同一个首球先不移除唤起，再移除唤起。第一次杀死一名敌人后，第二次动作重新创建目标选择。黑暗在动作创建时锁定最低当前生命敌人，同生命按列表先后，目标死亡后不转移；闪电在执行时使用独立cardRandomRng抽取活敌，即使仅一名也消费随机数，不借用旧战斗LCG。

轮末来源有一个关键同步边界：TriggerEndOfTurnOrbsAction在一次循环中调用所有球的onEndOfTurn；闪电/冰霜只是排入后续动作，黑暗直接增长储伤。因此末敌后来被前位闪电击杀时，黑暗本轮已增长，后续伤害找不到活敌而无效，但已排入的冰霜GainBlockAction仍须执行（clearPostCombatActions保留例外）；玩家死亡则全部停止。测试明确保留此反直觉情况。

## API和边界

`init(state, slots, options)`建立state.orbs；slots 0至10，options只接受nil或空表，未实现选项拒绝。重复初始化拒绝，战后重建由Combat调用方负责。

`channel(state, kind, api)`、`evoke(state, api)`、`dualcast(state, api)`、`startTurn(state, api)`、`endTurn(state, api)`，其中kind为lightning/frost/dark/plasma；api为`{damage=Combat.damage, block=Combat.block}`，避免循环require。`setFocus(state, value)`设置集中；此处只是状态数值接口，不宣称完整Focus Power施加、Artifact阻挡、Biased Cognition衰减已经接线。`snapshot`返回分离的数据副本，球事件detail含快照。

`prepareEvoke(state, remove)`和`resolve(state, action, api)`提供分离的动作边界供测试和后续队列接入；prepare默认移除球，false保留，Dark目标在prepare锁定。此低层接口假定调用方已经验证API与上下文；普通evoke/dualcast入口先检查API/RNG及等离子能量范围。支持范围为有界signed32数值，超范围明确拒绝，不用Lua浮点静默绕过溢出。

尚未实现Electrodynamics、Lock-On、Cables、Dark Core、Loop、Emotion Chip、球位增减卡及其他充能/唤起钩子；不提供开启这些机制的选项。尚未实现半死怪复活事务或原作所有非普通伤害钩子。既有固定Combat伤害路径只是本项目已支持敌人子集的桥接，不代表全量THORNS DamageInfo行为。

原作GameActionManager先轮末遗物/前置能力，再排入球触发，再触发手牌轮末。完整生命周期需共享战斗层接入并独立验证，尤其首轮和抽牌、轮末诅咒/能力的队列关系。本模块测试只通过真实Combat state调用明确生命周期API。

## 验证

执行 `npm ci --ignore-scripts --cache /workspace/.npm-cache`、`npm run build:data`、`node scripts/test-lua.mjs tests/lua/defect_orbs.lua`。定向23组通过，包含0/1/3球位、固定修正、独立RNG、负集中、Dark锁定、双放杀敌、末敌取消与同步增长、等离子时机、非法输入与快照隔离。未运行全量check，未导入平台或实机试玩。

## 六张基础卡接入（本轮后续）

新增 `abyss_defect_cards.withFoundationCards(data)` 返回完整深拷贝并附加六张规则定义，重名拒绝；不修改生产数据、随机获取池、职业菜单或首发清单。基础卡和升级由真实 `Combat.play` 消费，目标攻击仍走现有普通攻击链；充能和双放由共享Effect dispatcher调用上面的球API。Darkness+通过 `darkImpulse(state)` 在生成新Dark之后触发所有Dark的被动增长一次，新生成球也参与，不改变其他球。Cables联动仍不支持。

| 初代卡 | 本轮规则 | 固定源 cards/blue/ 文件SHA256 |
| --- | --- | --- |
| Zap | 1费，生成1闪电；升级0费 | 8d37ed631a4133ebaa3947e5a23908852edb33505d713261344e6d6bad57a69e |
| Dualcast | 1费，同首球两次唤起；升级0费 | 1f08c372558b65869566bb13fef25ded3af0f21c88e003217e74955bb566f7b0 |
| Cold Snap | 1费，6伤害后冰霜；升级9伤害 | 4aa9a3a7c4c1e6bfce32aee03b80eb8b86f9805fe462cf7ac11df77f9fcf5d20 |
| Ball Lightning | 1费，7伤害后闪电；升级10伤害 | 2f5ad022ba3ae0f69cb52df5da225f728b771346b8df2e53f85c4fbbdf9fca27 |
| Coolheaded | 1费，冰霜后抽1；升级抽2 | d527203fca40f13dc164103596259b5f8fa67964baee4faf94520655e759900b |
| Darkness | 1费，生成Dark；升级随后触发所有Dark被动 | dc3af79a546fe3fefe4df7c53efc24543f68fee436914650fe9a8bc7295af5dc |

`actions/defect/DarkImpulseAction.java` SHA256为 `92993a0546ac29b7f2443020af8025bab87961cba8ba5950c4634e1de4ab87ab`。同一319009固定来源，未混用版本。此动作对各Dark调用开始与结束被动，Dark开始被动为空，所以本切片等价于仅增加储伤；Cables额外首球触发未纳入。

补充验证：球模块27组通过，`node scripts/test-lua.mjs tests/lua/defect_cards.lua` 真实卡牌20组通过，覆盖六卡基本/升级、零球位、满槽、目标拒绝、末敌清后续生成、双放杀敌与重新选敌，以及后续错误抛出前已发生的伤害/充能/RNG消费在 `Combat.play` 中全部回滚。回滚包含原 orb/RNG 引用、随机primitive words及counter、能量、手牌/弃牌与事件。尚未验证这些卡的生产自然获取、平台显示、原生存档或实机。

末敌清理复核：已创建的冰霜被动/唤起动作在胜利后仍可获得格挡，禁止在终局新建球/唤起；已创建动作遇玩家死亡也停止。另三组真实state回归覆盖Lightning后Frost、先prepare再胜利、prepare后玩家死亡。

## 五张后续规则卡

同一319009固定来源新增下列派生定义，仅通过opt-in helper开放；不是完整职业池或重编程实现。`withFoundationCards`现附加11张定义，原有六卡不裁剪。

| 源cards/blue文件 | 规则 | SHA256 |
| --- | --- | --- |
| Leap.java | 1费卡牌格挡9，升级12 | a65b7ce314e982351ba4b11918ac9f2bbbb885e5ea2693ad63ac3a5d5ff7be88 |
| SweepingBeam.java | 1费全敌6伤害后抽1，升级伤害9 | 80b98e407d1c67d8566e48a3c1823577ab2dca6e5c766090c1e438f6229c5085 |
| BeamCell.java | 0费3伤害后易伤1，升级4伤害后易伤2 | e91972516aa98df533d840acf8c0b1e4137f720b7d3f5b97261fe59c1f8cc779 |
| Fusion.java | 2费生成1等离子，升级1费 | 19bed2555b5d32b6b1cdd5acaeecf5a9f1f8bc9482ce4e9f2e93ab8c64c69729 |
| Defragment.java | 1费能力集中+1，升级+2 | 840c1b826dd5e473255cc6a79bdc5cd303eaf14dfdd6f093bfb029fb19518c27 |

集中正数叠加的999上限来自FocusPower自身的stackPower override，不是AbstractPower基类通则。构造器首次赋值不钳制，但本切片来源牌首次只施加1或2。FocusPower还明确支持负数与归零移除；本轮只开放正数gainFocus，未提供负数施加、衰减、Artifact与负Focus Power完整生命周期，不能因此开放Reprogram等牌。

FocusPower.java固定来源SHA256：`266d04b57ccb01daaff326346c21b2935caa82158eaf2a12f6291ba453491da4`。新增 `tests/lua/defect_expansion.lua` 的真实Combat.play 17组通过，包含五卡普通/升级、费用、AOE不同敌人的修正、卡牌伤害与球伤害隔离、卡后抽牌、等离子真实下一回合、能力牌离开pile、既有球集中即时刷新、Artifact正负边界、999上限及负增量拒绝。同期原六卡20组、球模块27组复跑均通过；未运行全量回归。
