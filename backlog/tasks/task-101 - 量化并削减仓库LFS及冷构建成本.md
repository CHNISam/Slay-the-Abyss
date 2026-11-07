---
id: TASK-101
title: 量化并削减仓库LFS及冷构建成本
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 01:46'
updated_date: '2026-11-07 06:03'
labels: []
milestone: m-7
dependencies: []
documentation:
  - docs/backlog-details/M7-SCOPE-GAP-20261105.md
  - docs/backlog-details/TASK-101.md
priority: medium
type: task
ordinal: 164000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
当前仓库体积与LFS仅有旧快照，缺少checkout下载及冷构建成本证据；TASK-60处理CI下载故障、TASK-87处理指引，本任务只补全体积与构建成本线。架构及协作优先。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 绑定当前源码统计blob、LFS OID可读性、checkout下载字节及冷暖构建墙钟，区分Git pack与官方包大小
- [ ] #2 同环境前后证明确证重复下载或派生物成本已消除，或以实测说明保留原因；不重写历史、不删合法fixture与不可再生资源
- [ ] #3 跨平台构建、许可和候选输入完整性保持，独立复审及实际合后Full通过；导航缺口复用TASK-87不另建指引系统
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定当前源码与任务来源，复用 Git/LFS 清单统计并分别标记可读、缺失和未验证对象，不下载非必需资源。
2. 在云隔离目录记录无生成物与重复构建的真实耗时、产物摘要和派生字节，保留前后同源配对样本及失败。
3. 仅修复有实测且不与其他任务重叠的成本问题，先负例后实现；否则保留资源并明确原因。
4. 独立复审和相关回归后提交 Draft PR，保持原 Full/合后验收与跨平台未验证边界，不提前勾选AC。

5. 从实际develop c685409d独立线性接续#522，纳入已审跨轮产物一致性修复；保留历史收据，仅定向回归与当前库存校验，不重复本地Full或三组真实构建。

从最新develop线性接续#533，保留现行CI库存并集，经独立复审和正常CI交付；旧PR保留至成果验收。

按本轮合并清理指令接续现有PR544：复现并修复Windows短路径与Git LFS长路径的夹具误判，完整保留缓存归属断言及九种路径；继承配置矩阵按原30秒子进程上限分三组，不增加重试或删场景。精确独审后仅更新原PR，Full及合后验收独立。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮新增只读Git/LFS成本采集器及隔离冷暖构建测量，15项定向回归与3组默认构建通过；21产物逐项相同，未发现可据以删冻结资源或宣称提速的证据。精确字节、版本与边界见TASK-101附件；独立复审及PR/合后Full待，所有AC保持未勾。

2026-11-06线性接续：基于实际develop c685409d，仅接续#522 cf46596专属成果并纳入跨轮P2产物一致性修复；当前21项仓库成本及8项库存合同29/29通过。原三组真实构建及独审保留为历史证据，未重跑Full或真实构建；当前独立深审、精确托管/合后Full与跨平台待。库存742/1401与冻结741/1401分开，timings/workflow/预算均未改。负责人Furinya和全部未勾AC保持。

本轮verify:backlog、check:guidance、check:syntax和diff检查通过；Backlog CLI 1.55.3只读doctor仍报告既存五组跨归档ID冲突并退出1，未自动修复无关历史。

2026-11-06恢复既有成果集成：#530实际合入develop 67793786f82db4059e9de463674bd40e4be38932后，仅接续#522七文件；不纳入旧TASK-74系列交付记录，避免覆盖#531。保留历史样本与原计划；当前库存743 JS/1401 Lua，冻结741/1401，runtime和repository-costs两文件按未知成本验证。当前精确候选独审及托管/合后Full仍待，全部AC保持未勾。

实际677基线的最终七文件候选：repository-costs21、calibration8、runtime6共35/35通过，0失败/跳过。脚本与测试保留已审跨轮修复摘要779fd89b/7c8b8c94，原两份证据逐字不变；未重跑Full或真实三组构建。

2026-11-07 Owner明确恢复M7剩余治理和已有PR集成；本轮以de218e5c接续#533已审成本切片，不扩展实验、不重复采样、不回带旧核心状态。原三项AC继续未勾，技术证据追加到TASK-101附件。

本轮固定Node24定向35项：32通过、3项按原Windows符号链接权限条件跳过，0失败；指引/任务/语法/diff检查通过，当前Backlog doctor通过。独立代码复审PASS；精确提交与远端Full/合后验收待，不把跳过或历史性能样本算当前跨平台证明。

本轮PR544 Windows定向：修前实际LFS九组中八败，原生realpath探针证明ADMINI~1与Administrator别名误判。改用native规范化后九组全过；完整原31项27过/3原Windows符号链接跳过/1继承配置子进程超时，保留失败。未改30秒子进程上限，全部九组×两种继承配置分三组执行后通过；新增真实junction、同前缀相邻目录及根目录拒绝测试通过。生产脚本不变，未复跑业务Full或真实仓库性能测量。当前独审与新HEAD托管验证待，AC/owner/status不变。
<!-- SECTION:NOTES:END -->
