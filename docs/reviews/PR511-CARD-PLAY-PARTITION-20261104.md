# PR511 历史出牌回归预算切片

基线：`1a24acf18326df41cb5ac562c44c04ff0323fcdb`。本切片仅维护历史回归的执行分配，不证明当前游戏输入、官方导入或设备体验。

## 原始失败与定位

- [Full 41818991963 / Windows 5 job 126537438765](https://github.com/FurinyaWorks/Slay-the-Abyss/actions/runs/41818991963/job/126537438765) 的原始日志第 1040 行起记录 `battle_ui_card_play_slice_2.lua` 在 Node 24.18.0、总预算 30000ms 下 `ETIMEDOUT`，wrapper 测得 30921ms。
- 该次 stdout 已完成原 5–8 四组，`LUA_CARD_PLAY 4 passed; 0 failed` 与 `P0_CARD_PLAY_SLICE 5 8 4` 均已输出。stderr 的阶段时间为 STAGED 13174ms、PROJECTED 13297ms、BUILT 13919ms。历史快照准备、执行和退出清理共享原总预算，不能将断言输出完成算作进程成功。
- `lua-workers.mjs` 原阈值为 10000ms。该入口不在 safety map 时使用原 unknown 10000ms，因此已经独占执行；新增入口同样保留独占。无依据修改并发或调度权重。
- 同一修复前源码在本机 Node 24.18.0 原入口通过，旧 5–8 片 20049ms，STAGED 1217ms、BUILT 1894ms。本机与 hosted 准备成本不同；没有声称本机重现了原 CI 超时。

## 有界改动

沿用原出牌及 Sapphire 分片方式，将旧 5–8 片分为 5–6 与 7–8；只新增 `battle_ui_card_play_slice_5.lua` 并登记历史 runner 精确名单。五片覆盖顺序为 1–3、4、5–6、7–8、9–11，11 组无重漏。

完整 `battle_ui_card_play.lua`、原历史源码、原支持夹具和 oracle 均未修改。原始正文 SHA256LF 保持 `3f07a7f2fd72f35feac148261039616e7f43a1bb4bc5e04f11b4167f321fde0d`，当前完整入口 SHA256LF 保持 `f7e3e48abd31d6953da2fb835208505c12eaece13536690f11a4724b27b8d69e`。每片仍是包含快照准备与退出的 30000ms 总预算。

## 本轮验证

全部使用本机现有 Node 24.18.0，在独立工作树串行执行；原始输出保存在该树 `build/delivery/`。

- 先红：`card-play-contract-red.log` 因旧范围仍为 5–8 而失败；`card-play-runner-red.log` 因新增精确入口未登记而失败。均为预期断言失败。
- 定向合同：`node --test --test-concurrency=1 tests/p0-card-play-partition.test.mjs tests/historical-monster-ui-runner.test.mjs tests/lua-workers.test.mjs`，16/16 通过，0 skip。保留删断言、重复 selector、缺片、多余入口、原时间/输出/信号和外来源码拒绝；新增漏组、重复组、截短组和未知 slice6 拒绝；新 slice5 的独占执行受真实 profile 回归覆盖。
- 原始入口：每片直接执行 `node scripts/test-lua.mjs tests/lua/<entry>.lua`，无 timeout override，五片全部成功，11 组全部实际执行。对应日志为 `<entry>-green.log`。

| 入口 | 原组号 | 本机总耗时 ms |
| --- | --- | ---: |
| battle_ui_card_play | 1–3 | 6700 |
| battle_ui_card_play_slice_4 | 4 | 8142 |
| battle_ui_card_play_slice_2 | 5–6 | 6389 |
| battle_ui_card_play_slice_5 | 7–8 | 11942 |
| battle_ui_card_play_slice_3 | 9–11 | 12384 |

- 原 runner 边界与发现：`node --test --test-concurrency=1 tests/lua-shards.test.mjs tests/lua-runner-cli-continuation.test.mjs tests/lua-runner-diagnostics.test.mjs tests/lua-runner-output-buffer.test.mjs tests/test-affected.test.mjs`，125/125 通过，0 skip，日志 `card-play-runner-boundaries.log`。确认完整发现/分片无重漏、未知项保守回退、真实 CLI 失败后继续且最终非零、原 timeout 和有限输出预算不变。
- `git diff --check` 通过。

当前变更尚待独立复审与精确新 HEAD 的完整 Quality；本机通过不替代 hosted CI 成功。TASK-74 的最终记录由主控通过 Backlog CLI 统一更新，本切片不改任务状态、生产 Lua、架构配置、领域证据或队列工具。
