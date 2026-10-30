# 两个 CI 汇总作业的 Runner 调整

## 真实基线

固定基线为 develop `9293405dfa07be95c632ac1a15cc4ebc2fb3034b`，Quality [run 41001153119](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/41001153119)，attempt 1，成功。以下使用该运行 GitHub jobs API 的 `created_at`、`started_at`、`completed_at`，时区 UTC；排队是 started-created，执行是 completed-started，不把两者混算。源响应由本轮主控保存于 `.artifacts/round3/baseline-ci-jobs.json`，该本地产物不随源码提交。

| 作业 | 创建 | 开始 | 完成 | 排队 | 执行 |
| --- | --- | --- | --- | --- | --- |
| impact | 04:07:48 | 04:07:51 | 04:08:05 | 3秒 | 14秒 |
| engineering-posix | 04:23:26 | 04:37:35 | 04:37:38 | 849秒 | 3秒 |
| check | 04:40:18 | 04:50:00 | 04:50:03 | 582秒 | 3秒 |

Windows八片排队分别为2/293/467/408/504/509/298/2秒，执行为1430/1416/1465/1384/1134/1409/854/1452秒。POSIX四片排队3/4/58/203秒，执行917/603/564/552秒。最后回归片在04:40:18完成，最终 check 在04:50:03完成，汇总尾部增加585秒。impact 门前仅约18秒，不是本轮主要瓶颈。

从最早 job 创建到最终完成为42分15秒；工作流创建到结束为主控采集的42分16秒，两者起点口径不同。即使假定汇总无排队，回归片完成仍需约32分30秒，不能据此宣布 Full≤30分钟。

## 本轮修改

仅将 `check` 与 `engineering-posix` 两个 shell-only 汇总作业的 `runs-on` 从 `ubuntu-24.04` 改为 `ubuntu-slim`。名称、needs、always 条件、实际判定命令、2分钟预算、权限及完整测试矩阵保持原样。交付仍使用原17项作业合同，无需更新 Required Check 名称或 ruleset。

[GitHub 官方 Runner 说明](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)将 `ubuntu-slim` 定位于轻量自动化和短作业：1 CPU、5 GB内存、14 GB SSD，在共享 VM 上提供临时隔离容器。它不支持需要特权的挂载、Docker-in-Docker及低层内核操作；最长15分钟。两个汇总仅使用 Bash `test`，无需这些能力，保留的2分钟预算低于平台上限。

官方同时说明 slim 沿用标准托管并发模型。本轮是降低轻作业资源需求的最小实施，不能承诺不同资源池必然缩短排队；须按当前SHA真实运行验证。presentation保持原POSIX环境，它承担文件系统边界测试，基线仅执行11秒；重测试矩阵同样不迁移。

## 验证合同

`tests/helpers/ci-runtime-workflow.mjs` 仅在两个精确 job 边界中逆转唯一 runner 行，再进入既有路由逆转与冻结 hash 检查。新增测试记录修改前完整逆转结果的 SHA-256，证明调整后恢复同一合同；timeout、steps、always、缺失/重复 runner 等负例必须拒绝或保持不同 hash。原有真实 Shell 测试继续验证缺失、失败、取消、跳过与错误路由不能通过。

定向验证包含 summary-runners、impact、windows-shards、posix-shards、runtime、delivery、downloads、reviewed-lfs。最终仍需当前提交完整 Quality，并读回两汇总的实际 runner 标签、队列与执行时间；本地测试不证明 hosted 排队改善，也不替代官方完整验收。

2026-10-30本地使用与CI相同的 Node 24.18.0，以上八个文件共59项测试全部通过，失败/取消/跳过均为0，耗时49.377秒；两项新增测试已在实施前观察到预期失败。JS语法及 `git diff --check` 通过。初次默认Node22运行不支持既有探针所需的 `--test-isolation=none`，不计为通过；改用固定24.18.0后保留原测试重新验证。此次未执行官方托管运行、未改分支保护或提交合并。
