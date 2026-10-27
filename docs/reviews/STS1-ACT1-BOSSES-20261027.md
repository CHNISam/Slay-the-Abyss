# 第一幕剩余 Boss：规则与接线记录

基线：develop `c91f0d22`。PR238 `a4dac772` 已只读核对，未包含本片两个 Boss。新行为独立实现，无第三方程序、美术或音频复制。

## 方法依据与修复

固定参考为 [aeubanks/sts@319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，社区反编译镜像，未认证为 PC 二进制。本地仅供只读核查；下表记录本轮实际方法文件摘要。

| 方法链 | 原版要求与本次实现 |
|---|---|
| `Exordium.initializeBoss` | 按 GUARDIAN → GHOST → SLIME 已见历史优先选择；三种均已见才按 monsterRng 的一个 randomLong 洗牌，未见分支重复同一 Boss 且不消耗 RNG。默认空历史继续 Guardian。 |
| `Hexaghost.<init>/getMove/takeTurn/changeState` | A0 250 HP，开场继承一次 AI roll。Activate 在执行时捕获当前 HP，Divider 每击为 floor(HP/12)+1，共6击；Activate→Divider 为 SetMove 不 roll。其后 Sear6+1Burn、Tackle5×2、Sear、Inflame12Block+2Strength、Tackle、Sear、Inferno2×6，循环重置；后续每回合保留一次 roll。 |
| `BurnIncreaseAction.update` → `Burn.upgrade` | Inferno 六击后，先升级 discard 再 draw 的现有 Burn；不升级 hand/exhaust；随后追加3张新 UID 的 Burn+。之后 Sear 也创建 Burn+。基础/升级伤害2/4。玩家死亡取消尾部；源怪反伤死亡但有同伴时尾部继续，最后一怪胜利时取消。 |
| `SlimeBoss.getMove/takeTurn/damage` | A0 140 HP；Sticky塞3Slimed → Prepare → Slam35，直接 SetMove 且不额外 roll。非致命伤害在 <=maxHP/2 时立即打断为 Split，保留已入队攻击。 |
| `SuicideAction(false)` → `SpawnMonsterAction` | 用分裂执行时剩余 HP 依次创建 SpikeSlime_L(-385,20)、AcidSlime_L(120,-8)；不继承力量/毒/死亡触发，不抽子代 HP，仅各一次开场 AI roll。出生回合不行动，再分裂复用既有大型软泥策略；活子代全部死亡才发一次 Boss 奖励。 |

原生目录中的旧 Burn 使用 `endTurnDamage`，完整职业目录使用 `burnDamage`；新 Boss 注册在私有 Combat 目录兼容两种 ABI，调用者数据保持不变。普通升级必须保留 PR238 已修的状态/诅咒排除守卫，Burn+ 仅由对应原版方法升级生成，不让 Forge 或 Armaments 升级状态牌。

## 验证与边界

共享文件由主 session 单独写入。独立树只提交新 Boss 模块与测试；待接线涉及 EnemyAI 钩子、Combat 私有注册与异种分裂、现有临时弃牌动作的 upgraded 标志、Boss queue 与 Run room 路由，以及 `abyss_act1_bosses: core` 架构分类。隔离 `work/integration` 副本按同一补丁测试，不整文件覆盖主线。

- 未接线的 c91 原入口真实红例：已见 GUARDIAN 的独立历史 fixture 应选择 Hexaghost，实际仍是 The Guardian。
- 新增21组定向回归：真实 `Run.startRoomCombat`、`Combat.endTurn`、原版分段伤害、Divider分段边界、全循环、Burn目标牌堆/升级/UID、死亡尾部、两级分裂、RNG计数、奖励仅一次及输入数据隔离。
- 原 Guardian24组、opening14组、Spike split18组、Acid split15组、encounter_runtime10组均在隔离补丁上按原30秒runner通过，无删断言、缩池、抬超时或重抽。新模块和新Lua夹具语法解析通过。
- 正式 source room 以显式标记的已见历史 fixture 验证；这证明对应正常房间命令接线，**不证明玩家已经自然解锁**。Run.new 的持久化历史入口和平台能力仍由主 session 核实；不调试注入伪造自然解锁。
- 没有新 GIL、官方导入、实机画面/音效、平台完整四职业自然路径或完整 Quality 证据。主题图标及最终平台呈现由主 session 最小接线并分别验收。三四幕其余 Boss/精英不包含在本片完成声明中。

## 本轮参考文件 SHA256

| 路径 | SHA256 |
|---|---|
| `monsters/exordium/Hexaghost.java` | `768a74579c61c740e049f5c1353e59406add5b5d4b14da986b72837e97354ac5` |
| `monsters/exordium/SlimeBoss.java` | `bac1c11c710cf2d2cdd61ad5516f2eca2c932a0bc7f25d2593f0aba1afd89b21` |
| `actions/unique/BurnIncreaseAction.java` | `db18cb114e26870ae0a2f59b8e7e2551cb3c929bbe4edeafa3b72b5f3360ef04` |
| `cards/status/Burn.java` | `a065c155ce2efb9b7a968bfe55e68d5290d02ddabcf6becd4ca43db80a30dc12` |
| `dungeons/Exordium.java` | `93808b9da69b76da6b8f0471cc3533fa113fa28298939bbc48eb55566a976c08` |
| `actions/common/SpawnMonsterAction.java` | `731309c39e9d0143f187cc4c2b391cca1983d915aa53e84b95e4ec6907fedb4a` |
| `actions/common/SuicideAction.java` | `66dbf76651c6499205c340d7f9304b031b19fd69cfd596475af209b21aeabd04` |
