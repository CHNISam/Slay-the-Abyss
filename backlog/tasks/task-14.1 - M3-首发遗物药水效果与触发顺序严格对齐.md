---
id: TASK-14.1
title: 补齐遗物药水剩余效果和正常获取
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-27 04:21'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-14
references:
  - data/SOURCES.md
  - data/relics.json
  - data/potions.json
  - docs/backlog-details/TASK-14.1.md
  - docs/reviews/TASK-14.1-m3-inventory-audit.md
  - docs/reviews/M3-PACK-POTION-20261025.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/reviews/M3-EVENTS-INVENTORY-INTEGRATION.md
  - docs/backlog-details/BACKLOG-UPDATE-20261027.md
parent_task_id: TASK-14
priority: high
type: enhancement
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已交付基础库存、大批药水效果及部分正常渠道，完整效果与自然获取仍需逐件验收。当前PR238同步主线后，库存恢复和钨合金棍自然来源两份回归失败；先修复并通过最终SHA完整CI，再补同候选全池组合与平台证据。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 已实现道具的固定来源、规则和已知差异已留档，未实现项单列。
- [x] #2 药水使用、选牌、丢弃、扩槽及永久库存事务已接入；105项药水专项和13份遗物/诅咒专项已通过。
- [x] #3 已实现用例覆盖背包命令、跨房间、战后、重复操作与失败回滚，39项输入/原子性回归已有记录。
- [x] #4 本地、候选读回和已有实机记录已分层保存；未导入或未实测的项目明确标记。
- [ ] #5 补齐完整原版道具池中尚缺的遗物/药水效果，并逐件核对数值、对象、持续时间、限制和触发顺序。
- [ ] #6 接通21瓶待获取药水及完整33项采样器的正常奖励/商店来源，保持原版概率，不靠去掉门禁或重抽放行。
- [ ] #7 全池逐件验证叠加、跨房间、战后和重复使用；尚未实现的组合不能沿用已有子集测试判通过。
- [ ] #8 同一候选逐件自然取得、使用和触发，保留对应平台日志与截图。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-24 M3复核：以当前13遗物和7药水清单重新审计来源、效果与正常获取入口；优先补真实库存入口的状态边界和奖励后使用验证。仅当固定来源及红例证明当前差异才改生产代码，不重做已合固定槽或开战顺序。更新专项账本，平台和正版PC证据继续独立保留。

原版PotionPopUp与AbstractPotion.canDiscard明确支持主动丢弃，当前缺入口。追加离线切片：先写Run.discardPotion真实槽位和无效输入原子性红例，再最小新增库存命令；UI接线由主线程随后处理。本树不碰UI。

2026-10-24 用户确认原神已开并授权任意必要验收：从develop31a8f37固定源构建新副本并独立读回；确认窗口/同级权限，clientScriptLog=true导入新存档，取本轮ready/日志/截图。正常资源下验证战后发瓶、跨节点用瓶、丢弃后换瓶与资源账本；明确自动命令驱动和物理UI输入的证据边界，不外推全件实玩或M3整体通过。

2026-10-25 用户批准完整原版内容池：分别固定Ironclad A0第一幕遗物和药水完整来源/顺序/消费目录、实际可达渠道与机制依赖，再按效果钩子分组补齐。13遗物/6可获药水只是历史基线，不能通过受限桶或缺项重抽保持自报概率；跨色等合法依赖必须明确，不静默删池。目录、实现、平台与自然实玩仍分层验收。

2026-10-25 资料包接入M3：复用生产Run/UI，补状态变化但尚未重绘时旧选敌确认、同ID换瓶和取消的全状态原子性回归；证红后才修复。代际冲突待用户明确，不改数值、卡池和版本。分开记录候选、官方导入和同候选试玩。

2026-10-26本轮M3并行：inventory独立工作树审计剩余效果后接完整33药水采样及奖励/商店正常渠道，不能只撤acquisitionPending、删池或重抽；父线程统一验证集成与Backlog写入。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24 M3当前清单复核：13遗物/7药水定义、27份固定镜像blob及限制见docs/reviews/TASK-14.1-m3-inventory-audit.md与source-identity.json。未重复改固定槽/开战顺序/已修力量上限。补原版主动丢弃：Run命令4红→4绿，三槽选择确认接通活动局顶栏，奖励/商店满槽可丢旧瓶后原槽领取/购买，保留短按用药。UI9绿含run/phase/换瓶/同ID真实补回/resize/关闭重开/终局旧确认和用药手势，旧指针问题先红后换背包身份修绿。6种自然战后瓶用原始牌组实际击败Cultist后领取、跨map相位下一战生效6绿。既有专项及JS host/layout13全过，独立子代理复审UI9+布局2通过。没有平台构建/导入/实机，Boss3件终局后无自然后续触发、Poison无战士自然入口、正版来源认证和完整队列仍保留，四项全量AC不勾。

2026-10-24 固定31a8f37新候选官方导入1845，47模块/2298控件读回一致。正常114金币商店购火瓶50→64，三槽确认丢弃不扣费，再购同ID火瓶50→14；携至第3层使用，12血赤甲虫死亡、另敌15/15、能量3/3、库存1→0，空槽重按不变。新27号日志106打印含本轮ready、药水命中12/致死、ABYSS_SETTLEMENT_DEFEAT；真实离开后落盘。首战与开局有人协助，不归因全自动输入；20点基础伤害在12血目标截断，本轮不认证精确20。满槽替换/余下瓶/全件触发和全UI门禁仍缺，AC不勾。官方图严格字段审计失败保留（布局/省略默认值），未放宽审计。证据见docs/M3-LIVE-INVENTORY-20261024.md及docs/evidence/m3-live-31a8f37/receipt.json。

2026-10-25 五瓶Swift/Weak/Fear/Ancient/LiquidBronze真实Run库存效果已实现，12组Lua/3项JS及相关门禁通过。五瓶暂acquisitionPending并列明清单排除，两个旧selector保原6瓶获取轨迹；不能把此隔离误当原版概率。完整33统一接入时必须移除此排除，不跳过unsupported。SacredBark/onUsePotion等依赖保留。见docs/reviews/TASK-14.1-potion-basic-five.md。

用户明确把资料包接入作为M3冲刺一环。最新develop3ed8bf4已批准完整内容池，旧30张仅为接线盘点；资料包记录STS2方向，而当前SCOPE仍STS1，已向用户请求锁定代际和构建。免费委派限额未有恢复依据，本片由Codex直接执行。

资料包药水目标事务验证切片：新增tests/lua/potion_target_rejection.lua，生产host监听器7/7通过（无render旧目标死亡/替换/换序/同ID换瓶/turn/phase与取消重选）。现有targeting5、commit4、input ownership7、discard UI10通过；launch-content13项及verify:backlog通过。独立子代理复跑7/7且无确认P1/P2。未复现需改生产代码的缺陷，保留现有实现；平台/自然获取不计通过。候选构建另记。源码规则代际待用户明确，不改数值或范围。

本片候选离线构建与独立读回通过：运行时固定源3ed8bf4，61/61模块逐字节匹配，UI2824/max60，结算22节点，0error/33warning原样保留。候选SHA256 f2808674cca47de5aade4871fc0da82fdd9d25c801e6cc7d31ec4cd0400bdf68，位置及图审计有限范围见docs/reviews/M3-PACK-POTION-20261025.md。官方导入、同候选真实试玩、自然获取未验证；父任务AC不勾，M3未验收。

2026-10-25 本轮M3生产切片在独立树完成串行集成：四事件/永久事务/十种诅咒清除，战士药水效果与五槽原生UI，33common+3special遗物触发。详见docs/reviews/M3-EVENTS-INVENTORY-INTEGRATION.md。事件69项、药水20份105项、遗物13份及inventory11项本地通过；全部72非基础合法胜利领奖分片保留通过，旧160卡面断言经真实RED修为178版本GREEN。完整含BGM候选cf77beea4ef77dbda269b344a4c972ac6aac7dff0621fa5acc807a0f364ab728，71模块与bd93be7逐字节一致，静态0错误36警告；归档.artifacts/m3-events-inventory-20261025，最终提交还须再次audit及当前PR完整CI。官方导入、同候选真实试玩、BGM听测、UI总门禁未验证。完整25自然事件池、剩余遗物效果、33药水自然渠道及6种效果、Spirit Poop生产总分仍缺，父任务/M3不标完成。

2026-10-25 最终候选更新：领奖事务保留独立RewardItem owner且完整异常回滚，旧奖励UI断言保持并通过；permanent_transactions13项、178卡面、25项来源契约及十组旧流程回归完成。生产源ded810f0f7b403b564bee64df06117587957500f重建含BGM候选4d9f3d0a0e21e9ea4f7e96eca7adf8ae1eaede4c117ec02aa6022f5e4d8c7f8c，71模块逐字节独立读回，静态0错误36警告。稳定证据.artifacts/m3-events-inventory-20261025，最终PR头完整CI/合并仍待实际结果。按用户最新要求，任何鼠标键盘/抢焦点/实机输入先约本轮窗口；本轮未获桌面窗口，官方导入、同候选真实试玩、BGM听测与UI总门禁未验证。全池/自然渠道/总分及平台缺口继续保留，父任务与M3不标Done。

2026-10-25 RC2：保留develop已合入PR207布局，源3e9873220cf5aa055799992c906ade0daf167f63重建含BGM候选8c8f04612f6c1858b5146fb2355eda020e3fcf342f897d1e187d88f0a2097ce0，71模块逐字节审计，静态0错误/36警告。旧e1全CI首轮药水预算超时、仅一次重跑后Node全过但Lua旧oracle失败，日志均保留；七份旧oracle按当前契约校准，失败身份/RNG/完整75/UID及下战断言和原时限不降，17个Lua入口+12个Node本地通过。最终头完整CI及合并以本PR实际记录为准，父任务/M3保持In Progress。没有桌面输入窗口，不操作鼠标键盘或抢焦点，官方导入/同候选试玩未验证。

2026-10-25 CI环境校准：1647330完整Node1268pass/119既有skip/0fail、数据通过；本机Node22三份Lua超时，GitHub45分钟取消，仅完成到potion_status_rules，未合并。官方校验便携Node24在同机原预算下living_wall18267ms/card_help_release20229ms/battle_ui48674ms全部通过。Quality仅固定Node24.18.0，源码/候选/系统MCP Node及全部断言、45分钟与单测预算不变。最终头完整CI仍待真实结果，平台未验证且无桌面窗口，父任务保持In Progress。

2026-10-26状态整理：PR197/200/206已整合库存与事件道具推进，旧1647330的Node环境/CI等待不能作为当前阻塞。按当前完整目录逐件核效果、获取和随机消费，保留尚未证明的组合与平台记录。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-26测试状态澄清：现有自动化覆盖的是已实现内容和明确边界；生产abyss_potion_rewards仍按acquisitionPending排除新瓶，并从受限池选择，故剩余不仅是实机缺测。依据M3-EVENTS-INVENTORY-INTEGRATION及当前生产代码；本轮无新增测试或玩法修改。

2026-10-26逐项AC校准：将混合的已实现/已有自动回归与完整池/平台待验拆成独立条款；依据既有合并及验证记录勾选，不新增通过结论。原验收快照保留docs/evidence/backlog-ac-before-20261026.json，全部原范围要求由拆分后条款继续承接。

父线程Node24独立组合复验全部33瓶两渠道13分片0失败；无色依赖已合成后真实78双版本执行通过。独立审查发现匕首增长逃跑丢失，已修到所有成功命令/药水事务边界并实跑Smoke/Chaos/选牌/失败回滚。没有新GIL/导入/实机。

2026-10-27独立复审确认鲜血药水与魔法花重复倍率，已在集成树按固定源改为原量入队、实际治疗一次修正；21旧项及新增Toy排队项合计22通过。另核实黏液/转轮事件致死绕过瓶中精灵，m3-event-fairy独立树修战外自动复活与回滚，不冒充完整遗物自然获取或平台通过。

2026-10-27事件Fairy8组已在集成树独立复验，含Bark/Bloom、物理槽、陈旧战斗隔离、后续缺遗物导致的HP/瓶/RNG/owner完整回滚；鲜血治疗22组与实际缺牌/升级奖励2组通过。当前PR234完整门禁仍待新SHA结果，不将专项当全池组合或实机。

2026-10-27最新合并回归核对：PR238远端仍a4dac772、草稿且冲突，未合并；fc51f198同步尚未提交。最后定向结果inventory_restore失败13.626秒（750 ~= 738），tungsten_rod_channels失败1.045秒（smiling_mask ~= tungsten_rod）；toxic_egg_profiles通过1.996秒、relic_top_bridge通过2.890秒。先按真实恢复/自然获取路径诊断，不删断言、缩池或升预算。证据根build/pr238-resume-20261027-091929/fc51-final-focused.json及同目录fc51-final-*.log。不得沿用同步前成功认证本次合并，全池与平台AC继续未勾。

2026-10-27优先级重排：High：当前PR238库存恢复与道具正常来源回归失败，直接阻塞整合收口。 解除后移出High再提升下一项；不放宽原验收。
<!-- SECTION:NOTES:END -->
