---
id: TASK-64
title: 接齐三钥匙真实获取与第四幕盾矛心脏
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-26 05:06'
updated_date: '2026-10-27 19:16'
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
<!-- SECTION:NOTES:END -->
