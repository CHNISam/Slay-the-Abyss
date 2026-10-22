---
id: TASK-22.1
title: 修复地图强制楼层数据契约漏检
status: Done
assignee:
  - Furinya
created_date: '2026-10-22 21:21'
updated_date: '2026-10-22 21:27'
labels: []
dependencies: []
parent_task_id: TASK-22
priority: high
type: bug
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有校验器允许非14层营地及缺少强制层可用遭遇的数据进入构建，但 abyss_map 已要求14层营地及1层normal、6层elite、15层boss。仅补齐现有合同，不更改地图规则、数据、运行时或产品设计。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 restFloor仅接受14，非法值给出rules.map.restFloor定位。
- [x] #2 强制1层normal、6层elite、15层boss各至少一个闭区间覆盖遭遇；缺池或范围错位给出floor/tier定位。
- [x] #3 合法真实数据、单候选和可选层缺池不被过度拒绝；CLI非法数据非零退出；回归测试覆盖边界。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 先运行独立红例并添加Node回归测试。2. 最小修改validator并补齐既有合法fixture的elite/boss。3. 运行相关及全部Node测试、真实数据与CLI，冻结hash交独立复审。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor dot / fix_map_contract_validation。基线 develop 3f6ebe6acb244afce4d5e64d09a0b3142979bc9f。精确写入边界 scripts/validate-data.mjs、tests/validate-data.test.mjs、tests/validate-map-contract.test.mjs及本子任务。未认领或改写父TASK22历史quality-gates claim。开放PR 25/26/27/29/30/32/33/37文件清单均无重叠。未合并前保持In Progress。

候选验证：先在未改实现上复现独立8类漏检；29项新增合同回归先11失败，再最小修复转绿，合并既有48项validator回归为77/77通过。覆盖营地14、三个必选tier缺失/范围错位、闭区间min/max边界、单候选、可选层缺池、重复敌人引用、额外候选及CLI非零退出。完整npm test真实运行119项：113通过、6失败，均因环境缺少fengari-node-cli（UTF8 roundtrip、six-table Lua load、runner failure/timeout、suite discovery、theme Lua load、actual Lua controller）；npm run check和test:lua亦受同一缺依赖阻断，未安装包。语法、真实六表、data/UI/map/theme构建及Python12测试通过；git diff --check通过。2026-10-22 21:22 UTC冻结前刷新develop仍3f6ebe6；待独立复审和正式CI，不声明平台编译、导入或实机通过，不改父任务、保持本任务In Progress。

2026-10-22 21:27 UTC收尾核实：PR #38 已真实 squash 合入 develop e07757ad86f39d21473c8fcc80b24c20d7caf71e；PR head 3e00b39a1ad855c7b880215f93a258cff6129c22。正式CI run 39856992706 的 check 和 presentation 两项均 completed/success，链接 https://github.com/CHNISam/Slay-the-Abyss/actions/runs/39856992706 。独立评审复跑77/77及原8类红例转绿，另16组畸形输入/范围/单点边界探针通过，无阻断；本次收尾再次复跑77/77通过。前述本机Fengari缺失保留为历史环境事实，不再作为已合并修复的阻塞。仅完成本子任务的validator合同修复；父TASK22未改，不代表平台编译、存档导入或实机验证。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已补齐既有地图合同：restFloor固定14，强制1层normal、6层elite、15层boss要求闭区间可用遭遇；不新增候选数量或可选层限制。77项相关回归和独立探针通过，正式CI两项成功后合并 PR #38：https://github.com/CHNISam/Slay-the-Abyss/pull/38 。CI：https://github.com/CHNISam/Slay-the-Abyss/actions/runs/39856992706 。本任务Done仅指数据校验修复交付。
<!-- SECTION:FINAL_SUMMARY:END -->
