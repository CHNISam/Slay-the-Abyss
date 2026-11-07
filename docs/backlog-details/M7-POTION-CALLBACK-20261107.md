# M7 药水使用回调职责解环

接续 TASK-74.19，基于真实 `origin/develop@2ad07111e3d5b5cb52b4229860b3b780941e29a9`。开始前复核当前 Sprint、任务池、全部开放 PR #540–#547 与活动切片。三条产品路径未与在途 Power/Shop、Session奖励、Watcher、Inventory、Colorless/Capability、Act1、Defect、Actor presence、永久健康或 RunCardCatalog 重叠；既有任务保持 In Progress/Furinya，未重复领取或勾选未完成 AC。Actor 待批准上传未触碰。

## 实际职责与边界

新 `abyss_relic_potion_hooks` 只承担普通药水使用后的遗物回调。Toy Ornithopter 的拥有判断、有效角色检查、战斗 heal5 入队与非战斗直接治疗从混合 Session Hooks 移出。独立模块仍动态读取共享 Queries.owns、Actor.isActive 及 Reactions.enqueue，不缓存函数快照。

原 Hooks 的 onUsePotion 通过固定共享槽提供原 API；双向赋值、nil/false、callable table、保存函数身份与无关字段继续工作。`abyss_run_potion_candidate` 仅更换导入目标，原资格检查、候选副本、effect→hook→释放槽→afterPotionActions→drain、失败回滚与上层提交归属均未改变。

非战斗治疗保留原 `math.min(maxHp,hp+5)` 和 Bloom 阻断，不复用 Run.heal，不加入 Magic Flower 或战斗同步。Hooks 原私有 healRun 仍服务 Meal Ticket，两者暂保留相同的短规则而不引入额外耦合。

对 Hooks.onUsePotion 的 rawget/rawset/pairs 及模块 metatable 反射形态不在等价声明内；现有生产调用均为普通字段调用。没有新增通用服务定位器、注册器、install fallback 或运行时 owner 状态。迁移函数体可能改变原生 Lua 诊断的源码路径/行号，不声明所有 traceback 字节恒等；本片已测错误对象与 Candidate 非可调用槽诊断不作通配规范化。

## 完整测量

[机器证据](../evidence/m7-potion-callback-20261107.json)保留全体模块摘要、全部 require 位置、SCC 成员/内部边索引及原 Luacheck 测量。没有删除图边、过滤 deferred require、刷新历史阈值或新增 deferred 豁免。

| 指标 | before | after |
| --- | ---: | ---: |
| 模块 / 完整测量 | 333 / 5386 | 334 / 5388 |
| 全部 require 位置 | 1920 | 1923 |
| Combat SCC：成员 / 内部位置 / 唯一对 | 81 / 623 / 400 | 81 / 623 / 400 |
| Session SCC：成员 / 内部位置 / 唯一对 | 15 / 62 / 41 | 14 / 60 / 39 |
| CC>15 / CC>30 / 最大 CC | 237 / 58 / 75 | 237 / 58 / 75 |
| 历史静态警告 | 14 | 14 |

只有 Candidate 退出 Session SCC，最大环与全库高 CC 没有下降。新模块17行、callback CC4保持；Hooks154→148行，固定槽分支4→5；Candidate121行与原函数复杂度保持。全部1772个受管测量通过。新模块完整函数/初始化块 CC≤15、行数≤1000；原 Hooks 两个门面函数仍受原 CC15 门槛。

`potion-callback-session-independence` 直接禁止新回调和 Candidate 回导 Session 命令/房间 owner，真实 AST 闭包与负例另覆盖即时/延迟边。新模块属于 core；依赖 Combat基础规则合理，不将其称为零依赖叶子。

## 来源与验证

四 owner 精确来源桥覆盖两个旧 Lua、新 callback witness 和完整架构配置。旧333模块归档直接复用原 Colorless 完整语料字节，逐文件 Git blob/hash 均可追溯2ad07111；不手写旧侧，不缓存场景结果。recognized projection 每次鲜读全部 raw owner，old/foreign/partial/witness 不授权 I/O；仅输入侧 JSON token 等价布局允许格式变化。四个 detached copy manifest 补完整只读依赖，旧历史叶退休仍保持原错误顺序和实时路径/内容校验。

新行为单文件10/10通过；完整333原始源码独立VM与当前VM的31检查点逐项一致，每侧全字段图23,319,377字节。真实状态、RNG、别名、metatable、返回元组、错误与事务回滚保持；三个可解析语义退化由实际Lua断言检出。三个冷加载顺序各自执行全部槽/身份断言及非空完整图，不重复主行为矩阵。来源54/54、库存8/8通过。选定旧回归、顶层raw fixture与所有实际命令结果见机器证据。

测试首轮两个重复全fixture的冷VM被SIGKILL；第二轮512MiB主VM出现真实heap OOM。保留失败，改为小冷VM、JS只保留definition ID校验而将完整字段流式写盘、require时编译已验证的完整源码。未改任何产品断言或完整图内容；最终使用原始1024MiB/30s上限。完整成功新JS wall time26,661.777321ms，对应本地floor候选26662ms。本片不改既有 Hosted 观测或预算，不触发重复 Full；本地成功耗时只供组合发布的 planning floor，不能冒充 Hosted CI。独审在提交外绑定精确 HEAD/BASE，组合交付及真正合入仍需原全部门禁。本片不声明已合并、M7完成、官方导入、真实 ready 或设备实测。
