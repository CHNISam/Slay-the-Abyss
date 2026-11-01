# 目标仓库接入定位（2026-10-23 develop 快照）

执行 Agent **必须先对照最新仓库复核路径与行为**；以下是上游已实际阅读的定位，不代表当前 branch 一定没变化。

| 需求 | 实际文件或依赖 | 可行的最小落点 | 风险/注意 |
| --- | --- | --- | --- |
| 开局简短旁白 | `src/lua/abyss_game_ui.lua` | `self:refresh()` 中菜单 `summary` 文本（快照行 62-63） | 现在还承载玩法说明 `battleUI.instructions`；不可替换成纯剧情 |
| 胜败文案 | `src/lua/abyss_game_ui.lua` | `mode == victory/defeat` 的汇总 `summary` 文本 | 需要保留用时、层数/生命/金币/卡组/遗物、平台正式结算、重开、错误提示 |
| 标题与菜单布局 | `scripts/game-ui-layout.mjs` | 已有 `menuPanel` 的 title/summary/按钮 | 服从已批准的原生 UI 构图和原生直接子控件容量；不要造新 UI 框架 |
| 营地/商店/未知事件/宝箱 | `src/lua/abyss_node_ui.lua` | `title`、`hint`、`notice` 现有文案位置 | 现有 `cleric`、净化神龛等事件文字、条件和交互必须正确；不改变动作列表 |
| 关卡/节点逻辑 | `src/lua/abyss_nodes.lua`, `src/lua/abyss_map.lua` | **只读了解语义** | 不为了剧情改随机流、路由、资源交易或交互 |
| Boss 身份 | `data/enemies.json` | `guardian` → 显示名`深渊守卫` | 不动 Boss 数值、意图、敌人池；不强改名称或 AI |
| 角色卡牌显示 | `data/presentation/traveler.zh-CN.json` | 用来查现有岩系表达 | 不随便改牌效和既定卡名 |
| UI 基线 | `docs/design/UI_DESIGN.md`; `data/presentation/ui_theme.json` | 服从现有字体、主题色、字高、布局 | 原型批准 PR #19，不重新设计卡牌或背景 |
| UI 平台问题与验收 | `docs/design/PLATFORM_PARITY.md`; `docs/P0-SMOKE.md` | 确认未测项、当前可靠证据 | 不能声称本地测试=真机验收 |

## 推荐的实现设计（非强制）

- 如果仓库已有可复用的 presentation/bundle 工具，则将本包 JSON 中几条需要的文字整合到现有构建链；**不要为不足十条文案设计新 i18n 框架**。
- 优先小 diff：重用现有 `summary` / `hint`，必要时新增一个最小 presenter/helper，不能改变 game core state。
- UI 若只容纳一行，则首发只做 `intro.compact` + `victory.compact` / `defeat.compact`。Boss / node 可记为可选后置。
- 新建 UI 控件前先核对原生容量、自动化构建与 `verify:ui` 门禁；不能影响当下的 P0 真正通关。

## Backlog 与里程碑

若后续用户指示落库：先 `backlog instructions overview` → 搜索现有 `TASK-4`（UI/反馈）、`TASK-18`（发布物料）、`TASK-24`（已 Done 的设计成果）及相关 M4 任务。优先复用可承接的工作项；若真有不可分割的新工作，按 CLI task-creation 建一个**范围清楚、可验收**的 M4 小任务，不能因为剧情把 M1 主冲刺改掉。所有 Backlog 内容必须由 CLI 修改，**不直接编辑 backlog/tasks/*.md**。
