# 原生快照字段 key 类型判定

基线 `b4ac63145689b9dd632db100eee49087f6182b39`。本切片只在每次 `Snapshot.capture` 内增加字段 key 的类型缓存：同名字符串、数字等 key 在完整 Run/catalog 图中重复出现，缓存其是否为 table，减少 Fengari 的 `type` 调用。缓存包含 false key，不把 false 当作未命中。value 仍逐项判型，table key 与 value 都继续完整遍历；没有 data/catalog 豁免、跨调用缓存或父快照复用改动。

实际保存图、pending 栈、恢复闭包、owner 和 release 原文保持。新增缓存没有进入保存图，恢复/owner 闭包无其引用；这是源码可达性结论，不是原生 weak-table/GC 实测。每次 capture 多一个临时缓存表，其内存和原生 GC 影响未测。

机器证据：[snapshot-key-types-20261104.json](../evidence/snapshot-key-types-20261104.json)。固定官方 Node 24.18.0，真实 Silent Run 加实际第一房战斗图包含 8122 表、31060 字段、1444 唯一 key；全量 data/catalog 均包含。每个新进程先各预热一次，两轮各 8 对交错顺序样本，每样本 12 次 capture，使用 `os.clock`。完整原始样本及反向波动保留在机器证据，不将局部结果当作完整 CI 或官方 Lua 提速。

两轮各 96 次 capture 的总时间分别为 8.826001→7.895763 秒（10.54%）和 8.579373→8.058533 秒（6.07%），每轮仍有反向样本。先 `npm run build:data`，显式重放用 `node scripts/benchmark-snapshot-key-types.mjs`；它从当前源码精确逆转出旧实现，仅写 build，仍使用原 30 秒入口预算，不加入日常必跑微基准。

原 `silent_natural_build.lua` 完全未改，仍在同一 VM 两次完整四房并比较 canonical。原 30 秒入口预算内，本机顺序 before→after 为 24005→23056ms；反序 after→before 为 23713→25144ms。四次业务 stdout 逐字节一致，含真实奖励、HP、回合与组合记录。此处本机 before 已能通过，没有本地重现 hosted 超时；精确 HEAD Full 仍须重新验证，不能据约 4–6% 的两对样本宣称故障已经稳定修复。

验证范围：

- 原 96 随机全图与 key-only/cycle/alias/false/data/catalog、20000 层深链、single-use owner 合同不变。
- 新专项覆盖 false key、table-key cycle、同名字段在两次 capture 之间切换 scalar/table 值、前后快照独立恢复、owner 消耗/释放及未写入缓存状态。
- 新增精确两块增量逆转换，先恢复缓存前源码，再走原冻结 traversal inverse；旧 hash、旧 Silent fixture hash、原三种真实漏图错误变异保留。额外、部分或错误缓存块均拒绝。

没有改变 runner、预算、有效断言或冻结 fixture，没有官方导入、ready、设备、原生 Lua 内存或 FPS 证据。最终独立审查、当前组合 Full 和实际合后 CI 分别记录，任务未提前完成。
