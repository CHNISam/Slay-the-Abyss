# 可直接发给 Coding Agent 的起始指令

请为 `CHNISam/Slay-the-Abyss` 的轻量世界观「岩脉残响」准备一次**小范围、可验证的叙事接入**。这是一份随附的完整分层素材包，**不要一上来把所有文件都读入上下文**。

## 第一轮只做这些

1. 先读仓库最新 `AGENTS.md`、`docs/HANDOFF.md`、`docs/SCOPE.md`，遵守 Backlog.md CLI 和 GitFlow-lite 规范；按仓库要求运行 `backlog instructions overview`。确认 `develop` 当前状态与已有任务/PR，绝不覆盖其他 worktree 或未提交变更。
2. 再读本包 `README.md`、`00-contract/EXECUTION_BOUNDARY.md`，检查目前的 P0/M1 主线是否允许并行接入。**不要干扰 Boss 胜利、结算及核心试玩回归。**
3. 世界观依据 `01-world/WORLD_BIBLE.md` 和 `01-world/CANON_BOUNDARIES.md`；游戏显示文案仅从 `02-copy/narrative.zh-CN.json` 选，优先保留 `approved_draft` 原文。长文案容不下则按 `02-copy/COPY_RULES.md` 降级。
4. 当准备实际改代码时，再读 `03-integration/REPO_TOUCHPOINTS.md` 和相关真实源文件。主菜单先加最短背景与胜/败摘要一行；Boss 登场与节点风味是**非阻塞可选项**，只有能用现有可验证挂点低成本接入才做。
5. 检查是否已有可承接的 M4 任务；若需要新任务，使用 Backlog CLI 原生创建、关联 `m-5`，不要直接改任务 Markdown。**不创建剧情系统、不重做 UI、不改变规则/数值/概率/可执行事件/地图节点。**
6. 依照 `03-integration/ACCEPTANCE.md` 完成本地回归；平台构建、导入、真机逐层如实报告。若现在尚不能安全接入，应先交付差异清单+低风险方案，保留未执行项，不捏造完成状态。

## 交付我什么

- 变更文件列表 + 简短说明；能合并时提交 feat 分支/PR，按仓库现行 CI 和 review 规则办理。
- 演示入口、胜利、失败的实际文案截图或说明（按本地/平台/实机区分）。
- 回归测试结果和任何文本裁切/控件容量/千星平台阻塞证据。
- 如果只能做部分，明确 Done/未做/Blocked 与后续下一步；不要把可选剧情变成 M1 的新阻塞。

**核心目的**：让玩家明白“为何进入深渊、为何一路战斗、击败守卫意味着什么”，但一打开游戏依旧能直接玩。
