# 《杀戮原塔2》版本一览

这里是**源码版本索引**，与 Backlog Milestone 分开管理。详细玩家更新内容只有一份：[CHANGELOG.md](../../CHANGELOG.md)。

> 2026-10-27 回溯整理：版本日期取 Git 提交在北京时间的日期；这些节点**不等于历史平台发布记录**。旧提交的 `package.json` 当时大多仍为 `0.1.0`，不重写旧提交。最新 `v0.10.1` 的 Tag 应指向本次版本字段/说明合入并验收后的提交，不能直接指向旧的修复提交。

| 版本 | 日期 | 本版概要 | 源码位置 |
| --- | --- | --- | --- |
| `v0.10.1` | 2026-10-27 | 战斗反应修复 | [修复范围截止](https://github.com/CHNISam/Slay-the-Abyss/commit/b164fda7c7f174788abd891bcec1e612696422ad)；Tag 待合入后固定 |
| `v0.10.0` | 2026-10-27 | 第二幕、手柄与更新公告 | [c91f0d2](https://github.com/CHNISam/Slay-the-Abyss/commit/c91f0d22edb73acad3405c030a330f4b55c3f8fa) |
| `v0.9.0` | 2026-10-26 | 角色与跨章节内容 | [c8b42fc](https://github.com/CHNISam/Slay-the-Abyss/commit/c8b42fc6dab165ce83cbf7ad13e283124d04a549) |
| `v0.8.1` | 2026-10-25 | 移动端及流程修复 | [c1cb78e](https://github.com/CHNISam/Slay-the-Abyss/commit/c1cb78e8fcbeead0c8439477c39b75f9f4429e8f) |
| `v0.8.0` | 2026-10-25 | 战士卡池与探索内容扩展 | [66f3afb](https://github.com/CHNISam/Slay-the-Abyss/commit/66f3afb23500c77d3e437cce37583073c6d4c5c8) |
| `v0.7.0` | 2026-10-25 | 音效与动态卡牌说明 | [9ae1aec](https://github.com/CHNISam/Slay-the-Abyss/commit/9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db) |
| `v0.6.1` | 2026-10-24 | 集中操作修复 | [4846853](https://github.com/CHNISam/Slay-the-Abyss/commit/48468534d6648ed5fa62a5a165badc7a92d268a4) |
| `v0.6.0` | 2026-10-24 | 开场演出与奖励体验 | [5afd8a4](https://github.com/CHNISam/Slay-the-Abyss/commit/5afd8a4adad1846e50a53f8f557a24a032a196a4) |
| `v0.5.1` | 2026-10-24 | 战斗和触控修复 | [3bd3afa](https://github.com/CHNISam/Slay-the-Abyss/commit/3bd3afafc3898ecce23f4d303b9508b8dc3dba2a) |
| `v0.5.0` | 2026-10-24 | 随机事件与动态战斗信息 | [b92bce6](https://github.com/CHNISam/Slay-the-Abyss/commit/b92bce64951c8cb2168ae93334ca5438aaf2ad55) |
| `v0.4.0` | 2026-10-23 | 敌方逻辑与操作打磨 | [95ce2bd](https://github.com/CHNISam/Slay-the-Abyss/commit/95ce2bd594f62b7d8a1f5b6ad326fa5886973077) |
| `v0.3.0` | 2026-10-23 | 卡组、节点与拖牌交互 | [0fb6dc2](https://github.com/CHNISam/Slay-the-Abyss/commit/0fb6dc2fc7eeacea2751209a6e4bfad17f79fa4a) |
| `v0.2.0` | 2026-10-23 | 地图与完整游戏流程 | [2ff1588](https://github.com/CHNISam/Slay-the-Abyss/commit/2ff15886b88de479f0b3ffd1722dcc42ba27ee3e) |
| `v0.1.0` | 2026-10-22 | 初始战斗与卡牌闭环 | [7cda589](https://github.com/CHNISam/Slay-the-Abyss/commit/7cda589f5642bddfd94daaab07a1c51f77b9a52e) |

## 后续版本怎样维护

- **何时升级**：只有确定一个新版本批次才升级；新增功能通常升 MINOR（`0.10.1 → 0.11.0`），纯修复升 PATCH（`0.10.1 → 0.10.2`）；不按日期、提交数或 Milestone 升级。
- **写哪里**：唯一游戏公告正文在 [CHANGELOG.md](../../CHANGELOG.md)。本目录是索引，新增一行即可。代码版本来自根目录 `package.json`，lockfile 与 manifest 跟随同步。
- **怎么操作**：复用仓库现有 `release-please` / `git-workflow` Skill 和 [发布操作单](../PUBLISHING.md)。真实千星奇域发布时间、作品 GUID、交付产物及证据另记在 `data/release/publications.json`；不使用 Milestone 充当版本号。
- **历史 Tag**：按上表固定原 Git 提交；这些追溯 Tag 是源码版本标识，不冒充旧版曾公开发布。不要移动已有 Tag，不建立 `archive/*` Tag。
- **游戏公告**：Alpha 构建读取本地 CHANGELOG 中不晚于当前代码版本的记录，即使历史发布凭证尚缺也能查阅；未有凭证时显示「版本日期」，不显示虚构的「发布日期」。
