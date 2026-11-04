# 结束回合公开入口与事务判定

基线 `f26aeb30c0995de70cf340af977d3c8579c1a2b5`。仅整理 `advancedTurnCleanup` 与公开 `M.endTurn`；原生/实验结束阶段、遗物预处理、开回合和构造器不改。独立测试和固定完整旧源见[测试附件](TASK-74.12-TESTS.md)。

七个新 helper 分别承接目录能力判定、Power能力判定、单卡能力判定、保留续动、事务需求、快照所有权选择、受保护执行；公共入口保留编排。每个目录/Power/卡牌字段仍按原表达式短路读取，不把 `state.catalog.cards` 缓存成新局部，也不跨两次判定缓存结果。

保留的公开合同：

- 药水待选拒绝仍是第一个动作；遗物返回nil与false不同，pause/terminal直接返回一个true。
- 保留恢复仍检查pendingChoice，按原顺序标记保留、resume、finish；其拒绝返回两个值、成功暂停返回一个true。没有把helper内部的nil reason扩展成公开第二返回值。
- 事务路径先取得capture/ownedRestore，之后才重新读取状态选择resolver；所有者只消费原次数，异常执行原restore并原样抛错。
- 非实验直接native、第二次高级判定后直接experimental、末尾受保护fallback三条路径全部保留。两条直接调用仍tail return，受保护路径仍明确返回ok、reason两个值。
- `beginRelicEndTurn`及其内部快照位置保持，未将整个公开入口包入新事务或吞掉原错误。

## 本轮指标与验证

源码指标：[end-turn-admission-20261105.json](../evidence/end-turn-admission-20261105.json)。测试机器证据另见[独立测试报告](../evidence/end-turn-admission-20261104.json)。固定Node24.18.0、Luacheck1.2.0。

| 同一完整源码集 | 旧 | 新 |
| --- | ---: | ---: |
| M.endTurn CC / 行数 | 34 / 30 | 13 / 18 |
| advancedTurnCleanup CC / 行数 | 25 / 14 | 8 / 9 |
| 新增具名helper | 0 | 7，最高CC12 |
| 范围函数 / 总CC / 分支数Σ(CC−1) | 2 / 59 / 57 | 9 / 66 / 57 |
| 全库函数 / 完整测量 | 4794 / 5117 | 4801 / 5124 |
| CC>15 / CC>30 / 最大CC | 279 / 75 / 82 | 277 / 74 / 82 |
| 模块 / 唯一依赖对 | 323 / 1507 | 不变 |
| 静态require调用位置 | 1876 | 1874 |
| 最大SCC成员 / 内部调用点 | 104 / 804 | 不变 |
| 精确静态告警 | 15 | 不变 |

总CC增加7来自七个新增函数的基础路径，范围分支数不变；不能称为全局分支或游戏性能下降。两个重复Snapshot require位置归入同一快照职责，每条实际执行路径的查询与时序仍保留；唯一依赖关系没有减少。

公开入口、原判定和所有新增helper纳入现有CC15门禁。统一工程检查通过，5124/5124完整测量无缺项，15历史静态告警无新增。

本轮原六份事务/生命周期回归通过，原预算未改：`run_nested_snapshot_owner_turn`、`run_turn_reward_rollback_retain`、`owner_end_rollback`、`owner_end_retention`、`owner_end_native_cleanup`、`original_v4_lifecycle`。逐入口真实执行时间见源码指标机器证据；没有复用上个切片的通过结果。

专项由另一执行者提供12场景独立VM完整图与12项真实变异，覆盖nil/false/暂停、真实和动态fallback、快照前后读序、owner消费、晚期真实RNG消耗后的异常恢复及返回arity；最终完整图2739223字节、SHA256 `d05b686fa93c2566ef548a525c262b1597ddd45e611c4015eaa8981ec5967559`。精确源码绑定见测试附件，不把测试编写者当作本实现的最终独立审查。

本轮按主控约定不并发写Backlog、不自行提交或推送。`git diff --check`通过。精确组合HEAD独立复审、Full及实际合入push分别待验；没有候选、官方导入、ready或设备实测，不宣称整体工程阶段完成。
