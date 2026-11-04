---
id: TASK-98.1
title: 修复迁仓后的自动合并仓库身份校验
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 05:26'
updated_date: '2026-11-04 08:10'
labels: []
milestone: m-7
dependencies: []
references:
  - 'https://github.com/FurinyaWorks/Slay-the-Abyss/rules/25870651'
documentation:
  - docs/backlog-details/TASK-98.1.md
parent_task_id: TASK-98
priority: medium
type: bug
ordinal: 141000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
仓库ID1429751262已迁至FurinyaWorks/Slay-the-Abyss，启用和暂停入口仍写旧路径，导致合法PR被拒。只修仓库身份入口，不接管TASK-98其他交付或TASK-99收据继承。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 启用和暂停使用新规范仓库路径，并校验不可变仓库ID；旧路径、异仓和缺失身份继续拒绝
- [x] #2 既有严格基线、独立评审、Full回归与失败撤销门禁保留，迁仓正负例及原合同定向测试通过
- [ ] #3 当前SHA独立复审、Required CI和合后实际身份有证据，未验证部分保持未完成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 核对仓库ID、最新develop、规则与开放PR并隔离工作树。2. 最小修复启用/暂停的规范路径与身份校验，不重写历史证据。3. 用迁仓、旧路径、身份缺失/不符及暂停负例回归，并跑原交付合同。4. 独立复审后报告，PR及CI另行验证。

PR504已合入c1cf79d、源PR506已关闭后，在新的develop短分支只承接两处当前操作文档路径与未逐例吸收的身份/旧Full负例；不重写生产实现、历史别名或原收据。补定向回归及独立复审，CI和实际接续另记。

接续PR510：保留原身份与文档断言，先复现CRLF标题分割失败，再以EOL规范化修复并加入LF/CRLF和缺标题负例；本地提交后由独立执行者复审，远端更新由协调者完成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已核实固定ID与规则，修复canonical路由及暂停身份。Node24三组定向77/77、治理41/41、doctor/backlog/guidance与diff检查通过；新增迁仓夹具在旧源码复现25失败。独立只读复审通过并独立重跑77项。完整CI、当前最终SHA复审绑定与合后身份尚待验证，保持In Progress。

本切片由PR504接续：采用固定ID numeric canonical和head/base ID、sameAdmission、迁移witness；保留原PR506记录，补三个CLI入口及身份失败不写远端、旧review拒绝负例。组合83项通过；实际新HEAD CI仍在queued，AC3保持未完成。

PR504已合入c1cf79d且原PR506已接续关闭。新独立短分支仅修CI文档两处当前路径，补44组身份元数据零远端写入与无witness旧Full拒绝；不修改生产脚本或历史别名。三组86/86、连同治理与分支历史共130/130通过；文档回归在旧路径复现1失败。三项临时源码负对照（ID宽松比较、漏full_name、漏run owner）均被新测试捕获；doctor/backlog/guidance/diff通过。新接续提交的CI与合后验证未完成，AC3不变。

接续PR510独审发现Windows CRLF使新增文档标题分割失败；原实现加EOL回归先红（34通过/2失败），仅在测试断言helper规范化CRLF后，原合同及LF/CRLF、缺标题负例共87/87通过，guidance/backlog/doctor通过。未改生产脚本、旧断言或历史证据；本地提交后待独立复审与远端Required CI，AC3保持未完成。
<!-- SECTION:NOTES:END -->
