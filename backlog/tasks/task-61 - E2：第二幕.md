---
id: TASK-61
title: 接齐第二幕敌人、事件和正式游玩流程
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-23 01:59'
updated_date: '2026-10-28 01:36'
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
priority: medium
type: feature
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
第二幕地图、队列和资源迁移基线已合入，本轮独立分支补齐5弱/8强/3精英/3Boss共19个源编组及特殊机制，40份固定源摘要和34组回归可查。仍缺事件专属敌人、13普通事件、完整Host自然流程及四职业连续/平台通关；本轮切片通过不等于第二幕整体Done。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 第二幕18至34层按原版地图、遭遇权重和全部三种Boss合法生成，接上第35层
- [ ] #2 13普通事件及神龛、一次性事件资格、内部交易和事件战斗真实执行
- [ ] #3 四职业分别正常连续通关且资源继承正确，保留同源本地、集成和平台证据
- [x] #4 第二幕18至34层地图、来源队列与跨幕资源迁移基础已合入PR213并有独立向量和事务回归。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-26本轮M3并行：act2独立工作树按固定来源补第二幕怪物组的A0数据/AI和正式构造分派，保留未实现内容拒绝边界，不代用第一幕怪物。Host/章节UI由父线程负责，事件和药水另树；统一集成和回归后再判各层验收。

本轮组合审查独立补齐章节非稀有奖励升级0/25/50/50%的源序、纯数据保留、UID领取及下一战；主线程接升级卡面与缺定义奖励的明确不可领取显示，身份与随机消费不重抽。

2026-10-27并发复核：events独立树先补The Joust真实屏序/随机时点与独立模块，主session接Act2Events/Nodes/UI；其后补Neow等真缺项，不改变原事件池顺序/资格/概率，不以full开关冒充完整可玩。

2026-10-27 独立接回已冻结 Ghosts 内容叶到已接受 b164fda7：复用原版构造期缓存成本、永久上限支付与5次真实取得钩子；保留最新输入/手柄/卡面/公告及损血复活修复。只接该事件及必要注册/测试，不与正在更新的PR238抢写同分支。先当前父树定向/回滚/静态与关键变异，再独立PR精确SHA完整CI；默认池与完整源池顺序概率不改，完整第二幕/自然通关/平台未证明的AC不关闭。Toxic Egg是当前主线未接受的后续能力，不把它缺失冻结成永久产品要求。
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
<!-- SECTION:NOTES:END -->
