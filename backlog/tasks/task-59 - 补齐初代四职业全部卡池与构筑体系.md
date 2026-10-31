---
id: TASK-59
title: 验收岩系旅行者与比赛正式入口
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-25 03:46'
updated_date: '2026-10-31 10:47'
labels:
  - required
  - sts1
  - builds
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-16
references:
  - docs/rules/CROSS_ACT.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/INTEGRATION-CLOSEOUT-20261025.md
  - docs/M3-STATUS-20261028.md
  - docs/evidence/backlog-merge-20261029.json
  - docs/backlog-details/TRAVELER-SCOPE-20261029.md
priority: medium
type: feature
ordinal: 95000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-10-29用户确认本次比赛只开放岩系旅行者，雷电将军留到下一版本；负责岩系旅行者两幕玩法和单角色公开白名单。显式full-source开发配置保留全部八种角色、雷电冻结V4与既有代码证据；下列雷电设备验收仅为未来要求，不计本次比赛必做。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 共享结算、选择交互与职业专属机制明确依赖和执行范围，领取后才开展开发，独立切片可并行，完整回归串行。
- [x] #2 原生75战士、三职业基础及61/56/55张实验卡、共享选择队列和离线职业菜单已合入并有冻结回归记录。
- [ ] #3 岩系旅行者的卡池、机制及道具交互按本次比赛首发清单逐项验证。
- [ ] #4 岩系旅行者自然获取卡牌并形成不同合法构筑，连续战斗与跨幕状态正确。
- [ ] #5 同一候选岩系旅行者自然完成第一幕和第二幕并正常结算，保存平台日志与截图。
- [ ] #6 正式比赛版仅开放岩系旅行者；其余七种角色不显示占位，公开入口、配置和随机职业选择均不可进入；显式full-source开发配置保留八种角色。
- [ ] #7 未来版本要求（不计本次比赛必做）：雷电将军V4愿力、雷眼、一心机制与卡牌完整可玩并完成真实设备验收。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
按完整四职业卡池及第一幕、第二幕当前比赛范围验收。独立工作树交付共享结算、完整合法来源及原生UI，保留所有同局机制、规则与证据标准；不为后续章节、跨局解锁或历史资格建立持久化后端。

2026-10-29按用户本次确认收敛公开职业为岩系旅行者；同步当前文档、里程碑、正式入口和范围门禁。历史两职业计划及雷电冻结V4未验收要求保留为未来候选，不自动完成任何验收。
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

2026-10-26状态整理：PR206已合入四职业整合，PR213已合入跨幕核心；不再把历史API Forbidden或paused当阻塞。生产战士75和实验66/61/56/55需分开，旧238/300不可直接当当前完整总数。本轮16.3/57.2/58.3/59.1本地机制切片已实跑收口，其余6个构筑子任务补为3/4；完整卡池、正式职业入口及自然通关仍缺。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-26 AC3按实际职业/共享核心分工、独立切片整合及串行完整回归记录勾选；不代表AC1/2/4的完整覆盖和自然通关通过。

本轮colorless独立提交完整35普通无色牌及4SPECIAL生成依赖，父线程已发现并修正无实体预览/持续能力说明与图标问题，正在组合Discovery及永久UID增长验证。三职业完整源池和余下牌效仍缺，不能用无色清单计入300职业牌，也不勾完整/自然/平台AC。

2026-10-27组合复审：最新主线商店/卡牌子视图抽取已合入隔离集成树。发现并修正无色动态模板索引导致商店崩溃，新增78基本/升级显示数值回归与真实商店说明通过。原640呈现矩阵及商店多角色fixture仍遇原30秒超时，另树分析注册/拷贝开销；不加时限、不减断言，当前不宣称完整检查通过。

2026-10-27优先级重排：High：四职业完整接线是后续章节逐职业验收的上游依赖，不能用实验子集代替。 解除后移出High再提升下一项；不放宽原验收。

2026-10-27运行时重算：以81f3ffd2的实际Run.new入口加载当前JSON与Lua，四职业各75张共300张的基本/升级Capability均通过；战士reward/src/shop各72个唯一ID，其他职业各71个，逐ID双版本无缺定义；四职业各33瓶药水均通过生产available定义检查。第三幕3弱/8强/3精英与三Boss均有生产路由，七普通事件仍缺MindBloom和Mysterious Sphere映射。PR252本次记待合，最终合并由主线程另行核对。证据：docs/evidence/m3-runtime-audit-20261027.json及docs/backlog-details/BACKLOG-UPDATE-20261027.md本轮节。Capability不代表逐牌实际执行或原版完整一致；定义注册和路由不代表自然获取、概率全链或平台通关。本次只更正首页与追加事实，状态、负责人、优先级、依赖和全部验收项保持，不新增勾选；历史数量和旧备注保留原样。

2026-10-28接续核对：当前主线b7dffdeb已包含PR238/250/252/259/262，第四幕及真结局接线不再待合并。M3当前32/46 Done，14项未完成。最新整合、遗留工作树与具体证据边界见docs/M3-STATUS-20261028.md；旧PR待合/冲突备注仅属历史。本次不新增自然获取、四职业四幕、平台导入或实机通过，不修改既有AC。

2026-10-28用户确认范围变更：当前比赛只覆盖第一幕、第二幕，优先前10分钟体验；第三幕/隐藏第四幕/真结局及依赖退出续玩、跨局进度、历史解锁或跨局留卡的内容退出比赛必做，保留为无新截止日的未来候选。四职业及已批准原创角色要求不变。同局跨房间、第一幕到第二幕的资源与随机流、内存快照/回滚和本局结算保留；源码/候选/平台/实机仍分层，未完成状态不因范围调整改变。
原AC4（仅保留历史要求，不再作为当前比赛必做）：固定来源版本和规则基线，差异逐项追踪；全部已开放章节逐职业正常通关并保留同候选日志与截图。

2026-10-28范围复审：当前Description已改为前两幕比赛范围；旧描述仅作历史记录，不再要求本次比赛四幕或持久Save能力。
原描述（历史）：当前运行时已装配四职业各75张，共300张，基本版和升级版均被效果系统接受；战士常规来源各72项，其余职业各71项均无缺定义。继续核对实际效果、生成及道具交互、完整随机链和自然构筑；正式平台开放及四职业四幕通关仍未验收。

2026-10-28范围决定：比赛范围见 docs/SCOPE.md；旧验收文字保留于历史记录，本次未新增通过证据。原受影响验收：四职业完整卡池、状态、生成牌、遗物与药水交互均有覆盖账本，逐项区分缺失、离线通过及实机通过。；各职业主要构筑及合法混合组合有真实获取和连续战斗证据；不以有限预设套牌代替全部合法机制。；固定来源版本和规则基线，差异逐项追踪；当前比赛第一幕、第二幕逐职业正常连续通关并保留同候选日志与截图，第三/隐藏第四幕与跨局历史不作为比赛必做。

主线历史：TASK-79关键CI修复在精确cd9源码头完成17项检查并经独立审查；后续CI及合后稳定性另行核验。

2026-10-29单角色范围同步：用户本次确认覆盖旧两职业公开要求。AC1/2勾选仅原有历史证据原样保留，未新增通过项；其余验收保持未勾。雷电冻结V4与全源码八形态留开发/未来版本，不冒充本次候选、实机或自然通关通过。

PR323原39dab5e9历史实施记录承接（不认证本组合，当前公开范围以docs/SCOPE.md仅岩旅行者两幕为准）：
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

2026-10-26状态整理：PR206已合入四职业整合，PR213已合入跨幕核心；不再把历史API Forbidden或paused当阻塞。生产战士75和实验66/61/56/55需分开，旧238/300不可直接当当前完整总数。本轮16.3/57.2/58.3/59.1本地机制切片已实跑收口，其余6个构筑子任务补为3/4；完整卡池、正式职业入口及自然通关仍缺。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-26 AC3按实际职业/共享核心分工、独立切片整合及串行完整回归记录勾选；不代表AC1/2/4的完整覆盖和自然通关通过。

本轮colorless独立提交完整35普通无色牌及4SPECIAL生成依赖，父线程已发现并修正无实体预览/持续能力说明与图标问题，正在组合Discovery及永久UID增长验证。三职业完整源池和余下牌效仍缺，不能用无色清单计入300职业牌，也不勾完整/自然/平台AC。

2026-10-27组合复审：最新主线商店/卡牌子视图抽取已合入隔离集成树。发现并修正无色动态模板索引导致商店崩溃，新增78基本/升级显示数值回归与真实商店说明通过。原640呈现矩阵及商店多角色fixture仍遇原30秒超时，另树分析注册/拷贝开销；不加时限、不减断言，当前不宣称完整检查通过。

2026-10-27优先级重排：High：四职业完整接线是后续章节逐职业验收的上游依赖，不能用实验子集代替。 解除后移出High再提升下一项；不放宽原验收。

2026-10-27运行时重算：以81f3ffd2的实际Run.new入口加载当前JSON与Lua，四职业各75张共300张的基本/升级Capability均通过；战士reward/src/shop各72个唯一ID，其他职业各71个，逐ID双版本无缺定义；四职业各33瓶药水均通过生产available定义检查。第三幕3弱/8强/3精英与三Boss均有生产路由，七普通事件仍缺MindBloom和Mysterious Sphere映射。PR252本次记待合，最终合并由主线程另行核对。证据：docs/evidence/m3-runtime-audit-20261027.json及docs/backlog-details/BACKLOG-UPDATE-20261027.md本轮节。Capability不代表逐牌实际执行或原版完整一致；定义注册和路由不代表自然获取、概率全链或平台通关。本次只更正首页与追加事实，状态、负责人、优先级、依赖和全部验收项保持，不新增勾选；历史数量和旧备注保留原样。

2026-10-28接续核对：当前主线b7dffdeb已包含PR238/250/252/259/262，第四幕及真结局接线不再待合并。M3当前32/46 Done，14项未完成。最新整合、遗留工作树与具体证据边界见docs/M3-STATUS-20261028.md；旧PR待合/冲突备注仅属历史。本次不新增自然获取、四职业四幕、平台导入或实机通过，不修改既有AC。

2026-10-28用户确认范围变更：当前比赛只覆盖第一幕、第二幕，优先前10分钟体验；第三幕/隐藏第四幕/真结局及依赖退出续玩、跨局进度、历史解锁或跨局留卡的内容退出比赛必做，保留为无新截止日的未来候选。四职业及已批准原创角色要求不变。同局跨房间、第一幕到第二幕的资源与随机流、内存快照/回滚和本局结算保留；源码/候选/平台/实机仍分层，未完成状态不因范围调整改变。
原AC4（仅保留历史要求，不再作为当前比赛必做）：固定来源版本和规则基线，差异逐项追踪；全部已开放章节逐职业正常通关并保留同候选日志与截图。

2026-10-28范围复审：当前Description已改为前两幕比赛范围；旧描述仅作历史记录，不再要求本次比赛四幕或持久Save能力。
原描述（历史）：当前运行时已装配四职业各75张，共300张，基本版和升级版均被效果系统接受；战士常规来源各72项，其余职业各71项均无缺定义。继续核对实际效果、生成及道具交互、完整随机链和自然构筑；正式平台开放及四职业四幕通关仍未验收。

2026-10-28范围决定：比赛范围见 docs/SCOPE.md；旧验收文字保留于历史记录，本次未新增通过证据。原受影响验收：四职业完整卡池、状态、生成牌、遗物与药水交互均有覆盖账本，逐项区分缺失、离线通过及实机通过。；各职业主要构筑及合法混合组合有真实获取和连续战斗证据；不以有限预设套牌代替全部合法机制。；固定来源版本和规则基线，差异逐项追踪；当前比赛第一幕、第二幕逐职业正常连续通关并保留同候选日志与截图，第三/隐藏第四幕与跨局历史不作为比赛必做。

主线历史：TASK-79关键CI修复在精确cd9源码头完成17项检查并经独立审查；后续CI及合后稳定性另行核验。

2026-10-29用户明确本版只旅行者，雷电留下一版本；授权发布与合并不等于已经平台发布。原AC逐字快照见docs/evidence/traveler-scope-before-20261029.json，雷电未验项迁TASK-85；已勾历史AC与旧备注保留。用户自述旅行者自然两幕通关，候选hash未提供，不勾同候选日志/截图条件。

2026-10-29合流保留上游证据：

上游PLAN历史增量（其旧角色范围已由旅行者单角决定覆盖）：
按完整四职业卡池及第一幕、第二幕当前比赛范围验收。独立工作树交付共享结算、完整合法来源及原生UI，保留所有同局机制、规则与证据标准；不为后续章节、跨局解锁或历史资格建立持久化后端。

合流双方完整metadata、AC、计划和实施notes见docs/evidence/backlog-merge-20261029.json；当前角色范围按旅行者单角两幕，雷电未来任务原81因上游重号经原生doctor改为TASK-85。所有原已勾AC不改，未验不勾。

2026-10-29用户明确研发顺序：先集中完成并验收旅行者比赛版本及投稿准备，雷电将军待旅行者版本完成后另开下一版本规划与验收；当前不并行推进其功能、美术或发布。已完成的V4资产和代码保留。

2026-10-31规划收口：按PR409固定655c500的STS1-DELTA-20261031「用户决定与排期」中明确授权，宽泛父项TASK-59依顺序让出一个必要High名额给已确认的事件身份外露TASK-4.18；验收要求、状态与全部AC不变。其余既有High不降级。
<!-- SECTION:NOTES:END -->
