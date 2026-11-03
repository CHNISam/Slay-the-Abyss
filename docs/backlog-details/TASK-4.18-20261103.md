# TASK-4.18：原作身份清理前置核查

核查日期：2026-11-03。源码基线：`568da4e4aabca7c67d148a7e970c01344b7de10d`（当轮 `origin/develop`）。本附件只记录源码与批准依据核查，不认证运行态或设备显示。

## 结论

**待内容评审：未查到 N'loth 的已批准本作角色、事件标题及礼物名称映射，因此本轮不改生产文案。** TASK-4.18 的三条验收均保持未完成。将英文改为“恩洛斯”仍是原作身份音译，不能当作世界观适配完成。

## 实际生产路径

| 展示位置 | 源码定位 | 当前内容 |
| --- | --- | --- |
| 事件标题 | `src/lua/abyss_node_ui_events.lua:13` | `nloth.name = N'loth` |
| 开场正文 | `src/lua/abyss_nloth_event.lua:20` | `N'loth指着你随身的两件遗物，提出交换。` |
| 首次交易说明 | 同文件 `:29` | `交出所示遗物，获得N'loth的礼物。` |
| 结束正文 | 同文件 `:61` | `N'loth转过身去，交易结束了。` |
| 选项标题 | 同文件 `:30` | 读取所选遗物实际 `d.name`；需在批准映射落实后连同真实候选核验 |
| 重复礼物说明 | 同文件 `:29` | `已经持有礼物：获得圆环，不失去所示遗物。` |
| 礼物实际名称/说明 | `data/relics.json:726` | `恩洛斯的礼物`；说明为稀有权重规则，无额外角色名 |
| 相关面具实际名称/说明 | `data/relics.json:724` | `恩洛斯的饥饿之脸`；说明为宝箱移除规则，无额外角色名；由换脸商事件取得，并非本事件奖励 |

## 批准依据检索

- `docs/backlog-details/STS1-DELTA-20261031.md` §4 指向 `data/presentation/narrative.zh-CN.json`、既有批准剧情及 TASK-44；明确无证实的批准名字不得发明。
- `data/presentation/narrative.zh-CN.json:36–55` 的 `eventCopy` 仅含 `living_wall`、`cleric`、`purifier`，没有 `nloth`。
- `docs/lore/v2/02-characters/INDEX.md`、`GUARDIANS_AND_OTHERS.md` 及 `docs/lore` 全目录未提供该角色映射。v2 决策允许的暂定方向不等于新增角色名获得批准，`candidate_only` 亦不能默认实装。
- `backlog task view TASK-44 --plain`：完成范围为四段主线、商人短反馈与两个事件正文，不包含 N'loth 映射。
- `backlog task view TASK-4.8 --plain`：记录中文化成果，不提供本事件角色适配批准；本轮不重开该中文化成果。
- 可复现检索：`rg -n -i "nloth|恩洛斯" docs/lore data/presentation/narrative.zh-CN.json docs/plans/2026-10-23-rock-vein-lore.md`，退出码 1、零匹配。此结果限于上述已指明依据，不宣称外部讨论绝不存在映射。

## 后续所需与验证边界

内容评审需提供或指认可追溯的事件标题、角色称谓、开场/首次交易/结束文案，以及真实礼物展示名；相关面具若同属该角色也应明确映射。随后仅改对外表现，保留 `nloth`、`Nloth's Gift`、`NlothsMask`、来源标识及日志身份。

生产逻辑保持原样：完整已持有遗物候选、shuffle 与随机流、两个交易候选、先失去后取得、重复礼物改得圆环且不移除原遗物均未触动。因没有获批实现输入，本轮没有红绿回归、候选构建/写入、官方导入、新 ready 或同候选 PC/手机截图；源码核查不能代替这些证据。

本轮 `gh pr list --state open --json number,title,headRefName` 被当前代理 `127.0.0.1:9` 拒绝连接，无法独立刷新 PR 查重；远端 PR 查重由主控统一处理。任务元数据也由主控通过 Backlog CLI 管理，本工作树未修改。
