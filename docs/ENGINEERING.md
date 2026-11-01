# 工程检查与证据入口

平台负载采用[双层工程门禁](PLATFORM_LOAD.md)：`npm run check:platform-load` 检查共用生产打包清单、重复模块/模板/控件名、既有原生UI限制及固定基线增长，输出 `build/platform-load-daily.json`。实际构建收据保存生产 manifest，已有读回/hash/旧脚本清理继续生效。Quality 完整分片和生产相关 fast 路径执行，不启动游戏。正式 RC 另跑 `npm run verify:platform-load -- <最终candidate.json> <official-load.json>`；缺少同候选官方证据必须非零，普通PR不要求这些实测。20MB关卡与3MB服务器独立硬限，16MB内部预警；源码/GIL字节不能换算官方读数。

原生列表生命周期属于可执行门禁：共享`game_ui_fixture`将`alive`建模为只读，并拒绝对已销毁实例调用`GetChild/GetChildren`；Grid可分别模拟复用、刷新销毁及滚动回收。`check:native-ui-contract`实际覆盖卡组/遗物查看、校准项替换、关闭重开、滚动回收，并运行移除生产存活保护的负对照，必须捕获无效对象访问。不得用始终保留实例的替身替代销毁场景；历史渲染轨迹与当前原生生命周期分别验证。该门禁源于2026-10-29实机点卡组/遗物报错，不能将此前静态或读回成功当成实机可用。

Node UI 专项门禁覆盖入口与全部 abyss_node_ui_* 模块：每模块≤1000物理行、每函数（含嵌套/工厂）≤350物理行，全部提取职责复杂度≤15；报告为 build/node-ui-size.json 与 build/responsibility-complexity.json。固定 develop 旧新对照运行 node scripts/compare-node-ui.mjs，范围与证据见 [Node UI专项方案](plans/2026-10-28-node-ui-refactor.md)。


源码职责、生成物和测试目录先看[模块导航](ARCHITECTURE.md)；内容源与参考数据边界见[数据入口](../data/README.md)。本页保留历史实施证据，当前模块集合和诊断数量以配置及本轮报告为准。

`npm run check:engineering` 在同一调用内读取完整 Lua 源码并采集一次架构、Luacheck 告警和复杂度，供原有质量、架构、静态门禁共同使用；其后仍执行关键变异与原生 UI 合同。共享仅限本次进程内存，不读取磁盘旧报告作为通过依据。三个独立 CLI 仍重新采集；工具缺失、采集或任一门禁失败均非零，质量采集失败写入本轮失败报告。

历史回放使用原始完整来源及独立 oracle，不冻结当前夹具注册器的实现格式。[历史原始输入](../tests/fixtures/pr323-historical-fixtures.json.gz)保留来源提交、逐文件 SHA256 和 Git blob；原始目标源码另受完整集合身份及原正式 beforeSha 约束，运行时真实构建和执行，不缓存场景结果。历史矩阵在独立临时目录执行，当前真实 Host/manager 生命周期回归仍读取当前源码。现行实现维护不刷新原档，历史来源通过不能替代当前动态控件、输入和状态断言。

全库质量基线、指定模块行数、完整构造器/函数跨度、Luacheck复杂度、包含延迟导入的完整依赖环与静态告警增减见[质量验收机制](ENGINEERING_QUALITY.md)。`npm run check:quality`每次重新采集并核对全部函数测量；新增数值指标暂为report-only，不能据其退出码0宣称热点已治理。原工程硬门槛仍由以下检查执行。

渲染治理的绝对门槛已接入 `check:lua-static`：战斗主render≤10，完整战斗控制器及battle_*子视图/输入模块、商店UI与卡面展示的每个函数≤15。固定Luacheck测量，AST核对函数测量完整性，报告见build/ui-complexity.json。缺测量或缺入口会失败，不能只报告相对降幅。实际实现、当前验证范围和历史纠正见[TASK-74](backlog-details/TASK-74.md)；完成声明遵循[项目协作](../AGENTS.md)的本轮证据要求。

本轮以 develop `20c6815e` 复核剩余指定职责：effects.apply、combat的queuedHandlers.effect、Act2 choose、角色文案fragments、feedback.step/paint、node.render、game.refresh。`check:lua-static` 对这些入口、其嵌套函数及本轮提取helper执行≤15门槛，输出 `build/responsibility-complexity.json`；每个AST函数与固定工具测量逐一对应，拒绝缺测、坐标移位、重复和未知格式。未触及的既有热点继续报告，不把该范围扩为全库统一上限。新增职责模块沿用对应前缀并纳入架构分类。

前次架构减负以 develop `d8a26227` 为基线：实际扫描116个Lua源码模块，静态基线113条、延迟导入例外19项。战斗手牌子视图与商店四类商品/服务渲染已有独立边界；完整Windows回归使用隔离VM分片，片内保持串行。具体指标、原回归和交付状态见[TASK-74](backlog-details/TASK-74.md)；机器结果以 `config/architecture.json`、`config/luacheck-baseline.json`及生成报告为准。[TASK-68](backlog-details/task-68.md)和下文的早期计数均为当时冻结切片，不作为当前数值。

日常小改动使用 `npm run test:fast -- --base origin/develop` 或 `npm run test:related -- --base origin/develop`；先加 `--plan`查看选择。也可用 `--files scripts/deck-ui-layout.mjs` 指定待验证的改动集合。本地 fast 与自动 PR advisory 共用有界的 JS、Lua 选集，直接改动的 Lua 夹具优先；相关层执行完整受影响回归。未知、删除、数据/配置/构建基础设施改动仍要求完整 `npm run check`，fast 只报告可映射部分及延期原因。零测试、部分成功均不能代替完整 Quality，覆盖层次与选择理由见 [CI-FAST](CI-FAST.md)。

多代理先划分源码写入范围；同一工作树的生成目录与工程报告由一个执行者写入，独立树的产物不互借。按可用内存、CPU和已有作业安排昂贵验证，复用现有分片与 worker；每个代理不各跑一轮完整检查。主控小批集成后验证组合，独立只读评审可与 CI 并行；保留失败、取消及重跑耗时，不恢复全局任务锁。

日常CI使用GitHub-hosted Windows和Ubuntu；受信分支显式`local-special`诊断入口保留，具体调度以[Quality工作流](../.github/workflows/quality.yml)为准。旧self-hosted常规调度与Remote Task Claim强制锁已按用户明确批准停用。保留Backlog、独立工作树、PR审查、精确head与全部完整质量门禁。GitHub原生每分支concurrency取消过时运行，不再把不同PR排在本机串行队列。Windows与Ubuntu覆盖不同文件系统语义；PR merge SHA和squash后的develop SHA也分别核对，不复用旧SHA的绿灯。

本轮参照 `Slay_the_Abyss_Engineering_Upgrade_2026-10-23.zip`，在 `origin/develop@cd8ceae` 上实施。保留现有玩法、PR19视觉基线、Fengari执行入口、Backlog和Quality。TASK-33/34/35维护执行状态；真实玩家关口仍在原任务。

| 改动 | 读取与执行 | 可证明的范围 |
|---|---|---|
| 日常代码 | `npm ci --ignore-scripts`；首次 `npm run setup:lua-static`；`npm run check` | 当前Node/Lua/Python回归及工程门禁 |
| Lua模块依赖 | `config/architecture.json`；`npm run check:architecture` | 作用域AST、函数内require、禁止层次、循环、未知/动态加载；`build/architecture.json` |
| Lua基础静态检查 | `.luacheckrc`；`npm run check:lua-static` | 固定Luacheck 1.2.0和二进制hash；新增诊断失败；声明范围内复杂度执行硬门槛，其余保留报告 |
| 关键测试敏感性 | `config/critical-mutations.json`；`npm run check:test-strength` | 四类指定语义退化，临时副本，指定断言来源；不是全库mutation score |
| 副本候选 | `node scripts/build-native-candidate.mjs <base.gil> [build/candidates]` | 重新生成数据/UI、当前源码及`generatedRuntimeModules`声明的生成运行时模块完整检查、输入与最终GIL真实摘要 |
| 启动取证 | 上一命令加 `--playtest`（仅客户端可用且允许占用输入时） | 实际MCP run/request、原始日志解码、本构建启动标记和ready；不等于完整游戏 |
| UI实机验收 | `npm run verify:ui -- <候选目录/candidate.gil>` | 同一候选/启动/截图、当前批准稿版本、完整关键项及明确人审范围 |
| 合并证据 | `npm run verify:delivery -- <PR> <独立审查.json>`；纯说明文档 `--low-risk-docs` | 当前head/base、测试merge parents、当前attempt全部必需作业；不自动合并 |
| 合入后复核 | `npm run verify:delivery -- <PR> <预审evidence.json> --merged` | 实际squash SHA、单父提交、源码树及该提交在目标分支的完整push Quality；不借PR绿灯 |

需要 Python 3 和 Pillow 12.3.0，可用 `ABYSS_PYTHON` 指定已有解释器。工具缺失、下载/hash错误、解析失败、超时或空报告一律非零，不静默跳过。Luacheck安装只写仓库 `build/tools/`，不改全局工具链；来源与两个平台hash在 `config/lua-tools.json`。

## 候选身份

每轮生成UUID子目录，源存档先复制再交MCP，`MILIASTRA_ALLOW_LIVE_WRITE=0`。历史目录中的同名清单不会被覆盖。新目录重新构建运行时生成模块，正式打包集合见[候选构建器](../scripts/build-native-candidate.mjs)的`generatedRuntimeModules`，不扫描共享build目录；测试fixture和残留Lua不能混入。成功收据包含源提交、脏工作树状态、逐文件输入/产物摘要、payloadDigest、最终candidate.gil摘要、实际checked集合和逐条MCP告警。未审查告警保留 `not_run`，不批量忽略。

`payloadDigest`覆盖实际源码、内容、主题、构建脚本、渲染器、依赖与模块策略；仅文档提交不迫使无关候选重建。每个实际输入仍记录内容摘要。收据自身不参与自身hash，构建ID通过打包后的入口输出 `ABYSS_BUILD <id>` 关联日志，避免GIL自身hash的循环引用。

`officialImport` / `playtest` 保持 `not_run`，实际启动证据另存 `startup-evidence.json`；静态成功不提升产品任务状态。失败轮保留 `failure.json` 和MCP逐次响应。当前dirty候选的收据会明确标记，不能报告为某个干净HEAD已验收。

## 日志与UI迁移

启动验证要求调用方传入真实start返回的runId/runDir、调用时刻、实际mapPath摘要与buildId，核对MCP落盘request。以当前MCP `inspectDebugLog` 实际重解码原始GIA；空/旧/跨目录文件、错run/候选、与原始文件不符的prints、错构建标记或runtime fault拒绝。解码适配只覆盖已观察格式，不为文件来源真实性提供密码学保证。

UI记录使用 `schemas/ui-acceptance.schema.json`：根部提供buildId/runId/payloadDigest/baselineRevision；逐屏提供候选身份、批准稿图片与截图的相对路径/真实hash、reviewer、合法reviewedAt、reviewScope、实际operations、空unresolved及全部关键checks。同图复用须在涉及各屏说明共享原因。截图相对真实run目录，批准稿相对 `docs/design/`；两者都必须可被Pillow解码。baselineRevision由当前UI_DESIGN、prototype及screens文件内容计算。

CLI从候选旁收据和启动证据取得预期身份，重验原始日志与当前payload；不从待验UI表中自取可信runId。历史 `ui-acceptance.json` 的partial/failed/pending保持原状，未补默认PASS。有效文件、结构和hash也不能证明画面好看或操作正确，人审仍须实际比较并操作。

## 静态基线与测试证明

现有Luacheck诊断逐条保存在[静态基线](../config/luacheck-baseline.json)，数量和对应源码以当前文件及`build/lua-static.json`为准。早期TASK-34在cd8ceae记录47条，PR75/77同步至ed39f46后记录53条，均为历史快照。无未定义全局/语法豁免。新同类诊断也失败；修改相关代码时复核并缩减具体基线，不能通配忽略。代码行移动可能需要审核后更新对应条目。全库复杂度有独立诊断报告；渲染与指定职责的硬门槛见本文开头和[检查器](../scripts/check-lua-static.mjs)，不声称全部热点均已治理。

四个算子保护：出牌失败回滚、满手抽牌边界、节点视图隔离、药水结算失败不提交。每轮正常基线→唯一合法变异→指定测试文件/断言行/标记→原文件hash复核；报告区分survived、invalid_mutant、infrastructure_error、timeout、inconclusive。产品抛出“assertion failed”文本不能冒充测试kill。

## CI与交付

必需作业是 `check`、`presentation`、`engineering-posix`。日常来源运行GitHub-hosted，显式诊断入口见上文；Ubuntu作业实际跑Node文件别名回归。保持只读权限、超时、取消旧运行、7天产物保留；check产出当前event/runId/attempt/head/base/tested SHA收据。

独立 Sub-agent 在功能切片稳定后、合并前聚焦状态边界、契约和 CI 盲区；与 CI 可并行，不重复完整检查。关键重构、游戏逻辑与跨模块集成深审，其余运行时/测试/配置/资产任务仍需独立评审，但可缩小范围。只有 README.md、CHANGELOG.md 或 docs/drafts|history|lore|research 下的 .md/.txt 非执行说明文件，且同一 PR 不超过20个新增/修改文件，可用 `npm run verify:delivery -- <PR> --low-risk-docs` 免独立 Sub-agent；删除、重命名及任何其他文件一律不豁免。该入口从 GitHub 分页读取完整 PR 文件清单，核对文件状态与 blob SHA、总数，绑定 head/base，合入后重新读取对比；失败退回正常独立评审，不新增 CI 作业或绕过原门禁。免审仅适用于 develop；GitHub Ruleset 目前不强制另一个账号审批，独立证据仍由协调 Agent 核验。

正常交付检查读取所有分页及当前attempt作业，拒绝必需回归作业的queued/failed/cancelled/skipped/missing和旧head/base组合；Full路径未选中的fast作业按下述版本合同验证。PR合并测试SHA允许不同于head，但实际parents必须是当前base/head。独立审查记录提供 `reviewedHeadSha`、`reviewedBaseSha`、可追溯 `reviewId`、`conclusion: pass`、`unresolved: []`；字段通过不自证审查独立，须检查真实会话/审查来源。记录可放PR附属产物，避免提交记录包含自身SHA的循环。合并前再查head/base，用现成expected-head机制，并复查合并结果。唯一基础设施应急例外按[CI流程](CI.md)取得Owner对精确PR/HEAD的一次聊天批准后执行；不改本验证器、不伪造绿灯，明确记录缺失检查与独立证据。

保存预审收据后，合入结果必须另验。`pr_passed` 只证明PR组合；实际合入提交的完整CI尚缺时为 `merged_pending`，实际SHA、源码tree、唯一父=预审base及对应push Quality均通过才是 `merged_passed`。验证后base前移即使源码tree相同也不能沿用旧组合。历史schemaVersion 2冻结为原15项成功作业（三个必需作业、8个Windows及4个POSIX分片），不改写或升级旧收据。新采证使用schemaVersion 3：原15项仍须全部成功，另要求impact成功、未展开的fast作业completed/skipped，共17项；Fast矩阵通过不能代替Full，缺少路由作业不能回退历史合同。PR预审与实际push各按自己的版本验证。逐作业绑定run_id、head_sha和attempt；采证末尾重新核对运行与attempt，拒绝诊断运行或旧成功记录。POSIX继续按文件使用Node原生分片，片内串行，每片保留完整工程门禁与20分钟作业预算。未来调整已有matrix须同步交付合同与其回归，不能只保留聚合作业名称。

schemaVersion 3预审在采证前后独立读取目标分支的Git ref，保存`targetBeforeSha`和`targetAfterSha`，两者都须等于已测base。PR API的base.sha与合成merge ref可能同时保留旧组合，不能代替实际目标引用；不一致即拒绝，不追认旧CI。该检查仅记录预审时的目标，合入后的历史验收仍按实际squash父与树验证，不要求之后的分支tip停留原位。

## 尚未取得的证据

本轮不启动原神、不占用键鼠；官方导入、玩家完整路径、截图体验与投稿仍独立验收。StrykerJS、原生LuaCov和JS全文件覆盖的报告试点不作为本轮必需门禁；没有执行结果就不填覆盖数字。LuaCov重试需隔离原生Lua5.3、LuaRocks/datafile及与Fengari的数值/退出行为对照，不能把Fengari VM的JS覆盖率称为Lua覆盖率。
