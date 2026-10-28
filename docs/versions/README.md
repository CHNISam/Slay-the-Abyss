# 《杀戮原塔2》版本一览

这里是**源码版本索引**，与 Backlog Milestone 分开管理。工程历史与玩家文案分开维护；供官方更新日志人工填写的玩家文案只有一份：[CHANGELOG.md](../../CHANGELOG.md)。

> 2026-10-28 复核：`v0.1.0`～`v0.10.1` 共 **14 个不可移动的注释 Tag** 已逐个核对目标提交，与本表一致。回溯 Tag 是可恢复的**源码检查点**，不是历史平台发布记录；旧提交里的版本字段不追改。`v0.11.0` 为下一源码版本候选，**尚未验收、未打 Tag、未在平台发布**。第三/隐藏第四幕及真结局仍属显式 experimental 测试入口的源码候选，完整自然通关与实机验收未齐，不承诺默认入口已启用。

| 版本 | 日期 | 本版概要 | 源码位置 | 变更对比 |
| --- | --- | --- | --- | --- |
| `v0.11.0`（候选） | 2026-10-28 | 第三幕、隐藏第四幕与场景交互 | **待验收冻结，暂无 Tag** | [候选差异](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.10.1...develop) |
| `v0.10.1` | 2026-10-27 | 战斗反应修复 | [fa93ac9](https://github.com/CHNISam/Slay-the-Abyss/commit/fa93ac9ff23e7e5cbcf74813d1f9fa776219a314)（PR #247 合入；修复范围截止 b164fda） | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.10.0...v0.10.1) |
| `v0.10.0` | 2026-10-27 | 第二幕、手柄与更新公告 | [c91f0d2](https://github.com/CHNISam/Slay-the-Abyss/commit/c91f0d22edb73acad3405c030a330f4b55c3f8fa) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.9.0...v0.10.0) |
| `v0.9.0` | 2026-10-26 | 角色与跨章节内容 | [c8b42fc](https://github.com/CHNISam/Slay-the-Abyss/commit/c8b42fc6dab165ce83cbf7ad13e283124d04a549) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.8.1...v0.9.0) |
| `v0.8.1` | 2026-10-25 | 移动端及流程修复 | [c1cb78e](https://github.com/CHNISam/Slay-the-Abyss/commit/c1cb78e8fcbeead0c8439477c39b75f9f4429e8f) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.8.0...v0.8.1) |
| `v0.8.0` | 2026-10-25 | 战士卡池与探索内容扩展 | [66f3afb](https://github.com/CHNISam/Slay-the-Abyss/commit/66f3afb23500c77d3e437cce37583073c6d4c5c8) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.7.0...v0.8.0) |
| `v0.7.0` | 2026-10-25 | 音效与动态卡牌说明 | [9ae1aec](https://github.com/CHNISam/Slay-the-Abyss/commit/9ae1aec7aa6f113c7fed5e5fad6241af7fe4a2db) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.6.1...v0.7.0) |
| `v0.6.1` | 2026-10-24 | 集中操作修复 | [4846853](https://github.com/CHNISam/Slay-the-Abyss/commit/48468534d6648ed5fa62a5a165badc7a92d268a4) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.6.0...v0.6.1) |
| `v0.6.0` | 2026-10-24 | 开场演出与奖励体验 | [5afd8a4](https://github.com/CHNISam/Slay-the-Abyss/commit/5afd8a4adad1846e50a53f8f557a24a032a196a4) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.5.1...v0.6.0) |
| `v0.5.1` | 2026-10-24 | 战斗和触控修复 | [3bd3afa](https://github.com/CHNISam/Slay-the-Abyss/commit/3bd3afafc3898ecce23f4d303b9508b8dc3dba2a) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.5.0...v0.5.1) |
| `v0.5.0` | 2026-10-24 | 随机事件与动态战斗信息 | [b92bce6](https://github.com/CHNISam/Slay-the-Abyss/commit/b92bce64951c8cb2168ae93334ca5438aaf2ad55) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.4.0...v0.5.0) |
| `v0.4.0` | 2026-10-23 | 敌方逻辑与操作打磨 | [95ce2bd](https://github.com/CHNISam/Slay-the-Abyss/commit/95ce2bd594f62b7d8a1f5b6ad326fa5886973077) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.3.0...v0.4.0) |
| `v0.3.0` | 2026-10-23 | 卡组、节点与拖牌交互 | [0fb6dc2](https://github.com/CHNISam/Slay-the-Abyss/commit/0fb6dc2fc7eeacea2751209a6e4bfad17f79fa4a) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.2.0...v0.3.0) |
| `v0.2.0` | 2026-10-23 | 地图与完整游戏流程 | [2ff1588](https://github.com/CHNISam/Slay-the-Abyss/commit/2ff15886b88de479f0b3ffd1722dcc42ba27ee3e) | [查看变化](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.1.0...v0.2.0) |
| `v0.1.0` | 2026-10-22 | 初始战斗与卡牌闭环 | [7cda589](https://github.com/CHNISam/Slay-the-Abyss/commit/7cda589f5642bddfd94daaab07a1c51f77b9a52e) | 初始检查点 |

## 后续版本怎样维护

- **何时升级**：只有确定一个新版本批次才升级；新增功能通常升 MINOR（`0.10.1 → 0.11.0`），纯修复升 PATCH（`0.10.1 → 0.10.2`）；不按日期、提交数或 Milestone 升级。
- **写哪里**：供官方更新日志人工填写的玩家文案在 [CHANGELOG.md](../../CHANGELOG.md)，内部工程变更在 [ENGINEERING.md](ENGINEERING.md)，本目录仅列版本与 Tag/提交对比。代码版本来自 `package.json`，lockfile 与 manifest 必须同步。Release Please 仅作草稿，`fix(ci)`、`fix(engineering)` 等技术提交可能混入自动文案，必须人工删去；纯重构默认隐藏。
- **怎么操作**：复用仓库现有 `release-please` / `git-workflow` Skill 和 [发布操作单](../PUBLISHING.md)。真实千星奇域发布时间、作品 GUID、交付产物及证据另记在 `data/release/publications.json`；不使用 Milestone 充当版本号。
- **历史 Tag**：按上表固定原 Git 提交；这些追溯 Tag 是源码版本标识，不冒充旧版曾公开发布。不要移动已有 Tag，不建立 `archive/*` Tag。
- **官方更新日志**：玩家更新说明统一使用千星奇域「奇域信息」的原生更新日志；人工从 CHANGELOG 选取已核实内容填写。游戏内不再维护公告弹窗或历史分页，主菜单仅显示当前版本号，不展示 Git SHA。未发布文案不作为平台已上线证据。
- **新 Tag 门槛**：内容冻结、必要验证和候选交付完成后才创建新正式版本的注释 Tag；既有 14 个 Tag 不创建替身、不删除、不移动或覆盖。本轮不创建 `v0.11.0` Tag。

## 2026-10-28 产品决定：统一使用官方更新日志

用户已确认：不再自行维护游戏内更新公告 UI，统一使用「奇域信息」中的官方原生更新日志。此项是当前产品决定，不是旧版本已在平台发布的历史证据。理由：

1. 官方原生更新日志承担玩家查看更新的入口，避免重复提供同类公告。
2. 官方日志可能获得「奇域更新速报」等曝光机会；是否收录、曝光或推荐**不作保证**。
3. 删除重复公告界面、历史分页、输入隔离、内容同步与专用测试的长期维护成本；不另建公告系统、自动同步工具或后台。
4. 将参赛前有限时间投入核心玩法、内容与游戏品质，以最小改动收口。

原「代码已公开到开源社区。」与非商用许可短文仅属于被移除的公告面板，随面板移除，不新建页面、链接或营销承诺；仓库 LICENSE、CHANGELOG 和版本/工程记录继续保留。
