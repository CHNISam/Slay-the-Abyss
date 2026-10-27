# 燃烧精英与绿钥匙源组件

TASK-64，固定规则来源为第三方反编译镜像`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是正版二进制对照或官方源码认证。源member的字节数、SHA256及Git blob身份见`tests/fixtures/emerald-elite-source.json`，不将上游原文复制进产品。

## 本片范围

`abyss_emerald_elite`只提供对既有地图、既有mapRng和调用者提供的资格/战斗事实进行计算的纯组件；没有Map、Run、Nodes、Host或UI接线，不创建资格，不直接设置`run.keys`。最终调用者负责验证地图生成上下文、合法路径、真实胜利、持续mapRng、奖励owner，以及整个事务的回滚。本片不证明绿钥匙已通过自然路径取得，M3和TASK-64整项仍未完成。

## 原版顺序

`AbstractDungeon.generateMap → setEmeraldElite`先生成路径并完成房型分配，只有终幕资格成立且本局未拿绿钥匙，才按源地图y、x升序收集精英，用当前mapRng的`random(0,n-1)`选一个节点。只有一个精英也抽一次；无资格或已有钥匙不抽。不得另起seed、改用room/miscRng、优先选可达路径或重抽。下一幕使用该幕本来的地图种子和流，不沿用上一幕地图流。

强化不是生成地图时抽取。`AbstractPlayer.preBattlePrep`先将怪物预战斗动作入队，再由`MonsterRoomElite.applyEmeraldEliteBuff`用同一个持续mapRng抽`random(0,3)`。当时初始怪物组共用同一种强化，后续召唤不继承：

| roll | 行为 |
| --- | --- |
| 0 | 每个敌人获得`act+1`力量 |
| 1 | 最大生命增加`round(float32(maxHP × 0.25f))`，再治疗同量；先用原构造HP抽样结果 |
| 2 | 每个敌人获得`2×act+2`金属化，敌方回合末获得格挡 |
| 3 | 每个敌人获得`2×act+1`怪物再生，敌方回合末治疗且不衰减 |

## 接口与所有权

- `select(map,mapRng,{endingUnlocked,emeraldOwned}) → selection,nextRng,reason`：输入流和图不变。图可用源`x/y`坐标，或项目`floor/lane`坐标；后者按幕起点转换。`selection`包含`version/act/nodeId/x/y`，返回的流是私有克隆。无资格、已有钥匙或第四幕返回空选择和未消费的克隆；符合资格却没有精英明确返回`no_elite_nodes`，不借其他节点代替。
- `prepare(selection,mapRng) → boost,nextRng,reason`：只在父流程确认真实燃烧房间入口时调用。`boost`保留选择身份并增加`roll`。调用者负责只准备一次及事务成功后提交返回的持续流。
- `apply(initialActors,boost,{applyPower,increaseMaxHp})`：首先校验完整初始目标组，再冻结目标成员；回调必须返回精确`true`才继续。`applyPower(actor,statusId,amount)`提交力量、金属化或`regenerate_monster`；`increaseMaxHp(actor,amount)`必须提交“加最大生命并治疗同量”的源动作。组件不直接写生命/状态，不安装普通怪物再生回合末处理。回调失败或抛错可能已改变调用者私有图，父流程必须整体回滚，不得提交部分结果。
- `rewardOwner(context,rewardCount)`：仅在资格成立、未持钥匙、当前带标记的精英真实胜利、非烟雾且已有至少一个奖励时，建立独立`EMERALD_KEY`奖励对象。不得拿显式战斗ID或测试自填context冒充自然战斗事实。
- `canClaim(offer,context)`及`claim(offer,context,obtain)`：必须在reward阶段且仍匹配同一`runSeed/act/floor/nodeId/sourceEncounter/combatGeneration`。领取调用注入的`obtain()`，只有精确`true`才将该offer置为claimed；失败保留未领取，重复/旧owner拒绝。外部Run事务负责实际钥匙及资源原子提交；本组件不签发安全令牌，调用者仍须保护真实context来源。

绿钥匙源RewardItem不设置`relicLink`，与蓝钥匙不同，不牺牲基础遗物或Black Star额外遗物。原版烟雾结算会准备部分房间掉落，但`CombatRewardScreen.openCombat(smoked=true)`不开放物品领奖，因此本接口不允许烟雾逃跑领取。调用者还须接上离开奖励、同owner重开、下一房间过期及UI旧手势验证；这些均不由本组件自动完成。

## 独立验证与待接边界

`emerald-elite-oracle.py`只用独立Python整数RandomXS128解释，不导入产品Lua；8组完整随机状态及后续抽样、9组HP舍入结果保存在`emerald-elite-vectors.json`。入口状态是合成的房型分配后状态，**不是完整原版地图生成证据**。源码锁覆盖资格、随机来源、强化时机、四种强化、绿钥匙独立奖励及烟雾领奖边界。

定向命令：`node --test tests/emerald-elite-component.test.mjs`。Lua fixture使用既有单次30秒预算，不扩大预算、不运行完整campaign。真实Map/Run/Nodes接线、通用怪物再生处理、奖励/UI及指针owner、地图恢复、持久历史provider、四职业自然四幕与平台验收都仍待父流程集成。

2026-10-28本片验证记录：先跑缺少模块的真实RED（486ms），再实现并通过八组纯Lua用例。静态审查发现的畸形`act=false`默认值、HP回调缺失误回退Power回调，均另有明确失败断言和RED→GREEN。最终Node三项全部通过，总1.184秒，Lua fixture688ms；独立Python oracle校验八组完整随机状态及九组舍入向量。固定Luacheck 1.2.0对新增模块零诊断，`git diff --check`通过。本片没有运行全量工程检查；新增模块的架构分类由父集成负责，不能把这组组件证据写成最终组合提交或自然/平台通过。
