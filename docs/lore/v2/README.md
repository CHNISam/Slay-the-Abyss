# 《杀戮深渊》·《岩脉残响》v2｜渐进式叙事资产包

> **状态：2026-10-23 用户暂定通过的审定基线；不是已实装或已完成平台验收。**
>
> 适用仓库：`CHNISam/Slay-the-Abyss`（当前开发分支 `develop`）。
>
> 核心方向：轻主线、强世界关联；角色的身份要体现在其行为、节点和玩法上。**不要退回“加四句氛围文案就算完成世界观”的旧方案。**

## 读取路由（只按当前工作读取必要文件）

```text
README.md                                      ← 先读，只需本文件
├── 00-contract/
│   ├── DECISIONS.md                           ← 用户已同意与未决定的边界
│   └── CANON_AND_SOURCES.md                   ← 原作依据 / 原神背景 / 原创划分
├── 01-world/
│   ├── WORLD_TREE.md                          ← 世界的主树（先看这份）
│   └── CAUSAL_LINKS.md                        ← 地脉、信仰、交易、生态的因果
├── 02-characters/
│   ├── INDEX.md                               ← 角色路由与敌人ID归属
│   ├── MERCHANT.md                            ← 商人（形象、动机、短台词）
│   ├── CULTISTS.md                            ← 祈火徒
│   ├── RAIDERS.md                             ← 窃金客、束缚者
│   └── GUARDIANS_AND_OTHERS.md                ← 古代守卫、圣职者、动物与小魔
├── 03-nodes/
│   ├── NODE_TREE.md                           ← 七类节点叙事用途
│   └── CLERIC_AND_PURIFIER.md                 ← 两个具体事件的起因/选择/结果
├── 04-copy/
│   ├── CORE_VERBATIM.md                       ← 四段原文，最高优先级，禁止改写
│   ├── core.zh-CN.json                        ← 四段原文结构化数据，不直接覆盖项目源文件
│   └── supporting.zh-CN.json                  ← 商人、遭遇、事件辅助文案，候选
├── 05-integration/
│   ├── CURRENT_CODE_AUDIT.md                  ← 2026-10-23 最新 develop 快照与缺口
│   ├── TASK_ROUTING.md                        ← 现有 Backlog 映射、不能动的边界
│   └── ACCEPTANCE.md                          ← 分层验收：设计 / 本地 / 平台 / 实机
└── 06-agent/
    └── START_PROMPT.md                        ← 给执行 Agent 的最小任务契约
```

**快速阅读路径**：
- 只审设计：`00-contract/DECISIONS.md` → `01-world/WORLD_TREE.md` → `04-copy/CORE_VERBATIM.md`。
- 改商店人物：再读 `02-characters/MERCHANT.md`、`05-integration/CURRENT_CODE_AUDIT.md`。
- 改事件：再读 `03-nodes/CLERIC_AND_PURIFIER.md`。
- 补窃贼玩法：读 `02-characters/RAIDERS.md` + 现有 TASK-15；必须另核原版规则。
- 给 Agent 施工：`06-agent/START_PROMPT.md`，而不是全文复制所有文件到提示词。

## 生效次序

1. 用户本轮批准的世界设计与 **四段原文**（本包 `00-contract`、`04-copy/CORE_VERBATIM.md`）。
2. 项目最新 `AGENTS.md`、`docs/HANDOFF.md`、`docs/SCOPE.md`、`docs/design/UI_DESIGN.md`（工程约束、真机事实优先于历史快照）。
3. 项目最新运行时数据、代码、Backlog CLI 和真实测试。
4. 本包人物/事件其他辅助文案（**暂定提案，不是原神或 STS 官方原文**）。

## 重要约束

- 仅产生供人和 Agent 审定的资产。**本包未写入游戏、未上传远端、未做 CI 或实机测试**。
- 不把原作《杀戮尖塔》的宗教、商人秘密或其他推测冒充官方已证实事实。
- 不复制原作对话和画面，不使用未经许可的素材；用 GI 已允许资产或原创替代。
- 切忌为每个敌人凭空写独白。先让身份与行为一致，必要处才添短文案。
- 规则数值 / RNG / AI / 掉落属于现有规则任务，本包不覆盖也不擅自修改。
- 未规定故事一定发生在 15/17 层；展示层读运行时地图事实。
