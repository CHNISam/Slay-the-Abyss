# 项目协作规则

## 许可与商业权利

用户2026-10-26明确禁止第三方未经授权商用，项目方保留商业化权利。根目录LICENSE是项目原创内容的非商业源码许可；公开仓库不授予商业使用权。修改或分发须保留许可与声明，不得擅自换成MIT、Apache等允许商业使用的许可；第三方内容继续遵循其各自许可，不覆盖第三方权利。

工程检查与证据合同见 `docs/ENGINEERING.md`。新增核心 Lua 模块须在 `config/architecture.json` 分类；`npm run check` 包含架构、固定版本 Luacheck 和四项关键语义变异。候选构建与实机验收仍分层记录；当前 SHA 的 Quality 全部作业成功才可合并。工程工具不得覆盖既有构建的脚本清理、结算图复用、BGM参数或实机输入窗口规则。

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

## 代理流量与持续成本（P0）

- 流量控制为最高优先级，同时保持简单，见 `docs/NETWORK_BUDGET.md`。CI保留推进的Git引用，新增pack超过32MiB警告、128MiB失败，npm优先缓存并限制重试。检查入口 `npm run check:network`。
- 下载异常先查原因，不盲重跑、删缓存、抬高阈值或引入大缓存往返。新增pack大小不是机场账单；源码通过与实际CI生效分开报告。不新增常驻监控或修改其他项目/代理全局开关。

## Toolchain (read before building levels)

### 占用鼠标键盘前先协调

- 任何会发送鼠标/键盘输入、抢占或切换前台窗口的操作（包括官方预览、导入、自动试玩、探针及故障恢复），开始前必须说明要做什么、何时开始、预计占用多久，并等待用户明确确认本次可用时间窗口。
- 用户要求修复、验证或继续任务，不等于已经让出鼠标键盘；历史测试授权不自动延续到下一轮。未取得本次时间窗口时，只做不抢占输入和前台的离线工作。
- 仅在约定窗口内操作；用户正在处理其他事情、要求停止或窗口到期时，立即停止发送输入并归还控制。需要延长或重新占用时重新协调，不能反复抢回。
- 自动试玩脚本、MCP helper 和子执行者同样遵守；启动前核对没有另一轮测试占用输入，结束后明确告知已归还鼠标键盘。

本项目是《原神》千星奇域（Miliastra Wonderland）UGC 关卡，参赛截止 2026-11-02（内部提交硬线 2026-10-30）。

- **交接说明（当前进度/阻塞/上手命令）：`docs/HANDOFF.md`** — 接手先看这个
- **产品范围、削减优先级与报告纪律：`docs/SCOPE.md`**
- **工具链唯一事实来源：`docs/TOOLCHAIN.md`**（官方客户端 / 千星沙箱 / miliastra MCP 的路径、版本、环境变量、调用顺序）。
- 千星奇域开发技能：`.codebuddy/skills/miliastra-wonderland/SKILL.md`。
- 用了 miliastra MCP 时：先读资源 `miliastra://workflow` 和 `miliastra://platform-rules`；`MILIASTRA_ALLOW_LIVE_WRITE` 保持 `0`；编译通过 / 写进存档 / 游戏里验证过要分开报告；发布由人完成。

## 桌面输入与实机测试窗口

- 任何可能移动鼠标、输入键盘、抢焦点或切前台的操作（包括启动/激活客户端或沙箱、自动导入和实机试玩），都须先向用户说明应用、目的及预计占用时长，等待用户明确让出本轮操作窗口。构建/测试/独占源码写入授权、历史实测授权、任务claim或用户沉默均不代表桌面输入授权；MILIASTRA_ALLOW_LIVE_WRITE=0也不能代替此协调。
- 同一已明确授权的窗口内按约定继续，不逐次点击重复询问。窗口结束、用户收回控制或检测到用户正在操作时，立即停止输入与前台切换，并停掉会自动重试或后台触发输入的流程；再次占用先重新协调。焦点失败后不得反复强制激活。
- 桌面操作由一个已约定的执行者串行负责；子代理与自动测试同样遵守，不能自行抢占。没有输入窗口时继续离线代码、构建、静态检查和候选审计；实机缺项如实保留。测试具体流程见docs/P0-SMOKE.md。

## Approved Art and UI Baseline

- 完整游戏冒烟与取证按 `docs/P0-SMOKE.md`。自动试玩必须显式 `clientScriptLog: true`；每次新导入后由工具确保订阅，不能把反复手动勾选当成用户职责。测试版启动异常须在界面显示诊断；没有本轮日志/ready证据不得判通过，不得复用旧日志冒充本轮。
- UI交付先对照 `docs/design/PLATFORM_PARITY.md`，核心信息与操作按 `docs/design/ui-acceptance.json` 逐屏实机审查；宣称UI验收通过前运行 `npm run verify:ui -- <候选.gil>`。它校验候选hash、批准稿参考、实机截图和关键检查项；`npm run check`通过不替代此门禁。装饰/动效可记录降级或延后，生命、费用、意图、价格等核心信息不得被静默省略。

- 用户已确认 [PR #19](https://github.com/CHNISam/Slay-the-Abyss/pull/19) 为整个游戏的美术与界面设计依据；已合入 `develop`（`91ae349`）。
- 实现前必读 `docs/design/UI_DESIGN.md`，对照 `docs/design/prototype/index.html` 与 `docs/design/screens/`；颜色、字号、间距、布局、图标和动效统一读取 `data/presentation/ui_theme.json`，Lua 使用 `npm run build:theme` 生成的 `abyss_theme`。
- 尽可能按批准稿还原。平台能力导致的差异须记录原因、采用的降级和验证状态，不能自行改换视觉方向。拖牌按规范分档落地，C 档点选始终保留。
- 原型中的规则、数值与演示数据不作为游戏逻辑来源；界面只读核心状态、发命令，实际内容以 `data/` 和 Lua 核心为准。
- 原型完成不代表平台实现或实机通过；按 `docs/SCOPE.md` 分层报告。

## Git Branch Workflow (GitFlow-lite)

- 使用独立工作树与短命分支；开始前核对现有PR、任务和脏文件，避免覆盖其他执行者。Backlog Assignee保持Furinya，执行范围和交付记录写入任务备注。
- 用户2026-10-26明确批准停用额外任务锁：Remote Task Claim Protocol及其旧paused状态不再是开发、提交、CI或合并前置要求。保留历史工具/协调记录，不借用其他session，不清除他人认领。尚装有旧claim hooks的本机，仅对已授权任务命令使用独立空hooks目录，不改全局配置。
- 采用GitHub原生PR审查与精确head校验，当前SHA完整Quality成功后squash合入develop。简化任务锁不减免任何测试、质量或产品验收门禁。

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
- `Quality/check` 使用GitHub-hosted Windows；Ubuntu作业保留文件系统边界回归。日常使用快速/相关测试，最终集成完整Quality通过。保留原测试时限，不以加超时、删断言或跳过有效测试解决红灯。

- 初代《杀戮尖塔》PC A0规则、数值、概率、AI和结算顺序贯穿相关任务，不另设规则一致性Milestone。2026-10-26用户明确四职业及第二至隐藏第四幕均纳入M3；旧E1–E5可选/投稿后窗口不再适用，任务与验收见docs/MILESTONES.md。双人合作和成就仍为独立候选；TASK-45保持平台权限阻塞，不主动要求账号升级。


## 任务写给人看

- 标题直接说要做什么；说明用日常中文，验收项一次说一件事。别在任务首页堆命令、缩写、版本编号、迁移历史和代理执行说明。
- 技术要求、执行方案和历史证据放在 docs/backlog-details/ 的对应附件，任务保留附件链接。执行时仍须读附件，精简文字不降低原验收标准。
- 里程碑内的必做任务全部完成、验收齐全后，及时用 Backlog CLI 归档里程碑；任务状态和完成证据保留。

## 免费模型委派（默认分工）

- Codex负责总体决策、任务拆分、关键代码、集成和最终验收；额度可用时，边界清楚、可独立验收的小范围代码修复、单模块实现、测试补齐、机械重构、文档维护和Backlog CLI操作优先交给OpenCode + DeepSeek。按任务跨度、耦合和风险分工，不把执行者限定为只做文档。单次委派写清目标、允许修改的文件、禁止事项、验收标准和验证命令；遵守本仓库Backlog与工作树流程，不覆盖其他Agent的改动。
- 使用原生CLI：`opencode run --model opencode/deepseek-v4.1-flash-free --format json`；先用`opencode models opencode --verbose`核对零定价与variants，默认使用支持的最高推理档位（当前`--variant max`；无variants时不传）。Flash模型的长任务先拆成短步骤，每段只交必要上下文、验证并交接后再继续，避免一次承包长链路；关键设计与高风险逻辑由Codex处理。不依赖界面默认模型；本轮普通CLI成功、`--pure`调用返回403，默认不加`--pure`。
- 用进程级`OPENCODE_CONFIG_CONTENT`将主模型和`small_model`固定为同一免费模型、`enabled_providers`只保留`opencode`、模型白名单只保留该免费ID，并限制本任务工具/文件权限；用`debug config`核对生效值但仅输出白名单字段，禁止输出凭证。临时覆盖用完即恢复，不持久改写全局配置。
- 不自动回退到收费模型。免费服务不可用、90秒无工具/输出事件或连续两次未达验收时停止该路径，由Codex接管并报告；OpenRouter仅在用户明确授权后试用当时已核价的免费模型，不用`auto`路由冒充免费模型。
- 免费不等于无限额度。用户或平台明确反馈限额后，停止该受限路径的后续委派，由Codex继续；有明确重置时间则按它安排，没有则记“窗口未知”，不猜每日或五小时重置、不反复探测。只有额度恢复的依据出现后，才用一个真实短任务验证；无事件仅记原因未明，不能倒推为限额或模型能力差。
- 优先用OpenCode原生`stats --days 0 --models`查看当天活跃会话用量，按官方错误类型区分`FreeUsageLimitError`、`GoUsageLimitError`和普通限流；临时限流沿用CLI内建的`retry-after-ms`/`retry-after`和有界退避，不在外层叠加重试循环。原生stats按会话更新时间筛选，不是平台额度表；本机1.18.24的JSON运行输出不包含重试状态，零事件不能证明没有内部等待。固定版本源码和统计口径见TASK-51附件。
- 节省额度先减少重复上下文、权限失败和无效启动：同一授权范围内的Backlog查重、创建、补备注可合成一个短批次，仍逐项读回；不并发写共享任务库。极小机械操作若启动和监督成本更高，可由Codex直接完成；有可验收的小模块再委派，不为“多用”空跑。保留最高推理档位约定，不用擅自降档代替任务收窄。
- Codex必须检查JSON事件中的真实工具调用、成果/文件Diff和相关验证；退出码0、模型自报完成或普通文本里的工具标签都不代表通过。只向执行者提供必要上下文，保存脱敏证据；不另建调度框架。
- 在已有任务备注中简记交付质量、总耗时、审查/返工和费用证据，未测的Codex额度节省写未知。用量注明统计时区、范围及输入/缓存/推理/输出口径；本地记录不等于平台限额计数，限额、权限失败、无事件和质量不合格分别记录。先串行；并发仅在独立工作树和互不写入的切片上小规模试验，经过验收再扩大，不让协作试验拖住业务交付。
- 已验证的最小调用配置、权限合并注意点与本轮证据见[委派记录](docs/backlog-details/TASK-51.md)。
