# 消除 JS 包装器与 raw Lua 的重复执行

本任务从 `origin/develop@8fe1b9fabaf296903d199aaaf616d98557f72c6b` 的独立 worktree 开始。原有 974 个顶层 Lua 入口、292 个 JS 测试文件和 59 个共享 Lua 支持文件，均在修改前记录摘要。仅调整测试的入口归属和路径，保留每个原始断言、角色、种子、分片及反例。CI 工作流、选测器、交付验证器和生产源码不修改。

基线收集期间，其他任务合入 CI 调度改动并占用了 TASK-75。本任务通过 Backlog 原生命令改为 TASK-76，再快进至 `257d9e0c9a4f2b680b8d1fc07c26025451eb5ac8`。机器核对从原起点到该集成点的生产 Lua、数据和所有 Lua 场景 diff 为空，实际 `runLua` 函数体逐字节相同；因此原运行输入仍成立。更新后的 runner 合同由其原有反向规范化测试验证，本任务不更改该实现。

## 等价判断与保留边界

只有实际观察到 JS 包装器直接调用同一顶层 Lua 文件、使用同一工作目录、默认 Lua 环境、相同用例参数且运行成功，才转交给 JS 入口。包装器的退出码、输出、向量和分区断言继续执行。每个 Lua 进程仍由原 `runLua` 创建，不缓存结果、不复用 Lua VM、不合并不同输入。

| 情形 | 处理与理由 |
| --- | --- |
| 相同文件、输入、环境和参数 | 移到 `tests/fixtures/js-owned/tests/lua/`，保留 JS 包装器，移除一次 raw 自动发现的重复运行 |
| UI 分片、角色、基础/升级版、种子矩阵 | 每个不同输入文件分别保留；只消除同一文件的第二个入口，不合并不同分片 |
| Beggar 的 `BEGGAR_SOURCE_CONTRACT` | JS 临时入口注入合同，raw 使用默认值，两者保留 |
| 遗物池的 `ABYSS_RELIC_FIXTURE` | JS 注入独立目录、队列向量和首尾抽取轨迹，raw 默认检查保留 |
| 宝箱的 `ABYSS_TREASURE_FIXTURE` | JS 注入独立 Java 向量，raw 默认检查保留 |
| `SPLIT_FAMILY` | 酸液/尖刺环境参数不同，原有执行保留 |
| 原始回归与语义变异 | 输入的生产实现及选择用例不同，四项变异配置及原入口保持原样 |
| runner 格式/失败诊断 | 使用替身验证调用合同，不是真实重复执行，保持原测试 |
| 临时生成的 oracle、非法数据反例、无法证明等价的入口 | 完整保留；预期非零退出仍由原 JS 断言核对 |
| `game_ui.lua`、`ending_history_host.lua` | 实际输出包含 `source=clock`；完整宿主的两次成功运行输出摘要也不同。不同有效种子不视为同输入，两者双入口保留 |

新路径保留 `tests/lua/<文件>` 后缀，是为了沿用原 runner 的既有 `endsWith` 配置。战斗 UI 的布局注入、宿主和地图属性的专用超时均不改动。新增测试使用进程替身，对每项迁移逐项比较原路径与新路径的实际 runner 环境、超时、缓冲区和注入布局；它不会再执行一次真实 Lua。

## 无漏测的证据

`tests/fixtures/lua-ownership.json` 记录每个原入口及其新归属。`tests/lua-ownership.test.mjs` 校验原始集合准确划分为 raw 与 JS 两组，每个入口仍存在、迁移后不再被 raw 重复发现、JS 所有者仍存在。

本次完整历史审计对所有原 Lua 入口、共享支持文件和改到的 JS 包装器比较修改前摘要。只对路径迁移和行尾作反向规范化；PR259 的共享支持读取位置、PR266 的混合 raw/JS 分区根目录、ending-history 中固定输入与时钟输入各自的路径，有明确列出的等价路径反向变换。原用例选择、循环、种子、断言和反例未删改。已有的冻结源码、分区和输出检查也继续执行。

常规 CI 门禁约束本次转交的 Lua、JS 包装器、改路径的参数 JSON 和原入口归属，不冻结未改动的 raw/共享支持文件今后的内容，也允许新增 raw 测试。完整历史摘要用于本 PR 的一次性证据审计；后续有意扩展已转交的测试时，应随审查同步相应快照。

本地还逐调用比较 Node 24 基线与迁移后的完整 stdout/stderr、退出结果、所属测试、环境和超时。每项输出摘要、输出行数和实际耗时存入 `docs/reviews/LUA-ENTRY-DEDUP-20261028.json`。完整输出留在本地脱敏日志中。

## 耗时口径与复现

用仓库已有的便携 Node 24.18.0，与 CI 固定版本一致，不替换系统 Node。首次 Node 22 记录存在原超时且已中断，不作为通过或加速证据。计时验收串行执行，不把并行负载下的失败计为改善。

初始 Node 24 观测通过 NODE_OPTIONS 注册 ESM 钩子，Lua 子进程也继承了该配置。这轮 290 项中 289 通过、意图回放超过原 30 秒预算；同观测模式重试仍超时。修正为仅给 node:test 传 --import 后，Lua 子进程使用普通入口，原意图组完整通过、0skip，回放19.85秒。初始耗时仅作带观测的热点线索，不与普通入口耗时作加速比；两次超时保留为观测结果，不据此宣称原测试有缺陷。性能验收的 before/after 基准两侧均无观测钩子。

真实本地负载基准使用三个重例，修改前重放原 raw 和 JS 的两次相同 `runLua` 调用，修改后执行保留的一次，并核对完整输出摘要。它测量这三个 fixture 的串行执行负载，包含每次 Lua 子进程开销；不包含整套构建和 JS 静态断言开销，也不是 CI 墙钟。

```powershell
node tests/benchmarks/lua-entry-duplication.mjs before .artifacts/dedup/benchmark-before.json
# 在转交入口后执行：
node tests/benchmarks/lua-entry-duplication.mjs after .artifacts/dedup/benchmark-after.json .artifacts/dedup/benchmark-before.json
node --test tests/lua-ownership.test.mjs
node tests/helpers/lua-ownership.mjs
```

`before` 必须在修改前的 worktree 运行。两次均使用同一 Node 24 可执行文件、同机串行、相同源码及原超时。不得将各 fixture 的累计 runner 时间替代整套 CI 的开始/结束时间。

历史完整 Quality [40623057222](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40623057222) 的八份 Windows 原始日志已取回，用于定位耗时热点。其源码为 `7993034fe09167d6157ebc4008016cefe4102b25`，共有 972 个 raw 入口，与本任务起点不同；因此历史耗时只作参考，不能据此宣称本 PR 的 CI 加速比。最终以当前本地基线排序和真实后续 CI 结果报告。

## 验证与集成记录

本地基线、迁移后结果、真实计时和最终 PR/HEAD 在取得实际结果后补入本节。本页当前不是完成声明。

用户在本次聊天明确紧急授权：本任务本地验证通过即可先经 PR 合入 develop，再接受完整 CI；使用现有合法 PR-only bypass，核对精确 HEAD 与文件范围，不修改分支保护，失败立即修复。此授权只用于本任务。完整 CI 尚未成功时不得报告为完整 CI 通过。
