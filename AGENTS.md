# 项目协作规则

<!-- BACKLOG.MD GUIDELINES START -->
<!-- backlog.md-instructions-version: 1.53.0 -->
<CRITICAL_INSTRUCTION>

## Backlog.md Workflow

This project uses Backlog.md for task and project management.

**At the beginning of each conversation in this project, run `backlog instructions overview` before answering or taking action. Re-read it only if you have not read it yet in the current conversation.**

Use the overview to decide whether to search, read, create, or update Backlog tasks.

Before task lifecycle actions, read the matching detailed guide:
- `backlog instructions task-creation` before creating or splitting tasks
- `backlog instructions task-execution` before planning, changing status or assignee, adding a plan or implementation notes, or implementing task work
- `backlog instructions task-finalization` before checking acceptance criteria, writing final summaries, or moving tasks to terminal statuses

Use `backlog <command> --help` before running unfamiliar commands. Help shows options, fields, and examples.

Do not edit Backlog task, draft, document, decision, or milestone markdown files directly. Use the `backlog` CLI so metadata, relationships, and history stay consistent.

</CRITICAL_INSTRUCTION>
<!-- BACKLOG.MD GUIDELINES END -->

## Toolchain (read before building levels)

本项目是《原神》千星奇域（Miliastra Wonderland）UGC 关卡，参赛截止 2026-11-02（内部提交硬线 2026-10-30）。

- **交接说明（当前进度/阻塞/上手命令）：`docs/HANDOFF.md`** — 接手先看这个
- **产品范围、削减优先级与报告纪律：`docs/SCOPE.md`**
- **工具链唯一事实来源：`docs/TOOLCHAIN.md`**（官方客户端 / 千星沙箱 / miliastra MCP 的路径、版本、环境变量、调用顺序）。
- 千星奇域开发技能：`.codebuddy/skills/miliastra-wonderland/SKILL.md`。
- 用了 miliastra MCP 时：先读资源 `miliastra://workflow` 和 `miliastra://platform-rules`；`MILIASTRA_ALLOW_LIVE_WRITE` 保持 `0`；编译通过 / 写进存档 / 游戏里验证过要分开报告；发布由人完成。

## Approved Art and UI Baseline

- 完整游戏冒烟与取证按 `docs/P0-SMOKE.md`。自动试玩必须显式 `clientScriptLog: true`；每次新导入后由工具确保订阅，不能把反复手动勾选当成用户职责。测试版启动异常须在界面显示诊断；没有本轮日志/ready证据不得判通过，不得复用旧日志冒充本轮。
- UI交付先对照 `docs/design/PLATFORM_PARITY.md`，核心信息与操作按 `docs/design/ui-acceptance.json` 逐屏实机审查；宣称UI验收通过前运行 `npm run verify:ui -- <候选.gil>`。它校验候选hash、批准稿参考、实机截图和关键检查项；`npm run check`通过不替代此门禁。装饰/动效可记录降级或延后，生命、费用、意图、价格等核心信息不得被静默省略。

- 用户已确认 [PR #19](https://github.com/CHNISam/Slay-the-Abyss/pull/19) 为整个游戏的美术与界面设计依据；已合入 `develop`（`91ae349`）。
- 实现前必读 `docs/design/UI_DESIGN.md`，对照 `docs/design/prototype/index.html` 与 `docs/design/screens/`；颜色、字号、间距、布局、图标和动效统一读取 `data/presentation/ui_theme.json`，Lua 使用 `npm run build:theme` 生成的 `abyss_theme`。
- 尽可能按批准稿还原。平台能力导致的差异须记录原因、采用的降级和验证状态，不能自行改换视觉方向。拖牌按规范分档落地，C 档点选始终保留。
- 原型中的规则、数值与演示数据不作为游戏逻辑来源；界面只读核心状态、发命令，实际内容以 `data/` 和 Lua 核心为准。
- 原型完成不代表平台实现或实机通过；按 `docs/SCOPE.md` 分层报告。

## Git Branch Workflow (GitFlow-lite)

- `master` = production. Tagged releases only. Never commit directly.
- `develop` = integration / development base. Default branch for daily work.
- Feature work: `feat/<slug>` branched from `develop`, merged back into `develop` via PR.
- Release: `release/<version>` from `develop` → merge into `master` (tag) **and** back into `develop`.
- Hotfix: `hotfix/<slug>` from `master` → merge into `master` (tag) **and** back into `develop`.
- Commits follow Conventional Commits: `feat|fix|chore|docs|refactor|test|perf|ci(scope): description`.
- Squash merge feature → `develop`; merge commit for `release/*` and `hotfix/*` → `master`.
- Never rewrite shared history; force-push only your own branch with `--force-with-lease`.
- Finish integration promptly: after a feature PR merges, verify its head has no new work, delete the remote branch, prune remote references, and remove its clean local worktree and branch in the same session. GitHub automatic branch deletion is enabled.
- Preserve dirty worktrees and independent commits; record why they remain. For squash merges, verify the merged PR head and retain recoverable history before forcing local branch deletion.
- Put review fixes and closeout notes into the existing task PR where practical. Do not leave completed review branches or create another branch solely to report an already merged change.

## Milestone 顺序验收

- 成果关口与证据标准见 `docs/MILESTONES.md`；按 M0 → M1 → M2 → M3 → M4 → M5 → M6 逐成果验收，仅最早未完成关口作为主冲刺；依赖满足的离线任务与 M4 品质工作可并行。M2=17层正常实机通关，M3=冻结首发清单并逐项齐备，M4=正式作品品质，M5=10/29同一RC冻结验收，M6=10/30人工投稿归档。
- 跨阶段任务拆成可独立验收的本地实现、平台导入/实测和发布工作。合并且证据充分的切片及时 Done，必要平台阻塞仍留原关口。
- 所有必要任务完成后立即收口；可选研究不阻塞首发。新建前查重，优先复用，重复/过时任务用原生取消/归档机制保留历史。
- 不能通过降低核心标准或改状态制造完成；记录具体缺失证据和下一动作，避免无证据重复尝试。
- CI核对PR当前SHA，各作业成功后按规范合并。单人项目不要求分支保护，不将套餐限制列作阻塞。

- 初代《杀戮尖塔》PC A0规则、数值、概率、AI和结算顺序贯穿相关任务，不另设规则一致性Milestone。E1–E5、双人合作和成就为独立候选，不加入10/30必过项；TASK-45保持平台权限阻塞，不主动要求账号升级。


## 任务写给人看

- 标题直接说要做什么；说明用日常中文，验收项一次说一件事。别在任务首页堆命令、缩写、版本编号、迁移历史和代理执行说明。
- 技术要求、执行方案和历史证据放在 docs/backlog-details/ 的对应附件，任务保留附件链接。执行时仍须读附件，精简文字不降低原验收标准。
- 里程碑内的必做任务全部完成、验收齐全后，及时用 Backlog CLI 归档里程碑；任务状态和完成证据保留。

## 免费模型委派（默认分工）

- Codex负责总体决策、任务拆分、关键代码、集成和最终验收；低风险、重复性强、可独立验收的任务优先交给OpenCode + DeepSeek。单次委派写清目标、允许修改的文件、禁止事项、验收标准和验证命令；遵守本仓库Backlog与工作树流程，不覆盖其他Agent的改动。
- 使用原生CLI：`opencode run --model opencode/deepseek-v4.1-flash-free --format json`；先用`opencode models opencode --verbose`核对零定价与variants，默认使用支持的最高推理档位（当前`--variant max`；无variants时不传）。Flash模型的长任务先拆成短步骤，每段只交必要上下文、验证并交接后再继续，避免一次承包长链路；关键设计与高风险逻辑由Codex处理。不依赖界面默认模型；本轮普通CLI成功、`--pure`调用返回403，默认不加`--pure`。
- 用进程级`OPENCODE_CONFIG_CONTENT`将主模型和`small_model`固定为同一免费模型、`enabled_providers`只保留`opencode`、模型白名单只保留该免费ID，并限制本任务工具/文件权限；用`debug config`核对生效值但仅输出白名单字段，禁止输出凭证。临时覆盖用完即恢复，不持久改写全局配置。
- 不自动回退到收费模型。免费服务不可用或连续两次未达验收时停止该路径，由Codex接管并报告；OpenRouter仅在用户明确授权后试用当时已核价的免费模型，不用`auto`路由冒充免费模型。
- Codex必须检查JSON事件中的真实工具调用、成果/文件Diff和相关验证；退出码0、模型自报完成或普通文本里的工具标签都不代表通过。只向执行者提供必要上下文，保存脱敏证据；不另建调度框架。
- 已验证的最小调用配置、权限合并注意点与本轮证据见[委派记录](docs/backlog-details/TASK-51.md)。
