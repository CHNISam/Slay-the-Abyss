# 无色卡牌注册与战斗执行分离

基线：develop `2ad07111e3d5b5cb52b4229860b3b780941e29a9`。本片接续 TASK-74.19，不重复认领、不修改负责人/状态/AC。开始时核对开放 #540–#543 及所有本地工作树，避开 Power/Shop、Session 奖励、Watcher/Inventory 和另一代理的 CardCapability。

## 实际职责

- 新 `abyss_colorless_catalog` 唯一持有 39 张卡、状态/图标/文案、池顺序及注册逻辑，只依赖 Copy。原静态数据与描述语义保留。
- `abyss_combat_catalog` 只消费该目录的注册能力，不再通过 Colorless 执行器载入 Actor、CardActions 和战斗生命周期。完整 AST 闭包恰为 CombatCatalog、ColorlessCatalog、Copy，含延迟边。
- 原 `abyss_colorless_cards` 保留战斗动作和状态钩子。三个公开静态方法经固定字段桥指向唯一 owner，普通字段读取/写入、nil/false/函数替换、saved alias 和动态 description 调用保持。没有通用服务注册或隐藏 require。
- 注册分为完整性检查、容器所有权、卡/池写入、状态写入。默认路径仅分离原有指定容器，owned 路径原地追加；旧定义别名、新定义图复制、先写卡/池再生成状态及异常时部分写入次序保留。Combat/Run 的战斗、事务、随机、事件和队列 owner 未迁移。
- 私有纯数据构造器 `e` 在注册与执行各自保留，不因共享几行代码反向导入执行器。

与既有固定能力桥一致，不宣称 facade 的 rawget/pairs/元表反射形状等价；实际业务调用仍为普通公开字段。原始 Lua 运行时诊断中的源码路径/行号会随职责移动，显式错误对象、返回与部分状态通过差分验证。

## 同算法新鲜测量

完整手写 Lua：333→334 模块，5386→5394 函数/初始化块，全部 AST/W561 对齐。总 require 位置1920→1921；增加唯一职责依赖，不隐藏原延迟引用。

| 指标 | 基线 | 本片 |
|---|---:|---:|
| Combat SCC 成员 | 81 | 80 |
| Combat 环内引用位置 / 唯一模块对 | 623 / 400 | 618 / 397 |
| Session SCC 成员 / 内部位置 / 对 | 15 / 62 / 41 | 15 / 62 / 41 |
| 全库 CC>15 | 237 | 236 |
| 全库 CC>30 | 58 | 58 |
| 全库最大 CC | 75 | 75 |

只有 CombatCatalog 退出 SCC。原 withCards CC23 拆成真实职责，所有新目录函数/匿名嵌套/初始化块最高14，双桥及目录全部接原CC15硬门禁；全库1784项受治理职责通过。14个旧静态告警保持，无新增豁免。即时图仍无环。

残余 Combat80 仍涵盖 Actor、卡执行、敌人/Power 生命周期，Session15仍混有永久命令/奖励准备，未称已验收低风险。#541 的 Power 降幅、#542 的 Session 降幅以及 #543 的 CC 降幅均不计入本片。

## 行为与来源证据

冻结 base 的全部333个完整手写Lua源，每个含LF SHA256及实际Git blob，before VM 不允许未知手写模块回退到当前目录；双方使用同一生成数据摘要。每侧均在独立30秒/1GiB进程运行，完整图逐次重新读所有可达字段与别名，未裁剪状态或缓存场景结果。

- 注册/所有权/接口/异常合同：9检查点，每侧439,316字节。
- 原 colorless_cards：20检查点，每侧7,282,037字节。
- 原 colorless_powers：29检查点，每侧10,356,693字节。
- 合计58检查点，每侧18,078,046字节逐字对应；含完整状态、事件、队列、随机流、别名与返回/异常对象。
- 新冷加载、直接/延迟边拒绝、CC16/main/nested拒绝，以及 owned容器、池顺序、动态描述三个真实可解析语义负控通过。
- 三个卡牌字面量迁移后，旧 Metamorphosis/SecretTechnique/Violence mutator 仅把 owner 改到真实新模块。原锚、变异、具名断言保留；DeepBreath/Impatience仍改执行器。39个固定源身份及负控读取真实新定义位置。

四owner完整来源epoch：两个旧Lua、新目录witness、完整架构配置。每次命中重新读全部实际owner；旧/外来/部分源码和witness不授权读取，输入配置只保留原严格token的排版等价，linked文件仍要求完整规范化字节。接原 M7→Relic/Core/UI 历史链与 Round3 的source、linked reader和历史副本退休入口，不改旧archive、guard、原读次数或oracle。

新目录退休只在既有历史materializer调用，源/目标实际路径与完整字节在准备和删除时再验；无新目录时不改变原Round3错误顺序。原目录退休仍绑定旧原始身份。

## 验证记录与失败保留

- 最终行为与旧5变异：14/14，22,468ms，`build/colorless-behavior-final.log`。
- 来源、库存及四类隔离来源、Round3：52/52，18,745ms，`build/colorless-source-third.log`。
- 旧 Colorless 动作/来源/历史退休受影响批：初次26/30通过，剩余双桥必需条目及3个迁移字面量锚已点修。双桥原复杂度合同另跑1/1；3锚在上面旧5变异中全部通过。独审独立复跑双桥合同亦通过。
- 原 M7、Relic、Colorless身份、Round3初批26/27通过，唯一退休错误顺序已在最终52项原断言通过。无重复大回放。
- 初始工程采集发现旧copy导入迁移后未用，已移除；最终共享采集、静态/架构、JavaScript语法、指引、Backlog范围/doctor、diff检查通过。
- 首次新来源批的清单排序、将允许的配置换行误作负例、旧退休错误顺序失败全部保留，分别修正清单顺序、真正外来输入和absent-leaf不介入；不删旧断言、不抬预算。

CI库存只新增两份JS和一份Lua到post-placement清单。它们仍属于当前Full，以原unknown成本安排；旧观测、floors、17/13布局、预算及worker不改。新专项本地22秒是本机观测，不当成托管/Linux证据。

完整同源图、所有模块摘要与检查点收据见 `docs/evidence/m7-colorless-catalog-20261107.json`。独审已完成实现/来源/实际Git档核对及窄动态探针，最终exact HEAD记录独立保存。本地未重复Full；本片尚未提交PR/合并，没有官方导入、ready、实机或发布证据。共享配置/库存/来源epoch与先合PR整合时须取并集并重新绑定完整组合，不覆盖在途工作。
