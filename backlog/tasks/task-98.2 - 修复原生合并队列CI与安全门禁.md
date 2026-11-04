---
id: TASK-98.2
title: 修复原生合并队列CI与安全门禁
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-04 07:48'
updated_date: '2026-11-04 08:43'
labels: []
milestone: m-7
dependencies: []
references:
  - 'https://github.com/FurinyaWorks/Slay-the-Abyss/pull/508'
documentation:
  - docs/backlog-details/TASK-98.2.md
parent_task_id: TASK-98
priority: medium
type: bug
ordinal: 142000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
接续现有PR508，Windows完整检查因换行和历史投影失败，独审发现暂停、动态授权、收据和规则校验缺口。保留504身份与继承修复，不启用远端队列。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 LF与CRLF工作流投影保留原冻结断言，负例拒绝未知漂移
- [ ] #2 暂停、动态授权、实际收据与规则漂移负例失败关闭
- [ ] #3 精确HEAD独审与托管完整CI通过后正常合入，队列仍未启用
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.核对504基线并保留身份与继承成果。2.先复现Windows与安全负例，再分文件修复。3.独审、定向与门禁验证。4.重查远端后更新508，等待精确HEAD完整CI正常合并。

原生队列读回接续：先补waiting/queued与失败清理负例，再提取精确队列身份及dequeue读回；arm核对SQUASH/ALLGREEN和原保护，原审查门禁握手保留。定向验证后本地提交，独审及远端更新由主控完成，未上线及真实演练保持未验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已在独立工作树接续504与原508历史，保留固定仓库ID及收据继承；CRLF精确投影、原生dequeue、BASE授权标记、当前成员/hold/依赖重验、实际收据attempt/parents及规则最终读回已实现。98项组合定向通过。完整CI与真实队列演练未完成，不勾最终验收。

原生arm接续：仅有merge_queue规则时读取真实SQUASH/ALLGREEN策略、精确PR/HEAD/entry并兼容waiting及queued+REST null；非队列仍要求squash。失败与pause共用dequeue及双读回，不确定保留。回归先红35/4与条目替换39/1；最终Node24标准隔离113/113，guidance/backlog/doctor与syntax通过。真实只读schema接受新增字段，508当前仍未启用队列；本地提交后待主控独审、更新与精确HEAD完整CI及真实演练，最终AC不变。
<!-- SECTION:NOTES:END -->
