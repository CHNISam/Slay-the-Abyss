# M7 Actor presence 职责解环

TASK-74.19 的独立实现切片，基于实际 `origin/develop@2ad07111e3d5b5cb52b4229860b3b780941e29a9`。继续主控分配的既有 In Progress 任务，不重复认领，不推进任务整体 AC。已核查开放 PR #540–#545 及并行 Act1Events 切片，五个产品路径未重叠；共享配置、来源回放与库存由主控串行整合。

## 改动与边界

`abyss_actor_presence` 持有原 Actor 的两个只读谓词 `isActive`、`isPresent`，函数体逐字保留。Act2 AI 决策、Act2 召唤规划和 Silent 弃牌退款只读取 presence，不再为了查询加载 Actor 的伤害/状态执行链。新模块无依赖，不转移 Combat 队列、RNG、事务或状态提交 owner。

Actor 保留原调用入口，用两个固定槽的动态门面读写同一组函数；保留替换、nil/false、callable table、保存旧函数、同次遍历期间替换以及无关字段 rawset 的行为。`isPresent` 保留半死/复活字段的原始 truthy 值，不归一化成布尔值。Actor 仍为996物理行。`rawget`/`pairs`/`rawset` 对这两个方法槽及 Actor 模块 metatable 的反射形态改变，不在等价声明内；仓库内未发现依赖该反射的消费者。普通调用与所有数据状态图不受这一例外豁免。

新增 `actor-presence-independence` 架构边界覆盖叶模块和三个消费者。门禁与测试仍遍历完整 AST require 图，包括函数内/已审核 deferred 边；没有删边、增加 deferred 豁免或改量尺。Presence 完整文件、Actor 两个桥及其嵌套函数执行现有 CC≤15 门槛。

## 同源实测

使用仓库原 `check-engineering.mjs`、固定 Luacheck 1.2.0 与 AST/W561 完整对应测量；[证据](../evidence/m7-actor-presence-20261107.json)保留全部 before/after require 位置、源码摘要、完整 SCC 成员及边索引、热点与本切片函数测量。

| 指标 | before | after |
| --- | ---: | ---: |
| Lua 模块 | 333 | 334 |
| 完整函数/主块测量 | 5386/5386 | 5389/5389 |
| 所有 require 位置 | 1920 | 1921 |
| Combat SCC 成员 / 内部位置 / 唯一依赖对 | 81 / 623 / 400 | 78 / 608 / 391 |
| Session SCC 成员 / 内部位置 / 唯一依赖对 | 15 / 62 / 41 | 15 / 62 / 41 |
| CC>15 / CC>30 / 最大 CC | 237 / 58 / 75 | 237 / 58 / 75 |
| 历史静态警告 | 14 | 14 |

退出 Combat SCC 的成员恰为 `abyss_act2_ai_moves`、`abyss_act2_summons`、`abyss_silent_discard_cards`。即时加载图仍无环。新增叶的两个谓词 CC5/7、桥 CC3/3；未声称全库高 CC 下降，本切片 CC>30 降幅为0。新测量共1774个受治理职责位置通过；未刷新旧静态警告、历史质量基线或硬门槛。

## 行为与来源证据

- 真实旧/新 VM 分别载入完整冻结333模块源码和当前真实源码；旧侧禁止未知手写模块回落到当前源码，同一轮生成输入摘要一致。复用不可变 `colorless-catalog-before-2ad07111.json.gz`，名称仅表示先前归档来源，不引入 Colorless 产品改动。
- `actor_presence_contract`、原 `act2_party_snapshot`、原 `silent_discard_build` 共48个完整对象图检查点，每侧16,665,763字节一致；包含所有可达字段、别名、metatable、RNG、返回/错误，不以挑选字段代替完整图。
- 自有契约覆盖48组合谓词输入、短路读序、抛出对象身份、动态槽替换、真实 Mystic 遍历、召唤规划/RNG与中途失败、真实 Gremlin Leader 战斗召唤、死亡玩家退款拒绝与敌方 presence 错误先于能量写入。
- 四个冷启动根均不加载 Actor/Combat/CardActions，包含先加载 Presence 并替换、再加载 Actor 的次序。八个真实源码即时/deferred 反向依赖注入被架构边界拒绝；三个有效 Lua 语义变异被指定行为断言杀死。CC16主块/桥/嵌套函数负例被拒绝。
- 六 owner 精确来源桥每次重新验证全部 raw 源码；原始、外来、半片和新增 witness 输入不能授权读文件。配置仅允许输入侧 JSON 空白布局等价，链接文件仍为精确 LF/CRLF 字节。现有 M7→Relic→历史链使用同一来源合同，不修改原历史 guards/oracle/计数。
- 历史副本退休只移除已审核 Presence 新叶；准备与删除时均重验内容、目标真实路径和 live 隔离，旧 Catalog 的验证顺序与保护保留。四个真实 detached 来源副本显式带齐新的来源文件，不依赖工作树 fallback。

## 验证记录与限制

最终 `tests/actor-presence.test.mjs` 12/12通过，零跳过，完整单文件 wall time 31,052.666793ms。旧 Actor 生命周期/复杂度/PowerRules 合计10/10通过；原 `act2_enemies.lua` 34/34通过。语法、工程门禁、指引、Backlog/doctor 与 diff 空白检查通过。新来源10/10、六个直接受影响旧来源文件42/42、现有CI完整库存8/8通过。来源日志保留在同目录 JSON；首来源组合52项中51通过，唯一新增测试错误地以不存在的schemaVersion构造token变异，改用实际layers/Actor presence键后新来源10项重跑全过。旧来源42项不重复运行。

首次行为测试6/12通过、6失败是新增 Mystic 测试误期望：给定 last=buff、previous=nil、仅一个缺10HP的活跃队友，原实现应选择 buff，测试错误写成 attack。修正自有期望后，受影响10项全部通过，再执行最终完整12项通过。失败日志与耗时保留；未修改产品来迎合误期望。原测试、生成输入和历史 oracle 均未删改。

新增完整行为文件真实耗时高于原 unknownJsMs=10000；本地成功测量只提供31053ms规划下限，不是 Hosted CI 测量。主控整合应按既有 planning floor 机制处理，并保持历史观测/预算不变。当前没有触发 Full，没有打开用户设备、官方导入或实机验收。独立只读深审 worktree PASS、未解决项为空，另独立验证7776组谓词/读取顺序探针及333个冻结源码Git blob；独审收据绑定提交后精确 HEAD/BASE，放在提交外避免自引用；合并仍须当前组合的独审与原全部门禁，不能借本地窄测冒充已合并。

## 独立交付成本接线

原切片 `9624804b44d4773a40c557f02e0b13b3a31f2497` 的生产、行为测试与历史证据不变。交付提交 `12078cb49d8790b87efaea936fac021a9376dca7` 已把上述完整成功12/12本机观测接入既有planning floor：31,053ms。新收据 [actor-presence-planning-floor-20261107.json](../evidence/actor-presence-planning-floor-20261107.json) 冻结完整日志、输入与来源，明确不是Hosted测量。原9个floor及其他timings字段逐字保留，不采截尾、失败或部分文件耗时。

独立当前库存748 JS/1403 Lua，17/13布局，含原60秒余量的规划上限Windows1,714,151ms、POSIX1,194,287ms；离原30/20分钟目标分别85,849/5,713ms。新增来源/库存/真实拒绝合同32/32通过，不重跑原行为大测或Full。此规划不能证明实际CI完成；#545已观察到旧20/30分钟job边界取消，其他在途共享CI修复尚未进入本基线，不能借其未合成果担保本片。

与#545的Colorless/Capability组合在独立本地树准备，两个精确config来源epoch须验证所有owner并保留原证据；不覆盖#545或把未合降幅计入本片。正式提交仍须最终HEAD独审、当前CI和仓库原生合并门禁。
