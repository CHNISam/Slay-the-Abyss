---
id: TASK-77
title: 让正式比赛流程在第二幕结束
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-28 08:20'
updated_date: '2026-10-28 14:41'
labels: []
milestone: m-4
dependencies: []
references:
  - docs/SCOPE.md
  - src/lua/abyss_ui.lua
  - src/lua/abyss_run.lua
priority: high
type: feature
ordinal: 1
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
正式双幕终点本地实现已合入；同候选平台导入、真实试玩与自然通关仍待验收。保留未来章节代码及同局状态。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 正式比赛入口支持第一幕正常接续第二幕，并在第二幕合法完成后进入本局结果，不能进入第三幕、隐藏第四幕或真结局。
- [ ] #2 保留同一局卡组、血量、金币、遗物、药水、随机流及回滚快照，不新增退出续玩、跨局历史、解锁或存储后端。
- [ ] #3 正式入口、第二幕终点、重复和非法换幕、胜败及重开都有生产回归；同候选平台和真实试玩证据单列，未实测不勾选。
- [ ] #4 第二幕Boss后宝箱领取与跳过都合法结束于同一双幕终点；正式UI不显示后续幕、三钥匙或真结局可用提示，本局结果层数及文案与双幕一致。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
只读审计e46bd5dd：abyss_ui.OnStart为campaign=true；Run.advanceAct允许1→2→3→4，暂无maxAct。保留campaign=true才能支持1→2，不得直接改false退回第一幕。Nodes.leaveTreasure与claimBossTreasure两条分支、Host/过期动作、结果floor分母17均须覆盖；未来四幕source/fixture保留。真实Boss历史provider未接，不得把跨局Boss解锁继续设为比赛依赖或伪造历史。

2026-10-28：本地双幕终点源码已实现，任务转为进行中，尚未验收完成。正式OnStart显式选择competition-two-act：第一幕接续第二幕，第二幕Boss宝箱领取或跳过都于34层进入双幕本局结果；核心拒绝第三/四幕，保留显式full-source未来测试配置。同局库存、随机流、事务与临时快照保留，不读取或产生跨局_WIN/_SPIRITS，也无退出续玩承诺。独立审查发现的OPEN时蓝钥匙offer漏门禁已在e9f1c0f7修复并重新source-only PASS。

受控生产接口回归已通过：真实OnStart/Host/Run/Nodes、首领战斗构造、两条宝箱终点、非法/重复/过期动作、胜败结算、重开与退出，以及同局资源/随机流/回滚。中间房间及最终伤害受控，不是自然通关。OPEN后无钥匙项/关联提示、直接领取原子拒绝、full-source正常钥匙offer和相同随机流/遗物池消费均有回归；旧strict trace与冻结hash保留。相关测试、架构、固定Luacheck及四项关键变异已通过；详见docs/reviews/TASK-77-two-act-endpoint-20261028.md。

已核对规划PR291实际squash48312c041f908ba87ea7555eb51f5bfce79243a0（父d2e0baa3，tree99d94a22），并正常merge为本地dc12847a9ce59fc9da5a71239b33a5413ee9456d：与已验证组合eac684e0精确等树ee686245，生产源码仍逐字节等于独立审查的e9。组合入口/历史/CI分片guard10项、规划回归27项、verify:backlog及OPEN独立probe通过；未推送或开代码PR。

剩余：当前运行时代码PR精确HEAD的完整Quality、同一候选官方导入/ready、平台UI与自然双幕通关尚缺，native/natural NOT_RUN。TASK-14.1的随机遗物池仍可能抽到未实现遗物；测试仅选合法已实现奖励验证接口，未缩池、改概率或宣称内容齐备。四项AC继续全部未勾选，不以本地受控测试代替平台验收或把本任务标为Done。

2026-10-28后续整合：已纳入实际接受77c2d5e6及此前角色二次确认、Molten/Mushrooms、共享卡框、guide、只读地图/本局菜单；CharacterSelect.options之后仍传递比赛profile，确认前不造Run。此前完整目标批次12/12通过；77c2上的新确认后双幕OnStart与严格来源正/负例通过。source历史以完整身份和精确hunk分层，不刷新旧archive/golden；新菜单“继续游戏”只恢复同一内存Run。干净7784与组合的原始live trace同为73316/1014606304，对旧81392/1836812524门禁仍RED，作为已有基线阻塞公开保留，未冒称全部Quality或平台验收通过。当前维持In Progress、全部AC未勾；许可证证据清单问题由独立范围处理，本任务未绕过检查。
<!-- SECTION:NOTES:END -->
