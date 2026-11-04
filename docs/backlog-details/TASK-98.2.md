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

## 原生 arm 读回与失败清理接续

从 `7eea66caaf97a546c5d84a498f72b241611162da` 隔离接续，未带入主控对 TASK-98/98.1/99 的收口修改。

官方 [GraphQL 合同](https://docs.github.com/en/graphql/reference/pulls#enablepullrequestautomergeinput) 明确队列忽略 enable mutation 的 mergeMethod，由队列合并策略决定；[队列操作合同](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/merging-a-pull-request-with-a-merge-queue)区分等待 Auto-merge 与已入队。旧 arm 只接受 REST `auto_merge.merge_method=squash`，且失败清理仅 Disable auto-merge，不能证明已入队条目消失。

- 只有实际读取到 `merge_queue` 规则才允许队列读回；原非队列路径仍要求 REST squash。原六项 Required 及来源、Strict、squash-only PR、线程与线性历史均保留，队列另要求 SQUASH/ALLGREEN、无 bypass，放行前规则移除也拒绝。
- 队列路径核对 GraphQL 的固定仓库 ID、PR node/number、当前 HEAD/develop、真实队列策略与 entry 关联；接受已启用等待或精确已入队，兼容已入队后 REST `auto_merge:null`。已观测 entry/queue 的替换拒绝，不以合成 entry.headCommit 冒充 PR HEAD。
- arm 失败与显式 pause 共用 native dequeue、对应 entry 收据及移除读回，再关闭 Auto-merge 并重读两面；错误收据、无效移除、重新入队与能力未知均保留 cancellation uncertain。放行前意外 merged 仍拒绝。

先补4组回归，旧源码35通过/4失败；修复后再补条目替换回归，39通过/1失败，修复后通过。最终固定 Node24.18.0 标准子进程隔离执行原五组加 governance/PR history 共113/113；guidance、verify:backlog、doctor、两份JS syntax和diff whitespace通过。新树起初缺luaparse，复用原工作树已安装依赖后执行；未变更锁文件或测试预算。

本轮只读真实 PR508 GraphQL 查询接受全部新增字段：当前 HEAD 为原 `7eea66ca...`、`isMergeQueueEnabled:false`、`isInMergeQueue:false`、autoMergeRequest/mergeQueue/entry均null。这只证明 schema 与暂停状态读回；queued/null、dequeue写入及故障均仍是隔离回归，不声称真实队列已启用或演练完成。当前补丁本地提交后由主控另行独审、更新508及验证精确HEAD完整CI；最终AC保持未完成。
