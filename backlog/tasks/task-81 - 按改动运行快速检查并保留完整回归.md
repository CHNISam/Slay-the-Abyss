---
id: TASK-81
title: 按改动运行快速检查并保留完整回归
status: In Progress
assignee:
  - Codex
created_date: '2026-10-28 15:30'
updated_date: '2026-10-28 22:25'
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

PR316核心超时修复已由accepted PR313（cec690c1）交付；本轮仅在既有职业选牌分片合同中补齐广义发现与针对性静态负例；实际进程编号联合仅作为本地验证证据保留，不加入普通Node套件。保留accepted Lua、manifest、runner hash与托管分片检查，原30秒预算验证；这是测试加固，不是M3玩法运行阻塞，不勾选性能验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
PR307；固定Node24.18.0专项32项通过，后续手动诊断输入与门禁9项通过。YAML/Bash语法通过；规则集证据已保存，无保护修改。当前远端Quality40716938768仍排队，未完成Full/Fast性能验收。创建时发现未合入审计工作树已占TASK80，改用TASK81；误建草稿6/7未提交。

PR307头11ff8b98真实Windows8片失败：原ci-downloads负例将第一个npm安装重试改99，但检查器只审旧rules作业，新增impact未纳入。最小修复将npm限制扫描扩展到整个Quality工作流，并逐安装步骤变异拒绝99重试。原失败与新负例本地Node24.18.0均通过，不删除原断言，不提高预算。

7058fb85真实Win4暴露原pr-history顺序断言失败：impact安装先于旧rules历史检查。将历史API检查前移到impact首次npm之前，移除rules和metadata重复调用；原顺序断言保留，调用计数加强为全文精确一次。全部CI合同（含Git真实下载/分片/冻结工作流/历史/快反馈）38/38通过0skip，Node24.18.0耗时42.3秒。两份原始失败日志已保存根.artifacts/ci-fast-pr307，不追认旧运行。

集成审计发现PR307的真实Full运行40722229360为原15项成功+impact成功+单个未展开fast跳过，共17项；旧交付验证器会将新增项拒绝。隔离0763d2e7工作树补版本合同：历史schemaVersion 2仍严格15项；新采证schemaVersion 3严格17项，缺两项也不回退历史版本，Fast-only/未知/重复/错身份/原分片非成功均拒绝；分页、原artifact和head/base/tree/重试校验保持。先红19通过2失败，再绿交付23项；最终可执行CI合同48/48和下载策略2/2通过，Node24.22.1。完整聚焦批次另有1项真实PowerShell checkout因本环境缺pwsh(ENOENT)失败，未跳过或改断言，不宣称该项或完整Quality通过。源码语法、网络和Backlog检查通过。未改工作流/保护/原证据，未push/合并/批准；待独立审查与正式当前SHA CI。TASK81性能AC不勾、仍In Progress。

2026-10-28 17:34 UTC只读API证实当前目标陈旧边界：branches/develop、git/ref/heads/develop及GraphQL引用均432eebb1d51a7ad37cfbc19f0e846bc00f1f4ba7；PR314仍报告base0763d2e7a4137a1f35d6a214922cb3ca938aa53c，refs/pull/314/merge仍aac67c0b983bfeb99067ef579b1ec1b92d57d2e7，其真实父为0763与abca269f332ce4db41cc4fd572d3adcf76264bdd。仅复查PR对象会错误沿用一致但旧的PR/merge/CI组合。最小修复在PR采证前后独立读目标Git ref，schema3绑定targetBeforeSha/targetAfterSha与已测base；旧schema2不变，历史合入不查询当前tip。新增未变目标通过、起始陈旧拒绝且不取产物、采证中前进拒绝、两处缺失/畸形/查询失败及真实采证调用顺序回归。交付专项先红23通过1失败，后绿27/27，Node24.22.1；不改工作流、保护、依赖、原收据或产品源码，不做fetch/rebase/push/合并。

PR316原head85489ef7及既有独立审查/预检保留为历史证据；accepted PR313已采用1–5/6–10的等价完整拆分并锁住原源Git blob/SHA与runner。当前改为复用已接受实现的最小测试加固，禁止覆盖accepted Lua/manifest或引入PR309的五片。原head已保留本地backup/class-choices-pr316-before-pr313-20261028，后续新head需另取独立审查与完整Quality。

PR316最终收敛为两文件测试加固：只改既有tests/game-ui-class-choices-partitions.test.mjs与本任务CLI备注。accepted Lua两入口、manifest、runner完整hash、worker/timing与原托管分片检查逐字节保留；既有逆向校验复用于断言/12张牌组/两种物理分支/重复选择器负例，另加缺片/额外片（含非标准家族文件名）/重叠/空隙/注释入口负例。普通Node合同仅静态3/3通过0skip，不启动Lua、不增加重复CI进程；Full仍按原始Lua调度执行两入口。

实际CASE编号联合已在本地验证，不作为普通CI新增测试：此前本地285449f3在重建data/UI/theme后Node24.22.1定向4/4通过0skip，两原30000ms进程11.500秒/14.646秒；独立审查4/4、11.458秒/13.004秒，实际编号1至10恰好一次。相关树外日志reconciled-pr313-focused-20261028.log及独立receipt保留为该历史head的证据。最终版本移除普通Node重复启动进程的检查，仅保留静态保护；新head需更新独立审查与当前SHA完整Quality，不复用旧854或285的预检资格。核心修复已随PR313接受，本轮不是M3运行阻塞；性能AC保持未勾选。

PR319已合入48cb48ce（cec唯一父），吸收严格交付schema3/真实目标tip合同和已证实的四项原预算夹具拆分；本分支完整保留其TASK81交付计划/备注。PR316旧94e的Full40762136486仅退出夹具超时，该夹具现已由accepted319修复；本次仅将原静态职业选牌保护逐字节重放到新基线，不复制运行时/分片实现，不新增Node Lua进程，不作为M3运行阻塞。旧854/285/94e审查与运行只作历史记录，新head需新独立审查和当前Quality，性能AC仍不勾选。
<!-- SECTION:NOTES:END -->
