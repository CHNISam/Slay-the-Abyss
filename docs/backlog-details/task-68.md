# 工程质量修复

范围为用户2026-10-26列出的CI、测试效率、四个大模块、延迟依赖、历史告警和证据管理。冻结对照为develop `45ba918`。没有进入游戏、占用键鼠、改变关卡内容或重写仓库。

## 失败依据和调度

- Quality655（40269018975）：Windows在04:45:23Z记录Kernel-Power506进入Modern Standby，原因Lid；随后Runner的WebSocket断连、TLS EOF，GitHub判定失联。三个Lua进程ETIMEDOUT，墙钟分别596.8/311.3/556.2秒，原预算60/30/30秒；部分输出已完成126向量或EVENT_RNG_PASS，不能把输出标记提升为进程通过。88项取消也不算执行成功。Ubuntu两个作业通过，不能替代Windows。
- Quality659（40284922381）：07:54:38Z明确记录Runner收到shutdown signal；不是靠修改测试断言解决的问题。
- 同步刚合入的PR215官方Runner实现，日常check使用GitHub-hosted windows-2025，固定Node24.18.0；Ubuntu文件系统验证保留。原测试预算和完整检查保留，未增加超时、复跑旧失败作业或修改机器电源/其他项目服务。
- 复用PR211的短效Power过期修复、按分支64个引用的下载保护与真实负对照；复用PR212完整状态比较中的combatGeneration夹具，未削弱比较。
- 用户明确批准停用额外任务锁：移除ownership作业和强制claim前置，保留旧工具及历史状态、不冒用其他session。Backlog、独立工作树、PR和当前SHA完整Quality仍必需。原跨PR本机串行队列移除，每分支concurrency取消过时运行；不同OS与不同merge/squash SHA的验证不冒称可直接复用。

## 分级与测试原子性

`test:fast`和`test:related`使用传递导入与字面fixture引用；Lua变更保守纳入动态JS桥，脚本变更纳入动态进程/目录发现集成。未知/删除/数据/配置/构建基础设施变更回退全量。`--plan`公开选择与原因；快速成功不等于完整回归。最终Quality始终运行原完整JS/Lua/Python、架构、静态、四项语义变异。

原129个JS文件和397个Lua fixture中，至少37个Lua fixture也由JS包装执行。包装另校验退出码、输出及桥接合同，不盲删。UI别名矩阵的每个用例仍有独立data/out和清理；只移除非CLI用例无关的scripts复制，以及无关tools树复制。CLI仍带真实脚本，renderer仍为真实生产文件，全部输入保护/已有输出/无部分产物断言保留。不共享可变fixture，不提高文件并发。

## 依赖和复杂度

| 项目 | 对照 | 修复 |
|---|---:|---:|
| Luacheck历史诊断 | 125 | 116 |
| 延迟导入例外 | 19 | 16 |
| Combat的直接引用者 | 14 | 11 |
| 源码模块 | 108 | 109 |
| onHpLost定义 | 2 | 1 |
| endTurn导出定义 | 2 | 1 |

新增abyss_copy保留原graph-copy实现和Combat.copy API，由三个独立定义构建器直接使用，消除其反向依赖；新增循环引用/共享值/表键身份/显式memo/legacy assert参数回归。不是为减行数机械拆文件。

原endTurn包装负责native/experimental分流及高级钩子异常时的snapshot恢复。改成命名明确的endExperimentalTurn内部函数，仍保持原pcall、恢复和错误传播。Run的事务边界保持；未把UI状态写入规则层。

四模块审计：Combat扇出40、被14模块引用，是规则门面及队列分派热点；BattleUI扇出9，NodeUI8，Run21。Luacheck实测最大复杂度分别为Combat queuedHandlers.effect168、BattleUI render352、NodeUI renderShop109、Run potionCandidate44。高复杂度真实存在，但本轮不以分支搬家伪造算法简化；大渲染闭包保留既有行为，先清掉确定冗余及局部重名。最大函数复杂度未宣称下降。

19项延迟边逐项按真实调用点核对：三项纯copy依赖已删除；Actor的状态/受伤反应、TurnPowers的运行时准备队列、BuildActions/Silent/Discard的已初始化Combat API、RelicHooks与CardActions的反应队列仍是运行时相互调用。顶层改成require会重新引入初始化环；未为归零例外而改回调顺序或注入新的框架。

125条诊断包括W43195、W21211、W2117、W3113、W4213、W4221、W4321、W4331、W2131、W5422。清掉无用amount函数及其两个遮蔽、unused loop/坐标、状态图标/坐标和药水/触摸key局部重名。其余方法self与闭包同名等按现有行为保留；没有把新告警加入通配豁免。基线按实际诊断及LF源码摘要逐条刷新。

## 证据与验证

docs/evidence当前树517文件/60,049,308字节，最大2,066,972字节。既有证据全部保留，不改Git历史。新增策略见该目录README：小清单+hash/身份/取回位置、必要原图去重复引用、临时产物留.artifacts/或短期CI artifact；长期证据有可取回归档前不迁走唯一副本。

本地与当前SHA CI的最终执行数、耗时及合并结果在完成验证后补入；未执行的项目不填通过。CI耗时还受平台与机器影响，不把不同主机的数字当作单变量性能提升。


### 已完成的定向测量

- 本机固定Node24.18.0：完整JS阶段1471项，1354通过、0失败、117环境权限skip、0取消，711.795秒。此轮运行期间继续完成局部重构，因此它是诊断/基线记录，最终head以官方CI为准。
- deck-ui-layout小改动：快速计划7个JS文件/16项断言全部通过，测试阶段0.795秒，包含选择/数据/UI准备的命令墙钟7.818秒。它减少的是执行集合，不声称每条测试快了近百倍；最终仍跑全量。选择器单元5/5，包含传递依赖、动态导入/目录发现、未知删除和数据回退。
- UI保护矩阵仍198组合；同Node完整运行中的原矩阵用例耗时和13.293秒，优化后定向4.039秒（约减少69.6%）。整文件205项，104通过/101权限skip/0失败，与本机权限边界一致；Ubuntu仍执行真实symlink。测量不是隔离CPU基准，不外推所有CI的同等加速。
- 当前Combat扇入14→11，扇出40→41（新增共享copy依赖及已复用的Power清理调用）；总require调用点仍496，不能宣称全图复杂度普遍下降。收益是三条初始化循环关系解除和稳定工具复用。
