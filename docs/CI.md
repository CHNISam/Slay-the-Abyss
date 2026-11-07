# 自动化检查

2026-11-07已读回 develop Ruleset 25870651：原生 Merge Queue 已开启，Squash、ALLGREEN、单条构建/合并、Strict、空 bypass。六项 Required 为 Actions 来源的 `check`、`presentation`、`engineering-posix`、`inventory`、`pr-quality`，及 Any source 的 `independent-review`。安全且完整映射的 PR 默认走双平台 Fast；核心、高风险、未知或超预算改动仍走 PR Full。`full-quality` 仍只证明完整 Full，队列组合与合后 push 始终 Full。配置读回不等于真实链路已经验收，须分别核对 Fast、入队、组合 Full、实际 squash 与 push Full。当前操作合同见[Fast准入](CI-FAST.md)。

2026-10-26起Quality/check使用GitHub-hosted `windows-2025`，固定Node 24.18.0、Pillow 12.3.0和Luacheck 1.2.0。Ubuntu的presentation和engineering-posix保留，真实执行Windows权限环境可能无法运行的符号链接/硬链接边界。三项均是正常合并前必需检查；基础设施故障的唯一应急流程见下文。

日常官方Runner无需用户电脑保持开机或联网。沿用PR215的可信develop/master手动local-special诊断入口，只有显式选择才使用旧本机；PR和日常push不会走它。未停止、注销或改动旧机器/其他项目的服务。原self-hosted设置与掉线记录可从Git历史和[工程审计](backlog-details/task-68.md)追溯。用户已明确批准停用额外Remote Task Claim任务锁；采用Backlog、独立分支/工作树、PR审查和当前SHA完整Quality。

TASK-74正式退役已停用任务锁的源码和29项专属测试，并移除两个npm入口；旧基线中这些测试占Windows约6分51秒。历史从[固定Git提交](REMOTE_TASK_CLAIMS.md)取回，当前游戏、构建和交付门禁覆盖保持。

日常使用 `npm run test:fast -- --base origin/develop` 获取 advisory 快速反馈，`npm run test:related -- --base origin/develop` 验证完整受影响集合；`--plan`只生成计划。未知输入及基础设施变更仍要求全量，fast 只报告独立可映射部分，不自动启动重复全量。自动 PR advisory 与本地 fast 共用选择器，选集、延期与零测试均显式报告，详见 [CI-FAST](CI-FAST.md)。最终集成执行完整 Quality，不能把快速层的成功当作完整验收。

完整 Windows 回归使用独立 VM 的 `rules (i/N)`，片数由[共享形状](../scripts/ci-quality-shape.mjs)定义。JS 使用 `ci-shards.mjs --shard=i/N` 按逐文件权重分配；Lua 使用 `--shard i/N`，计入前置 JS 负载后分配，JS 片内串行，Lua 按安全规则最多两个 worker、长夹具独占，普通 hosted Windows 作业保持原30分钟总预算（JS与随后Lua合计）。POSIX 的完整 JS 回归使用 `engineering-posix (i/N)`，不运行raw Lua，每个JS文件在该平台执行一次；第一片执行完整工程门禁，所有片保持原20分钟作业预算，矩阵最多同时12项。调度使用本平台实际观测成本与明确标注本地下界的逐文件最大值；未知平台才使用跨平台最大值回退。准备图片与执行使用同一平台计划。impact输出共享形状的实际矩阵，交付验证器使用同一份完整job名；任意片数均为第一片预留原平台门禁耗时。每个脚本保持独立进程、原超时和完整断言，输出按文件聚合，失败仍跑完剩余文件并非零退出。`check` 与 `engineering-posix` 分别汇总各自所有分片，失败、取消或跳过均不放行；三个必需检查名称不变，完整身份包括所有分片、三个汇总作业、impact与预期跳过的fast。schema 2的旧15作业历史合同保留，旧分片形状的绿灯不能认证当前完整集合。可信local-special手动诊断仍单片串行、保留原75分钟作业预算。当前完整校准、容量选择与实际耗时见[M7本批证据](backlog-details/M7-HOST-BATCH-20261105.md)。

PR391 的官方超时与成功日志证明早期四片、六片及八加八规划已过时：失败快返不能作为完整执行成本。现仅按各平台 `CI_FILE_TIMING success:true` 记录只升不降校准，来源身份保存在 timing JSON 元数据中；本地测量明确作为下界，例如 M3-integration 完整8/8组约403秒，不冒充 hosted/Linux 测量。f7成功完成的 raw Lua 记录继续升权后，Windows 11片已接近或越过原30分钟预算，最终采用13片；JS 加安全双 worker Lua 规划最大值约1,488秒，原1,800秒预算毛余约312秒，扣60秒安装敏感性后余约252秒；Linux 9片已含首片44秒门禁，规划最大值1,006.013秒，原1,200秒预算毛余193.987秒，扣53秒安装及 harness 敏感性后余140.987秒。这是规划代理与敏感性分析，实际完成时长仍须当前SHA官方CI验证。相较此前十一加九仅增加两份短安装，不重复执行测试文件；保留完整纯合同矩阵与真实 public 桥接检查、原作业与单fixture超时、Formal 180秒选择预算及全部断言。

本地 `npm run check` 保持完整串行；需要诊断某片时可用 `npm run test:lua -- --shard 1/4`，单片成功不代替完整检查。进程和文件系统测试保留独立临时目录。UI保护矩阵每个用例仍拥有新data/out目录，不共享可变状态。

每分支原生concurrency取消过时运行；移除跨PR的self-hosted全局队列。依赖安装使用锁文件、setup-node的npm下载缓存、prefer-offline与有界重试。保留增量Git引用、按分支有界引用缓存、pack大小摘要与128MiB异常门禁；它不是网络账单。GitHub-hosted是临时机器，其缓存无需通过本机代理下载。

合并须核对 PR 精确 head、base 和当前 attempt 的完整必要作业，通过下文 `npm run merge:auto` 的 pending→原生授权→success 握手入队。完整源码检查、平台构建、官方导入、实机与UI体验仍分层记录。日志空白时读取对应job的原始日志，不能判为通过。

2026-10-28轻量治理：develop 的原 Ruleset 仅允许 squash，并要求线性历史；master 保留 release/hotfix 的 merge 流程。既有 Licenses/inventory 加入 develop 必需检查，不新增验证作业。Quality 的 Windows 第一片在安装依赖前运行 `check-pr-history.mjs`，用事件中的精确 base/head SHA 分页读取 GitHub comparison，拒绝 PR 引入的任何合并提交（不检查 GitHub 合成 merge commit）。新依赖先独立合入 develop，再从它开始后续短分支，无需为每次基线前进重跑同步。历史读取失败或不完整会明确失败，不视作通过。它只做一次轻量 API 读取，不增加锁、轮询或另一套完整回归。

Licenses 与 Quality、Quick feedback 一样使用 GitHub 原生同引用 concurrency；新提交取消旧提交，PR 与 develop 的运行独立。已结束的 cancelled 保留历史；只有确认被更新 HEAD 或实际合入提交覆盖的非终态运行才手动取消。queued 先核对 runner/开始时间，pending 步骤表示依赖尚未执行，不能据此判断卡死。最终以最新 develop SHA 的完整必要检查成功为准。

候选构建与证据合同见[ENGINEERING.md](ENGINEERING.md)。不要通过加超时、删种子、删断言或跳过有效测试处理红灯。

## 核心分支原生保护

2026-10-26将旧Branch Protection迁为三份active Repository Rulesets：

| 规则 | 分支 | 生效要求 | 豁免 |
|---|---|---|---|
| [25870646](https://github.com/FurinyaWorks/Slay-the-Abyss/rules/25870646) | master、develop | 禁止强推、禁止删除 | 无，包含Owner |
| [25870648](https://github.com/FurinyaWorks/Slay-the-Abyss/rules/25870648) | master | 必须PR、解决讨论；不绑定未验证的CI | 无 |
| [25870651](https://github.com/FurinyaWorks/Slay-the-Abyss/rules/25870651) | develop | 必须PR、仅squash、线性历史、解决讨论、严格基线、原四项检查及independent-review/pr-quality、Squash/ALLGREEN队列 | 无 |

历史 PR 豁免曾为 CHNISam（111138384）和 v5g95m7t8m-max（337201427），`actor_type: User`、`bypass_mode: pull_request`；本轮三份规则均读回 `bypass_actors: []`，不能沿用历史豁免。防强推/删除单独成规则且不列豁免。两分支均不额外要求另一个账号审批；项目仍要求可追溯独立审查。

2026-11-04已读回 develop 的 `strict_required_status_checks_policy: true` 与六项必需 context。原四项及 full-quality 指定 GitHub Actions 15368，independent-review 为 Any source；旧 ownership 作业不恢复，原保护与 PR 豁免保留。

## GitHub 原生 Merge Queue

当前已启用原生队列，保护状态见本文开头的本轮读回。未增加第三方 App、Runner 或常驻调度服务。下列机制仍生效；后面的早期上线顺序属于历史切换步骤，不能据其重复配置或把排队当作 Full 通过。

- `quality.yml` / `licenses.yml` 监听 `merge_group(checks_requested)`，只针对 develop。impact 在非 PR 事件强制 **Full**；当前共享形状为 17 片 Windows、13 片 POSIX，加 presentation、inventory 及汇总作业。片数以 `scripts/ci-quality-shape.mjs` 为准，Fast 不能放行队列。
- 队列生成的组合提交与原 PR HEAD 不相同。现有 PR 侧 `independent-review` 仍由协调 Agent 核实真实独立审查；队列侧同名状态仅在 GitHub 原生队列准入、原六项 Required contexts 和整个组合 Full 均经校验后发布。**它不是对组合代码重新做独立人工审查**。队列的代码组合由 Full 验证。
- 队列开始时关闭准入状态；成功前复用既有 `checkoutReceipt`、共享形状的完整作业集合、实际 checkout SHA 和不可变 artifact 校验。失败、缺片、过期 run/attempt、Ruleset 漂移或无法验证的组合均不发布 success。保留 PR/push 的验证及合后收据，不能从队列绿灯反推原 PR 实机验收。
- #504 已合入迁仓身份和 #505 的严格收据继承；本切片在其上接续。队列发布同时核对实际收据的有效执行 attempt；不会用最新 run attempt 冒充未重跑首片的原执行。
- 组合放行前读取原生队列的完整成员前缀、当前组合 ref 和 develop BASE；逐 PR 检查当前 HEAD、hold、依赖落地及最新审查授权。成功授权描述追加精确 `[base:<SHA>]`，旧的无 BASE 标记状态须重新授权。下载不可变收据后重读授权与 Ruleset，要求 Squash、ALLGREEN、无 bypass；缺能力、缺页或无法唯一证明成员时关闭门禁，不猜测 GitHub 队列形状。首版最多验证 100 条完整队列成员，更多成员保持阻塞。
- GitHub 对只读 CI 隐藏 Ruleset 的 `bypass_actors`，不能将缺失字段当作空数组。已有管理员协调器必须亲见空数组，将完整规则、ID 和规范化 `updated_at` 的 SHA-256 绑定到精确 HEAD 审查状态的 `[rules:<摘要>]`。队列发布器要求该状态作者与原生入队者的不可变用户 ID 一致，并通过现有 Metadata 只读 API 重核作者仍为仓库 admin；公开规则及版本须与授权摘要完全匹配，下载后再读。该证明依赖现有可信管理员协调器，不是加密签名，也不表示 CI 亲见隐藏字段；规则变更或身份降权须重新授权。不新增令牌权限、密钥或作业。[API 字段可见性](https://docs.github.com/en/rest/repos/rules#get-a-repository-ruleset)与[用户权限读取](https://docs.github.com/en/rest/collaborators/collaborators#get-repository-permissions-for-a-user)。
- **历史上线顺序**：实现经独审与 Full 合入后，先启用 Require merge queue，再将 Required 的 `full-quality` 切换为同 Actions 来源的 `pr-quality`；读回保留 Strict、Squash、ALLGREEN、空 bypass 和原四项检查。真实样本仍须逐项保存成员、base/head、组合回归、暂停/失败剔除与合后 push 证据；不能从配置已开启推断全部验收完成。
- 先维持原 Strict 门禁和 `npm run merge:auto`，避免切换时放宽旧准入；要实现真正免更新分支的吞吐收益，还须**在演练后**适配旧协调器对固定 BASE / Strict 的假设，再决定是否关闭 Strict。禁止先关闭 Strict 或临时删除 `independent-review`/`full-quality` 来消除队列等待。
- **回退**：若需停用 Require merge queue，必须先恢复 Actions 来源的 `full-quality` 为 Required 并读回，保留原四项检查、independent-review 与 Strict；不能留下只有 PR Fast 的保护。原入口会拒绝缺少 Full 队列的 Fast 准入。组织迁移后的唯一仓库是 `FurinyaWorks/Slay-the-Abyss`。

官方依据：[GitHub Merge Queue 配置](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue)；[merge_group 事件](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#merge_group)。

## PR 自动合并准入

当前仓库为 `FurinyaWorks/Slay-the-Abyss`，固定 ID 为 `1429751262`。协调入口通过 `/repositories/1429751262` 解析当前名称，核对 settings、PR head/base 的真实 ID；不能用同名仓库或 fork 接续。迁移前的授权和 schema2/3/4/5 收据保留原文。合后验收仅可用单独的迁移见证衔接登记的旧名 `CHNISam/Slay-the-Abyss`：保存原授权文本及 SHA-256、固定 ID 的当前响应与旧名重定向响应，并核对本轮 PR/run 的仓库 ID，不能改写旧证据中的 owner。迁移前取消的 event 不作新 Full 证明，使用迁移后的新提交触发完整验证。

develop PR 的独立评审与 CI 并行。审查与准入通过后可挂起原生 Auto-merge；这只是授权，不是 `pr_passed`。PR 侧必须等原四项门禁、`independent-review`、`pr-quality` 全绿并满足严格基线才能入队，实际 squash 还须组合 Full 通过。Draft、冲突、未落地依赖、已知 CI 失败及锁定标签在启用前拒绝。

### 一次性仓库门禁配置

现有 [develop Ruleset](https://github.com/FurinyaWorks/Slay-the-Abyss/rules/25870651) 已完成配置：`independent-review`（Any source）、`pr-quality`（GitHub Actions，15368）、原四项 Actions 检查、Strict、squash-only、线性历史、已解决讨论及无 bypass 的原生队列。此处是核对入口，不要求重复配置。TASK-98 保存初始 Full 准入历史，TASK-81.2 接续 Fast 准入；任何规则变动均须保存快照、重新审查授权和读回，源码合入不代替远端规则证明。

`full-quality` 由原有 impact 作业开始时置 pending，再由原有 check 作业在 Windows、POSIX 和 presentation 全部结束后发布；不新增作业。发布器检查当前run/attempt、共享形状中全部真实作业身份/结果、PR HEAD、实际目标与合成双父；Fast永不发布success。只有impact/check增加job-scoped `statuses: write`，所有回归、LFS读取及默认权限仍只读。需要完整合并验证时使用已有 `ci:full` 标签，标签变动/ready会重新触发正常Quality；不以Fast反馈代替完整准入。

该额外 commit status 绑定受审的精确 HEAD：协调 Agent 检查独立评审记录、实际 develop ref、GitHub 合成 merge commit 的父节点和源码树、前置依赖及 Ruleset，先发布并读回自己的 `independent-review: pending`。保持该门禁关闭时显式调用 GraphQL `enablePullRequestAutoMerge`，绑定 `expectedHeadOid` 与 SQUASH，确认原生排队，再复核相同准入、最新 CI run/attempt 和 pending 状态 ID，最后写入 success 放行。即使 Full 已完成也使用同一握手；没有同步合并回退。每个 PR 同时只能有一个协调者。新 HEAD 必须重新审查、授权。**审查 JSON 不自证独立**，协调 Agent 须核对真实 reviewId 来源和未解决问题。

### 常规使用

PR 正文必须有一行 `Depends-on: none` 或 `Depends-on: #123, #456`；关联 PR 必须已确认合并。先由独立 Agent 复审并形成符合现有 `verify:delivery` 字段的 JSON（`reviewId`、`reviewedHeadSha`、`reviewedBaseSha`、`conclusion: "pass"`、`unresolved: []`）。本地在有 GitHub CLI 和已授权仓库身份的工作树中运行：

```bash
npm run merge:auto -- <PR> <independent-review.json> --dry-run
npm run merge:auto -- <PR> <independent-review.json>
```

Full 未结束时，schemaVersion 4 授权保存精确组合和 pending run，不能当作 Full 证明。Full 已完成时仍复用原 schema3 checkout artifact 完整校验。Full 发布器同时下载第一片不可变收据，核对实际 run/attempt、PR、HEAD/BASE、测试提交及双父，不能只用绿色作业元数据放行。远端动作前保存 journal；失败尝试撤销 review success 与 Auto-merge，读回须确认真实 squash 排队状态或匹配的实际提交。握手放行之前意外合并视为异常。

合并后运行 `npm run verify:delivery -- <PR> <上述证据.json> --merged`。Full 早期授权另外采集 schema5 历史 PR Full；Fast 使用 schema6 授权、schema7 PR 收据及 schema8 实际队列 Full/inventory 证据，另核独立 develop push Full。均须验证不可变 artifact、完整作业和最新 attempt、实际 squash 唯一父/树，不把合后引用伪造成合前观测。任一缺失保持 `merged_pending`，全部通过才是 `merged_passed`；历史 schema2/3 收据不改写。

暂停使用 `npm run merge:auto -- <PR> --pause`；若已在原生 Merge Queue，命令先调用 dequeue 并读回成员身份消失，再关闭并读回 Auto-merge，最后撤销审查状态。不能仅凭 `gh pr merge --disable-auto` 的退出码认定已出队。移除失败、能力未知或重新入队均不报告 paused。仅添加 hold 标签不是已确认取消。改变依赖/授权意图前先暂停，重新审查后再启用；已声明依赖必须是已纳入受审基线的提交，不允许授权未落地依赖。strict 会阻止落后的 head；更新分支形成新 head 后须有新审查状态，不自动强推、自动重基或假定旧审查仍有效。队列 BASE 变化仍要求新授权；原生 API 不提供可变正文/标签的原子条件，本流程不作此承诺。

自动入口仅用于同仓库的 develop PR，不改变 master 的 release/hotfix CI。Fork 的只读 token 不能发布新必需状态，其成果须由维护者接续到同仓库短分支后重新审查、验证；不是直接绕过门禁手动合入 fork PR。旧 run/attempt 的 planner 与 aggregate 不得覆盖新运行已写入的 pending/success。

## 一次批准的基础设施应急合并

本轮 master/develop 均无 PR bypass；下列流程保存历史批准与验证合同，不代表当前账号仍有应急合并能力。不能为赶进度自行修改保护或恢复历史豁免；正常排队与业务失败继续按原门禁处理。

正常开发仍须当前SHA的完整Quality成功。GitHub的用户豁免是能力；聊天批准是Agent使用这项能力的前提，GitHub不会识别聊天记录，也不会自动区分业务失败和基础设施故障。

1. 先确认是Harness/CI基础设施故障，保存真实运行/日志、故障原因和范围。业务断言失败、代码未验证、正常排队或赶工不是豁免理由。
2. Agent在聊天中一次性报告仓库、PR编号、目标分支、完整40位HEAD SHA、修改文件/内容范围、故障证据及独立验证结果，明确缺失的验证。Owner明确批准该PR/SHA后，保存聊天批准的原文/来源；一般性的“继续”或旧PR批准不能替代精确批准。
3. 执行前只读核对`gh api user`的真实身份、PR仍open且目标正确、HEAD仍为批准SHA、diff仍在批准范围内、无合并冲突、批准未撤回。仅使用已有的两个指定GitHub身份，不升级角色、不寻找或转交凭证。身份不可用则报告阻塞。
4. 匹配后立即用REST API绑定批准SHA合并，无需再问一次；用JSON文件传参数，避免shell插值。下例`approved-merge.json`是本次批准的临时请求，不是常驻工具：

```json
{"sha":"<Owner批准的完整HEAD SHA>","merge_method":"squash"}
```

```powershell
gh api --method PUT repos/FurinyaWorks/Slay-the-Abyss/pulls/<PR>/merge --input approved-merge.json
```

5. 仅HTTP成功且响应`merged: true`后，再读PR核对`merged`、`head.sha`、`base.ref`、`merge_commit_sha`和执行身份，保存批准/请求/响应与故障及验证证据。超时或返回不确定先读回，不能盲重试。HEAD变化、范围扩大、目标变化或批准无效时停止并重新询问；HTTP409不是让Agent换成最新SHA继续。权限拒绝时不改规则绕过，不把应急合并宣称为完整CI通过。仅在确认自己的分支无新工作后按既有规范清理。

2026-10-26隔离实测：[PR220](https://github.com/CHNISam/Slay-the-Abyss/pull/220)在无生产祖先、无工作流的临时分支上执行。Owner已授权本轮安全测试：临时失败状态使无豁免合并返回405；同一Owner在无豁免规则下也不能直接推送/强推/删除；加入两个User的PR-only豁免后上述引用操作仍422；错误SHA返回409；精确HEAD通过上述同步REST接口合并成功，无需`gh pr merge --admin`。临时规则和分支随后删除，PR保留证据。当前只有CHNISam登录，未用第二人身份或第三个普通Write账号实测，不能把规则配置读回当作这两种身份的实测；第二人Write角色已独立读回。详细证据见[任务附件](backlog-details/task-70.md)。

GitHub官方语义：[Rulesets API](https://docs.github.com/en/rest/repos/rules)、[PR Merge API及sha参数](https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request)。本轮验证的是同步`PUT /merge`；未测试异步merge-async，也未依赖管理员专用命令。

## 已审阅 PNG 的按需 LFS 读取

`ci-reviewed-lfs.mjs` 只允许 `art/cards/traveler-geo/` 中已审阅的六个精确 PNG 路径、OID 与字节数，冻结对象 payload 合计上限为 **5,983,528 字节**。本次Cleave及身份修正版Heavy共新增4对象、4,202,803字节；Armaments既有2对象保留，旧Heavy两对象仅在历史保留、不重复上传。拉取前校验 index 指针，缓存命中也不能绕过；拉取后必须验证真实 PNG 签名、完整 SHA-256 和字节数，原资产与 license 验证继续执行。指针文本不能充当已验证图片。

Quality 的图片准备与执行共用 `ci-shards.mjs` 计划；独立 LFS 工具仍保留原生 Node 分片诊断接口。只在实际承载 `reviewed-traveler-geo-assets.test.mjs` 的一个 Windows 分片及一个 POSIX 分片准备六图；Licenses 全 inventory 审计另准备一次。新增测试文件会移动分片，选择器不固定分片编号；原生 Node CLI 前后插入探针验证一致。presentation 没有这些图片依赖，不额外拉取。

checkout 默认 skip-smudge，自托管路径也显式禁用自动 smudge。仅显式 `git lfs pull --include=<六精确路径> --exclude=`，不使用 `fetch --all`、目录通配或历史全量拉取；git-lfs 3.6.1 的 pull 只扫描当前引用/index，不读取 fetchRecentAlways 的历史抓取设置。测试同时覆盖被扩大的 recent 配置和缺失的非目标对象。

使用既有 `github.token` 的只读权限，认证只放 Git 子进程环境，清除原 token 环境项且不回显 Git stderr/headers；不持久保存凭据，不增加工作流写权限。干净runner所需LFS filter仅用本次Git命令的`-c`设置，不修改持久Git配置。沿用本地 `.git/lfs/objects` 缓存及 npm/pip 现有缓存，不新增大型远程 cache。对象已在本地则不重新下载；缺失对象、超预算、OID 变化、错误内容均失败，不静默跳过。

上述上限是**允许对象的逻辑 payload**，不是 HTTP/TCP 字节、账号月度用量或费用硬限额。协议开销及额外运行不包含在内；传输关闭额外重试且有界超时。代码/离线测试不能替代远端真实下载和当前 SHA 的完整 hosted Quality/Licenses 验收。

完整执行提速记录、权重来源与实际时长对照见 [TASK-75](backlog-details/TASK-75.md)。权重只改变文件归属，不决定文件是否运行；未测新文件使用正数保守权重，日志输出 `CI_FILE_TIMING` 包含真实文件耗时，后续校准无需选测器。

托管 Windows 的原始 Lua 阶段使用 `--workers 2`，最多同时运行两个独立夹具进程；每个进程仍调用原同步 `runLua`，保留原超时和输出上限，失败后继续其余文件并使汇总失败。输出按完整夹具缓冲后写入，便于核对无重漏。JS 保持逐文件进程隔离、并发数1；本地默认及 `local-special` 仍用1个 Lua worker。分片把前置串行JS负载按worker数量折算后分配Lua，避免只平衡Lua而忽略总作业时长。Runner矩阵及required checks不变。

原始Lua的双进程只用于历史实测不足10秒的短夹具；达到10秒或未测的新夹具独占执行，再启动短夹具池。分片将独占夹具按占用两个潜在槽位计费。

2026-11-07 Owner要求停止逐秒放宽、反复整套重跑：Windows30分钟、POSIX20分钟改为性能目标，当前执行硬超时分别45/30分钟；耗时预测及60秒预留只作提示，不因超过预测扩分片或阻止交付。17/13分片、worker、安全资格、完整唯一覆盖、功能断言及严格合并门禁保持。默认Lua防卡死预算集中于`ci-timeout-policy.mjs`；调用方显式timeout和故意超时测试仍按原值执行。Sapphire每片准备、构建、Lua共用90秒防卡死预算，原21组与五片不变。保留真实耗时日志，用实际性能回退证据处理速度问题。

同一SHA的Full因临时runner故障失败时，保存日志、定位原因后可用GitHub原生`gh run rerun <run-id> --failed`只重跑失败作业；已有证据验证器按同run、同SHA、每个作业最新执行验证，保留前次成功作业。当前develop基线与tested组合也必须相同，基线推进后旧组合不能借用。业务失败必须修复，新SHA仍重新执行完整验证；不自动循环重试，不将旧失败记为成功。Fast仍要求当前attempt完整双平台，合并队列始终Full。

两项required汇总使用`!cancelled()`：普通失败或跳过依赖仍进入原严格shell断言，整轮被取消则不再排队执行汇总，避免旧run占着同PR并发组阻塞新候选。取消没有成功资格。已卡住的历史运行在核对精确过期HEAD并保留证据后，可用GitHub原生force-cancel清理，不反复取消或重跑业务。
