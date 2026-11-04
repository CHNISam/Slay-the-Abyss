# 实验回合结束职责

基线 `9a2d88dc2816a7a5613aba3035fecc0a8a4e0b1c`，完整旧 Combat Git blob `809cfe7376d3a96e442bfc03fe587f40132d5a17`。旧源固定在 `tests/fixtures/experimental-turn-end-before.json`，正常回归不读取 Git。此次只改实验结束回合区域；开回合、native 结束及构造区的原文范围在本轮证据中逐字核对。

同模块拆成六项职责，未与 native 协议合并：

| 职责 | CC | 保留的边界 |
| --- | ---: | --- |
| resetExperimentalTurnCosts | 8 | hand/draw/discard 临时费用及 Corruption 重置，exhaust 不动 |
| autoUseExperimentalEndCards | 9 | 先拍 handSize/UID，Burn 与 Regret 原逻辑；致死保留 cardInUse 并立即停止 |
| prepareExperimentalPlayerEnd | 9 | Rare、两次独立恢复 guard、成本、pre-card、自动牌、ordinary owner-end、NoDraw 顺序 |
| startExperimentalEnemyGroup | 8 | 先全体清旧 Block，再每敌 Choked、开始效果、HP/AI/队列结算 |
| runExperimentalEnemyGroup | 9 | 完整敌人引用快照，新召唤敌人不能当轮行动；保留 experimental=true 参数 |
| finishExperimentalRound | 7 | owner-end、Blur、Watcher、玩家/敌人轮末、AI/Defect、下一玩家回合 |

入口保留拒绝顺序、恢复标记消费、弃牌后终局、Vault 跳敌、enemy_turn、全敌阶段和轮末编排。入口 **CC55→15，115→23 行**；本片入口和六个 helper 的 CC 和 **55→65**，含六个新函数基础路径和四个显式编排 guard，不称为总分支减少或运行时提速。全部函数和匿名子函数接入已有 CC15 合同。

机器证据：[experimental-turn-end-20261104.json](../evidence/experimental-turn-end-20261104.json)。固定 Node24.18：

- 新增五类缺口：四牌堆费用/exhaust 边界、第二张 Regret 致死、真实 Vault 整敌图及真实 AI 流不变、Rare 回调设置恢复标记后第二 guard 生效、多个 pending 同存时拒绝优先级和零副作用。
- 独立旧/新 VM 另复用既有六个实验生命周期场景，覆盖保留暂停和单次恢复、NoDraw→Ethereal→Dark Embrace、真实 Reptomancer 召唤快照及异常完整回滚。最终完整 trace **2617440 字节**、双方 SHA256 `9ec08cd7142e378839dc9e3bc0b3fd91dbfc816dc8986f47f463bfa009bf8f67`。包含完整状态图、catalog、事件、引用别名、RNG、返回、异常和暂停队列，不排除 data/catalog。
- 六种真实源码变异均由行为断言拒绝：误清 exhaust 费用、将弃牌放到玩家结束准备之前、第二 guard 失效、live 敌列表遍历、致死 Regret 后继续、Vault 仍进入敌人阶段。初试单删显式 NoDraw fallback 会存活，因为 ordinaryOwnerEnd 已清除；不将它计为 kill，改用真正破坏 NoDraw/Ethereal 顺序的提前弃牌变异。
- 新差分/变异 2/2 通过，0 skip；native 独立差分和全部职责合同 16/16 通过，原 native raw 13 场景仍过。另十个原入口通过：end_turn_discard_order、owner_end_retention/rollback/powers/pre_cards、defect_final_end_cleanup、watcher_final_turn、watcher_early_turn_queue_order、corruption_cost、regret_boundaries。各原入口预算不变。

正常 raw 新专项仅打印五类缺口摘要，不重复执行旧六场景或输出大 trace；只有显式差分才重放旧场景。先 `npm run build:data`，再 `node --test --test-concurrency=1 tests/experimental-turn-end.test.mjs`。每 VM 保留原 30 秒预算。

## 源码范围证明与可维护性

本轮范围证明保存在证据和 Git diff，未将无关 prefix/suffix 永久冻结为行为断言。TASK-74.8 的新构造测试曾把构造前所有源码绑定旧 prefix；合法的 native/experimental 结束治理会使其误报，且没有业务行为被破坏。主控将在最终组合中用这类合法改动证明并接续修正该过度冻结约束；固定完整旧源、完整状态差分、所有语义变异和复杂度门禁继续保留。此处未修改已审构造输入，不通过删除有效行为断言制造绿灯。

LivingWall 的独立模块治理及其架构政策不在本片，最终多模块依赖/SCC 和全库指标由主控统一报告。独立精确 SHA 复审、Full 与实际合后验证另记；没有候选写入、官方导入、ready 或设备性能证据，任务不提前完成。
