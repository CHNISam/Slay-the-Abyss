---
id: TASK-64
title: 接齐三钥匙真实获取与第四幕盾矛心脏
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-26 05:06'
updated_date: '2026-10-27 20:57'
labels:
  - required
  - sts1
  - acts
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-62
references:
  - docs/rules/CROSS_ACT.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/backlog-details/BACKLOG-UPDATE-20261027.md
priority: medium
type: feature
ordinal: 109000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
隐藏第四幕早已纳入M3。已合入52营地→53商店→54盾矛→55心脏固定地图及资格/缺钥匙拒绝边界。剩余：真实三钥匙取得、历史资格持久化、盾矛与心脏完整机制、正式入口及四职业自然通关。边界测试构造钥匙不当作真实取得。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 三职业历史胜利资格与本局三钥匙都通过真实路径获得，营地和宝箱替代奖励正确且不重复领取
- [ ] #2 52营地、53商店、54盾矛精英、55心脏固定路径及完整特殊机制正确，心脏胜利后才进入真结局
- [x] #3 未满足资格或缺钥匙不能进入终幕，非法请求拒绝且不改变资源
- [ ] #4 四职业分别合法连续通关，持久资格的平台能力缺口单独记录，保留同源日志和截图
- [x] #5 终幕52至55固定地图及已有资格/三钥匙门的拒绝边界已合入PR213，并有本地事务回归。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-27继续保留真实资格阻塞：宝箱新多奖励蓝钥匙只牺牲关联基础遗物，金币/额外遗物独立；已有红钥匙不重做。跨局历史、燃烧精英及终幕自然完整链仍未认证，不用测试给定history当自然解锁。

2026-10-28在第三幕候选交付/完整CI期间推进依赖已满足的离线切片：按固定319009来源，独立实现盾矛与心脏的敌人/AI/源动作模块及向量；燃烧精英模块单独负责有资格地图选点、持续mapRng四强化和独立绿钥匙owner。三个切片不并发改共享Map/Run/Nodes/Combat/UI，父线程按边界接共享hooks和正式入口。先真实RED→GREEN、再完整失败回滚/既有RNG与呈现回归；任何组件完成不冒充终幕可达、三钥匙自然获得或持久平台验收。

PR262入口修复：在原始地图被复制和房间钩子执行前，复用既有Map.restore与Run幕诞生上下文验证规范地图及连续mapRng。保留无诞生上下文的旧组件入口；带燃烧契约而缺上下文必须拒绝。先记录伪造有效流/选择/标记/元表的RED，再验证无副作用拒绝、正常生成/恢复/已战斗后的延续、晚失败回滚及原队列回归；不改状态或AC，不混入Stage1历史或Eggs。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-26状态整理：PR213已合入终幕固定52至55地图与门边界，真实三钥匙获取、历史资格持久能力、盾矛/心脏机制及正式通关尚未完成，仍To Do。不得用测试构造的三钥匙视为正常获得。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-26原AC3按已合入且本轮通过的cross-act非法/缺钥匙门边界事务回归勾选；真实钥匙、历史持久资格、心脏机制及自然通关仍保留未勾。

接入Ruby Recall与Sapphire宝箱选择，沿用Nodes核心命令、来源令牌、真实永久牌/遗物后果及旧手势拒绝，兼容空所有者菜单与Start失败/重试。实现见src/lua/abyss_nodes.lua、abyss_node_ui.lua、abyss_run.lua；回归见tests/lua/ruby_recall.lua、ruby_recall_ui.lua、ruby_nested_refusal.lua、sapphire_treasure.lua、sapphire_treasure_ui.lua、m3_v2_keys_darkstone.lua及m3_current_owner_event_keys.lua。本地相关回归通过，完整Quality以PR当前提交检查状态为准。受控导航与钥匙资格不是自然获得证明；完整三钥匙隐藏结局、历史生产/持久化、全源池及原生四职业连续四幕仍待验收。 本轮基于最新develop增量整合，保留原版来源拖牌/持续选目标、共享卡面装配与卡牌ID美术接线；未引入新的同步反应结算。

2026-10-27合并状态更新：Ruby Recall、Sapphire宝箱选择及相关边界已随PR232合入develop fc51f1987130e398538e9663b736d66090dfdd07；精确接受HEAD为4a14598c8cd5284e210917bb7818d02c9100bf68，完整Quality 40441075319与Licenses 40441075355均成功，合并树与该HEAD相同。这不是三钥匙/终幕整体验收：剩余真实钥匙全路径、历史资格持久化、盾矛/心脏完整流程、完整来源池、官方平台和自然四职业连续四幕仍需完成；受控导航或测试构造钥匙不算自然取得。保留原状态、负责人、全部AC与历史，不标Done；后续输入整合须另跑新HEAD完整Quality。

2026-10-27最新边界：PR232已合入的Ruby Recall/Sapphire宝箱及钥匙核心/UI属于已交付代码；不能等同三钥匙自然取得、历史资格持久化或盾矛心脏完整实机通关。PR238同步fc51f198尚未提交，当前SHA完整CI不存在；四职业隐藏结局与同源平台日志截图仍缺，不新增勾选。

2026-10-28终幕胜利历史独立切片已保存abf008ed：独立owner与Host读取/记录将标准三幕胜利和Neow上局进度分开，固定种子只读既有资格而不新增WIN，默认旅者规则包映射战士、原创V4及其历史预装身份不冒算三原职业。纯owner与Host先红后绿，来源锁及静态/邻接回归通过；该切片尚待主线整合与最终组合验收。当前只承诺真实会话记录及可注入provider，不代表原生平台已持久化；燃烧精英/绿钥匙正常取得、第四幕盾矛心脏及自然四职业通关仍缺。详见docs/backlog-details/BACKLOG-UPDATE-20261027.md的10月28日节；不改状态或勾选。

2026-10-28终幕共享核心离线进展：三个独立组件与燃烧Map切片已在专用final-act树保存，Heart实际Actor限伤/格挡后预算/反伤失血/自身回合先毒重置/零身份/源-1痛苦5组通过；真实Ending生命周期与动作10组通过。Combat已在所有预战斗之后、首抽之前接options.emeraldBoost；普通怪物不衰减再生、Awakened只治疗一次、再生与后来Shackled同源顺序等5组通过。后者先捕获旧colorless力量恢复快捷路径抢先执行，再局限于有monsterRegen的owner延期，原非再生路径保持。节点/领奖UI、Beat/背刺与第四幕正式入口仍在接，未新增GIL/官方导入或自然终幕证据，不关闭AC。

2026-10-28第四幕组合离线验证：真实54盾矛/55心脏入口、三钥匙及源队列资格、燃烧精英/独立绿钥匙、Invincible/Beat/Surrounded与背刺、源特殊意图、等待继续页及true_victory已在独立树接通。组合207模块/1209边分层、固定Luacheck84历史诊断零新增、界面入口/全部受检helper复杂度门禁通过，四语义变异均被原断言杀死；四职业受控真实52→55、完整source四stream、奖励顺序、Beat双死/Fairy/Mark、Nodes/严格Host/完整意图与绿钥匙12项组合回归全通过零跳过。受控已达51/历史/钥匙及999攻击只用于接线，不算自然通关；原生GIL与完整当前SHA CI尚待，Lizard Tail和Black Star等生产遗物缺口、历史平台持久化、四职业自然连续四幕及实机继续未完成，不勾AC。

2026-10-28第四幕c5测试包已真实写入并独立读回213模块，正式资格/三钥匙门、绿钥匙、盾矛、心脏和确认真结局代码现可随该冻结候选由用户自行导入。组合复审捕获并修复两项：Map.snapshot洗掉原图元表，直接原图严格restore并拒root/nodes/末节点伪造；自动牌错误改变包围朝向，改为仅手动指定目标/定向药水转向，免费手动与原native/advanced及回滚保留。两项先真实RED再GREEN，10组转向、4组Nodes/3组严格Host与意图邻接通过；三名交叉独立复审绑定c5无未解Critical/Important。原源码4e因构建期间输入变化被标准门禁拒绝，保留为检查点；最终c5重新完整验证后交付，不抹去旧失败。没有本包官方导入、ready、自然取得三钥匙/资格、Lizard/BlackStar完整生产遗物、自然四职业连续四幕或平台持久化证据，不关闭AC。

PR262独立P1入口修复候选：原始图在复制及房间hooks前，经既有Run幕诞生事实和Map.restore重建/路径重播验证。只改Nodes前置校验，不改来源RNG或奖励owner；旧无诞生事实且无燃烧字段的组件API保留，false字段不当作缺省。伪造有效seed2流真实RED（原public enter成功），修复后核心4组GREEN；既有Emerald/终幕14项和来源队列/地图/跨幕15项Node测试零失败零跳过，原30秒fixture预算保留。语法、207模块/1209边架构、固定Luacheck84历史诊断零新增均通过；遗留入口/事务切片与最终false字段补测仍运行，独立精确提交复查及完整当前SHA Quality尚待，不推送、不改状态/AC，也不宣称自然/平台/M3验收。

2026-10-27 PR262 合并前来源复核：精确61b19351（79e76774玩法同树）真实Strike证明无敌额度0仍构造淬毒动作并误耗人工制品；固定sts@319009d5的AbstractMonster先执行目标ToChangeDamage，再执行Envenom.onAttack。最小修复复用Heart额度主人，抽出只读incomingAmount供Envenom判断，Actor仍唯一实际扣额度。新增原生/高级用牌队列0→1→1与纯预览/全格挡回归；定向Heart、触发器、毒构筑及架构/Luacheck通过，退回旧Combat时新断言真实变红。详见docs/reviews/PR262-HEART-ENVENOM-CAP-20261027.md。仅本地离线修复，不更改负责人/状态/AC；新SHA完整Quality、合入、同源原生与四职业自然四幕仍待证明。
<!-- SECTION:NOTES:END -->
