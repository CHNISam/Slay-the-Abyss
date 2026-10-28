# 测试双入口去重交接（用户要求立即停止）

随后用户另行授权创建PR。此文件保留停止时快照；下面“未提交/未创建PR”是当时状态。后续仅发布草稿供交接审查，不代表问题修复、验证通过或允许合并。

## 当前状态

- **未完成，验证未通过，未提交、未推送、未创建 PR、未合并。** 不可直接提交当前候选。
- 独立工作树：`F:/New folder/.worktrees/deduplicate-lua-tests`
- 分支：`feat/deduplicate-lua-tests`
- HEAD：`257d9e0c9a4f2b680b8d1fc07c26025451eb5ac8`；当前有约396项工作树变更，包含大量未暂存的 Lua 路径迁移。
- 本轮验证进程已结束。没有使用鼠标、键盘或官方客户端。
- Backlog：**TASK-76，In Progress**。原本本地创建的TASK-75与并行任务冲突，已用原生demote/promote迁到76；远端TASK-75及其附件没有覆盖。验收项均未勾选。
- 根工作区原有脏文件及其他工作树未处理。

## 用户约束

主要改tests，不改CI工作流、选测器、交付验证器；保留所有原断言、不同角色/种子/参数覆盖。无法证明等价的不要删除。用户授权本任务本地验证通过后用合法PR-only bypass先合develop，再完整CI，失败立即修复。**当前不满足合并条件。**

## 已做工作

1. 初始最新develop为`8fe1b9fabaf296903d199aaaf616d98557f72c6b`。建立独立工作树后快进至上述257d；机器检查确认这段仅CI集成，没有修改生产Lua、数据或Lua测试场景，runLua函数体相同。
2. 冻结初始974个顶层Lua、59个共享Lua支持文件及JS包装器摘要。通过原始CI日志、实际调用及耗时排查双入口。
3. **候选**迁移250个Lua到`tests/fixtures/js-owned/tests/lua/`，保留原JS包装器所有断言。嵌套目录保留`tests/lua/<文件>`后缀，以保留原runner的专用超时和战斗布局注入。只改路径，不改runner。
4. 添加`tests/fixtures/lua-ownership.json`、`tests/helpers/lua-ownership.mjs`和`tests/lua-ownership.test.mjs`。首次三个新测试及完整历史断言审计通过：974原入口、59支持文件、131个受影响JS包装器。**之后还原了三个必需路径，当前清单需重生成，不能沿用这次通过声明。**
5. 新增`tests/benchmarks/lua-entry-duplication.mjs`。同机Node24.18.0、无观测钩子的三例（battle_ui_slice_6、slice_7、map_no_crossings）负载：原6次调用187374.0396ms，保留3次101151.9152ms，输出摘要逐项一致。这仅是三例本地串行负载，**不是CI墙钟，也不是整套改善比例**。

## 必须保留的有效/受约束入口

- `game_ui.lua`及`ending_history_host.lua`有`source=clock`，不能按同输入去重；完整宿主两次成功输出确实不同。
- 注入BEGGAR_SOURCE_CONTRACT、ABYSS_RELIC_FIXTURE、ABYSS_TREASURE_FIXTURE的临时桥接，SPLIT_FAMILY变体、四项语义变异及不同角色/种子/分片均保留。
- 意图组六个入口原样保留：普通入口满批次335项中334过、1项`intent_artifact_playback.lua`原30s超时；单独普通入口曾整组通过，回放19.85s。不可把满批次说成全通过，不提高预算，不删回放。
- 不修改交付验证器。它硬编码依赖`tests/lua/black_star.lua`、`lizard_tail_run.lua`、`lizard_tail_persistence.lua`。已从HEAD还原这三个原路径；其owned副本暂时仍在，最终计划必须排除它们并清理副本。

## 当前失败与未完成项（优先处理）

1. **develop已经前进**：最后只读查询为`4a3167808006f67c0c267b453fb188fb6e370a0c`，本地未同步。它包含选测器/worker改动及PR282正式退役自定义公告。PR282删除`tests/lua/game_ui_release_notes.lua`和`tests/release-notes-ui.test.mjs`，修改game_ui、presentation trace及theme。不能用旧候选复活已退役公告；需在最新base重新核对迁移集合、快照与断言证明，保留他人变更。
2. **候选复验失败**：`.artifacts/dedup/js-after24-wall.json`记录status=1、2667115.8288ms。完整失败详情在`js-after24.log`末尾。存在路径引用遗漏、冻结源码合同和超时等失败，尚未全部分析修复。
3. 黑星负例起初被缺失原路径的ENOENT遮住，而不是命中FakeRare断言。三个验证器必需路径已还原，但尚未完成最终定向复验。
4. `tests/card-help-release-slices.test.mjs`的目录发现与映射前缀已改到owned，两项原合同已实际复测通过。生成脚本也已补入该静态依赖。
5. `tests/pr238-lua-budget-slices.test.mjs`是混合raw/owned合同，仍把`'tests/lua/' + slice.file`直接与已迁移entry比较，需要只修路径解析，保留全部原断言。不能整体替换raw根，因为另外三个家族仍是raw。
6. 大量库存/事件/证据门禁失败：**data/release中的证据路径也指向原Lua文件**，最初迁移只更新了tests。`verify-launch-content.mjs`在139/146等行检查这些路径存在。尚未改任何data文件；需决定纯路径元数据调整是否在授权范围，或保留被契约绑定的路径。不能改验证器逻辑或放松断言。
7. 还须检查独立源码锁、冻结hash等其它失败。新ownership门禁通过不代表旧合同已通过。
8. 完整CI、最新HEAD/范围核对、PR-only合并与收尾清理全部未做。

## 随机输入审计

源码发现`abyss_external_random`以时间初始化独立熵，主要用于Courier彩色卡补货；固定run.seed不能证明其固定。已有显式replay路径必须区分。

- 仅测试用探针：`tests/helpers/lua-entropy-audit.lua`（与`.artifacts/dedup/entropy-audit.lua`一致）。包装external.begin/snapshot/setReplayState及new_run_seed.next，只记录是否用未固定时间，不注入RNG值。尾部诊断由临时Node观测层移除，不改变原JS收到的stdout。
- 真实Lua校准已通过：固定回放输出、返回数量不变；未固定熵及失败的replay注入能标记。
- `.artifacts/dedup/js-after24.jsonl`每条记录含`entropyAudit/entropyComplete/unseededExternal`。检查时只针对实际迁移的记录；已保留raw的clock入口不能误伤同组固定输入。
- 到已读的中途记录，尚未发现owned候选使用未固定外部熵。**完整结果未最终审查。**

## 证据与临时脚本

都在本工作树`.artifacts/dedup/`，尚未归档到根工作区；**删除工作树前必须保留这些文件**。

- `frozen-before.json`：原源码摘要；`integration-proof.json`：8fe→257d输入和runner函数体相同。
- `ci-before-*.log`、`ci-before-jobs.json`：历史成功Quality40623057222（源码7993034，972raw），只作参考，不当当前源码证据或CI改善。
- `js-ordinary-before.log/jsonl/*-wall.json`：普通子进程基线，335项334过1超时，9个生成模块摘要逐调用记录。
- `js-after24.log/jsonl/*-wall.json`：候选复验与随机源追踪，当前失败。
- `canonical-inputs.json`：257d构建出的9个标准生成模块摘要。
- `benchmark-before/after.json`及log：实际三例负载；`benchmark-clock-mismatch.log`：不能去重完整宿主的失败对照。
- 初期`js-baseline24*`使用NODE_OPTIONS，钩子继承到Lua子进程，耗时有干扰；已修为仅node:test的--import。初始观测不作加速证据，原日志保留。
- `migrate.mjs`：生成器，当前已补排除三个验证器必需文件及意图组、clock文件；待最新base与其它合同修正。不要盲跑覆盖当前改动。
- `reset-migration.mjs`：只从**当前HEAD**恢复自己计划中的原tests文件，再删除自己owned副本。尚未执行；在换base前理解其行为并保留diff。不可覆盖他人改动。
- `report.mjs`：未完成，尚未生成最终`docs/reviews/LUA-ENTRY-DEDUP-20261028.json`；当前依赖旧base及未通过复验数据，不能当完成报告。
- `docs/backlog-details/TASK-76.md`是进行中草稿，部分中间描述需随真实结果更正。

Node24路径：`F:/New folder/build/tools/node-v24.18.0-win-x64/node.exe`。系统Node22不是CI版本。node:test/Node子进程在沙箱内会EPERM，之前通过工具的require_escalated运行。不要把权限失败当业务失败。

## 建议接手顺序

先保存当前diff和本地日志，审查复验全部失败；在最新develop隔离集成，避免复活公告。修正路径消费者并保留禁止改的验证器，重新生成最终ownership清单，严格比较活跃原断言、全部角色/种子范围、生成输入与实际结果。只有本任务必要验证真的通过，才按用户授权创建PR并绑定精确HEAD合法合并，再核对完整CI。当前不要发布、不要宣称完成。
