# 规划草稿统一收口｜2026-10-31

本次仅整理规划与来源，不修改运行时、候选或发布状态。核对基线为`96411b6`。所有新任务/草案均未勾验收；没有官方导入、ready或本轮设备通过证据。

## 来源与处置

| 原草稿 | 固定头 | 本次承接 |
| --- | --- | --- |
| [PR409](https://github.com/CHNISam/Slay-the-Abyss/pull/409) | `655c500ea26e80994276d03101cca3eeb2d61427` | [原差额全文](STS1-DELTA-20261031.md)原样保存，当前解释以下表为准；不迁入一次性workflow |
| [PR410](https://github.com/CHNISam/Slay-the-Abyss/pull/410) | `800521062323c3ecaf466d9ef4955f71998a8329` | [原实验任务全文](HYBRID-ART-PROPOSAL-20261031.md)存证；CLI创建TASK-94，未来Medium实验，无比赛里程碑/日期 |
| [PR423](https://github.com/CHNISam/Slay-the-Abyss/pull/423) | `6bbfe9252648b5127abe8b072a58511998c08cea` | CLI保留DRAFT-7动效标杆草案；原提案M4非紧急、不阻塞，当前不扩大必做里程碑；不迁入一次性workflow |

三个旧草稿在本统一变更审阅、验证和后续交付后可标为已承接并关闭；原分支应在确认无新提交、保留可恢复历史后清理。本次未推送、关闭PR或删除远端；本地提交仅用于保留可审阅的整理结果。

## PR409逐项对账

| 原事项 | 当前事实与下一步 |
| --- | --- |
| 乞丐付款后零可删牌无出口 | PR411已合`a1c0735`，不另建修复任务；自然与设备边界仍归既有事件/候选验收 |
| 本局计分与特殊遗物减1 | PR412已合`3b9150b`，并含PR417契约修复`96411b6`；不把旧断点重开为未实现 |
| 普通卡详情/只读升级预览 | PR413已合`90c044b`，PR414输入修复`7e747fc`；不重做详情，设备验收继续保留 |
| 事件N'loth玩家端身份外露 | 源码仍有已确认四处，TASK-4.18/High/M4承接；没有批准映射不得编造 |
| 三个局外图鉴 | 未见等价任务，TASK-4.19/Medium/M4承接；局内浏览已有，不重建 |
| 额外四Boss持久解锁 | TASK-53/Blocked/Medium，无当前里程碑；既有战斗实现保留，非M3 Bug |
| 高塔两项恩赐 | 现有历史资格规则先核对，TASK-13.1.3保留原验收；不自动诊断为随机池缺陷 |
| 42事件、130遗物来源等旧全面缺口判断 | 原广域证据保留，不能一律重开；源码回归不代替自然/平台验收 |

原409明确允许必要时让TASK-59、16.1、14.1依顺序从High改Medium。当前只新增一个已确认High，因此仅TASK-59让出一个名额并附理由；其他既有High不变，总数仍5。没有修改既有任务状态或勾选AC。

TASK-42现行说明改为旅行者两幕，旧AC6文字保留，追加解释避免把两职业当现行范围。TASK-47澄清候选不放行不等于删池重抽；TASK-61/53保留Boss解锁延期边界。原409提出的机器清单、历史Backlog资料页校正尚未在本次实施，见原文“任务库同步项”；保留为既有任务审阅上下文，不宣称已完成，也不修改运行时数据或历史证据。

## 两项实验边界

当前HANDOFF已记录Owner停止底图优化，现有图库足够发行；因此TASK-94保留同源矩形/三角/椭圆Alpha/混合、官方GIA、PC/安卓P95/P99、1/5/10卡及有界缓存生命周期的Go/No-Go目标，但退出当前比赛M3/M4。复用TASK-93及PR390/392/400，原样来源附件保留完整技术线索和旧数字的不可比边界。目标1秒/100ms/60或30FPS不是承诺或通过记录；未来正式接入仍须Owner批准。

DRAFT-7保留PR423一个高频交互的原生A/B、两轮独立视觉批评、专业Skills实际加载清单、动态回放与复现；模拟器和官方设备证据分别记录。原提案参考为`CHNISam/agent-skills`的`ui-animation/SKILL.md`与`review-animations/SKILL.md`；执行时须核对实际可用版本，不凭名称认定已加载。结论未来交TASK-4/29.1，不重复图元性能研究，不默认改当前玩法、美术开关或发布候选。

## 本轮离线验证

- Backlog CLI的`doctor`：无重复ID、自依赖或循环。
- `npm run verify:backlog`：通过，负责人、当前范围、排期与High≤5成立。
- `npm run check:guidance`与`git diff --check`：通过。
- `node --test tests/backlog-roadmap.test.mjs tests/release-notes.test.mjs`：45通过、12失败；12项均在release-notes预检读取既有美术包时遇到`Compact artwork source hash mismatch: armaments`，没有修改或绕过该校验。
- 干净基线`/workspace/Slay-the-Abyss`定向执行`node --test --test-name-pattern='UI batch preflight protects hardlink release input package.json' tests/release-notes.test.mjs`同样失败，确认不是本规划差异引入。该处`node --test tests/backlog-roadmap.test.mjs`独立30/30通过。

本轮GitHub API及Git远端认证失败，远端PR状态和关闭/删除均未执行；本地固定Git对象已保存全部上述来源，不绕过认证。
