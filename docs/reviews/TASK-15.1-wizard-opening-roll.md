# TASK-15.1 · 蓄能小魔开场选招抽样

## 有限问题与生产修复

基线 `329e8139cfaab6a69dda47954c207e76e0240886` 的 Wizard Gremlin（本项目 `wizard_gremlin` / 蓄能小魔）在开场直接进入 Charge，漏掉继承初始化本应消费的一次主选招抽样。固定动作不意味着没有随机调用。

生产修复仅增加 `charge_then_attack` 初始化时的一次随机请求，范围由数据中的 `rollRange: 100` 提供；schema 验证该字段为 1–65536 的整数。实际生产值 100 对应原来源 `random(99)` 的闭区间 0–99，本项目随机接口返回 1–100。结果不参与选招，仍是 Charge，初始蓄能仍为 1。开场生命21–25、攻击25、前两次蓄能及之后三次蓄能的节奏全部保持。

后续 `advance`、死亡处理和 `queuedRoll` 白名单不变。原来源的 Charge/Attack 转换是直接 SetMove 或排队 SetMoveAction，不是 RollMoveAction，所以不能把这次修复扩成每回合抽样。AI 专用副作用也不进入意图预览或被拒绝的出牌请求。

## 固定来源及认证边界

2026-10-23 UTC 只读核对社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。其版本字段声明 `[V2.3.4] (12-18-2022)` / `2022-12-18`；未经正版 PC JAR/hash 认证，不是官方开源或本轮原作观察。不将镜像代码加入游戏或编译运行。

方法链及独立预期：

- AbstractMonster.init 调用 rollMove；rollMove 请求 aiRng.random(99)，再调用 getMove。
- Random.random(int) 增加计数并调用底层 nextInt(range + 1)，因此上述请求覆盖 0–99。
- GremlinWizard.getMove 无视输入，设置 Charge；因此 0 和 99 两端均选 Charge，但都必须消费开场调用。
- GremlinWizard.takeTurn 的 Charge 和 Attack 分支不调用 RollMoveAction。非逃跑 A0 下，实际伤害轨迹为 0、0、25、0、0、0、25、0、0、0、25。

四份原始 UTF-8 内容均按 Git blob 算法重算并与读取返回 SHA 一致：

| 固定文件 | Git blob SHA | UTF-8 SHA256 |
| --- | --- | --- |
| [monsters/exordium/GremlinWizard.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/exordium/GremlinWizard.java) | `21c44b5f046fe73de8fdd8d0c2a8456d41b07ed2` | `2ccdf025b6eb531596e6f1124ba0fadfbe9287de9640ec3410c77c22df186ffa` |
| [monsters/AbstractMonster.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/monsters/AbstractMonster.java) | `4784e38e7afff5980736e2b5c718e62a0c838c47` | `f95baba14b00bffeb6a93e9fcf04cedad2a42a803c4b4342c1e017535acc601f` |
| [random/Random.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/random/Random.java) | `c4b71d5645688f6e764c46c593223eb91a5249bc` | `476be7d8af2080b6b52f6cecc78c35f01904c18dbacc7ea795a361e600f05172` |
| [core/CardCrawlGame.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/CardCrawlGame.java) | `6f15eb15977a40bcb6e95598513a3073310eacd3` | `ad06c2d2f13ad66843b5304b6c05fb6019ddc7e92359e95302f35ee540317846` |

## 红绿与回归

新增 `tests/lua/wizard_opening_roll.lua` 12组真实 Combat/Run 入口测试，先在旧生产实现观察12组全失败，再在修复后全部通过。首次草稿的 Run 夹具错误使用第3层，被现有楼层检查正确拒绝；在任何生产修改前改为实际合法第5层，重新保存了12组全部因漏抽样而失败的红例。

覆盖开场0/99、真实seed前进、双Wizard、HP→AI→洗牌的项目调用位置、十一回合不重复roll、Fat混编保持各自策略、只读意图、拒绝命令、毒死、同伴存活时反伤死、末敌反伤死和真实Run遭遇构造。原始Wizard9组及其他既有AI/UI用例随全套保留。

当前本地证据：

- 正常 data 构建与内容验证通过，JavaScript语法检查通过。
- Wizard schema 29组通过，包含缺失、0、负数、分数、过大及字符串范围拒绝。
- 可用的定向data/schema/构建保护JS检查203组全部通过。
- 原生Lua5.4全97个测试文件通过，含新增12组。首次自备执行器未给 battle_ui.lua 提供标准 ABYSS_TEST_LAYOUT 前置夹具，96/97；按项目runner相同的 battleLayout/toLua 方式补齐外部前置文件后，完整重跑97/97，无生产或旧测试修改。
- 最初扩大到209个JS测试时，4项依赖Fengari的既有构建/runner测试因本隔离目录没有 `fengari-node-cli` 失败，其余205项通过。没有安装依赖、绕过拒绝或把这些失败写成全量通过。之后203项是不依赖该运行时的独立子集，不替代完整 `npm run check`。

当前提交的正式Quality和独立评审以最终PR为准。本地未运行完整npm check、Fengari或平台构建；未导出候选、官方导入或千星实机。

## 保留的缺口

本项目目前把生命、AI、洗牌及部分后续奖励共用LCG seed；原作使用独立随机流。因此补一次AI请求会改变本项目随后的洗牌和奖励轨迹，但不改变开场先抽出的Wizard生命。这是当前共享随机实现下的预期副作用，不代表原版完整种子重放或流初始化已经对齐。

单Wizard、单卡、项目seed42的手算调用序列为HP后22539、AI后42944；四卡夹具继续请求4/3/2，结束seed50871，抽牌UID为2/3/4/1。这些是项目回归向量，不是原版PC oracle。双敌先全部HP再逐个AI的构造位置只用于保护现有项目接口，没有把该跨流排序认证为原作。

逃跑/领袖通知、原版遭遇编组、其它敌人的遗漏、完整RNG、官方版本真实性及全部平台验收仍保留。父任务TASK-15、M1及UI门禁不能由这一个切片关闭。
