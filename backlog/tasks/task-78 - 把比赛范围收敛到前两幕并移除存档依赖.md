---
id: TASK-78
title: 把比赛范围收敛到前两幕并移除存档依赖
status: Done
assignee:
  - Furinya
created_date: '2026-10-28 08:19'
updated_date: '2026-10-28 09:11'
labels: []
milestone: m-4
dependencies: []
references:
  - docs/backlog-details/COMPETITION-SCOPE-20261028.md
priority: medium
type: task
ordinal: 0
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户2026-10-28明确将比赛重心改为第一幕、第二幕和前10分钟体验，第三幕、隐藏第四幕、真结局及依赖持久存档的功能退出当前比赛必做。用户确认无奇匠Lv.4权限，不升级账号或另建后端。旧四幕承诺按本决定替换，保留代码、状态和证据，不伪造完成。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Backlog任务和M3至M6范围同步为前两幕；未来章节与持久存档依赖不再阻塞比赛，未完成状态和历史证据保留。
- [x] #2 SCOPE、MILESTONES、HANDOFF、协作规则和当前候选发布文字一致；前两幕同局状态、回滚及本局结算保留。
- [x] #3 规划范围检查及正反例通过，负责人、优先级和High上限等既有门禁保留；正式入口不得越过第二幕的未实现缺口单列。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 用CLI调整里程碑、任务范围与依赖并保存前后清单。2. 同步当前范围、交接及候选文案，保留历史源码证据。3. 更新精确范围门禁和专测，运行规划及相关文档检查，不宣称运行时/实机完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLI范围与非Save分类已完成，原有任务状态、负责人及已勾AC数量前后比较全部保持。62/64转Low且清里程碑，45/53仍未来；61/63及同局状态保留。verify:backlog通过、规划和发布文案54/54专测通过、原生产清单/Lua门禁通过、doctor无重复或环、diff检查通过。正式运行时双幕终点仍未实现，由High TASK-77承接，不生成新候选、不声称M3/平台通过。

编号核对：未合PR289已占TASK-76（Lua测试去重）。本范围任务通过原生task demote→DRAFT-6→draft promote重新分配TASK-78，保留原验收、实施及证据；未直接编辑Backlog ID。正式双幕终点继续TASK-77。

PR291当前CI发现历史公告退役回放把现行CHANGELOG误当冻结退役后输入（rules4：288通过/1失败）。用户授权范围文字更新后，该历史输入已合法变化；本轮只修测试历史回放边界：读取不可变归档CHANGELOG，保留归档hash、其他来源漂移检查及现行版本/发布校验，不改玩法或放宽测试时限。

PR291历史文案兼容修复已验证：原CHANGELOG漂移失败在/tmp/pr291-retirement-red.log真实复现；新增独立归档getter绑定原before SHA256 c906c8ea3cad9b9c282d89c332cbedab3cdee4279220547b5abea800456e57a5，仅历史CHANGELOG显式取归档。原preRetirementSource函数逐字节不变；gzip及所有历史hash未更新。归档篡改、显式现行漂移及其他源码漂移负例保留。相关74项覆盖：规划/发布54、M3整合6（含79543/79757真实完整trace）、原生合同6、正式入口3、职责/退役5均已通过；初跑4项缺本地生成data/theme，按原build:data/ui/theme/layout准备后原组重跑通过，失败日志保留。verify:backlog与diff通过；不改生产、归档、golden、超时或运行时入口。当前SHA远端CI仍需重跑。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
已用Backlog CLI同步前两幕比赛范围、未来章节/持久化边界与相关任务；当前文档及v0.11候选文案一致。规划门禁、54项专测、原生产清单和doctor通过。TASK-77仍To Do，高优先级阻塞正式双幕候选；本次不改玩法。
<!-- SECTION:FINAL_SUMMARY:END -->
