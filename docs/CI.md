# 自动化检查

2026-10-26起Quality/check使用GitHub-hosted `windows-2025`，固定Node 24.18.0、Pillow 12.3.0和Luacheck 1.2.0。Ubuntu的presentation和engineering-posix保留，真实执行Windows权限环境可能无法运行的符号链接/硬链接边界。三项均是正常合并前必需检查；基础设施故障的唯一应急流程见下文。

日常官方Runner无需用户电脑保持开机或联网。沿用PR215的可信develop/master手动local-special诊断入口，只有显式选择才使用旧本机；PR和日常push不会走它。未停止、注销或改动旧机器/其他项目的服务。原self-hosted设置与掉线记录可从Git历史和[工程审计](backlog-details/task-68.md)追溯。用户已明确批准停用额外Remote Task Claim任务锁；采用Backlog、独立分支/工作树、PR审查和当前SHA完整Quality。

TASK-74正式退役已停用任务锁的源码和29项专属测试，并移除两个npm入口；旧基线中这些测试占Windows约6分51秒。历史从[固定Git提交](REMOTE_TASK_CLAIMS.md)取回，当前游戏、构建和交付门禁覆盖保持。

日常使用 `npm run test:fast -- --base origin/develop` 获取 advisory 快速反馈，`npm run test:related -- --base origin/develop` 验证完整受影响集合；`--plan`只生成计划。未知输入及基础设施变更仍要求全量，fast 只报告独立可映射部分，不自动启动重复全量。自动 PR advisory 与本地 fast 共用选择器，选集、延期与零测试均显式报告，详见 [CI-FAST](CI-FAST.md)。最终集成执行完整 Quality，不能把快速层的成功当作完整验收。

完整 Windows 回归分成八个独立 VM 的 `rules (i/8)`。JS 使用 `ci-shards.mjs --shard=i/8` 按逐文件实测耗时分配；Lua 使用 `--shard i/8`，计入前置 JS 负载后分配，每片内部均串行。POSIX 的完整 JS 回归分成四个独立 VM 的 `engineering-posix (i/4)`，使用同一加权分配器和 POSIX 独立耗时表，每个文件在该平台执行一次，每片保留完整工程门禁与原20分钟作业预算。每个脚本保持独立进程、原超时和完整断言，输出按文件聚合，失败仍跑完剩余文件并非零退出。`check` 与 `engineering-posix` 分别汇总各自所有分片，失败、取消或跳过均不放行；三个必需检查名称不变，完整托管Quality共15个作业。可信 local-special 手动诊断仍单片串行、保留原75分钟作业预算。细节与实际耗时见 [TASK-74](backlog-details/TASK-74.md)。

PR252的运行40524983643中，POSIX旧第一片975项JS全部通过，耗时1192.218秒；随后工程门禁亦通过，但加上安装与取证使作业越过20分钟总预算。四片继续使用隔离VM和片内串行，减少单VM分配到的测试文件数；不增加作业或单fixture超时，也不删测试。新分片的实际完成时长仍须当前SHA官方CI验证。

本地 `npm run check` 保持完整串行；需要诊断某片时可用 `npm run test:lua -- --shard 1/4`，单片成功不代替完整检查。进程和文件系统测试保留独立临时目录。UI保护矩阵每个用例仍拥有新data/out目录，不共享可变状态。

每分支原生concurrency取消过时运行；移除跨PR的self-hosted全局队列。依赖安装使用锁文件、setup-node的npm下载缓存、prefer-offline与有界重试。保留增量Git引用、按分支有界引用缓存、pack大小摘要与128MiB异常门禁；它不是网络账单。GitHub-hosted是临时机器，其缓存无需通过本机代理下载。

合并须核对PR精确head、base和当前attempt的三个必需作业，使用GitHub原生 `gh pr merge --squash --match-head-commit <SHA>`。完整源码检查、平台构建、官方导入、实机与UI体验仍分层记录。日志空白时读取对应job的原始日志，不能判为通过。

2026-10-28轻量治理：develop 的原 Ruleset 仅允许 squash，并要求线性历史；master 保留 release/hotfix 的 merge 流程。既有 Licenses/inventory 加入 develop 必需检查，不新增验证作业。Quality 的 Windows 第一片在安装依赖前运行 `check-pr-history.mjs`，用事件中的精确 base/head SHA 分页读取 GitHub comparison，拒绝 PR 引入的任何合并提交（不检查 GitHub 合成 merge commit）。新依赖先独立合入 develop，再从它开始后续短分支，无需为每次基线前进重跑同步。历史读取失败或不完整会明确失败，不视作通过。它只做一次轻量 API 读取，不增加锁、轮询或另一套完整回归。

Licenses 与 Quality、Quick feedback 一样使用 GitHub 原生同引用 concurrency；新提交取消旧提交，PR 与 develop 的运行独立。已结束的 cancelled 保留历史；只有确认被更新 HEAD 或实际合入提交覆盖的非终态运行才手动取消。queued 先核对 runner/开始时间，pending 步骤表示依赖尚未执行，不能据此判断卡死。最终以最新 develop SHA 的完整必要检查成功为准。

候选构建与证据合同见[ENGINEERING.md](ENGINEERING.md)。不要通过加超时、删种子、删断言或跳过有效测试处理红灯。

## 核心分支原生保护

2026-10-26将旧Branch Protection迁为三份active Repository Rulesets：

| 规则 | 分支 | 生效要求 | 豁免 |
|---|---|---|---|
| [25870646](https://github.com/CHNISam/Slay-the-Abyss/rules/25870646) | master、develop | 禁止强推、禁止删除 | 无，包含Owner |
| [25870648](https://github.com/CHNISam/Slay-the-Abyss/rules/25870648) | master | 必须PR、解决讨论；不绑定未验证的CI | 两个指定个人，仅PR |
| [25870651](https://github.com/CHNISam/Slay-the-Abyss/rules/25870651) | develop | 必须PR、仅squash、线性历史、解决讨论、三个Quality检查及inventory（GitHub Actions app 15368） | 两个指定个人，仅PR |

两个个人分别为CHNISam（111138384）和v5g95m7t8m-max（337201427），均为`actor_type: User`、`bypass_mode: pull_request`。第二人仍为Write，无Write/Admin角色级豁免。防强推/删除单独成规则且不列豁免，避免PR豁免扩大为引用破坏权限。两分支均不额外要求他人批准；这是强制PR，不是额外审批系统。

develop的`strict_required_status_checks_policy: false`，不用为启动测试反复同步最新develop。合并前仍核对精确HEAD、当前base和真实合并冲突。旧`ownership`作业已删除，不再Required；新规则先active并读回，再删除旧保护，没有保护真空。日后发现CI作业改名应更新实际Required名称，不能留永久等待的检查。

## 一次批准的基础设施应急合并

正常开发仍须当前SHA的完整Quality成功。GitHub的用户豁免是能力；聊天批准是Agent使用这项能力的前提，GitHub不会识别聊天记录，也不会自动区分业务失败和基础设施故障。

1. 先确认是Harness/CI基础设施故障，保存真实运行/日志、故障原因和范围。业务断言失败、代码未验证、正常排队或赶工不是豁免理由。
2. Agent在聊天中一次性报告仓库、PR编号、目标分支、完整40位HEAD SHA、修改文件/内容范围、故障证据及独立验证结果，明确缺失的验证。Owner明确批准该PR/SHA后，保存聊天批准的原文/来源；一般性的“继续”或旧PR批准不能替代精确批准。
3. 执行前只读核对`gh api user`的真实身份、PR仍open且目标正确、HEAD仍为批准SHA、diff仍在批准范围内、无合并冲突、批准未撤回。仅使用已有的两个指定GitHub身份，不升级角色、不寻找或转交凭证。身份不可用则报告阻塞。
4. 匹配后立即用REST API绑定批准SHA合并，无需再问一次；用JSON文件传参数，避免shell插值。下例`approved-merge.json`是本次批准的临时请求，不是常驻工具：

```json
{"sha":"<Owner批准的完整HEAD SHA>","merge_method":"squash"}
```

```powershell
gh api --method PUT repos/CHNISam/Slay-the-Abyss/pulls/<PR>/merge --input approved-merge.json
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

原始Lua的双进程只用于历史实测不足10秒的短夹具；达到10秒或未测的新夹具独占执行，再启动短夹具池。完整run40635392726证明无条件双进程会触及原有30/120秒预算，因此不放宽超时，以调度独占解决竞争；分片将独占夹具按占用两个潜在槽位计费。
