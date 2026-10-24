---
id: TASK-14.1
title: M3 首发遗物药水效果与触发顺序严格对齐
status: In Progress
assignee:
  - '@Codex-relic-order'
created_date: '2026-10-23 01:57'
updated_date: '2026-10-24 02:11'
due_date: '2026-10-28'
labels:
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-14
references:
  - data/SOURCES.md
  - data/relics.json
  - data/potions.json
parent_task_id: TASK-14
priority: high
type: enhancement
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2026-10-23用户要求：首发实际纳入的第一幕内容严格还原初代Slay the Spire PC正式版Ascension 0的数值、机制、算法、概率及结算顺序。只允许名称/背景/元素表现包装，禁止自创机制、简化AI或自行调平衡。主冲刺按最早未完成成果关口推进，离线工作可并行。PR #51已合并，现有实现以最新develop与专项证据为准。 TASK-14库存/有限效果完成不等于原版一致；SOURCES承认药水damage/block及遗物block固定处理为简化。须逐件核对，不能推断所有药水都吃修正。TASK-13.1/12.5负责获取概率/价格，本任务负责取得后的效果。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 逐项对照账本包含原版PC版本、来源URL/章节/原作观察日期、准确值/范围/算法/概率/结算顺序、当前实现位置、差异、验收输入和预期；资料不足标待核实，禁止猜测，未核实/未修复不计严格一致性通过。
- [ ] #2 逐件核对纳入遗物药水的值、对象、修正/不受修正规则、层数/时长、触发次数、消耗顺序、满槽及战斗外限制；起始遗物与战后回血时点一致。
- [ ] #3 真实库存入口测试开战/回合/出牌/受击/胜利/跨节点触发、叠加冲突、末敌击杀、失败不耗物及重复使用；各例预期来自原版。
- [ ] #4 数据完成、独立原版预期的自动测试、平台编译/副本导出、官方导入、千星实机分层报告，附SHA、候选hash、种子/输入、日志与截图或录像，不互相替代。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
核对首发遗物药水来源并建立逐件账本；为已证实缺口加入固定原版预期回归并证红；最小修复后跑npm run check，平台依赖保持未验收。

药水槽位切片：逐件读取固定镜像7件药水use/getPotency与原版库存方法；对已证实的固定槽位消费/最左空槽填补先写真实Run入口红例，再实现稳定槽位及稀疏视图、UI计数与补货库存命令；不增加发瓶来源/概率，不碰Combat调度。

开战队列切片：复核PR87固定源码推导并在当前52f35dd重跑14组独立诊断证红；将首回合构建分成基础抽牌前/后，仅对已支持六件按钩子队首/队尾语义分派，保留真实Run入口原子拒绝；纳入常规回归、验证换序/跨战与相关全量门禁。原作PC构建认证、完整调度器和平台AC继续保留。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Codex inventory_parity领取离线可推进部分，基线c2c2cd2；不打开原神、不调用MCP。使用systematic-debugging和automated-testing-workflow技能，按来源和红绿证据推进。

离线切片：首发14件来源账本已记录位置、数值、触发、验收输入与剩余差异。铜鳞稀有度Uncommon→Common；普通0伤害攻击仍按每段触发Thorns。新增inventory_parity 10组（3个缺陷例在c2c2cd2证红后修复证绿），statuses35及inventory11通过。npm run check全绿（JS180通过/14符号链接权限跳过；Python12通过/1权限跳过；Lua全量通过）。精确开战队列、原作PC构建/录像、槽位身份及千星平台验证未完成，全部严格AC保持未勾。

同步a6be1b6后完整检查发现PR37新block_damage测试同样固化了0攻击不反刺旧预期，来源支持的契约应为0 Block的Body Slam仍触发3反刺；已修正该用例为损失3HP，不改Body Slam算法。此为可解释的整合回归，继续完整复验。

最终a6be1b6整合基线完整npm run check退出0：JS180通过/14符号链接权限跳过；Lua744组通过（含新增inventory_parity10、BodySlam25、statuses35）；Python15通过/1权限跳过。日志保存在隔离树inventory-check.log。来源账本docs/reviews/TASK-14.1-inventory-parity.md保留所有未证实差异，交主线程复审合并；不以离线门禁替代平台/原作实测。

新切片基线e47bfcf，feat/task14-potion-parity，确认Fire当前及来源均20、Block才12，其他2/2/2/6/5相同，无数值修复。固定镜像AbstractPlayer.obtainPotion为最左PotionSlot原位set；第二固定镜像aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0/TopPanel.destroyPotion明确set(slot,new PotionSlot(slot))，版本字段也声明2.3.4但均未验证正版hash。主线程授权修正真实槽位压缩差异；节点已无自然药水获取链，不制造来源，只补库存obtain命令。

固定槽位切片最终：来源镜像逐件确认7瓶基础量20/12/2/2/2/6/5，无JSON数值改动。消费改为原槽留空、Run.obtainPotion最左空槽填入/满槽与未知id原子拒绝，potionView保持槽号，potionCount显式计数；battle/node UI同步稀疏槽位及补货。potion_slots6组修前5红（3个真实槽位差异、2个缺库存命令），修后6绿；新增同场中槽补货与仅槽3目标瓶、节点计数回归。npm run check退出0：JS260通过/14符号链接权限skip，Lua31脚本780组通过，Python15通过/1权限skip。隔离树potion-check.log、potion-slots-red.log保留日志。docs/reviews/TASK-14.1-potion-slots.md记录固定源码/交叉版本及真实输入；自然获取链尚无，未发明奖励/概率/claim事务；Strength/Dex共享层数上限与原作onUsePotion队列、全池/平台AC仍未完成。

本批代码已合develop fac093c（药水PR78），实际离线构建源022f22cf；git diff确认src/data/scripts与合入代码完全一致。完整check及各PR当前SHA Quality全绿，实际gil独立核实24模块源文、1220控件/六列模板/22节点启用结算图，客户端静态0error/15条已定位自定义方法warning；内存重注入与候选字节相同。候选SHA256 a6d839d45753af0e536142bba7a3cd2322155dda38a67cbcc220bce7b6c8e114，正式底图hash前后相同且liveWrite=0。证据docs/evidence/offline-candidate-022f22c.json及P0-SMOKE。未开原神、未官方导入/实机，所有剩余平台/全项AC保留原状态。

Codex-relic-order在feat/continue-relic-order独立领取开战遗物离线切片，基线52f35dd；不打开原神、不调用live MCP，与Combat调度负责人协调最小函数边界。

开战队列离线切片完成，基线52f35dd。固定镜像aeubanks/sts@319009d5六件方法复核：Lantern首回合TOP先执行，三能力battleStart TOP按持有逆序且在基能/抽牌前，Anchor/Bag BOTTOM保留相对顺序在普通抽牌后；ID表只存钩子位置，全部数值仍读effects。PR87原14组在当前Fengari证红3绿11红；加2混排修前3绿13红，修后16绿。补失败原子性、基础能量overflow、回调不入状态与次回合不重复、真实两战重建后20绿；overflow曾单独19绿1红后修复。首次npm check在JS218后runner无输出持续占CPU，只停止本轮PID9568，命令退出-1，未声称完整check通过。精确UI input保护重放205组104pass101skip、theme保护46组38pass8skip均退出0；后续npm test完整584组469pass115权限skip，0失败退出0；Lua54脚本全过含opening20；Python15pass1权限skip；syntax/schema/theme分别退出0。未再跑组合check，交主线程整合复验。日志保留本worktree不提交；docs/reviews/TASK-14.1-opening-relic-order.md列来源/输入/红绿/限制。没有开原神、平台编译或导出/导入/实机；镜像非认证PC，完整队列/药水上限与onUsePotion缺口仍在，4项AC不勾、任务保持In Progress。

2026-10-24批准路线图：本地原版对照可并行执行，不以基础实机验收作为本地开发前置；本任务既有AC、状态和证据保留。M2通关不等于本项完成，严格实机验收仍须独立取证。
<!-- SECTION:NOTES:END -->
