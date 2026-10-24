# TASK-17.1 · 守卫首领开场选招的随机消费

## 有限生产缺口

基线 `2bf87d6097848f921842dd2cd78958355a34958b` 的 Guardian 已有240生命、30初始模式转换阈值、攻击/防守阶段及排队变形，但 `guardian` 初始化没有消费继承的开场选招随机请求。

本切片仅在该策略初始化时请求一次经 schema 校验的 `rollRange: 100`，随后仍由已有 Guardian 状态机设置 Charge Up 与 Mode Shift。不开辟新随机流，不修改伤害、格挡、阈值、状态、目标或动作周期。

The Guardian 与先前 Cultist/Lagavulin 切片不同：七种后续行动均直接设置下一动作，没有 RollMoveAction。普通伤害、毒伤、火瓶、荆棘和 Twin Slam 导致的模式变化同样不请求 AI 随机数。“Roll Attack”是动作名，不代表抽样调用。本次不将 Guardian 加入死后排队 roll 白名单。

## 固定来源与身份

2026-10-23 UTC 只读核对社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。全部四份来源以 base64 原始字节解码并复算 Git blob 匹配，不依赖工具展示文本的额外换行。版本字段自称 `[V2.3.4] (12-18-2022)` / `2022-12-18`；未经正版 PC JAR/hash 认证，不是官方开源、原作录像或本轮 PC 实测。仅根据调用关系独立实现行为，没有移植、编译或提交来源实现。

| 固定来源 | 方法事实 | Git blob |
| --- | --- | --- |
| [TheGuardian.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/TheGuardian.java) | 无 init 覆盖；getMove 忽略 num；七种行动及 changeState 直接 setMove，不排 RollMoveAction | `fb8e25d4ba5b1c0c0bade62022c4ff6f6d995a99` |
| [AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | init 调用 rollMove；后者请求 aiRng.random(99) | `4784e38e7afff5980736e2b5c718e62a0c838c47` |
| [Random.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java) | int 包装为 nextInt(range+1)，对应0–99闭区间 | `c4b71d5645688f6e764c46c593223eb91a5249bc` |
| [CardCrawlGame.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/CardCrawlGame.java) | 上述版本声明，仅为镜像自述 | `6f15eb15977a40bcb6e95598513a3073310eacd3` |

Guardian 原始 UTF-8 SHA256：`40571fa4c941d70c1814b0c0ff5cffa7d8933e24b49d95f2b531a3dc05598d56`。既有 Guardian 阶段账本使用另一固定来源镜像，其身份和证据边界不被本次替换；本切片只核对并修正漏掉的开场调用。

## 独立输入与回归

新增 `tests/lua/guardian_opening_roll.lua` 14组，均从真实 Combat 或 Run 入口执行，没有替换 EnemyAI 或 Guardian 实现：

- 原作0/99端点映射到本项目1..100包装，两者均消费一次，仍以240生命、0格挡、30模式转换和 Charge Up 开场。
- 开场请求先于实际四卡洗牌；两只 Guardian 各消费一次，独立新战斗也各自消费一次。
- 攻击阶段 Charge/Bash/Vent/Whirlwind 以及防守阶段 Close Up/Roll Attack/Twin Slam 均不追加请求。
- 直接伤害、非致死毒伤、真实火瓶和反伤触发模式转换不追加请求；有队友及末敌反伤死亡均不排新的 roll。
- 只读意图、拒绝出牌和失败出牌回滚不重复消费；保留 HP、格挡、阈值、种子及表身份。
- 真实 Run 的第16层 boss_guardian 入口在十张初始卡洗牌前消费一次；火瓶随后正确跨过模式转换阈值并消耗槽位，不再抽样。

手工核算的项目 LCG 向量（不是原作 RNG 向量）：seed42 → 开场22539 → 四卡洗牌42944 → 26841 → 6182，最终抽牌 UID 为1/4/3/2。单卡、不发生洗牌时开场后 seed22539；两只 Guardian 连续初始化后 seed42944。Spy 保留真实 RNG 的种子副作用，仅在0/99端点例替换返回值。

旧生产代码先运行：14组中8过6败，失败均对应缺少开场请求、初始化顺序或真实 Run 开场调用；修复后14/14通过。新增8项 schema 正反例，旧代码5过3败（缺少必需字段检查、生产配置缺字段、合法字段被视为未知），修复后8过。其余非法字段红例此前被未知字段门禁拦住，不冒称全部先失败。

## 本地验证与剩余关口

- JSON→Lua、UI测试前置产物正常构建；数据校验与修改 JS 语法检查通过。
- 新 schema 加既有 enemy AI、Cultist、Lagavulin 检查共42项通过。
- 完整100个原生 Lua5.4 fixture 通过，包括新14组、既有 Guardian/阶段易伤、Cultist/Lagavulin/队列、卡牌、遗物、节点及UI检查；没有修改旧测试预期。
- 182个未改动的已物化 runtime/data/scripts/Lua/helper 文件与基线 Git blob 逐byte吻合。只有上述 AI 入口、敌人数据和 schema 三个生产文件变动。

没有安装依赖或运行受限的完整 npm check，原生 Lua5.4 不等于 Fengari 或最终 CI。独立评审及当前 SHA Quality 结果由对应 PR 记录；本片没有平台编译、候选导出、官方导入或千星实机证据。

生命、AI、洗牌及部分奖励仍共用项目16位 LCG；原作独立随机流、RandomXS128 生产接线及种子映射尚未对齐。补开场请求会改变本项目后续牌序/队友选招/奖励，不能当作原作种子重放一致。完整动作队列、其余敌人、原作版本真实性及 TASK-17 原数据17层通关/正式结算/平台 AC 均保留，不据本切片宣称整体通过。
