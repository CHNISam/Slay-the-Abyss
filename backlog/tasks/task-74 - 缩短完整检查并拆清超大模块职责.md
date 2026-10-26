---
id: TASK-74
title: 缩短完整检查并拆清超大模块职责
status: Done
assignee:
  - '@codex'
created_date: '2026-10-26 14:33'
updated_date: '2026-10-26 15:14'
labels: []
dependencies: []
references:
  - docs/backlog-details/TASK-74.md
ordinal: 118000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
完整CI反复耗时近一小时，界面大文件提高修改成本。本轮拆清界面职责、分片完整回归，并正式退役先前已停用的额外任务锁及其专属测试。保持游戏、构建和当前交付门禁覆盖；旧锁历史可从Git取回。详情见 docs/backlog-details/TASK-74.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 完整游戏、构建和当前交付检查保留断言与失败传播，并有官方Runner耗时对照
- [x] #2 超大模块按明确职责拆分，公开接口及构建模块完整
- [x] #3 相关回归和工程门禁通过，记录剩余热点与未执行的平台验证
- [x] #4 已停用任务锁的代码和专属测试正式退役，活动调用者核查完成且历史可取回
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.按成功CI分阶段记录耗时和重复执行。2.保留同步Lua执行，仅增加严格确定分片。3.并行拆分战斗手牌子视图与商店商品和服务渲染职责，保留布局和规则来源。4.用四个独立Windows VM分片，片内串行并保留原跨平台和聚合门禁；仅迁移逐条复核的旧告警行号。5.运行原回归、工程门禁、独立审查及当前SHA官方完整CI，按证据合并与收口。

6.真实CI日志确认旧任务锁29项测试耗411.110秒，按既有停用决定正式退役工具及专属回归；不操作远程coord分支或本地Git元数据，补固定历史取回说明。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已集成两个UI职责切片和最小Lua分片CLI；固定Node24通过19项原runner/数据/分片回归，候选子模块部署闭环及四项语义变异门禁通过。静态113条无新增，42条仅行号移动。并发试验因重例预算风险撤回，CI采用四个隔离Windows VM、片内保持同步串行；现等待当前SHA官方完整CI，未计为最终通过。

独立审查codex-integration-review-20261026-be1ab064通过：所审head be1ab06480c6a8338b8177a20741dab9211c6023、base d8a262270b959d19825932e049e76064108bd67e，UI更新顺序/闭包身份、分片425无重漏、113条静态诊断精确迁移及必需check收据兼容均核对，无未解决项；最终正式CI尚在执行。

范围补充依据：本轮用户要求架构轻量化，TASK68已批准停用额外任务锁；旧日志证明仍为其付出6分51秒Windows回归成本。明确将其源码和29项专属断言一起正式退役，不作为游戏覆盖削减，不把退役测试计入保留或通过。

旧任务锁正式退役切片已完成调用者与源码审查：三文件及专属29测试/两个npm入口一起移除，协议提供固定d8完整SHA取回链接；净删1425行。当前活动规则、CI、脚本、配置及测试无引用，core.hooksPath未设置；不动其他机器的自包含hook或远程协调记录。非测试门禁和工程门禁复核通过，最终全量CI继续。

首轮官方完整验证记录：run40342575491全SUCCESS，当前实现头be1ab06480c6a8338b8177a20741dab9211c6023，直接四个job原始日志复核425 fixture精确并集，JS1560全过/0skip。该轮保留旧工具测试，退役后预期JS1531、Lua425不变；将其一并作为最终PR头重新验证，不跳过任何有效游戏门禁。Done随该PR通过当前SHA全部必需检查并合并后进入develop。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
战斗主render圈复杂度359→274，商店109→编排4/子函数最大33；退役已停用任务锁及29项专属测试净删1425行。官方完整首轮40342575491全绿，Windows1560项/425个Lua逐文件无重漏，等待52分39秒→19分28秒（约减63%）；独立审查及本地架构/静态/四项变异通过。旧锁退役后最终PR头仍由当前SHA完整Quality强制把关，只有成功才合并；平台导入/实机未执行，不据此关闭相关关口。详见docs/backlog-details/TASK-74.md和PR228。
<!-- SECTION:FINAL_SUMMARY:END -->
