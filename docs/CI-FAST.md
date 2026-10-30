# CI 按影响选测

TASK-81。快速反馈、完整受影响回归、集成验收分层报告；性能验收仍须真实当前版本的样本，不沿用旧 PR 或取消运行的资格。

普通 develop PR 使用完整受影响集合，不采用原 advisory 的90秒截断。Windows和POSIX均执行选中的完整JS文件和Lua夹具。所有原断言、子进程预算及失败语义保持。预计超过180秒的集合转完整回归，不删去超预算测试。只有明确列出的纯文字文件可免业务回归，仍执行治理、许可和presentation门禁。

Lua 模块按 `config/architecture.json` 的现有层分类：已登记的 UI 职责与入口同样可规划完整受影响回归，不再仅识别六个入口文件。核心、未登记模块、数据、配置、依赖、工作流、未建模输入、删除或未映射文件均 Full。develop/master push、发版 PR 和手动运行均 Full；PR 带 ci:full 标签可强制 Full。现有 Full 矩阵和步骤完整保留。标签移除不会追认旧结果，应推送新提交重新规划。

Required Checks继续使用check、engineering-posix、presentation、inventory，绑定现有GitHub Actions app。前两项汇总同时依赖影响计划、Full分片及Fast矩阵；计划必须成功且选中执行必须success，失败、缺失、跳过、取消全部拒绝。无需改名或修改ruleset，核心分支禁止强推/删除及PR规则保持。

Quick feedback 自动随 develop PR 运行，也保留手动诊断；它是 advisory，不进入 Required Checks。`npm run test:fast -- --base <commit>` 与 `--ci-fast` 共用选集：纯 JS 和按测量权重在 90 秒估算内安排的完整 Lua 夹具，优先直接修改的夹具；执行时先跑选中的直接修改 Lua，再跑 JS，最后跑其余 Lua，任一步失败立即停止，不重复夹具。估算不是超时，不更改夹具原断言和期限。`--plan` 的 `feedback` 可查看两入口的实际选集。`test:related` 仍运行完整受影响集合，未知输入回退 `check`。

fast/advisory 对未知输入只提供可独立映射部分的反馈，并明确要求完整 Quality；零测试显示未执行及非回归验收，不启动重复全量，也不声明覆盖。集成 JS 和未排入的 Lua 由完整 Quality 兜底。PR 使用精确 merge SHA 和事件 base SHA，在隔离托管 runner 上运行，只读权限且不持久化凭据；新提交取消同 PR 的旧 advisory。Node 固定 24.18.0。Full路径当前实测主耗时为测试本身，不能为了初始化优化破坏完整测试依赖。

混合未知输入的 advisory 在一次图分析中求全部静态映射，不按每个变更文件重复解析全库；未映射输入不会触发额外动态扩集。只复用本次调用的内存闭包，不缓存跨调用源码或报告。CLI 的 `planDurationMs` 和 plan/build/tests 阶段耗时用于区分规划、初始化与真实执行，失败也保留阶段耗时。

基准：真实GitHub run40708754842，SHA53fa164a，创建14:43:27至完成15:04:40 UTC，21分13秒（含排队）。原始jobs和ruleset保存在docs/evidence/ci-fast/。

验收口径：按固定工作流版本采集自然PR运行，分别报告Fast/Full样本数、SHA、attempt、结论、创建到最后Required Check完成的耗时，以及各job排队/执行时间。P50/P90用nearest-rank；失败和取消单列，不从样本中静默删除，不用重跑历史SHA刷样本。Fast至少20个真实PR样本且覆盖源码、测试和纯文档后判断P50≤300秒、P90≤600秒；Full当前版本实际回归≤1800秒。未达样本量只报告观测值，不宣布总体达标。

美术输入分两组：原六张审阅 PNG 仍仅由审阅测试/许可审计准备，预算 5983528 字节；运行时只准备固定三张卡牌预览和一张背景预览，独立上限 181870 字节。JS 测试会通过辅助模块/子进程开启美术，因此 Full 分片与 Fast 对非空 JS 集合保守准备这四项；纯文字、空集合、仅 Lua 和默认关闭美术的 presentation 构建不新增下载。两组共用本地 LFS 对象缓存，重叠三张预览不重复传输；读取前核对索引指针，读取后核对 PNG、长度及 SHA。这里的字节数是逻辑输入上限，不是实际计费读数。
