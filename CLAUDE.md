# Slay the Abyss（原神千星奇域 · Miliastra Wonderland）

- 通用协作规则、Git 分支规范（master/develop）、Backlog.md 用法：见 `AGENTS.md`
- **工具链（官方编辑器、千星沙箱、miliastra MCP 的路径与调用方式）**：见 `docs/TOOLCHAIN.md`
- 千星奇域开发专属技能：`.codebuddy/skills/miliastra-wonderland/SKILL.md`

动手改关卡前，先读 `docs/TOOLCHAIN.md`；接了 MCP 就先读资源 `miliastra://workflow` 和 `miliastra://platform-rules`。

## Claude 分工（仅 Claude 适用，始终生效）

原因：Claude 额度很少，且最擅长美术与前端，额度只花在这上面。

- **只负责**：美术、界面与交互——UI 布局与样式、视觉还原、动效、图标与美术资源、原型页面、界面文案呈现，以及为验证这些改动所需的截图与查看。
- **不负责**：合并与集成（合 PR、rebase、解冲突、发版、清理分支）、后端与游戏逻辑（Lua 核心规则、数值、`data/` 内容逻辑、存档/导入流程）、CI 修复、工具链与 MCP 维护。遇到这类工作就停下，写进交接，不顺手做。
- 用户直接要求做范围外的事时，先提醒这条分工，用户坚持再做。
- **做完即交接**，让其他 agent 不用问就能接着干：
  1. 改动提交到自己的 `feat/<slug>` 分支并推送（可开 PR，但不合并、不跟 CI）。推送前本地只跑 `npm run test:related`，通过即推。全量 `npm test` 和 `npm run test:lua` 交给 CI 跑，本地不跑全量，也不等它跑完才推。原因：全量要跑很久，会把本机内存耗尽。用户说“测完再推”时，也按这条执行。
  2. 在对应 Backlog 任务的实现备注里写清：改了什么（文件/界面）、对照的设计稿、已验证到哪一层（原型 / 编译 / 实机）、还没做的事和需要后端或集成接手的点。
  3. 没有对应任务时，在回复末尾给出同样内容的交接说明。
