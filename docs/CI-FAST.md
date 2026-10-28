# CI 按影响选测

TASK-80。当前为待验证实现，尚未完成性能验收。

普通 develop PR 使用完整受影响集合，不采用原 advisory 的90秒截断。Windows和POSIX均执行选中的完整JS文件和Lua夹具。所有原断言、子进程预算及失败语义保持。预计超过180秒的集合转完整回归，不删去超预算测试。只有明确列出的纯文字文件可免业务回归，仍执行治理、许可和presentation门禁。

核心Lua、数据、配置、依赖、工作流、未建模输入、删除或未映射文件均Full。develop/master push、发版PR和手动运行均Full；PR带ci:full标签可强制Full。现有Full矩阵和步骤完整保留。标签移除不会追认旧结果，应推送新提交重新规划。

Required Checks继续使用check、engineering-posix、presentation、inventory，绑定现有GitHub Actions app。前两项汇总同时依赖影响计划、Full分片及Fast矩阵；计划必须成功且选中执行必须success，失败、缺失、跳过、取消全部拒绝。无需改名或修改ruleset，核心分支禁止强推/删除及PR规则保持。

Quick feedback不再自动随PR重复执行，保留手动诊断。Full路径尚未削减初始化；当前实测主耗时为测试本身，不能为了初始化优化破坏完整测试依赖。

基准：真实GitHub run40708754842，SHA53fa164a，创建14:43:27至完成15:04:40 UTC，21分13秒（含排队）。原始jobs和ruleset保存在docs/evidence/ci-fast/。

验收口径：按固定工作流版本采集自然PR运行，分别报告Fast/Full样本数、SHA、attempt、结论、创建到最后Required Check完成的耗时，以及各job排队/执行时间。P50/P90用nearest-rank；失败和取消单列，不从样本中静默删除，不用重跑历史SHA刷样本。Fast至少20个真实PR样本且覆盖源码、测试和纯文档后判断P50≤300秒、P90≤600秒；Full当前版本实际回归≤1800秒。未达样本量只报告观测值，不宣布总体达标。
