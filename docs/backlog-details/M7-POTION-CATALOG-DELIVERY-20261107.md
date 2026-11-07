# Potion callback 与 Run catalogue 组合交付

## 范围与源码身份

本地独立分支从已公开 draft #548 的 `0bc050279aae90b8e423a0d02f0c8ca56bf0331b` 建立，叠入已独审 Potion `e2ecb75160065d01535413704179c0c6c5ab6fa8`；共同 develop 基线为 `2ad07111e3d5b5cb52b4229860b3b780941e29a9`。只新增 Potion 三个生产 owner 与对应 architecture 边界；保留 #548 的 Run 生产、原证据和 71327ms floor。与共同基线相比，实际生产并集只有 Run catalogue、RelicHooks、RunPotionCandidate 和新 PotionHooks。

共享 static governance 与 JS/Lua inventory 取并集。Potion 四 owner（含完整 architecture）字节未变，因此保留原 source proof/reader；完整 333 源 gzip、Git blob、旧 source 链及 retirement 保护不改。新 CI timing 外层以 `tests/helpers/potion-callback-planning-before.json` 保存 #548 完整 timing 前源，逐字重建仅追加 Potion floor 的当前源后，才接回原历史逆投影；不以单刷 after hash 取代完整链。

## 完整指标及行为

| 指标 | develop 2ad | #548 Run | 本组合 |
| --- | ---: | ---: | ---: |
| 模块 / 完整测量 | 333 / 5386 | 333 / 5401 | 334 / 5403 |
| Combat SCC 成员 / 内部位置 / 唯一对 | 81 / 623 / 400 | 81 / 623 / 400 | 81 / 623 / 400 |
| Session SCC 成员 / 内部位置 / 唯一对 | 15 / 62 / 41 | 15 / 62 / 41 | 14 / 60 / 39 |
| CC >15 / >30 / 最大 | 237 / 58 / 75 | 235 / 56 / 75 | 235 / 56 / 75 |

组合即时图仍无环；含延迟导入的完整图为 334 模块、1923 引用位置。重新运行完整工程采集，5403/5403 测量、1807 governed、14 条原静态告警、零新增告警及门槛放宽。CC 改善属于 #548，Potion 本次只减少 Session 一员，不将其归为 Potion 的 CC 收益。

组合 Potion 完整文件实际 10/10、无取消/跳过；两个独立 VM 的 31 个完整图检查点逐字一致，每侧 23,319,377 字节。保留冷加载、双向动态 callback 槽、nil/false/callable table、保存函数引用、返回 tuple、错误、队列及 rollback；三个真实可解析语义负控被原断言检出。当前原生 raw 药水四 fixture 全通过。

#548 的 14 项、264 检查点/每侧 48,319,157 字节使用其原精确已审来源，不重复重型回放。Run 生产及其直接 fixture/helper/测试字节不变；共享 static 已对组合重新采集，不能把原 #548 VM 收据改称本组合的新一次执行。

## 规划来源与风险

新 floor 为 **29232ms**，来自本组合一次完整成功 Node runner 的 `29231.664342ms` 向上取整。它不是外层进程 wall；本组合外层 wall 未单独采集。原 Potion 完整成功外层 wall `26661.777321ms`（floor 26662）及原 TAP `26590.905967ms` 分别完整保留，绝不等同或补偿换算。机器收据为 `docs/evidence/potion-callback-planning-20261107.json`，含两次完整原日志与真实来源、所有 333 before/334 after/13 generated 源身份。

原九 floors 与 Run 71327 保持不变，共十一 floors。Hosted Windows/Linux 观测表、unknown costs、raw worker safety、17/13 分片、worker=2、并发上限、预算、60s reserve 均不变；未带入 Actor timing 或新 RunMax 诊断。

实际 discover 为 **749 JS / 1403 Lua**。按现行完整分配和 60s reserve：

- Windows：1,718,183ms；旧 30 分钟预算余 81,817ms。
- POSIX：1,199,633ms；旧 20 分钟预算仅余 **367ms**，虽静态 guard 本轮通过，仍几乎没有预测误差空间，不能据此保证 Hosted 完成。
- #541 提议的 Windows45/POSIX30 分钟未在本树实施；按相同工作量分别余 981,817ms / 600,367ms。必须和旧预算分别报告。

floor 仅是完整成功本地观测的规划下限，不是 Hosted 测量、性能比较或进程 deadline 保证。完整规划列表与每片负载在机器组合证据及 `build/potion-catalog-delivery/planning.json`。

## 验证与未完成项

- Potion 完整行为 10；source/inventory/CI 29；原历史 source 链 34；M7 最外层 source 1，共 74 项本轮最终 JS 通过，未重复旧 #548 重型回放。
- raw `potion_candidate_boundaries`、`potion_health`、`potion_fairy`、`potion_callback_contract` 四文件通过。
- 完整 AST/SCC/CC + static、Backlog doctor、verify:backlog、diff whitespace 通过。原始早期计时口径断言失败保留于日志，纠正区别 TAP 与 wall 后最终通过，未降低阈值或断言覆盖。
- 本轮仅本地 commit，等待独立精确 HEAD/base/tree 复审。没有 push、PR、评论、全仓 Full、merge、官方导入、ready 或用户设备验证；任务 owner/status/AC 保持，不能关闭 M7 总目标。
