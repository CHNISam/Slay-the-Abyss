# Chaos 目标预排与遗物共享随机流独立证据

基线为已合并 develop `b4f88a1`；工作树 `/workspace/m3-chaos-shared-rng`，分支 `feat/m3-chaos-shared-rng`。状态 `TEST_ADDED`：未发现生产差异，未改生产 Lua、旧 golden、概率、池、Backlog、CI预算或远端。Backlog CLI 在该环境不可用，未手改任务。此次不触碰 PR437 或旧工作树。

## 固定来源与模型

读取 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 公开镜像的 DistilledChaosPotion、PlayTopCardAction、NewQueueCardAction、UseCardAction、MonsterGroup、AbstractDungeon、MummifiedHand、StrangeSpoon、DeadBranch，以及 Inflame/Impervious/Strike_Red。12份原始文件 SHA256 入新 fixture；方法体不入仓。这是固定镜像源码核对，不是原版 PC 二进制认证。

原版 Chaos 在 use 中先构造全部3个 PlayTopCardAction 的活敌目标，各消费 cardRandomRng；随后实际自动出牌触发干瘪之手、出牌消耗处置的勺子布尔，以及未被勺子改为弃牌时的树枝身份抽样。树枝遍历完整 common→uncommon→rare 原池并排除 HEALING。

新 `sts1_chaos_shared_chain.py` 复用独立 Python XS128 `Stream`，只读冻结原版注册与池。预期不调用生产 clone、生产采样器、本地牌定义或生产函数。固定种子 `0/1/2`，完整70牌序列、每次 bound/返回值/两个64位 word 与 counter 的前后状态都入表。种子1的勺子改弃牌；种子0/2真实消耗并生成树枝牌；种子2使第三目标与干瘪之手的抽样不同，避免相同 bound 偶然掩盖消费顺序。

生成器与全部输入保存原始字节 SHA，来源键用 `relative_to(...).as_posix()`。精确 LF 属性、PureWindowsPath/PurePosixPath 回归及真实 Git CRLF clone 一并覆盖；未固定对照文件必须确实转 CRLF，认证字节必须不变，原 `--check` 必须成功。

## 公开 Run 链与边界

先用公开移除/取得命令构造合法7张永久牌组与三件遗物、Chaos及Elixir。实际进入 `medium_slimes` 双敌显式 ID 开发战斗；仅将已经生成的真实战斗牌实例重排为受控手牌/抽牌堆，不伪造 UID 或效果。初始手牌 Defend/Bash/Anger/Whirlwind，自动出牌顺序 Inflame→Impervious→Strike。

- 真实公开用瓶执行全部效果。只观察 `Combat.autoplayTop` 并继续调用原函数，核对每个目标及三次入口的完整 cardRandomRng 都已到独立 `afterTargets`；每张实际 play 事件保留对应预排目标。每次随机 wrapper 的完整轨迹与独立表逐项比较。
- 干瘪之手仅选择仍有正费用的 Defend/Bash，排除0费与X费。永久/本回合成本结果与实际身份核对；Inflame真实力量2、Impervious真实格挡30、自动牌不耗能量；Strike在独立第三目标上造成6+2伤害，另一敌不变。
- 勺子的真实弃牌/消耗目的地、树枝新战斗UID和源身份、全队列排空均有断言；永久牌组与其它战斗/永久随机 owner不变。
- 在 Chaos 前真实使用 Elixir 并完成空选择，取得一个真正已完成的旧 token且不消费随机。Chaos 后重复该 token、已消费的瓶位和已处置自动牌 UID，均拒绝且完整 Run及共享流不变。

这是受控公开命令链，不是自然取得、正式房间 seed传播、原版 PC帧执行或官方设备证据；不外推所有153遗物或所有随机消费者。能力标记 `TEST_ADDED`，不把新增测试或变异当作生产 RED。

## 精确负变异与预算

只在临时模块副本中分别删去一次最终目标预排抽样和一次实际出牌勺子布尔；每个消费位置都先要求源码唯一匹配。两个变异都必须在 `every Chaos shared stream draw` 的新断言处被拒，不能用任意 Lua报错冒充 kill。生产文件不被写入。

保留 JS整入口10秒、Lua调用30秒预算；三个正向种子各有独立薄JS入口，两个变异各独立入口，元数据/路径/CRLF另一个入口，共6个文件8个测试。最终逐入口标准 `node --test tests/<entry>` 均通过：

| 入口 | 实际进程时间 |
| --- | ---: |
| chaos-shared-chain.test.mjs（3项元数据） | 256ms |
| chaos-shared-chain-seed-0.test.mjs | 6833ms |
| chaos-shared-chain-seed-1.test.mjs | 7028ms |
| chaos-shared-chain-seed-2.test.mjs | 7455ms |
| chaos-shared-chain-preplan-mutation.test.mjs | 1703ms |
| chaos-shared-chain-spoon-mutation.test.mjs | 1739ms |

逐入口日志在 `/workspace/cloud-reports/m3-chaos-shared-chain*.test.mjs.log`。额外执行 `git diff --check`、JS语法和Python编译；未重跑其它全套。最初合在单文件的22秒入口已拆分，不通过修改预算解决。
