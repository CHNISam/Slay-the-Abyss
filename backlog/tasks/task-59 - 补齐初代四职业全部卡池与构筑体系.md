---
id: TASK-59
title: 补齐初代四职业全部卡池与构筑体系
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-25 03:46'
updated_date: '2026-10-26 05:57'
labels:
  - required
  - sts1
  - builds
milestone: m-4
dependencies:
  - TASK-16
  - TASK-56
  - TASK-57
  - TASK-58
references:
  - docs/rules/CROSS_ACT.md
priority: high
type: feature
ordinal: 95000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户要求所有初代职业及流派均纳入正式需求，只有单职业或单流派不能视为交付。复用TASK-16、TASK-16.1、TASK-47和TASK-56/57/58。按后续授权开展隔离开发与并行子任务，保留既有首发截止。以初代《杀戮尖塔》PC A0固定版本为规则基线，逐项记录来源及证据等级；数值、费用、升级、概率、随机消费和结算顺序保持一致，独立实现。完整职业卡池及合法组合为必做范围，构筑示例不是裁剪白名单；未认证社区来源不称为原版二进制认证。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 四职业完整卡池、状态、生成牌、遗物与药水交互均有覆盖账本，逐项区分缺失、离线通过及实机通过。
- [ ] #2 各职业主要构筑及合法混合组合有真实获取和连续战斗证据；不以有限预设套牌代替全部合法机制。
- [ ] #3 共享结算、选择交互与职业专属机制明确依赖和执行范围，领取后才开展开发，独立切片可并行，完整回归串行。
- [ ] #4 固定来源版本和规则基线，差异逐项追踪；全部已开放章节逐职业正常通关并保留同候选日志与截图。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
分职业独立研究和实现基础机制，主执行者在隔离集成树复核共享战斗入口与定向回归；保留完整卡池、自然获取、平台及实机缺口。本轮用户授权暂免认领，不解除暂停，不提交推送合入。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-25：用户明确授权本轮隔离开发暂免远端认领；全局paused未解除。基线877c4af，未提交/推送/合入。综合可审查目录 /workspace/sts-integration，说明 docs/rules/CLASS_FOUNDATION_INTEGRATION.md；各独立树 /workspace/sts-silent、/workspace/sts-defect、/workspace/sts-watcher 保留。已启动三个独立Sub-Agent并完成首批只读核源、模块实现和主执行者集成复核。固定社区镜像aeubanks/sts@319009d5，独立编写实现，未经正版二进制认证。共55组新增Lua、7项相关Node、6个既有Lua回归文件及JS语法检查通过；未跑完整check，未做平台或实机验收。 Sub-Agent交付已检查实际文件和运行结果；源研究与实现为免费与否未知的本平台subagent，不声称额度节省。

后续开发检查点：/workspace/sts-integration冻结版本完整npm run check exit0，JS1347项、Lua228顶层文件全执行、Python22项，Node/Python无跳过；新增14个Lua文件共198组。源/测试SHA256验证未改变，原始日志build/classes-full-check.log。三实验职业原始初始牌组通过seed42首间真实普通房间胜利并进入第二间验证重建；普通发布入口仍默认战士。已接扩展牌、战术大师/本能队列、Focus正数、姿态能力循环。完整卡池/概率/平台UI/实机仍未完成。下一阶段隔离树/workspace/sts-next继续毒流、集中生命周期和占卜，新阶段不计入本冻结检查点。未提交推送合入，全局认领仍paused，用户本轮豁免仍适用。

2026-10-25 四职业构筑与界面冻结检查点 /workspace/sts-ui，feat/experimental-class-ui，基线877c4af。完整 npm run check exit0：JS1349/no skips、Lua247顶层全部执行、Python22；73个源/测试hash复核未变。包含毒流、Focus/Bias/球位、占卜队列、战士七牌、Accuracy、Mantra、职业菜单与mandatory choices及故障回归。独立review修复SharpHide致死使用牌处置、Devotion构造计数时点；旧失败/中断日志保留。当前92/300职业牌，208缺失；完整账本docs/rules/CLASS_CARD_COVERAGE.md，集成边界docs/rules/ARCHETYPE_INTEGRATION.md。原生参数注册/平台/实机未验。后续 /workspace/sts-builds 正接腐化消耗、弃牌减费、Loop/Electro与保留成长，不计入此冻结check。保持全局paused，沿用用户本轮隔离开发豁免；未提交/推送/合入。

2026-10-25 持续隔离开发：当前 /workspace/sts-triggers（feat/card-trigger-builds，基线877c4af）已双版Capability实算165/300：红52、绿41、蓝35、紫37，135仍缺；未把模块定义当成全部流派。phase3定向：战士30、猎人39、机器人52、观者23、触发能力组件28+真实出牌21、独立顺序review3、展示11/370变体、状态真实UI30例。新源码尚待完整check；107树完整check exit1（JS1349绿，Lua255全执行但两旧fixture共6死亡处置假设失败，Python未到），原失败日志和hash保留，当前树已按固定源保留死亡cardInUse UID并定向Thunder27/Twin16通过。当前集成说明 /workspace/sts-triggers/docs/rules/CARD_TRIGGER_INTEGRATION.md，覆盖账本 CLASS_CARD_COVERAGE.md。下一批独立私树继续补缺卡，未接不计支持。保持paused，沿用本轮开发豁免，未提交推送合入。

完整日志复核纠正：早先仅扫107树日志后半段遗漏4份，107/workspace/sts-builds实际6份Lua fixture共15死亡处置旧假设失败；165/workspace/sts-triggers完整check exit1，JS1349无skip，Lua262全部执行，四份旧fixture共9断言失败，Python未到，597输入hash未变。四份测试已按同一固定源保留死亡cardInUse原UID修正，block_damage25/copied_attack34/hp_loss27/iron_wave12定向通过；仅此四测试不同、165源码逐字节相同的/workspace/sts-checked正在完整复验。新机制开发继续/workspace/sts-flow，原失败树与日志保留，不改写成成功。

2026-10-25 最新165冻结检查点 /workspace/sts-checked（feat/verified-card-triggers）完整npm run check exit0：JS1349/no skips，Lua262顶层全执行无失败，Python22；597输入SHA256复核未变，build/card-triggers-code-hashes.json/full-check.log留证。仅4旧死亡处置fixture按源修正，165源码与原sts-triggers字节相同，旧两树失败日志保持。后续/workspace/sts-flow正在接下一69张牌（warrior状态29、defect engine63、silent tactics60、watcher flow27、展示21/512变体已定向绿），未将后续树算入本完整check或所有300完成。仍未提交推送合入，平台未验。

用户最新要求停止扩展，尽快收口合并后交接。238张收口候选在 /workspace/sts-merge（基线877c4af；66/61/56/55），剩62张Final与身份/自动出牌组件留 /workspace/sts-final 及各私树，未计入已接入。旧238 full失败日志保留，修正版正在串行完整复验。已fetch远端c1cb78e（含PR196战士75张）；对最新版只读three-way检查确有17文件冲突，不可覆盖。GitHub auth status退出1且api/user Forbidden，当前无法远端PR合并；未推送、未合并、未变更认领或其他活动会话。交接材料 /workspace/sts-closeout，含完整候选patch、冲突表和后续组件；验收项与状态保持原样。

最终本地收口复验已实际完成：/workspace/sts-merge npm run check exit0，JS1349全部通过无skip、274份顶层Lua逐文件确认全执行、Python22通过，619输入SHA256全部未变。已停止全部子代理和新开发，原失败树/日志保持原样。完整交接 docs/CLASS_CARD_HANDOFF.md 与 /workspace/sts-closeout。远端尚未提交/推送/合并：GitHub认证无效/API Forbidden；最新develop c1cb78e含另一套75战士，共享核心17文件真实三路冲突，当前串行整合会话保持不动。此通过仅认证877c4af旧基线的238本地候选；不借此认证新合并结果/原生实机，不勾验收。

继续合并更正：用户要求继续后，实际Git push --dry-run成功，不能用gh API Forbidden推断整个Git写入口不可用。已在最新c1cb78e基础 feat/four-class-integration 实际三路整合，17冲突由独立代理分文件解决；native75与实验238同时保留，完整复验待实际整合完成。旧收口包与失败证据保持不改。

整合收口：已基于最新develop c1cb78e实际解决冲突，保留生产75战士与实验66/61/56/55；源1c255ce完整npm run check exit0，JS1368零skip、345份Lua逐文件全执行、Python22通过，714源输入SHA256全部未变。仅后续交接/任务元数据变更，已测源不变。交接docs/CLASS_CARD_HANDOFF.md，未接模块portable归档docs/drafts/class-final。Git提交/推送已实际成功，此前以gh失败推断所有写入不可用已更正。四职业300与平台验收仍未完成，不勾AC。

2026-10-26章节已纳入M3。本轮四职业跨幕边界验证发现并修复Watcher共享Vigor重复注册，以及新诅咒导致职业呈现/启动失败；保留批准中文名称，四职业实际卡牌渲染、菜单/资源/能力回归恢复通过。完整300牌与所有章节自然构筑/通关仍未齐，不勾AC。独立工作树feat/m3-four-acts离线切片及分层证据见docs/rules/CROSS_ACT.md。
<!-- SECTION:NOTES:END -->
