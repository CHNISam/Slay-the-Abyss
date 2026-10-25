# 远端任务执行权

Backlog 管任务状态、里程碑和 Assignee。新工作 Assignee 保持 **Furinya**；Executor 是认领中的 `agent + session`，不改历史负责人。执行权唯一事实在 `origin` 的 **`coord/task-claims`** 分支 `claims.json`，不要手改或强推这个分支。

Node 22 + Git 即可运行，无数据库和后台服务。所有本地 Codex、远端 Agent、OpenCode 和 Sub-Agent 使用同一个入口。子执行者必须独立任务、独立 session、独立分支/工作树及认领；不能借用父级 receipt。父子任务不能同时拥有执行权；父执行者先释放，再由子领取，或保留一个所有者串行完成。

## 开始工作

先运行 Backlog instructions、查重/读任务、读取本页，再只读检查远端与工作树。没有明确路径范围时禁止开发。每个执行会话生成 UUID，不能使用 GitHub 用户名作为会话身份，也不能让两个进程共用同一个 session。

```powershell
$env:TASK_CLAIM_SESSION = (node scripts/remote-task-claim.mjs session | ConvertFrom-Json).session
node scripts/remote-task-claim.mjs list
```

将 spec 放在被忽略的 `build/claim-spec.json`，示例（ID、session、分支与范围均须替换为实际值）：

```json
{
  "task": "TASK-123.1",
  "agent": "codex-local",
  "session": "本会话生成的UUID",
  "branch": "feat/example",
  "scope": {
    "paths": ["src/lua/example.lua", "tests/lua/example.lua"],
    "modules": ["example"]
  },
  "leaseSeconds": 1800
}
```

路径是仓库相对文件或目录前缀，**没有 glob**。大小写、斜杠与 Unicode 规范化后比较；路径遍历、Windows 别名和符号链接写入不受支持。`modules` 必须明确给出（确无共享模块才用空数组）；例如两个不同文件都修改战斗结算，应同报 `combat`。路径相交、共享模块同名、同一分支或 Task ID 的点分父子关系任一成立即冲突。不要靠谎报模块或拆任务绕过冲突。

```powershell
node scripts/remote-task-claim.mjs claim --spec build/claim-spec.json
# 领取的分支尚未checkout时，先用受控worktree入口（拒绝覆盖已存在目录）：
node scripts/remote-task-claim.mjs worktree --path .worktrees/example
Set-Location .worktrees/example
node scripts/remote-task-claim.mjs check
node scripts/remote-task-claim.mjs install
```

推荐直接 `claim --spec build/claim-spec.json --path .worktrees/example`：先远端CAS领取，成功后才建树并将receipt只写到目标树。父工作树已有认领时，子执行者必须用自己的session/spec和这个入口；父receipt保持原样，父子/范围冲突照样拒绝。认领成功但建树中断时保留远端可到期租约和已有文件，不回滚、删除或覆盖历史工作；先list再按恢复流程处理。

也可以在已存在的独立工作树 `claim/adopt`；它不会清理该树。每个树只保存一个 receipt，位于该树的 Git 元数据中，不进入提交。receipt 不是授权替代物：每次都要重新访问远端，并匹配环境中的 session、generation、分支及未过期租约。新机器 clone 后须运行 `install`；本地安装会给同仓库全部工作树启用 hooks，旧树无 receipt 时提交/推送会失败。已有其他 hooks 时安装拒绝覆盖，须先人工保留并组合门禁。

## 开发、续租和交付

开始开发、扩大范围、提交、推送、集成和完成 Backlog 前必须检查远端。所有执行器/代理/会改变成果的命令通过 `run` 启动，退出码非零就停止后续操作；它先确认所有权、检查已有脏路径、续租，再启动子进程，长任务定期续租，失败会终止子进程树，结束后再次核验。Windows 的 `.cmd` 经明确的 shell 运行：

```powershell
node scripts/remote-task-claim.mjs run -- codex
node scripts/remote-task-claim.mjs run -- powershell -NoProfile -Command 'npm run check'
# OpenCode仍遵守免费模型锁定、权限边界及限额暂停规则；用run包住原生命令。
node scripts/remote-task-claim.mjs renew
node scripts/remote-task-claim.mjs check --paths dirty
node scripts/remote-task-claim.mjs expand --scope build/expanded-scope.json
node scripts/remote-task-claim.mjs check
git add <本任务文件>
git commit -m 'fix(scope): description'
git push -u origin feat/example
```

扩大范围文件只包含完整的新 `paths/modules` 对象。先 `expand` 成功，再修改新范围；它不允许静默缩小范围。`check` 也应在每批编辑或直接工具写入前执行，人工/Agent 工具写入不可能由普通 Git hook 拦截。不能使用 `--no-verify`、覆盖 hooksPath 或直接 API 合并来绕过门禁。

pre-commit 核对所有权及暂存路径；pre-push 核对所有权、整个分支成果相对基线的路径和目标分支，只准推自己的工作分支，禁止直接推 develop/master、删除分支或协调分支。推送前还通过CAS记录当前HEAD的授权，Quality/ownership在远端重新验证PR精确SHA仍有唯一有效租约；绕过本地hook的普通新提交不能通过此检查。失权不能通过这些入口提交/推送。远端不可达、权限不足、CAS/确认失败都退出非零；绝不把本地状态或推送超时当成领取成功。

同步上游使用普通非破坏性 Git fetch/merge，保留已有工作；随后用已合入 HEAD 的最新远端 develop SHA 更新比较基线，不能用任意提交隐藏越界改动：

```powershell
node scripts/remote-task-claim.mjs sync-base --base <当前origin/develop的SHA>
node scripts/remote-task-claim.mjs integrate --pr <PR号> --sha <当前HEAD>
node scripts/remote-task-claim.mjs check
# 通过Backlog CLI记录真实验收与完成；不改Assignee约定
node scripts/remote-task-claim.mjs release
node scripts/remote-task-claim.mjs list
```

若同步develop产生冲突，先保留并暂存真实解决结果，再运行`sync-base`，最后提交merge。该入口仅接受远端develop精确SHA作为唯一MERGE_HEAD，要求冲突全部解决，并检查暂存树相对该上游只有认领范围内的差异；继承上游原文件无需扩大范围，越界改动解决结果会被拒绝。更新基线后应完成该merge；若中断则保留工作并先完成同步，不能借回退基线隐藏修改。pre-commit检查整个暂存成果相对已验证基线的路径。

`integrate` 只合入 develop；校验工作分支、本地 HEAD、PR SHA 与所有当前 CI 检查成功，续租并再次读取远端后，以 `--match-head-commit` squash merge。完成/放弃均释放，保留 generation 墓碑和 Git 历史；其他 session 不能续租或释放。清理分支/树仍按 AGENTS 的备份、干净状态和 merged-head 核验规则，由协调者收口，不清理其他人的工作。

## 过期、中断和迁移

过期立刻失去受控操作权。`recover --spec ... --evidence '旧执行树已停止/失联调查记录'` 仅接受过期或已释放的 Task，产生更大的 generation；旧 receipt 即使同账号、同分支也永久失效。普通新 Task 可以利用已过期的范围，但旧任务仍然不能通过检查。中断发生在推送成功、receipt 落盘之前也可能留下租约：先 `list`，确认 session，再等待到期并 recover，不能强推或删除远端“锁”。CAS 拒绝后重新读取完整远端状态，重新核查冲突/所有权，最多六次；网络/权限/receive-hook 拒绝且远端未推进就立即失败。

本次初始化快照见 [迁移盘点](evidence/task-claim-migration-20261025.json)。所有 In Progress 任务、在途分支和脏文件均保留；工作树干净或分支较旧不能证明旧执行者停止。其他机器与会话明确为未知。协调分支初始为 **paused**：fresh claim 一律拒绝；仅 TASK-55 的单一安装执行者可 bootstrap，重叠的旧工作记录在 bootstrapOverlaps 并继续隔离，不获得新执行权。此例外只存在首次初始化，不可用于普通领取。

现有工作由实际执行者先停止旧执行树、核对并保留 diff，再建立含实际 task/session/branch/完整范围的 spec：

```powershell
node scripts/remote-task-claim.mjs adopt --spec build/adopt-spec.json --reservation <远端隔离项ID> --evidence '旧session已停止、保留的HEAD和diff核对记录'
```

adopt 必须匹配隔离 Task/分支，覆盖完整旧范围，并检查其他活动认领和未知隔离项，不能借迁移偷取有效租约。粗粒度的旧任务/工作树隔离可能互相冲突，必须先由协调者核实实际归属和停止证据；不能为方便开发直接消掉未知项。

只有 bootstrap 协调者可逐项 `migration-resolve --reservation ID --evidence ...` 记录旧工作已交付/停止且历史保留；原记录不会删除。TASK-55 完成释放后，可从 `list.released` 取原范围，以新session和完整原范围 `recover` 协调职责；仅沿用首次记录的bootstrap隔离例外，不允许扩范围，也不能越过其他有效claim。这样释放安装任务不会造成迁移死锁。其他机器全部核实并升级入口后，才可 `migration-resolve --external-reviewed yes --evidence ...`，最后 `migration-open --evidence ...`。任何未知项仍在则拒绝开放。**本次交付不声称所有旧会话已迁移，不自动开放大规模并行。** 返回 M3 时先迁移所需旧工作并消除隔离冲突。

## 保证边界

普通 Git 非强制 ref 更新是原子 CAS；跨任务的冲突检查和写入在同一状态提交中，双进程不能分别写出相交有效执行权。每次接管使用全局递增 generation，续租不改变身份。机器时钟须同步 UTC；这是客户端租约，不是服务器授时/对抗恶意机器的系统。时间异常、远端协调分支被人为强推、故意复用session或绕过hooks都不在保证内。

Git hooks、受控命令和远端读取阻止合作执行者失权后的新操作；不能撤销已经写出的文件，不能拦截任意编辑器/外部 GitHub API，不能将GitHub merge与另一Git ref更新变成同一事务。检查与外部操作之间存在很小的时间窗口；长命令按心跳发现失权，强杀父进程时应停止整个子进程树。不要把这套轻量协作门禁当作服务器权限系统。未升级的其他机器仍是明确风险，迁移暂停继续生效。

运行真实并发验收：`node --test --test-concurrency=1 tests/remote-task-claim.test.mjs`。测试创建临时 bare remote、三个独立clone和独立Node进程，含接收端屏障，无共享工作树或原子性 mock；清理只针对测试自己创建的系统临时目录。
