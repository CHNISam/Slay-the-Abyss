# Slay the Abyss · 岩脉残响 / 轻量叙事交付包

**用途**：供 Coding Agent 逐级读取、评审并在《杀戮深渊》现有玩法上集成最小叙事，不是剧情系统重构。

**版本**：2026-10-23 / v1.0（提案包）。目标仓库：`CHNISam/Slay-the-Abyss`，参考分支 `develop`。

## 索引（按需读，不要全量一次加载）

| 需要回答的问题 | 只读这个文件 |
| --- | --- |
| 目标、范围、不能动什么？ | `00-contract/EXECUTION_BOUNDARY.md` |
| 游戏讲什么？ | `01-world/WORLD_BIBLE.md` |
| 哪些是原神既有概念、哪些是原创设定？ | `01-world/CANON_BOUNDARIES.md` |
| **游戏实际显示的中文文本** | `02-copy/narrative.zh-CN.json` |
| 文案如何选、太长怎么降级？ | `02-copy/COPY_RULES.md` |
| 代码仓库往哪里接？ | `03-integration/REPO_TOUCHPOINTS.md` |
| 如何判定完成？ | `03-integration/ACCEPTANCE.md` |
| 给 Agent 的可直接粘贴指令 | `04-agent/START_PROMPT.md` |

## 建议读取顺序

1. **先给 Agent** `04-agent/START_PROMPT.md`（可直接粘贴该文件全文）。
2. 它先读目标仓库最新 `AGENTS.md`、`docs/HANDOFF.md`、`docs/SCOPE.md` 和本包 `00-contract/EXECUTION_BOUNDARY.md`。
3. 需要叙事时读 `01-world/WORLD_BIBLE.md`；写界面文案时读 `02-copy/narrative.zh-CN.json`。
4. **只有接入实现时**再读 `03-integration/REPO_TOUCHPOINTS.md`；验证时读 `03-integration/ACCEPTANCE.md`。

## 最重要的限制

- 目前是**叙事提案及文本物料**，不是已经合入的游戏功能，也不是已经实机验证。
- 用户已认可主线文字方向。JSON 内 `approved_draft` 为之前展示并获得正面反馈的原句，其他 `candidate` 是可选择的新文案。
- **不要替换已批准的 PR #19 UI 视觉基线**，不要改变战斗、路线、怪物、经济或事件规则。
- M1/P0 完整战斗验收优先；轻量叙事最好排在 M4（Backlog ID `m-5`），不阻塞主线。
- 文案里不写死层数，兼容原有 15 层和后续 17 层对齐任务。

## 文件身份

`02-copy/narrative.zh-CN.json` 是本包**游戏呈现用文本的唯一规范副本**。其他 Markdown 讲意图、边界和接入，不应复制第二套有冲突的展示文字。
