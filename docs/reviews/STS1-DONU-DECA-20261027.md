# Donu/Deca 双 Boss 与新 Boss 意图入口

基线：develop `c91f0d22`，首批第一幕Boss独立提交 `457030c`；PR238 `a4dac772` 的第三幕普通怪与事件保持复用。本片不重写其第三幕模块，新增 `abyss_act3_bosses` 接入同一 Combat/EnemyAI/Run 的最小边界。

固定源码为 [aeubanks/sts@319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，社区反编译镜像，未认证 PC 二进制。只读核对真实方法，自行实现行为，不复制第三方程序、图片或音频。

| 方法依据 | 当前差异与实现 |
|---|---|
| `MonsterHelper.getEncounter("Donu and Deca")` | PR238 对应 Boss 不可用；新增正式来源映射，严格 Deca→Donu 构造与行动顺序。按现有 Acts 的第50层Boss进入，第51层仍为 ending 节点。 |
| `Deca.<init>/usePreBattleAction/getMove/takeTurn` | A0 250 HP、2Artifact，先10×2攻击后塞2Dazed；次轮给全部存活敌人固定16Block，持续交替。复用 block 效果，新增 all_allies 目标仅允许 Deca；不按敏捷/脆弱改这16点格挡。 |
| `Donu.<init>/usePreBattleAction/getMove/takeTurn` | A0 250 HP、2Artifact，先给全体敌人3Strength；次轮10×2攻击，交替。复用既有 enemyStrengthAll，只新增Donu资格，保留其他来源限制。3Artifact是A19，不能混入A0。 |
| 两者 `die` → `areMonstersBasicallyDead` | 不新增独立胜利路径；复用组生命判断。仅第一只死亡仍战斗，最后一只死亡才发一次Boss奖励；不将它们各算一次胜利。 |
| 继承 `init/rollMove` + 每次 `takeTurn` 末尾 `RollMoveAction` | 两只各消费一个开场roll；每个存活回合各一个roll。Deca反伤死亡但Donu存活时保留排队Dazed与roll；末怪胜利或玩家死亡时按现有动作清理规则取消。 |

附带必要的共用意图修复：SlimeBoss 异种子代不能读取单一 splitEnemy 字段导致 nil；同时显示两种子代与分裂时HP语义。UNKNOWN 有明确标签；Hex Inferno 的细节补齐两牌堆升级及3张Burn+，后续Sear的Burn+可见；Deca16Block明确为全体。这些只是共享UI最小接线，不修改卡面、布局、主题方向或引入美术占位假冒。

验证：新增14组 Donu/Deca定向，真实 `Run.startRoomCombat` + `Combat.endTurn`，包括初始数值、首轮顺序、四回合精确伤害、固定Block、Artifact耗尽、同伴死亡、死亡尾部、随机计数、奖励一次与数据隔离。另有真实生成战斗控件测试：异种分裂提示→结束回合→两种子代显示→点击新子代实际扣6HP，并覆盖Unknown/Burn升级/全体Block意图。均按原30秒runner在隔离接线组合通过；无删断言、缩池、升超时或重抽。c91正式第三幕Boss入口的真实红例为 `act_content_unavailable`，保留日志。

主session单独修改共享文件，应用相应EnemyAI/Combat/Effects/Run resolver、架构分类与意图视图补丁；本树仅提交独立模块/测试/证据。既有PR238已完成章节范围检查，实际整合仅替换第三幕Boss resolver，不应用本地c91测试桥覆盖整段Run。

本片未证明三幕自然连续到达、真实已见历史持久化、完整钥匙/第四幕、同候选GIL、官方导入、实机或完整Quality。Awakened One、Time Eater与第三幕精英仍是具体剩余缺口，不因双Boss已经实现而称第三幕完成。

| 本轮只读文件 | SHA256 |
|---|---|
| `monsters/beyond/Donu.java` | `59a461be4012be96ac4e53c31e9d4172d101b26992087e10369543ed4c06438b` |
| `monsters/beyond/Deca.java` | `5bf2f1d942f2c08d985c0212f9139d56ed8ad1a105f1fc510c4e91be8a5ae210` |
| `helpers/MonsterHelper.java` | `e6a60cdfa7af881d5f128a9532664ea33f32e71239cda49f3983fceac95a10e1` |
| `actions/common/SpawnMonsterAction.java` | `731309c39e9d0143f187cc4c2b391cca1983d915aa53e84b95e4ec6907fedb4a` |
