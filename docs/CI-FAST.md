# CI 按影响选测

TASK-81。当前为PR #307待验证实现，尚未完成性能验收。固定Node24.18.0的32项专项测试已通过；YAML和新增Bash步骤语法通过。Runner 40716938768首次仍在排队，未将排队记为成功。

普通 develop PR 使用完整受影响集合，不采用原 advisory 的90秒截断。Windows和POSIX均执行选中的完整JS文件和Lua夹具。所有原断言、子进程预算及失败语义保持。预计超过180秒的集合转完整回归，不删去超预算测试。只有明确列出的纯文字文件可免业务回归，仍执行治理、许可和presentation门禁。

核心Lua、数据、配置、依赖、工作流、未建模输入、删除或未映射文件均Full。develop/master push、发版PR和手动运行均Full；PR带ci:full标签可强制Full。现有Full矩阵和步骤完整保留。标签移除不会追认旧结果，应推送新提交重新规划。

Required Checks继续使用check、engineering-posix、presentation、inventory，绑定现有GitHub Actions app。前两项汇总同时依赖影响计划、Full分片及Fast矩阵；计划必须成功且选中执行必须success，失败、缺失、跳过、取消全部拒绝。无需改名或修改ruleset，核心分支禁止强推/删除及PR规则保持。

Quick feedback不再自动随PR重复执行，保留手动诊断。Full路径尚未削减初始化；当前实测主耗时为测试本身，不能为了初始化优化破坏完整测试依赖。

基准：真实GitHub run40708754842，SHA53fa164a，创建14:43:27至完成15:04:40 UTC，21分13秒（含排队）。原始jobs和ruleset保存在docs/evidence/ci-fast/。

验收口径：按固定工作流版本采集自然PR运行，分别报告Fast/Full样本数、SHA、attempt、结论、创建到最后Required Check完成的耗时，以及各job排队/执行时间。P50/P90用nearest-rank；失败和取消单列，不从样本中静默删除，不用重跑历史SHA刷样本。Fast至少20个真实PR样本且覆盖源码、测试和纯文档后判断P50≤300秒、P90≤600秒；Full当前版本实际回归≤1800秒。未达样本量只报告观测值，不宣布总体达标。

美术输入分两组：原六张审阅 PNG 仍仅由审阅测试/许可审计准备，预算 5983528 字节；运行时只准备固定三张卡牌预览和一张背景预览，独立上限 181870 字节。JS 测试会通过辅助模块/子进程开启美术，因此 Full 分片与 Fast 对非空 JS 集合保守准备这四项；纯文字、空集合、仅 Lua 和默认关闭美术的 presentation 构建不新增下载。两组共用本地 LFS 对象缓存，重叠三张预览不重复传输；读取前核对索引指针，读取后核对 PNG、长度及 SHA。这里的字节数是逻辑输入上限，不是实际计费读数。
