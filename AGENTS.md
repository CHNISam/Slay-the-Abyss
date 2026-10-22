
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
