---
id: TASK-16
title: M3 战士卡池扩展与卡牌升级
status: To Do
assignee: []
created_date: '2026-10-22 13:48'
updated_date: '2026-10-22 21:31'
due_date: '2026-10-28'
labels: []
milestone: m-4
dependencies:
  - TASK-9
  - TASK-14
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
把卡池扩到投稿可用规模，营地升级卡牌生效。时间不足时优先保核心构筑完整。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 卡池扩展到投稿可用规模（首轮 30+，时间允许继续补到 75）
- [ ] #2 卡牌升级在营地可用且效果生效
- [ ] #3 卡牌文案与数值为自有实现，不搬运他人资产
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-22 UTC：dot 在 feat/dot-entrench-candidate 基于 develop a3526615d02655d5eb5b02261c84043fb219756e 做独立候选接续，非正式认领或整项交付。TASK-14 未完成，TASK-16 状态、负责人、依赖及 AC 不变。生产写入仅 src/lua/abyss_effects.lua 和新增 tests/lua/entrench.lua：使现有 entrench 当前格挡翻倍，普通2费/升级1费，不重新应用敏捷或脆弱，不改数据/UI/核心其他文件。先写真实 Combat.play 红测试，再最小实现；覆盖零格挡、连续倍增、32位边界、非法能量/重复UID完整状态及真实奖励获取后下场使用。正式 npm check/Fengari 尚未运行，须独立复核与 CI；不代表平台编译、存档导入或实机验收。

候选本地进展：先运行9组新增红测试，均以 doubleBlock 不受支持或奖励未出现失败；最小复用已有固定格挡路径后10组（含负敏捷补测）通过，原表、运行卡名掘壕及表现层名称均未改。真实原始初始牌组完成战斗、实际奖励领取 entrench、下一场与防御配合出牌通过；不是15层通关或平衡验证。npm run check 已实跑退出1：90项JS中84通过、6项因缺失 fengari-node-cli 失败；未安装依赖，正式 Fengari32 与聚合门禁仍待 CI。系统 Lua5.4 为补充证据，不能替代 Fengari/平台；Python 12项通过。候选待独立审查，未改变本任务完成度。

2026-10-22 UTC：dot 基于 PR37 head 8ee173cad52695fbf0d5b4266215debafdd932ba 的物化快照做独立集中精神（battle_trance）候选，保留 entrench，不包含 flex；非正式认领，TASK-14 待满足，状态、负责人、依赖和 AC 不变。已核对最新 AGENTS/HANDOFF/SCOPE 与原表/overlay：普通0费先抽3、升级先抽4，再 noDrawThisTurn。仅 abyss_effects 注册并将既有 source.noDraw 设 true，复用 Combat.draw 检查和 startPlayerTurn 复位，不改核心、数值、表现或永久状态。先写真实 Combat.play 红测试，14组功能/奖励负例失败、1组非法命令通过；接线后新增15组系统 Lua5.4测试通过，包含空/满手、洗牌、连续零费、已有抽牌卡前后交互、敌方动作及下回合恢复、真实初始牌组取胜领奖后下场出牌。全8个Lua文件系统Lua5.4补测通过；npm run check 实跑失败：JS90项84通过6项缺失fengari-node-cli，未安装依赖；Python12项和数据校验通过。系统Lua5.4不替代正式Fengari32/CI，候选待独立复核及TASK-14正式整合，不代表平台编译、导入、实机或Task16完成。
<!-- SECTION:NOTES:END -->
