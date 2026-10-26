# 工程检查与证据入口

2026-10-25统一集成：历史TASK-33/34/35编号仅对应本分支创建时的记录，不覆盖当前同号产品任务，见[编号迁移说明](reviews/engineering-legacy-tasks.md)。本轮工程与其他成果一起在现有PR206验证；当前架构为66模块，平台/实机验收状态不因工程门禁提升。

当前静态基线为114条逐条复核的既有告警，`reviewedSourceHashesLF`对源码换行规范化后记录哈希；不包含未定义全局或语法错误。以下53条、19模块及当时任务编号属于原冻结工程切片的历史证据。

本轮参照 `Slay_the_Abyss_Engineering_Upgrade_2026-10-23.zip`，在 `origin/develop@cd8ceae` 上实施。保留现有玩法、PR19视觉基线、Fengari执行入口、Backlog和Quality。TASK-33/34/35维护执行状态；真实玩家关口仍在原任务。

| 改动 | 读取与执行 | 可证明的范围 |
|---|---|---|
| 日常代码 | `npm ci --ignore-scripts`；首次 `npm run setup:lua-static`；`npm run check` | 当前Node/Lua/Python回归及工程门禁 |
| Lua模块依赖 | `config/architecture.json`；`npm run check:architecture` | 作用域AST、函数内require、禁止层次、循环、未知/动态加载；`build/architecture.json` |
| Lua基础静态检查 | `.luacheckrc`；`npm run check:lua-static` | 固定Luacheck 1.2.0和二进制hash；新增诊断失败；复杂度仅报告 |
| 关键测试敏感性 | `config/critical-mutations.json`；`npm run check:test-strength` | 四类指定语义退化，临时副本，指定断言来源；不是全库mutation score |
| 副本候选 | `node scripts/build-native-candidate.mjs <base.gil> [build/candidates]` | 重新生成数据/UI、当前24模块完整检查、输入与最终GIL真实摘要 |
| 启动取证 | 上一命令加 `--playtest`（仅客户端可用且允许占用输入时） | 实际MCP run/request、原始日志解码、本构建启动标记和ready；不等于完整游戏 |
| UI实机验收 | `npm run verify:ui -- <候选目录/candidate.gil>` | 同一候选/启动/截图、当前批准稿版本、完整关键项及明确人审范围 |
| 合并证据 | `npm run verify:delivery -- <PR> <独立审查.json>` | 当前head/base、测试merge parents、当前attempt全部必需作业；不自动合并 |

需要 Python 3 和 Pillow 12.3.0，可用 `ABYSS_PYTHON` 指定已有解释器。工具缺失、下载/hash错误、解析失败、超时或空报告一律非零，不静默跳过。Luacheck安装只写仓库 `build/tools/`，不改全局工具链；来源与两个平台hash在 `config/lua-tools.json`。

## 候选身份

每轮生成UUID子目录，源存档先复制再交MCP，`MILIASTRA_ALLOW_LIVE_WRITE=0`。历史目录中的同名清单不会被覆盖。新目录重新构建五个运行时生成模块，不扫描共享build目录；测试fixture和残留Lua不能混入。成功收据包含源提交、脏工作树状态、逐文件输入/产物摘要、payloadDigest、最终candidate.gil摘要、实际checked集合和逐条MCP告警。未审查告警保留 `not_run`，不批量忽略。

`payloadDigest`覆盖实际源码、内容、主题、构建脚本、渲染器、依赖与模块策略；仅文档提交不迫使无关候选重建。每个实际输入仍记录内容摘要。收据自身不参与自身hash，构建ID通过打包后的入口输出 `ABYSS_BUILD <id>` 关联日志，避免GIL自身hash的循环引用。

`officialImport` / `playtest` 保持 `not_run`，实际启动证据另存 `startup-evidence.json`；静态成功不提升产品任务状态。失败轮保留 `failure.json` 和MCP逐次响应。当前dirty候选的收据会明确标记，不能报告为某个干净HEAD已验收。

## 日志与UI迁移

启动验证要求调用方传入真实start返回的runId/runDir、调用时刻、实际mapPath摘要与buildId，核对MCP落盘request。以当前MCP `inspectDebugLog` 实际重解码原始GIA；空/旧/跨目录文件、错run/候选、与原始文件不符的prints、错构建标记或runtime fault拒绝。解码适配只覆盖已观察格式，不为文件来源真实性提供密码学保证。

UI记录使用 `schemas/ui-acceptance.schema.json`：根部提供buildId/runId/payloadDigest/baselineRevision；逐屏提供候选身份、批准稿图片与截图的相对路径/真实hash、reviewer、合法reviewedAt、reviewScope、实际operations、空unresolved及全部关键checks。同图复用须在涉及各屏说明共享原因。截图相对真实run目录，批准稿相对 `docs/design/`；两者都必须可被Pillow解码。baselineRevision由当前UI_DESIGN、prototype及screens文件内容计算。

CLI从候选旁收据和启动证据取得预期身份，重验原始日志与当前payload；不从待验UI表中自取可信runId。历史 `ui-acceptance.json` 的partial/failed/pending保持原状，未补默认PASS。有效文件、结构和hash也不能证明画面好看或操作正确，人审仍须实际比较并操作。

## 静态基线与测试证明

53条现有Luacheck诊断逐条保存在 `config/luacheck-baseline.json`（归属TASK-34）：UI方法self遮蔽、未使用局部值/参数。最初cd8ceae有47条；同步已合入的PR75/77至ed39f46后，复核两份UI文件的行位变化和回调未用参数，新增6条。无未定义全局/语法豁免。新同类诊断也失败；修改相关代码时复核并缩减具体基线，不能通配忽略。代码行移动可能需要审核后更新对应条目。复杂度输出独立于门禁，未设置统一4/6/8分数阈值。

四个算子保护：出牌失败回滚、满手抽牌边界、节点视图隔离、药水结算失败不提交。每轮正常基线→唯一合法变异→指定测试文件/断言行/标记→原文件hash复核；报告区分survived、invalid_mutant、infrastructure_error、timeout、inconclusive。产品抛出“assertion failed”文本不能冒充测试kill。

## CI与交付

必需作业是 `check`、`presentation`、`engineering-posix`。2026-10-26用户已公开仓库并指定GitHub官方免费runner：check统一使用标准`windows-latest`（含fork），ownership/presentation/engineering-posix使用`ubuntu-latest`。不依赖本机自托管runner、不使用larger runner；Ubuntu作业实际跑Node文件别名回归。保持只读权限、超时、取消旧运行、7天产物保留；check产出当前event/runId/attempt/head/base/tested SHA收据。运行环境切换不豁免ownership或当前SHA验收。

交付检查读取所有分页及当前attempt作业，拒绝queued/failed/cancelled/skipped/missing和旧head/base组合。PR合并测试SHA允许不同于head，但实际parents必须是当前base/head。独立审查记录提供 `reviewedHeadSha`、`reviewedBaseSha`、可追溯 `reviewId`、`conclusion: pass`、`unresolved: []`；字段通过不自证审查独立，须检查真实会话/审查来源。记录可放PR附属产物，避免提交记录包含自身SHA的循环。合并前再查head/base，用现成expected-head机制，并复查合并结果。

## 尚未取得的证据

本轮不启动原神、不占用键鼠；官方导入、玩家完整路径、截图体验与投稿仍独立验收。StrykerJS、原生LuaCov和JS全文件覆盖的报告试点不作为本轮必需门禁；没有执行结果就不填覆盖数字。LuaCov重试需隔离原生Lua5.3、LuaRocks/datafile及与Fengari的数值/退出行为对照，不能把Fengari VM的JS覆盖率称为Lua覆盖率。

## Linux本地等价检验

2026-10-26用户明确允许Linux使用等价检验，避免因没有PowerShell阻塞工程推进。`tests/ci-downloads.test.mjs`在Windows继续执行工作流原PowerShell检出正文；非Windows使用`scripts/ci-checkout-equivalent.mjs`，在独立临时仓库中实际执行Git初始化、origin更新、旧/新引用保留、精确SHA fetch/checkout、pack字节计量、摘要、阈值拒绝及清理。

Linux入口是固定版本工作流的行为等价检验，不解释PowerShell语法，也不冒充Windows实测。它锁定已审阅的检出正文SHA256，仅允许原回归明确使用的旧引用负对照和1KB超限测试变体；工作流其他变更一律失败，须复核等价关系。测试继续验证首次大包、微小增量、旧流程重复传输、超限失败和摘要，没有跳过断言、降低128MiB阈值、下载大型运行时或改动正式CI检出流程。

本轮真实Linux结果：首次262501B，小增量319B，旧流程跟进262723B；3项测试通过。此结果解除本地pwsh缺失阻塞，不替代Windows CI或游戏实机证据。

完整Linux JS复验：1471项全部通过、无跳过，见`docs/evidence/linux-checkout-equivalent-20261026.json`。此前缺pwsh失败日志保留为历史，不改写为当时成功。
