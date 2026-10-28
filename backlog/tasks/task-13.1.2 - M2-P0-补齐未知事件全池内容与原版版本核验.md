---
id: TASK-13.1.2
title: 补齐第一幕剩余事件并接通完整25事件池
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-23 16:11'
updated_date: '2026-10-28 01:36'
due_date: '2026-10-28'
labels:
  - p0
  - required
  - rule-parity
  - implementation-gap
  - partially-implemented
milestone: m-4
dependencies:
  - TASK-13.1.1
  - TASK-13.1.2.3
references:
  - docs/backlog-details/TASK-13.1.2.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/reviews/TASK-13.1.2-fountain.md
  - docs/BACKLOG-RECONCILE-20261026.md
  - docs/BACKLOG-AUDIT-20261026.md
  - docs/reviews/M3-EVENTS-INVENTORY-INTEGRATION.md
  - docs/M3-STATUS-20261028.md
parent_task_id: TASK-13.1
priority: medium
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已合入的基线和本轮离线切片累计接通19个事件命令/原生界面，新增变换、黏液、转轮、实验室、蓝衣女子和再次相遇。仍缺冒险者、金偶像、蘑菇、配对、面具交易和跨局留卡等6项及完整默认25池、自然/平台证据；不删池或重抽。具体源码与验证见附件和本轮冲刺记录。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 原七事件及活墙、清咒喷泉、蛇、大鱼、铁匠、篝火等已有事件命令、选牌与永久事务已合并，69项事件/UI/事务记录可查。
- [x] #2 完整事件目录、资格/池顺序依据和已实现事件的回归记录已建立；候选与正式入口有区分。
- [ ] #3 补齐第一幕25个潜在事件的全部选项、代价和结果：11普通、6祭坛、8条件一次性事件，不能删池。
- [ ] #4 将完整25事件按原版资格、池顺序和随机消费接正式池，独立回归证明概率不被重分配。
- [ ] #5 配对与转化候选接通正式事件路由、原生界面和永久奖励事务，并完成平台验收。
- [ ] #6 全部合法事件经正式玩法遇到并完成，覆盖空牌组、资格不足和重复输入，保留对应实机证据。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
按固定来源补齐第一幕25个潜在事件及全部选项、代价、资格和随机消费。保留已接的七个自然事件、六个显式入口和永久事务，盘点剩余内容后逐项补正式自然池与原生交互；完整池、正常获取和同候选平台证据未齐不得标完成。

2026-10-26本轮M3并行：events独立工作树复用既有事件体和配对/转化候选补正式事件事务，按固定来源逐片交付，完整25事件与自然/平台标准保留；父线程统一集成与Backlog写入。

2026-10-26后续独立事件批：在正确职业药水池依赖上实现Lab、The Woman in Blue和WeMeetAgain，保持直接均匀药水抽样、Java洗牌及房间内库存限制；不改默认完整池门禁。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
M3末张移除切片：固定CardGroup/Cleric/PurificationShrine/GoldenWing方法核对后，去除项目自加的至少两张限制，空牌组能正常开战、抽牌和失败。事件/商店原生控件37组与核心8组红绿及相关71组回归通过；金翼空组献祭仍扣7生命并完成，避免死选牌器。配对/转化仍不进入首发七事件池。来源blob、精确输入及原生空列表降级见docs/reviews/TASK-13.1.2-empty-permanent-deck.md。未编译/写副本/官方导入/实机，整体AC保持未勾。

2026-10-25 用户已批准完整25事件，纠正旧restricted-seven首页。Living Wall显式入口及Forget/Change/Grow已实现：42组定向通过，完整72槽34当前内容可用/38原子守卫；未接正常概率池，完整牌池/无色/诅咒与onRemove/onObtain/Searing Blow钩子仍须父线齐备。来源及边界 docs/reviews/TASK-13.1.2-living-wall.md。未知事件原220seed夹具30秒超时保留，正在原覆盖原预算优化；未宣称平台/完整事件池Done。

合并前补查纠正P2：旧备注把34个有定义结果称可用不准确，其中7牌实际未实现。已补共享card capability（变换/旧奖励/商店/升级共用），独立首发清单核33包含/7排除；72槽强制抽样修为27成功/45原子守卫，7项旧对象引用、牌组、UID与全部RNG不变，不缩池/不重抽。原夹具红10组1失败，修后10组通过9846ms。前次守卫无P1/P2判断已撤回并复审。完整25事件、全卡及平台AC仍未完成。

清除诅咒祭坛已接入full目录、正式Nodes事务与原生UI。固定源确认事件本身不加血/最大生命，当前Regret可净化，其他未实现移除钩子先原子拒绝。核心7/7、UI3/3、清单13项由主线程复跑通过；节点21与LivingWall10日志已读。默认七事件池未改，不虚报完整池/自然获取。子代理被平台用量上限中断后由Codex接管；独立来源复核已完成，最终独立代码复审未完成。候选/导入/同候选试玩另记，AC不勾。

冻结源0b8d325的增量候选已构建并完整读回：62/62模块逐字节相同，UI2824/max60，0error33warning。hash 8a9945e040e16250ca37c381b3b1e0698e26b754c001378949aa3f0723af5925，旧候选未改，liveWrite=0。未知事件13组与语法检查也通过。候选摘要docs/evidence/fountain-candidate-0b8d325.json。官方导入、同候选真实试玩、自然获取仍未验证，默认七池未扩大，父任务AC保持未勾。

读回口径纠正：审计ok=true且62/62源码匹配，其中61份逐字节相同，abyss_fountain有CRLF/LF差异，经原有允许的规范化匹配；原始hash均保留。此前62/62逐字节的文字已在交接/报告更正，不改审计标准或候选。

2026-10-25 用户已明确选择补齐完整第一幕事件池。任务首页仍残留restricted-seven旧方案，本轮通过CLI纠正；批准范围不是重新待决。完整审计在.artifacts/sts1-event-full-pool-audit-20261025/REPORT.md。当前实现七事件/缺18的事实与平台未验边界保留，不改Done或勾AC。

2026-10-26状态整理：最新实际基线为PR197/200/206后的整合，不再只按七事件缺18的旧备注判断。应逐项核对当前事件体、正式路由与25项资格/随机消费后验收；配对/转化候选Done不等于全池接入或平台通过。

2026-10-26任务首页校正：直接体现已合并成果及下一步，撤销仅登记/未启动等过时开工描述。保留原有全量验收标准，不以合并代替平台验收。

2026-10-26逐项AC校准：将混合的已实现/已有自动回归与完整池/平台待验拆成独立条款；依据既有合并及验证记录勾选，不新增通过结论。原验收快照保留docs/evidence/backlog-ac-before-20261026.json，全部原范围要求由拆分后条款继续承接。

本轮19条生产事件映射已由实际Lua注册表与清单双向校验；默认随机仍7事件，12条额外显式路由不冒充自然入池。新增独立源概率、交易/领取、重复输入和失败回滚回归，最终组合完整Quality仍在收口。

2026-10-28接续核对：当前主线b7dffdeb已包含PR238/250/252/259/262，第四幕及真结局接线不再待合并。M3当前32/46 Done，14项未完成。最新整合、遗留工作树与具体证据边界见docs/M3-STATUS-20261028.md；旧PR待合/冲突备注仅属历史。本次不新增自然获取、四职业四幕、平台导入或实机通过，不修改既有AC。
<!-- SECTION:NOTES:END -->
