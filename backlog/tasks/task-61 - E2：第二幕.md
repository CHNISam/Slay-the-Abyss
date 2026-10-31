---
id: TASK-61
title: 接齐第二幕敌人、事件和正式游玩流程
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-23 01:59'
updated_date: '2026-10-31 01:23'
labels:
  - required
  - sts1
  - acts
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-63
  - TASK-59
references:
  - docs/SCOPE.md
  - docs/backlog-details/DRAFT-2.md
  - docs/rules/CROSS_ACT.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/backlog-details/BACKLOG-UPDATE-20261027.md
  - docs/M3-STATUS-20261028.md
  - docs/backlog-details/TRAVELER-SCOPE-20261029.md
  - docs/evidence/backlog-merge-20261029.json
priority: medium
type: feature
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
完成第二幕比赛内容及岩系旅行者单角色连续两幕流程；现有本地成果保留，雷电将军验收转TASK-85。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 第二幕18至34层按原版地图、遭遇权重和全部三种Boss合法生成，并按比赛双幕配置完成本局，不接第35层。
- [ ] #2 第二幕不依赖持久存档的普通事件、神龛和一次性事件按冻结比赛清单执行，资格、内部交易及事件战斗正确；跨局历史依赖单独列为未来。
- [x] #3 第二幕18至34层地图、来源队列与跨幕资源迁移基础已合入PR213并有独立向量和事务回归。
- [ ] #4 岩系旅行者从正常开局合法连续通关第一幕和第二幕且资源继承正确，保留同候选平台证据。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
按已合入第二幕代码补真实缺口，保留原版遭遇、AI、同局奖励/事件及随机流；正式比赛在第二幕合法结束，不再把第三幕入口或跨局历史能力列为本任务依赖。源码、同候选自然流程和平台通关分别验收。

2026-10-29当前角色范围仅岩系旅行者；第二幕完整内容、权重、全部三Boss、跨幕状态与同候选实机标准保持。

2026-10-31 本轮排查：逐项核对前两幕事件与遗物目录、比赛裁剪和正式输入链；以Beyond Simulator及真实Lua事务复现不可选项，补红绿回归；修复后独立复审、候选读回及当前SHA CI。实机与手机证据单独保留未验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26状态整理：PR213已合入第二幕地图/队列/转场共享基础，但第二幕怪物AI与事件体尚未实现，正式Host未接，不能当内容齐备。仍To Do；内容实现从现有核心继续，勿重写地图。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

本轮隔离分支已增量实现第二幕全部5弱/8强/3精英所需怪物与编组，含Hex、Flight、Confusion、吸血破甲、Leader真实召唤；Champ已实现，另外两Boss和事件敌人仍缺。各切片定向红绿与固定源SHA账本见docs/rules/ACT2_ENEMIES.md，父线程正在组合验证。当前不是完整第二幕/平台验收，三项广义AC不勾。

2026-10-27组合复审：真实Leader重复Rally保留尸体后，活敌真实索引超过5导致界面不可见已复现。独立m3-summon-visibility树正在分离显示槽与actor身份，保留核心尸体、点选/拖牌/帮助/反馈及旧输入保护；缺陷修复及当前SHA完整检查完成前不提高父任务验收状态。

2026-10-27组合修复已合入隔离候选源码：第二幕19常规编组含3Boss本地可进入，召唤5槽映射保留核心尸体/真实actor索引与UID；章节非稀有奖励升级按0/25/50/50%贯通到真实卡面、纯数据奖励与永久领取。首轮完整JS1437通过/5失败/119既有条件跳过，五处旧合同已逐项核实并定向修复，完整检查重跑中。事件专属敌人、第二幕事件、自然全程与平台仍未验，父任务不Done。

补齐Beggar、Mausoleum、Addict事务及现有控件界面，接入Darkstone永久诅咒钩子；修正Mystic接收者引用快照、Vampire治疗先于反伤、V4 Life Suck攻击识别、Plated及相关反应进入已有队列的顺序。保留空所有者菜单与Start失败发布边界。实现见src/lua/abyss_act2_events.lua、abyss_node_ui.lua、abyss_effects.lua、abyss_plated_armor.lua；顺序与限制见docs/rules/ACT2_ENEMIES.md。回归见tests/lua/m3_combined_queue.lua、m3_current_owner_event_keys.lua、plated_armor_queue.lua、act2_party_snapshot.lua、act2_vampire_order.lua、original_v4_vampire_attack.lua及原game_ui_owner_initialization.lua、game_ui_phase_four.lua。本地聚焦与相关回归通过，完整Quality以PR当前提交检查状态为准。原生客户端、自然四职业连续四幕、历史生产/持久化、全源事件/遗物/宝箱池仍未证明；空必选牌组不提供跳过或退款，死亡攻击者Vampire与部分Darkstone战斗健康上下文限制保留。 本轮基于最新develop增量整合，保留原版来源拖牌/持续选目标、共享卡面装配与卡牌ID美术接线；未引入新的同步反应结算。

古老文字（Back to Basics）本地增量按固定319009d5来源实现：优雅免费复用永久删牌/Parasite钩子，非瓶装可清除牌按唯一UID选择，空合法组直接结果。简洁仅认八个源初始打击/防御ID，瓶装牌照常升级，已升级牌不重复；零目标有效，缺失/不支持的源目标升级内容在任何写入前原子拒绝。原创V4可选优雅，简洁因初始源标签映射未确认明确不可用（实现边界，不是源职业规则）。两分支均结果页另按离开回图；四参选牌内部canCancel=true，其余升级/变形/清除/任意数量标记为false，正常事件不显示取消，不套用Beggar付费强制元数据。既有NodeUI控件、13项完整实验池精确映射与默认受限七事件池保留。新17公开事务/9生成控件组、既有三Act2事件/UI/目录、永久删牌事务及源钩子相关回归通过；架构143模块701边、固定Luacheck无新增诊断，四关键语义变异均由原断言杀死。实现与来源限制见docs/rules/BACK_TO_BASICS.md，回归见tests/back-to-basics-event.test.mjs及tests/lua/back_to_basics_event.lua、back_to_basics_ui.lua。完整Quality与官方客户端/自然四职业连续流程NOT_RUN，不勾全量AC，不关闭TASK61/M3。

2026-10-27合并状态更新：PR232已合入develop fc51f1987130e398538e9663b736d66090dfdd07；精确接受HEAD为4a14598c8cd5284e210917bb7818d02c9100bf68，完整Quality 40441075319与Licenses 40441075355均成功，合并树与该HEAD相同。本任务上述第二幕事件、源结算和Back to Basics切片不再只是未发布候选。本备注仅更新合并事实；完整源卡牌/事件/遗物/宝箱池、剩余钥匙与隐藏结局、官方客户端/平台及自然四职业连续四幕仍未齐备，不据此勾全量AC或改变任务状态/负责人。后续输入整合须另跑新HEAD完整Quality。

2026-10-27主线核对：PR232已合入develop fc51f198，第二幕事件、钥匙和源结算顺序有新增本地成果，不能继续视为全未实现。PR238主集成同步此版本仍未提交且有两份库存相关失败；本任务完整第二幕与正式跨幕自然通关尚未验收。保留现有AC，先收口当前合并/CI，再补同候选自然通关和平台证据。

2026-10-27 Ghosts 独立内容切片在已接受 b164fda7 定向集成：固定源缓存和旧实现复用，构造期成本缓存、真实永久上限支付、5次公开取得及完整回滚已接，保留新输入/手柄/卡面/公告/损血复活修复。当前44项Node与5份相关Lua、架构146/719、固定Luacheck无新增、4项关键变异通过；最终两条fixture/契约修订后26项核心再通过。Toxic Egg缺失只用显式私有缺能力夹具验证拒绝，不冻结全局缺失；隔离使用fd80真实遗物owner与定义的未来组合12+4组通过，8档五次升级、实际后置成本/金币和晚拒绝回滚可查，仅Ironclad验证升级后下一战，不冒充完整PR238或自然通关。默认池与完整13池顺序/资格/概率未改。独立PR当前SHA完整CI与平台仍待证据；整项TASK61/M3不关闭。

2026-10-27 Ghosts 合并核实：PR248 精确HEAD f56271b648893f7cf82dce389c0e115468b80f0f，Quality40474624519全部7作业及Licenses40474624562成功，已合入develop dc5b22319980c6fb63ee1f58a306acaf91c441b1，合并树49f2649096c6a19a682122b275cdf3ecbfda4345与候选一致。此轮本地组合保留PR238当前事件与Ghosts注册/获得钩子；Library等新增叶尚须组合验证和独立PR，不关闭整项第二幕或M3验收。

整合执行时最新develop dc5b223（PR248 Ghosts源事件和PR246批准插画制作基线）；保留本轮Joust/第三幕/Neow及既有事件来源入口，Ghosts已接真实Act2分发、Pool与NodeUI，不重复开发。组合定向及当前SHA完整Quality仍待，此广域任务不据此勾整体验收。

2026-10-27 独立源码增量候选：Library已按固定319009d5接入20张不同源卡选一、重复重抽稀有度与身份、不改pity、逆序展示、独立预览与公开永久取得、构造期缓存Sleep及独立Leave。四职业真实目录/RNG/下一战和原生控件模拟通过，独立源码审查PASS；与已接受Ghosts/Toxic Egg及当前版本公告组合后，87项Node与177组既有Lua回归、构建/架构/固定静态门禁通过。相关实现见docs/rules/THE_LIBRARY.md；默认来源池顺序概率未改。未认证原生客户端、全事件/自然连续四幕；整项AC保持未完成，当前新PR完整Quality仍待。

2026-10-28接续核对：当前主线b7dffdeb已包含PR238/250/252/259/262，第四幕及真结局接线不再待合并。M3当前32/46 Done，14项未完成。最新整合、遗留工作树与具体证据边界见docs/M3-STATUS-20261028.md；旧PR待合/冲突备注仅属历史。本次不新增自然获取、四职业四幕、平台导入或实机通过，不修改既有AC。

2026-10-28 dot巢穴独立切片：固定社区镜像319009d5的Nest/DamageInfo/RitualDagger/获得效果四份来源hash复核，按intro→continue→99金币或NORMAL损血6后获得仪式匕首→结果→独立离开接入真实Act2/Pool/Nodes。默认七事件与完整13项顺序概率未改。新10组永久事务与5组真实生成UI/公共Nodes回归通过；实际先复现致死返回pending，再补Act2失败收尾；19项既有Act2回归通过。真实来源账本登记Nest及匕首事件渠道，单卡实际增长复用已有实现。PR260持有NodeUI，当前复用通用未知事件标题、按钮及旧输入保护，不抢写。源码/离线模拟已验，完整精确SHA CI、自然四职业路线、GIL导入/ready及PC/实体手机仍未验，不勾整体AC、不改状态。

PR267首轮完整Quality40619558644实际保留一项Windows失败：phase_four_presentation_render.lua在30040ms超时，前三职业通过但Watcher未完成；不当作PASS或盲重跑。同缺陷已由PR266原执行者在ca376218修正，本分支原样复用其tests-only预算拆片（含配套Transient/发现门禁），不重复实现、不改时限或生产代码。原720变体分160/180/180/200逐份实际通过5.25/6.19/6.08/7.07秒，原19Transient组及预算门禁8项通过；独立复审与新精确SHA完整CI继续，旧失败保留。

2026-10-28 已按PR266真实合入f1ab9a9接回最新develop，保留其完整任务对账、54遗物/复活共享实现与测试修复；冲突任务页从该真实基线恢复后仅用CLI追加本切片原计划与证据。原样复用修复不再作为相对develop的新改动。新增持久Nest/Tail真实Nodes组合：首次复活、同局第二次致命、两瓶Fairy优先、Mark禁止治疗/消耗、晚获牌失败回滚重试；原候选隔离4组通过，当前最终组合再验。此处是源码集成，不扩张自然/平台验收。

2026-10-28用户确认范围变更：当前比赛只覆盖第一幕、第二幕，优先前10分钟体验；第三幕/隐藏第四幕/真结局及依赖退出续玩、跨局进度、历史解锁或跨局留卡的内容退出比赛必做，保留为无新截止日的未来候选。四职业及已批准原创角色要求不变。同局跨房间、第一幕到第二幕的资源与随机流、内存快照/回滚和本局结算保留；源码/候选/平台/实机仍分层，未完成状态不因范围调整改变。
原AC1（仅保留历史要求，不再作为当前比赛必做）：第二幕18至34层按原版地图、遭遇权重和全部三种Boss合法生成，接上第35层
原AC2（仅保留历史要求，不再作为当前比赛必做）：13普通事件及神龛、一次性事件资格、内部交易和事件战斗真实执行

比赛Boss内容与合法同局流程保留，但跨局Boss已见/解锁历史不列必做。正式平台无历史provider，不能把默认Guardian/Champ优先策略冒称全Boss自然历史已验证；冻结比赛Boss资格策略与待验缺口须在TASK-47/77明示。

2026-10-28范围决定：比赛范围见 docs/SCOPE.md；旧验收文字保留于历史记录，本次未新增通过证据。原受影响验收：四职业分别正常连续通关且资源继承正确，保留同源本地、集成和平台证据

2026-10-29用户决定：本版仅岩系旅行者两幕，雷电将军验收转未来TASK-85。原AC与计划完整快照：docs/evidence/traveler-scope-before-20261029.json；历史通过项不撤销，未通过项不勾选。用户自述旅行者自然通关，候选hash未知，不作为同RC日志或设备全量证据。

合流双方完整metadata、AC、计划和实施notes见docs/evidence/backlog-merge-20261029.json；当前角色范围按旅行者单角两幕，雷电未来任务原81因上游重号经原生doctor改为TASK-85。所有原已勾AC不改，未验不勾。

2026-10-31 实际GIL对照：v13缺11事件映射，旧包真实遗物获取拒绝；PR357/377后的4c262462集成候选已含补全。本轮新增42事件、130遗物与11复杂选择的正式比赛配置广域回归；证据及验收边界见 docs/reviews/TWO-ACT-SELECTION-AUDIT-20261031.md。用户实际包身份、同候选官方与设备复验未齐，保持未完成。
<!-- SECTION:NOTES:END -->
