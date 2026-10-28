# 工程变更记录（内部，不进入游戏公告）

游戏内「更新公告」只使用 [CHANGELOG.md](../../CHANGELOG.md)，这里记录玩家无须了解但开发者需要追溯的 CI、重构、测试、协作及美术实验。**本文件不等于实际平台发布证明**。版本与每段源码提交的可点击 Git Diff 见 [版本一览](README.md)。

## v0.11.0 候选（自 v0.10.1 起；2026-10-28）

- **玩法与内容**：四职业卡组与跨章节接线整合（[#238](https://github.com/CHNISam/Slay-the-Abyss/pull/238)）；补齐第三幕敌人（[#252](https://github.com/CHNISam/Slay-the-Abyss/pull/252)）、事件/历史资格（[#259](https://github.com/CHNISam/Slay-the-Abyss/pull/259)）；接入隐藏第四幕、盾矛与心脏、真结局（[#262](https://github.com/CHNISam/Slay-the-Abyss/pull/262)）；蜥蜴尾巴和黑星（[#266](https://github.com/CHNISam/Slay-the-Abyss/pull/266)）；商店/宝箱/营地交互（[#260](https://github.com/CHNISam/Slay-the-Abyss/pull/260)）。
- **UI 与美术研发**：来源透明说明（[#258](https://github.com/CHNISam/Slay-the-Abyss/pull/258)）；岩旅行者原生样卡的*受控试制*（[#261](https://github.com/CHNISam/Slay-the-Abyss/pull/261)）。受控样卡不代表已在玩家默认卡池正式启用，因此不写入玩家公告。
- **工程质量**：持续集成分片与 Windows/POSIX 负载优化、精确来源的成功作业复用及冻结合同修复（[#269](https://github.com/CHNISam/Slay-the-Abyss/pull/269)、[#270](https://github.com/CHNISam/Slay-the-Abyss/pull/270)、[#271](https://github.com/CHNISam/Slay-the-Abyss/pull/271)、[#272](https://github.com/CHNISam/Slay-the-Abyss/pull/272)、[#273](https://github.com/CHNISam/Slay-the-Abyss/pull/273)、[#274](https://github.com/CHNISam/Slay-the-Abyss/pull/274)、[#275](https://github.com/CHNISam/Slay-the-Abyss/pull/275)）；架构与受影响测试修复（[#254](https://github.com/CHNISam/Slay-the-Abyss/pull/254)）。这些优化仅改变开发和测试过程，不写进玩家公告。
- **证据边界**：本区间的代码合入不等于自然四幕通关、完整实机验证或千星奇域正式发布。版本冻结前必须核对最终 `develop` 版本差异、必要质量检查与候选产物，再创建不可移动的 `v0.11.0` 注释 Tag；未冻结前此节只是候选范围。[实时比较](https://github.com/CHNISam/Slay-the-Abyss/compare/v0.10.1...develop)。

## 早期内部变更的保留位置

- **v0.10.0**：手动 Release Please 版本提案、版本信息构建和游戏内历史公告接线（[#242](https://github.com/CHNISam/Slay-the-Abyss/pull/242)）。此版本玩家公告仅表达玩家可见的历史公告入口。
- **v0.9.0**：UI/架构依赖整理和 CI 调整；属于内部工程信息，已从游戏公告移出。
- **v0.8.1**：开发协作及任务边界修正；属于内部工程信息，已从游戏公告移出。
- **其余历史版本**：每个版本均在 [版本一览](README.md) 中保留固定 Tag、准确源码提交和相邻版本的 Git Compare；不复制完整 Git 日志，也不按每次提交人为增加版本。

## 后续维护口径

1. 功能合并到 `develop` 时，保留 Conventional Commits / PR / 任务与测试证据；**不因合并次数或 CI 次数自动升级版本**。
2. 准备一个可交付的源码批次时，先核对上一个 Tag 到候选提交的差异，选择 MINOR（实质新增）或 PATCH（仅修复），同步 `package.json`、lockfile、manifest 和玩家公告，工程信息保留在本文件及 Git/PR。
3. Release Please 是**人工审阅的提案**，非未经审阅直接发布的公告。特别注意 `fix(ci)`、`fix(engineering)`、`feat(release)`：其 Conventional Commit 类型可能让技术内容进入自动草稿，审阅时必须移除；纯 `refactor` 默认隐藏。涉及玩家可见性能或体验才允许进入玩家公告。
4. 实际源码验收和平台发布是两道独立关口。确认目标提交、构建/实机验收和交付产物后才打不可移动注释 Tag；官方发布成功且有凭证时，才登记 `data/release/publications.json`，不拿 Tag 冒充作品已发布。
