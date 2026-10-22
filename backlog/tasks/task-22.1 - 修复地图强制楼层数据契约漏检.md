---
id: TASK-22.1
title: 修复地图强制楼层数据契约漏检
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-22 21:21'
updated_date: '2026-10-22 21:23'
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
- [ ] #1 restFloor仅接受14，非法值给出rules.map.restFloor定位。
- [ ] #2 强制1层normal、6层elite、15层boss各至少一个闭区间覆盖遭遇；缺池或范围错位给出floor/tier定位。
- [ ] #3 合法真实数据、单候选和可选层缺池不被过度拒绝；CLI非法数据非零退出；回归测试覆盖边界。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 先运行独立红例并添加Node回归测试。2. 最小修改validator并补齐既有合法fixture的elite/boss。3. 运行相关及全部Node测试、真实数据与CLI，冻结hash交独立复审。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Executor dot / fix_map_contract_validation。基线 develop 3f6ebe6acb244afce4d5e64d09a0b3142979bc9f。精确写入边界 scripts/validate-data.mjs、tests/validate-data.test.mjs、tests/validate-map-contract.test.mjs及本子任务。未认领或改写父TASK22历史quality-gates claim。开放PR 25/26/27/29/30/32/33/37文件清单均无重叠。未合并前保持In Progress。

候选验证：先在未改实现上复现独立8类漏检；29项新增合同回归先11失败，再最小修复转绿，合并既有48项validator回归为77/77通过。覆盖营地14、三个必选tier缺失/范围错位、闭区间min/max边界、单候选、可选层缺池、重复敌人引用、额外候选及CLI非零退出。完整npm test真实运行119项：113通过、6失败，均因环境缺少fengari-node-cli（UTF8 roundtrip、six-table Lua load、runner failure/timeout、suite discovery、theme Lua load、actual Lua controller）；npm run check和test:lua亦受同一缺依赖阻断，未安装包。语法、真实六表、data/UI/map/theme构建及Python12测试通过；git diff --check通过。2026-10-22 21:22 UTC冻结前刷新develop仍3f6ebe6；待独立复审和正式CI，不声明平台编译、导入或实机通过，不改父任务、保持本任务In Progress。
<!-- SECTION:NOTES:END -->
