# 现有仓库审计快照（施工前需刷新）

审查时间：**2026-10-23**；审查 `develop` 提交：`95ce2bd594f62b7d8a1f5b6ad326fa5886973077`。这是编包时的已观测事实，后续实施先 `fetch` 最新 `develop`，不要把本快照当始终最新。

| 范围 | 观察到的事实 | 对 v2 的影响 |
|---|---|---|
| `data/presentation/narrative.zh-CN.json` | 四段原文保存在 `flow.*.full`；旧短句保存在 `flow.*.compact` | 本包原文已保留；**现有运行时未读取 full** |
| `src/lua/abyss_game_ui.lua` | 菜单、Boss、结算分别使用 `Narrative.flow.intro.compact`、`bossEntrance.compact`、`Narrative.flow[mode].compact` | 当前游戏虽有叙事钩子，但使用的是被用户否决的压缩文本 |
| `src/lua/abyss_node_ui.lua` | 事件已有 `cleric/purifier` 自定义正文；节点 hint 也拼接 `nodeFlavor` | 事件文本可以对照更新；避免同时叠加冗余风味文字 |
| `scripts/node-ui-layout.mjs` | 商店有货品、遗物、服务相关容器 | 尚未在该界面证实商人的独立可见立绘/头像；要评估控件与资产可行性 |
| `data/enemies.json` | 23 敌人定义；`looter` 只有攻击/格挡意图 | 缺失偷金/逃跑/追回金币等身份机制，归 TASK-15 |
| `backlog/tasks/task-32 ...` | TASK-32 `Done`，验收的是 compact 短文案本地接入 | 旧 Done 不等于 v2 标准通过；不要篡改历史 |
| `docs/design/UI_DESIGN.md` + PR19 | 既有美术/UI 批准基线 | 不能自行换一套商店界面/字体/视觉方向 |

## 验证边界

- 本包只做文档和结构化文案，不修改仓库、不生成平台候选、不做独立原生 UI 验收。
- Repo 先前报告有本地静态/回归证据，但**并不等于本轮 v2 文案已实际进入游戏**。
- `docs/HANDOFF.md` 与 `docs/P0-SMOKE.md` 标注当前候选的编译、导入、实机状态；遵守最新真实证据，不拿旧日志冒充当前版本。
