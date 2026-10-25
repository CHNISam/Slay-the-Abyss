# TASK-55 远端执行权实现与迁移

用户授权的P0工程修复；不是TASK-54任务编号治理。Backlog仍负责任务状态/里程碑/Assignee，执行所有权只由独立Git协调分支负责。新任务Assignee为Furinya，历史负责人不批量改写；Executor是claim内agent/session。

## 实现

- `scripts/remote-task-claim.mjs`：Node22内置库CLI，`coord/task-claims:claims.json`，普通非强制push实现CAS。每次拒推后重新读取并执行完整冲突/所有权检查，最多六次；远端未推进或不可达即失败，不复用旧写入覆盖新状态。
- `claim/renew/check/release/list/adopt/recover/expand`：独立会话、分支、规范化路径、共享模块、父子ID互斥，全局递增generation及过期租约。Backlog的大小写/数字前导零别名归一化后互斥。释放保留墓碑，接管替换generation，旧会话不得续租/释放/提交。
- `claim --path`、`worktree`、`run`：先领取再建独立树；父receipt不被子覆盖。受控命令先检查/续租，定期续租，远端失败终止整个子进程树，退出后复核。目标存在即拒绝，不重置或清理历史工作。
- `install`：共享Git元数据中保留稳定runtime，覆盖该仓库所有本地worktree的pre-commit、prepare-commit-msg、pre-push、pre-merge-commit及pre-rebase门禁。已有第三方hooks时拒绝覆盖。prepare-commit-msg也防止普通`--no-verify`绕过失权检查。
- pre-push CAS授权精确SHA，Quality/ownership远端复核有效租约与SHA；`integrate`核对当前PR/HEAD/分支/全绿CI及远端所有权后，带`--match-head-commit` squash至develop。同步上游只接受远端develop真实SHA的`sync-base`。Quality/check新增仓库级串行组，避免未来不同PR同时启动全量检查。

串行组使用GitHub原生`queue: max`，避免默认单pending槽位让后来的独立PR取消前一个等待作业；保留原有按ref取消过时头的workflow设置。配置依据[GitHub并发文档](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)，不另建调度器。

## 验证

测试先于实现，在真实临时bare remote上运行独立Node进程和独立clone。首轮缺少CLI导致失败；8组、10组、11组、13组迭代均实际复验。推送HEAD别名正例曾失败，修正后通过；不放宽互斥或超时标准。

最终14组覆盖强制接收端竞争屏障、同任务唯一胜者、无冲突CAS合并、父子/路径/模块/任务ID别名、租约接管旧令牌、非所有者释放、并发续租/释放、断网/拒推、未知迁移/adopt、范围扩张、真实commit/push/远端PR授权、异常进程树终止/恢复、受控worktree、协调者释放后的恢复和独立子执行者。没有用mock证明Git原子性。实际执行结果、源码hash及范围见[验证记录](../evidence/task-claim-validation-20261025.json)。完整质量检查只在当前SHA CI中串行运行；相关本地检查不冒充全量CI通过。

## 迁移现状和限制

[只读快照](../evidence/task-claim-migration-20261025.json)记录14个可访问工作树、26项本地In Progress记录（含本任务）、远端分支、每个dirty路径/hash和各分支独立修改。38条旧任务/工作树保守隔离；根目录8处原修改、m2-exit未解冲突、诅咒/药水等在途改动均未覆盖、重置或清理。快照不承诺后续其他会话未推进。

远端初始化已成功推送并读回，TASK-55 generation=1。迁移保持paused，外部机器和其他会话未知。唯一安装任务的bootstrapOverlaps显式保留，旧执行者没有被假定空闲；有真实停止/交付证据才可逐条resolve/adopt，全部旧入口和外部机器核实后才可open。不开放批量并行。安装任务释放后，后续协调者可以原范围、新session恢复协调职责；不能扩大例外或绕过其他有效claim。

本机共享门禁已安装；远端新clone必须install并通过run启动。未升级的外部机器、蓄意绕过hooks/API、时钟偏差、任意工具直接写入，以及远端merge与另一ref验证间的短窗口仍是边界。该机制保证合作执行者的执行权互斥与失权拒绝，不宣称服务器权限隔离或所有旧会话已经迁移完成。

免费模型沿用TASK-51的限额暂停，无恢复依据，本轮Codex直接完成关键协议；未增加模型调用或调度框架。工程交付后M3仍是游戏主线，不改变内容池、规则、美术、里程碑或任何在途游戏实现。
