# 自动化检查

2026-10-26起Quality/check使用GitHub-hosted `windows-2025`，固定Node 24.18.0、Pillow 12.3.0和Luacheck 1.2.0。Ubuntu的presentation和engineering-posix保留，真实执行Windows权限环境可能无法运行的符号链接/硬链接边界。三项均是正常合并前必需检查；基础设施故障的唯一应急流程见下文。

日常官方Runner无需用户电脑保持开机或联网。沿用PR215的可信develop/master手动local-special诊断入口，只有显式选择才使用旧本机；PR和日常push不会走它。未停止、注销或改动旧机器/其他项目的服务。原self-hosted设置与掉线记录可从Git历史和[工程审计](backlog-details/task-68.md)追溯。用户已明确批准停用额外Remote Task Claim任务锁；采用Backlog、独立分支/工作树、PR审查和当前SHA完整Quality。

日常使用 `npm run test:fast -- --base origin/develop` 获取快速反馈，`npm run test:related -- --base origin/develop`验证相关集成；`--plan`只列出受影响集合。未知输入及基础设施变更回退全量。最终执行 `npm run check`，不能把快速层的成功当作完整验收。

完整 Windows 回归分成四个独立 VM 的 `rules (i/4)`。JS 使用 Node 原生 `--test-shard=i/4`；Lua 使用 `--shard i/4`，每片内部均串行。每个脚本保持独立进程、原超时和完整断言，输出按文件聚合，失败仍跑完剩余文件并非零退出。`check` 汇总所有分片，失败、取消或跳过均不放行；三个必需检查名称不变。可信 local-special 手动诊断仍单片串行、保留原75分钟作业预算。细节与实际耗时见 [TASK-74](backlog-details/TASK-74.md)。

本地 `npm run check` 保持完整串行；需要诊断某片时可用 `npm run test:lua -- --shard 1/4`，单片成功不代替完整检查。进程和文件系统测试保留独立临时目录。UI保护矩阵每个用例仍拥有新data/out目录，不共享可变状态。

每分支原生concurrency取消过时运行；移除跨PR的self-hosted全局队列。依赖安装使用锁文件、setup-node的npm下载缓存、prefer-offline与有界重试。保留增量Git引用、按分支有界引用缓存、pack大小摘要与128MiB异常门禁；它不是网络账单。GitHub-hosted是临时机器，其缓存无需通过本机代理下载。

合并须核对PR精确head、base和当前attempt的三个必需作业，使用GitHub原生 `gh pr merge --squash --match-head-commit <SHA>`。完整源码检查、平台构建、官方导入、实机与UI体验仍分层记录。日志空白时读取对应job的原始日志，不能判为通过。

候选构建与证据合同见[ENGINEERING.md](ENGINEERING.md)。不要通过加超时、删种子、删断言或跳过有效测试处理红灯。

## 核心分支原生保护

2026-10-26将旧Branch Protection迁为三份active Repository Rulesets：

| 规则 | 分支 | 生效要求 | 豁免 |
|---|---|---|---|
| [25870646](https://github.com/CHNISam/Slay-the-Abyss/rules/25870646) | master、develop | 禁止强推、禁止删除 | 无，包含Owner |
| [25870648](https://github.com/CHNISam/Slay-the-Abyss/rules/25870648) | master | 必须PR、解决讨论；不绑定未验证的CI | 两个指定个人，仅PR |
| [25870651](https://github.com/CHNISam/Slay-the-Abyss/rules/25870651) | develop | 必须PR、解决讨论、三个Quality检查（GitHub Actions app 15368） | 两个指定个人，仅PR |

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
