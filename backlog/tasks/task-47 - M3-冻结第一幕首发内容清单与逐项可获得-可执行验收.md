---
id: TASK-47
title: 确定首发内容，并逐项确认真的能玩
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-24 02:01'
updated_date: '2026-10-24 22:59'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-7
references:
  - docs/backlog-details/TASK-47.md
  - docs/DELIVERY-CLOSEOUT.md
  - docs/LAUNCH_CONTENT.md
  - data/release/launch-content.json
priority: high
type: task
ordinal: 75000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
列清楚首发有哪些卡牌、敌人、遭遇、事件、遗物、药水和Boss。每项都要能正常遇到、拿到或使用。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 清单上的每项都通过正常玩法获得并使用过，有测试和实玩记录，不靠调试塞进背包。
- [ ] #2 能自然组成不同合法卡组并重复游玩；未完成项逐项列出。
- [ ] #3 首发清单同时注明每项代码或素材实际接入入口、对应平台及实机验收任务和当前占位；独立候选与离线文件不能登记为玩家可用。
- [ ] #4 首发清单包括完整75张铁甲战士牌及1个Boss，逐项注明合法获取/生成规则、实现状态与未验证缺口；75张未齐不得通过首发验收。
- [ ] #5 首发涉及的原版内容池与必要依赖齐备，保留原版概率；删池、未实现占位或缺项重抽不能算完成。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 从生产代码枚举各类首发内容及合法入口，明确候选排除。 2. 建立逐项机器清单和中文说明，列明验收任务、本地、平台和实机边界。 3. 定向核对清单与生产池，保留自然获取和实机缺口，不因建表转Done。

整合develop9ae1aec：正式17项队列绑定及Guardian与legacy显式ID分开盘点，保留large_slime/lots_of_slimes/exordium_thugs等动态成员与模块部署门禁。全解锁Ironclad A0第一幕完整原池/随机消费/机制依赖须逐项核验；旧30/13/6仅历史基线，完整75张不可缩减，逐项自然获取和同源实机证据仍未勾。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已按6e8714f建立生产首发范围清单：30张基本/升级职业牌，另列3种状态/诅咒；19普通敌人、3精英、1Boss及18遭遇；当前已接7事件；13遗物及6种战士可获药水。配对/转化、未实现7牌和Silent专属毒药水明确排除。每项经profile关联代码入口、已有本地测试、平台/自然实机待验状态和负责任务。机器校验与4项定向回归通过，默认Node测试会发现新门禁；未运行游戏/MCP或制作候选。三件Boss遗物第17层才获，本幕无后续战斗自然触发，保留此执行边界。所有AC仍未勾，TASK-47保持In Progress。详见docs/LAUNCH_CONTENT.md。

首发清单已整合ee9c40d窃金客入口及本轮末张移除/药水丢弃。30职业牌/23敌人/18遭遇/7事件/13遗物/6可获得药水为现生产接线盘点，尚非严格合规放行表；medium_slimes/gremlin_gang明确列为已知编组缺口，完整地图12/12仅隔离候选未接生产。逐项自然获取、不同合法构筑、平台与本候选实玩记录仍缺，全部AC保持未勾。

最终承接b757705的PR174动态小软泥：清单门禁先真实失败，按默认false/true两组补成员、酸液M/棘刺M渠道，新增缺分支/漏渠道负例后清单5项与small-data合计12项通过。保持各层证据分开，候选生产迁移及逐项实机仍缺。

2026-10-25用户纠正正式范围：75张全部必做，历史30张仅为旧进度。本轮TASK-16维护四层逐卡矩阵；清单门禁不再将30张硬编码为完成目标，平台与自然获取证据仍未验收。

已同步开发附件的当前有效范围：完整75张基本/升级正式必做，历史30张仅旧盘点；10/25–27逐卡实现与回归、10/28同源平台/自然构筑、10/29RC、10/30硬线。运行098的完整CI40138123646通过、原生9/9定向验证与正常实玩6层/16层两次战败分别记录于75行矩阵；本任务仍未验收，不能把定向资金/导航夹具当自然取得。
<!-- SECTION:NOTES:END -->
