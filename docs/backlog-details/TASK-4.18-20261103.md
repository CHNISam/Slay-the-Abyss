# TASK-4.18：原作身份清理前置核查

核查日期：2026-11-03。源码基线：`568da4e4aabca7c67d148a7e970c01344b7de10d`（当轮 `origin/develop`）。本附件只记录源码与批准依据核查，不认证运行态或设备显示。

## 当前结论（纠正初次阻塞判断）

本轮用户纠正英文名字后，复用 `data/relics.json` 已有“恩洛斯的礼物”中的中文称呼，将事件标题、开场、首次交易说明、结束正文四处统一为“恩洛斯”。没有发明新人物、遗物或世界观。初次结论“无 Lore 映射因此完全不能推进”过强：已有中文成果足以支持这次名称一致性修复。完整世界观适配与同候选设备验收仍未认证，不能据此勾完 TASK-4.18。

## 修复前源码与运行态 mock

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

通过真实 `Nodes.enter` 及 `UI.new`，使用仓库生成的原生控件树与既有 mock，读取 `eventView/name`、`body`、`option1/description`，修复前实际返回前三项表中英文文案。路径为 `abyss_node_ui_events.install → renderEvent → writeEventHeading / eventOutcomeBody → control.text`；选项经 `abyss_node_ui_faces.eventOptionText` 直接返回 `option.description`，没有中文覆盖层。礼物奖励则经 `ctx.relicName → abyss_relic_names.get` 读取既有中文名称。此结果是运行态 mock，不是官方客户端截图。

## 批准依据检索

- `docs/backlog-details/STS1-DELTA-20261031.md` §4 指向 `data/presentation/narrative.zh-CN.json`、既有批准剧情及 TASK-44；明确无证实的批准名字不得发明。
- `data/presentation/narrative.zh-CN.json:36–55` 的 `eventCopy` 仅含 `living_wall`、`cleric`、`purifier`，没有 `nloth`。
- `docs/lore/v2/02-characters/INDEX.md`、`GUARDIANS_AND_OTHERS.md` 及 `docs/lore` 全目录未提供该角色映射。v2 决策允许的暂定方向不等于新增角色名获得批准，`candidate_only` 亦不能默认实装。
- `backlog task view TASK-44 --plain`：完成范围为四段主线、商人短反馈与两个事件正文，不包含 N'loth 映射。
- `backlog task view TASK-4.8 --plain`：记录中文化成果，不提供本事件角色适配批准；本轮不重开该中文化成果。
- 可复现检索：`rg -n -i "nloth|恩洛斯" docs/lore data/presentation/narrative.zh-CN.json docs/plans/2026-10-23-rock-vein-lore.md`，退出码 1、零匹配。此结果限于上述已指明依据，不宣称外部讨论绝不存在映射。

## 修复与验证边界

只改上述四个玩家文案字符串；已有遗物中文名称、`nloth`、`Nloth's Gift`、`NlothsMask`、来源标识及日志身份均保留。未查到完整 Lore 映射的事实保留，但它不再作为这次中文修复的阻塞。

定向回归 `tests/lua/nloth_chinese_presentation.lua` 先红后绿：修复前明确由 `[NLOTH_COPY] Chinese event title` 行为断言拒绝；修复后真实控件读回标题“恩洛斯”、开场“恩洛斯指着你随身的两件遗物，提出交换。”、交易说明“交出所示遗物，获得恩洛斯的礼物。”及结束正文“恩洛斯转过身去，交易结束了。\n获得遗物：恩洛斯的礼物。”。JS wrapper 将其纳入标准测试发现。

`tests/lua/face_nloth_skull_events.lua` 11项通过，包括完整候选shuffle、重排后身份、重复礼物保留原遗物、失败取得回滚与重试。只改文案，完整已持有候选、shuffle/随机流、两个交易候选、先失去后取得及重复礼物规则未改。没有候选构建/写入、官方导入、新 ready 或同候选 PC/手机截图；mock不能代替这些证据。

标准入口 `node --test tests/nloth-chinese-presentation.test.mjs` 1/1通过；`node --test tests/m3-relic-choice-events.test.mjs tests/special-event-relics.test.mjs` 4/4通过，覆盖原18项事件命令与130种遗物牺牲、11项面孔/恩洛斯/头骨、12项特殊事件遗物合同。`git diff --check` 通过。完整CI与独立复审由主控对最终组合SHA执行。

本轮 `gh pr list --state open --json number,title,headRefName` 被当前代理 `127.0.0.1:9` 拒绝连接，无法独立刷新 PR 查重；远端 PR 查重由主控统一处理。任务元数据也由主控通过 Backlog CLI 管理，本工作树未修改。
