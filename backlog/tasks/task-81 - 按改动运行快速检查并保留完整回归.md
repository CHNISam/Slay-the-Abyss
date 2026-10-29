---
id: TASK-81
title: 按改动运行快速检查并保留完整回归
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-28 15:30'
updated_date: '2026-10-29 02:27'
labels: []
dependencies: []
priority: medium
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
方案与真实Runner证据见docs/CI-FAST.md。普通PR消除重复回归，保留高风险完整检查。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 普通PR按影响选测；高风险及develop和发版完整回归
- [ ] #2 保留断言与Required Checks；失败取消缺失均拒绝
- [ ] #3 真实Runner Fast P50≤5分钟、P90≤10分钟；Full≤30分钟
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
采集基准与保护；实现影响计划和稳定汇总；负例与真实Runner验收。

集成修复：保留历史schemaVersion 2的15作业证据；新采证使用schemaVersion 3，要求原15项成功、impact成功和未展开fast跳过。先补真实17作业形状及缺失/身份/重试负例，再最小修改交付验证器并跑聚焦CI合同；不改工作流、门禁或既有收据。

当前base收口：实际develop已432eebb1，而PR314 API与合成merge父仍0763。新schema3预审在采证前后独立读取目标Git ref，两次实际SHA必须等于已测base；历史schema2和已合入提交验收不追认当前分支tip。新增旧PR/旧merge/旧CI一致但目标前进、采证中前进和畸形ref回归；仅交付聚焦先红后绿，不改工作流。

CI故障切片：保留真实Windows ENAMETOOLONG记录；原生分片探针改在临时根目录以原排序文件名启动，新增实际argv便携断言，比较修复前后命令长度与逐片完整覆盖；只本地提交后独立审查，不发布。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR307；固定Node24.18.0专项32项通过，后续手动诊断输入与门禁9项通过。YAML/Bash语法通过；规则集证据已保存，无保护修改。当前远端Quality40716938768仍排队，未完成Full/Fast性能验收。创建时发现未合入审计工作树已占TASK80，改用TASK81；误建草稿6/7未提交。

PR307头11ff8b98真实Windows8片失败：原ci-downloads负例将第一个npm安装重试改99，但检查器只审旧rules作业，新增impact未纳入。最小修复将npm限制扫描扩展到整个Quality工作流，并逐安装步骤变异拒绝99重试。原失败与新负例本地Node24.18.0均通过，不删除原断言，不提高预算。

7058fb85真实Win4暴露原pr-history顺序断言失败：impact安装先于旧rules历史检查。将历史API检查前移到impact首次npm之前，移除rules和metadata重复调用；原顺序断言保留，调用计数加强为全文精确一次。全部CI合同（含Git真实下载/分片/冻结工作流/历史/快反馈）38/38通过0skip，Node24.18.0耗时42.3秒。两份原始失败日志已保存根.artifacts/ci-fast-pr307，不追认旧运行。

集成审计发现PR307的真实Full运行40722229360为原15项成功+impact成功+单个未展开fast跳过，共17项；旧交付验证器会将新增项拒绝。隔离0763d2e7工作树补版本合同：历史schemaVersion 2仍严格15项；新采证schemaVersion 3严格17项，缺两项也不回退历史版本，Fast-only/未知/重复/错身份/原分片非成功均拒绝；分页、原artifact和head/base/tree/重试校验保持。先红19通过2失败，再绿交付23项；最终可执行CI合同48/48和下载策略2/2通过，Node24.22.1。完整聚焦批次另有1项真实PowerShell checkout因本环境缺pwsh(ENOENT)失败，未跳过或改断言，不宣称该项或完整Quality通过。源码语法、网络和Backlog检查通过。未改工作流/保护/原证据，未push/合并/批准；待独立审查与正式当前SHA CI。TASK81性能AC不勾、仍In Progress。

2026-10-28 17:34 UTC只读API证实当前目标陈旧边界：branches/develop、git/ref/heads/develop及GraphQL引用均432eebb1d51a7ad37cfbc19f0e846bc00f1f4ba7；PR314仍报告base0763d2e7a4137a1f35d6a214922cb3ca938aa53c，refs/pull/314/merge仍aac67c0b983bfeb99067ef579b1ec1b92d57d2e7，其真实父为0763与abca269f332ce4db41cc4fd572d3adcf76264bdd。仅复查PR对象会错误沿用一致但旧的PR/merge/CI组合。最小修复在PR采证前后独立读目标Git ref，schema3绑定targetBeforeSha/targetAfterSha与已测base；旧schema2不变，历史合入不查询当前tip。新增未变目标通过、起始陈旧拒绝且不取产物、采证中前进拒绝、两处缺失/畸形/查询失败及真实采证调用顺序回归。交付专项先红23通过1失败，后绿27/27，Node24.22.1；不改工作流、保护、依赖、原收据或产品源码，不做fetch/rebase/push/合并。

2026-10-29 CI探针修复（仅本地待独立审查）：develop 58f72c2c 的Quality 40801744986/rules4 job123213242113原始日志确认原生八片探针spawnSync ENAMETOOLONG。Windows实际加权计划把POSIX四片合同放在rules3，也有同一重复绝对根目录缺陷；两份专用测试仅改cwd=临时根+原排序basename argv并新增便携实参断言，原断言、隔离、TAP及30秒预算不变。348文件逐片修复前后完全一致（八片44/44/44/44/43/43/43/43，四片87/87/87/87）；绝对argv变异在Linux亦被新增断言拒绝。当前Linux完整命令字符含NUL为21676→10192；已知Windows Node路径+67字符示例临时根模型为33840→10176（POSIX旧33144），真实hosted临时路径未采集。Node24.22.1聚焦18/18通过；初跑17/18缺fengari依赖失败原样保留，使用既有同版本NODE_PATH复跑，无安装。源码语法、网络与Backlog检查通过；未push/建PR/批准/合并，未取得新Windows hosted成功，TASK81性能验收仍未完成。证据保留于/tmp/windows-shard-probe-argv-20261029及原始hosted日志。
<!-- SECTION:NOTES:END -->
