# PR #496 排队准入边界

> 历史调查记录，保留原结论的适用范围。2026-11-04 Owner 明确要求保留并启用自动合并；TASK-98 接续实现采用 strict、原 check 作业发布的 Full 状态与显式 pause，删除了“可变标签/正文原子撤销”的过强承诺。新的授权/验收分离、测试和部署记录以 [启用计划](../plans/2026-11-04-auto-merge-enable.md)、[当前 CI 合同](../CI.md)及本轮真实证据为准。下述调查不表示撤回功能。

2026-11-03 本轮只读调查；没有修改 Ruleset、写审核 status、启用 Auto-merge 或合并真实 PR。

## 现场事实

- `gh api user` 返回登录身份 CHNISam；仓库 API 返回 `owner.type=User`、`visibility=public`。
- Ruleset 25870651 为 active branch rule，包含 develop、exclude 为空。
- 四项 Required checks 仍为 check、presentation、engineering-posix、inventory，来源均为 GitHub Actions 15368；strict=false。没有 independent-review 或 merge_queue 规则。
- 实际 GraphQL schema introspection 中，EnablePullRequestAutoMergeInput 与 MergePullRequestInput 均只有 expectedHeadOid 作为源码前置条件；没有 expectedBaseOid、正文摘要、标签、依赖版本或失效时间字段。
- Quality 目前订阅 pull_request、develop/master push 和 workflow_dispatch。新增事件处理器本身不能让本机读取、status 写入和 GitHub merge 成为同一个原子操作。

## 为什么不能用撤销循环保证安全

最小顺序：先验证 HEAD H / BASE B 的完整 Full CI 与独立评审，然后写入 H 的 success 并启用原生 Auto-merge。最后一次读取之后，正文、hold 标签或依赖声明改变，H 不变；也可能 develop 从 B 前移到 B2。原生合并先于 webhook/轮询撤销发生时，撤销已经太晚。

本轮本地 mock 分别复现上述四种后续变化：函数已经返回 auto-merge-requested，HEAD 不变，模型中的 native request 仍存在，也没有追加 failure status 或 disable-auto 调用。这是代码控制流负例，不是真实 PR 合并实测。

官方语义支持上述限制：

- [Auto-merge GraphQL 输入](https://docs.github.com/en/graphql/reference/pulls#enablepullrequestautomergeinput)只提供 expectedHeadOid；同页 direct merge 也没有 BASE 或 PR 元数据比较条件。
- [REST 异步合并](https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request-asynchronously)的 sha 同样只绑定 HEAD；异步请求不是原子元数据准入接口。
- [Commit statuses](https://docs.github.com/en/rest/commits/statuses#about-commit-statuses)绑定提交；同一个 HEAD 的正文/标签修改不会生成新的提交身份。
- [Loose/strict required checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#require-status-checks-to-pass-before-merging)明确允许 loose 分支在未追上目标分支时合并。strict=true 可以加强 BASE 保护，但不能绑定正文或 hold 标签。
- [Merge Queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue)可验证最新组合，但文档限定组织所有的仓库。当前个人仓库不满足资格；即使迁移，队列本身也没有原子正文/标签前置条件。

因此，仅追加 independent-review 并保持 strict=false，无法兑现“排队期间任意上述变化都在合并前可靠失效”的完整合同。这个结论是基于公开 API 语义和本地竞态负例的推断，不声称已经通过真实合并验证。

## 当前处理与最小方案

- 保持 Draft/HOLD；保留现有 Full CI 和保护，现网 non-strict 配置继续失败关闭。不能把 strict=true 下能够启用的路径称为持续准入已完成。
- 最小安全范围是只做完整 Full CI / 独立评审的只读预审，不留下原生排队授权。监督下重新检查后同步合并可以缩短等待窗口，但依然不是 BASE/正文/标签的原子保证，不能冒充满足本需求。
- 若继续要求真正的队列合同，需要另行决定可用的服务端强制机制及其权限边界：最新组合需平台强制检查；作为授权依据的依赖声明等需绑定不可变提交；可变 hold 的生效语义也必须有明确的强制入口。迁移组织、改规则、安装服务或收紧写权限均超出本轮操作范围，不能自行执行。仅安装 webhook 撤销器不足以证明完整保证。

## 本轮具体代码修复

最后一次 Full collector 返回 current 时，旧实现只比较 HEAD/base.sha，可能在目标已改为 master 后仍先写 success 和调用 --auto。现在在每次写入前的 PR 读回中比较完整未合并身份：PR number、open/merged/draft/mergeable、HEAD 仓库及 SHA、develop 目标及 BASE SHA、合成 merge SHA、正文、标签与 changed_files。末次目标、PR number、fork 或 merge SHA 改变的负例要求任何 POST 或 gh pr 动作发生前失败。

这项修复覆盖启用前的已观察变化，不消除最后读取之后的队列生命周期窗口。
