# TASK-98.2：原生队列接续修复

接续 PR #508 的原 HEAD `2034c92659686e0bf2e612099e20c528df3b3703`，基于已合入 #504 的 develop `c1cf79dfa8e81189546d95277d3bb891d831ba6e`。原分支提交及历史证据保留，重放时只移除已由 #504 完整身份校验替代的名称替换，不覆盖 numeric repository identity/witness 或严格继承解析。

## 根因与修复

- Windows run 41780796248、rules (3/13) job 126416799482：精确 LF 工作流块无法匹配 CRLF checkout，历史逆投影误判。现按输入 EOL 精确反演完整块，保留其他字节；LF/CRLF、未知漂移及重复/缺块负例覆盖，不修改原 hash、断言或期限。
- 原 `--pause` 只有 Disable auto-merge，已排队时 GitHub CLI 可以直接成功退出。现先 native dequeue、核对队列成员身份消失，再关闭 Auto-merge 并再次核对，最后撤销 review；能力/身份未知、失败或重入不报告 paused。
- 队列发布原先只读取初始事件和 Full 元数据。现读取完整原生队列前缀、真实组合 ref、develop BASE 与逐 PR 当前身份、锁定标签、依赖落地和最新 review；收据下载后再次核对。成功 review 描述带精确 BASE 标记，基线变化须重新授权，不放宽旧 Strict/固定 BASE 合同。
- 队列收据原先遗漏实际 JSON attempt 和 parents 内容关联。复用 #504 的 receiptErrors 核对有效首片执行 attempt，并将实际收据 parents 与组合提交的 GitHub 父节点逐项比对；不假设队列固定父数。
- Ruleset 在下载后重读，要求六项原来源、Strict、squash-only PR、线程已解决、线性历史、SQUASH/ALLGREEN 和无 bypass。

## 本轮证据与边界

`node --test tests/merge-queue-admission.test.mjs tests/merge-queue.test.mjs tests/auto-merge.test.mjs tests/full-quality.test.mjs tests/delivery.test.mjs`：98/98。CRLF、暂停、BASE标记、错误attempt、空/错parents、原保护缺失、下载中授权/规则变化均先复现红灯，再修复通过。guidance、backlog/doctor、JavaScript syntax 与 diff whitespace 检查通过。

本地最初 mutation 检查因新工作树没有 build/lua 报 infrastructure_error；先运行既有 build:data/build:ui，再验证，不修改门槛。最终 mutation 与精确 HEAD hosted Full 以本轮实际命令/PR状态为准。

原生 schema 和只读 PR 查询已实测；dequeue 写入、队列组合布局和动态成员负例均为隔离模拟，没有启用远端 Merge Queue、改规则或实测误合并。超过100成员、缺页、共享head等无法唯一确认布局保持阻塞；真实队列小型PR演练、基线推进后的吞吐收益仍待后续管理员启用及实证，不能由本地测试代替。
