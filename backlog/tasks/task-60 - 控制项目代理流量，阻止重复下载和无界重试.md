---
id: TASK-60
title: 修好CI重复拉取，并限制异常下载
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-26 02:09'
updated_date: '2026-10-27 15:04'
due_date: '2026-10-26'
labels:
  - p0 cost engineering
dependencies: []
references:
  - scripts/ci-checkout-equivalent.mjs
  - docs/evidence/linux-checkout-equivalent-20261026.json
priority: medium
type: bug
ordinal: 0
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户将流量控制列为最高优先级，随后明确要求保持简单：修复重复拉取、限制下载重试、打印每轮新增Git包大小并对异常大包失败。不引入整机流量账本、常驻监控或预装bootstrap。详情与生效边界见docs/NETWORK_BUDGET.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 连续增量拉取不重复传输已有大对象，并保留精确提交和基准检查
- [ ] #2 CI记录新增Git包大小，异常大包失败；依赖安装优先缓存且重试有界
- [x] #3 轻量回归和工程检查能抓住旧拉取方式，不新增常驻服务或全局配置
- [ ] #4 记录本机止损已生效与仓库接线待共享文件释放的实际边界
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 保留已添加的runner持久引用。2. 只改现有checkout引用、包大小记录/异常阈值和npm下载参数。3. 用真实离线Git回归及轻量合同检查验证。4. 保留独立工作树，待PR206共享文件释放后再受控推送集成。

2026-10-26按用户追加授权，提供Linux本地等价检验，Windows继续跑实际PowerShell正文；复核工作流指纹、真实Git字节量、旧流程负对照与超限拒绝，避免环境缺失导致停工。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已确认runner空闲并添加refs/ci/network-budget指向现有HEAD b6a29e4，立刻改善旧工作流的增量协商。Windows拒绝停止服务；远程disable Quality被自动审批拒绝，未执行；保留其他runner与工作流。根旧任务库误生的同号TASK55已原生归档，不覆盖真实TASK55。

用户明确授权本轮独立实现例外：只在独立分支本地实现/测试流量保护，保留PR206原稿，待共享文件释放后再推送集成；不借用TASK47会话、不改远端claim、不绕过提交推送hooks。

用户最新明确“别搞复杂，不要太离谱”；收窄并撤出整机账本、代理PID采样、进程熔断与预装bootstrap。此前只有隔离build内短测，没有常驻服务或全局安装；不将已撤出的复杂方案作为待交付。

简化候选本地验证通过：node --test --test-concurrency=1 tests/ci-downloads.test.mjs 为2/2通过；直接执行工作流checkout原文（仅离线替换传输URL），首次262501B，小增量319B，旧流程负对照262723B；缩小测试阈值可真实拒绝超限包。npm run check:network、npm run check:syntax、npm run verify:backlog和git diff --check均通过。只保留原CI约30行修改、轻量合同和离线回归；复杂监控源码已撤出，未部署常驻进程。未运行远端CI/完整玩法套件；没有推送合并，AC2/4待共享文件交接与实际接线核对。用户当前授权仅独立本地实现/测试，不以自动重试或绕过claim扩大范围。

用户追加要求推送，并在正常提交被TASK_CLAIM_SESSION钩子拒绝后，明确授权这一次跳过认领钩子，只提交并推送feat/network-budget；不合并、不改其他分支、不修改持久门禁配置。无远端claim授权，不宣称ownership或当前SHA CI通过。分支push不命中现有develop/master触发器，本轮不创建PR或手动启动完整CI。

Linux等价检验已实现，3项通过：首次262501B/增量319B/旧流程262723B。适配器只允许已审阅工作流及明确负对照变体；未知工作流语义、引用不一致均拒绝。正式CI正文和阈值未改，不下载大型运行时，不冒充Windows或远端CI证据。详见docs/ENGINEERING.md。

Linux完整npm test复验1471项全部通过，0失败/0跳过；原缺pwsh失败日志保留，新的等价检验单独记录于docs/evidence/linux-checkout-equivalent-20261026.json。没有修改正式CI或宣称Windows、远端CI、M3整体验收通过。

2026-10-26用户明确仓库已公开，要求使用GitHub官方免费runner。API确认visibility=public且连接具备push权限；本轮将Quality/check由本机自托管改为标准windows-latest，其余作业ubuntu-latest，保留全部测试、精确SHA检出、网络门禁、ownership和收据。托管工作区不承诺跨轮对象复用；不操作本机runner服务。当前SHA远端CI仍待实际运行，不勾选相关验收。
<!-- SECTION:NOTES:END -->
