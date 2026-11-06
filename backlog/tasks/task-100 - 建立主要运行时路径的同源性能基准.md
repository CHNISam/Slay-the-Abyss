---
id: TASK-100
title: 建立主要运行时路径的同源性能基准
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 01:46'
updated_date: '2026-11-06 12:38'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/M7-SCOPE-GAP-20261105.md
priority: medium
type: task
ordinal: 163000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
已有局部VM和快照数据不足以证明启动、战斗、地图与奖励整条路径成本；补齐同源基准以定位真实工程热点，设备体验继续由M8验收。架构及协作优先。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 同一源码、输入及种子下覆盖冷暖启动、战斗回合、地图菜单奖励切换，记录模块加载、原生写入、快照、内存和总耗时
- [ ] #2 至少三组可复现配对样本报告P50/P95与调用次数，原静止300帧重复提交有绝对计数；整体路径无未解释回退
- [ ] #3 优化以行为等价、独立审查和实际合后Full验收；无官方候选设备证据保持UNVERIFIED并明确交接TASK-4.21
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.复用现有Host与运行时夹具，固定当前源码摘要与确定输入。2.实现有界的代表路径离线测量入口，区分真实调用计数与VM时间，不改生产架构。3.定向合同测试及独立审查，记录未覆盖设备与完整前后比较；本切片不宣称任务完成。

4.按Owner集成要求保留原#523，以实际合入的#521/c685409d建立线性接续，不强推、不引入合并提交；刷新schema2三VM来源与分项，保留历史证据和未勾AC，完成精确独审及原生Full/队列/合后验证。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR #523 首份离线Host全路径基线已实现：固定实际seed、源摘要、三次独立VM、冷暖构造/回合/300帧/卡组/奖励，调用计数一致；4项定向合同测试通过。证据与边界见docs/backlog-details/TASK-100.md。尚非优化前后对照，无官方设备及合后Full，全部AC保持未勾。

补充schema2逐阶段原生方法/属性名计数及总数一致性门禁，6项定向测试通过；一次诊断定位300帧写入来源，非优化结论。待#521最终组合刷新正式三样本/源摘要，不复用旧核心证据。

以#521实际合入c685409d线性接续#523/5439b658，原分支与两份历史报告保留；新schema2三VM的491来源逐项一致，11阶段计数和分项一致，wall P50/P95为5746.400/5771.628ms，仅离线基线。运行时6项与库存8项共14/14；当前742JS/1401Lua与冻结741/1401收据分开验证，原17/13分片、timings与预算不改。CLI1.55.3 doctor报告既存5组重复ID未修；精确独审、托管Full、队列及合后验收继续，AC未勾。

接续实际已合530的67793786，仅移植原526可见性优化/已有实验，不覆盖530未优化基线报告。494实验输入逐字相同，无重采样；新增1JS/1Lua沿post-placement unknown清单，8项库存PASS。受控20主配对通过预声明判据并独立重算，原不利样本保留；精确提交准入和实际合后Full仍待，所有AC未勾。
<!-- SECTION:NOTES:END -->
