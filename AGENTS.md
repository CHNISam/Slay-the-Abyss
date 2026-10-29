# 项目协作

《杀戮原塔2》是原神千星奇域 UGC。当前比赛仅开放岩系旅行者第一、二幕；完整范围以 [SCOPE](docs/SCOPE.md) 为准，进度看 [HANDOFF](docs/HANDOFF.md)，验收看 [MILESTONES](docs/MILESTONES.md)。不在指引中维护历史决定和任务快照。

## 开始与交付

- 每次会话先运行 `backlog instructions overview`；创建、执行、收口前分别读对应的 `backlog instructions task-creation`、`backlog instructions task-execution`、`backlog instructions task-finalization`。任务与里程碑只用 Backlog CLI 修改，先查重；负责人沿用 Furinya，任务正文用简洁中文，技术证据放对应附件。
- 先核对任务、PR 和脏文件，从最新 origin/develop 建独立工作树及 feat/<slug> 短分支，保留他人的改动。Conventional Commits；当前 HEAD 的全部必需 CI 成功后 squash PR → develop。master 只接发布；release 从 develop、hotfix 从 master，均合回 master 与 develop。保护及精确 SHA 合并流程见 [CI](docs/CI.md)。不恢复旧任务锁。
- 合并后核对分支没有新工作，保留可恢复历史并清理自己的干净工作树和分支；脏树与独立提交保留。版本与不可移动的注释 Tag 按 [PUBLISHING](docs/PUBLISHING.md)，不自动发版或创建归档 Tag。
- 完成须有本轮对应证据：源码检查、候选写入/读回、官方导入、真实 ready、各设备实测分别报告；未验证的要求保持未完成。可独立试玩的切片及时交付，启动失败优先修复。

## 验证入口

| 用途 | 命令 / 事实来源 |
| --- | --- |
| 日常反馈 | `npm run test:fast` / `npm run test:related` |
| 完整验证 | `npm run check`；工程门槛见 [ENGINEERING](docs/ENGINEERING.md) |
| 指引防回退 | `npm run check:guidance`；长度、入口、命令及薄适配器 |
| 任务范围与队列 | `npm run verify:backlog`；检查负责人、优先级、High 上限与当前比赛范围 |
| UI 候选验收 | `npm run verify:ui -- <候选.gil>`；[批准稿](docs/design/UI_DESIGN.md)、[平台差异](docs/design/PLATFORM_PARITY.md) |
| 候选交付 | `npm run verify:delivery`；[冒烟与取证](docs/P0-SMOKE.md) |

规则参数、阈值和测试合同以可执行配置为准，不在此重复。新增核心 Lua 模块在 [架构配置](config/architecture.json) 分类；不靠放宽门槛、删断言或跳过有效测试解决失败。UI 只读核心状态、发命令；主题来源为 [ui_theme](data/presentation/ui_theme.json)，由 `npm run build:theme` 生成。遵循批准稿，平台降级记录原因与实测状态，保留 C 档点选。

## 必要边界

- 任何鼠标、键盘、抢焦点或切前台操作，先说明应用、目的、开始时间及预计时长，等待用户明确让出本轮窗口；历史测试授权不延续。只在窗口内由一个执行者操作；用户收回控制、正在操作或到期时立即停止输入和自动重试，告知已归还控制。无窗口则继续离线工作。
- 关卡与 MCP 操作先读 [TOOLCHAIN](docs/TOOLCHAIN.md) 和 [千星技能](.codebuddy/skills/miliastra-wonderland/SKILL.md)，使用 MCP 前读 miliastra://workflow 与 miliastra://platform-rules。MILIASTRA_ALLOW_LIVE_WRITE 保持 0，只写存档副本，发布由人完成。
- 实机需本轮候选身份、日志/ready 和设备证据；自动试玩显式 clientScriptLog: true，工具确保每次新导入后订阅。不得用旧日志、离线模拟或 PC 结果代替当前手机实测。
- 原版对照、无 Lv.4 持久存档依赖和同局状态要求见 [SCOPE](docs/SCOPE.md)。不自行调平衡、升级账号或引入后端绕过限制；保留 full-source 内容及历史证据。
- 保留 [LICENSE](LICENSE) 的非商业许可及项目商业权利；第三方素材保留各自授权，不擅自更换许可。
- Codex 负责决策、集成和验收；适合的短任务优先免费 OpenCode，配置、最高推理档位及验收方式见 [委派记录](docs/backlog-details/TASK-51.md)。明确限额后暂停，恢复窗口未知时不试探、不切收费模型；仅有恢复依据后做一次短任务验证。

门禁覆盖与维护方式见 [指引维护](docs/AGENT_GUIDANCE.md)。
