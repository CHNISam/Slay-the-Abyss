---
id: TASK-13.1.2
title: M3 首发事件清单齐备与原版版本核验
status: To Do
assignee: []
created_date: '2026-10-23 16:11'
updated_date: '2026-10-24 02:07'
due_date: '2026-10-28'
labels:
  - p0
  - required
  - rule-parity
milestone: m-4
dependencies:
  - TASK-13.1.1
  - TASK-13.1.2.3
parent_task_id: TASK-13.1
priority: high
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
承接已批准六事件受限池和后续现有事件切片，先由TASK-47冻结首发具体事件ID、选项与渠道，再逐项实现与验收。其余11+6及一次性目录保留候选身份，不因目录存在声称完整PC事件全池。清单冻结不改变已纳入事件的原版资格、数值、概率或随机消费；不能通过抽后重试隐藏缺口。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 按TASK-47冻结首发事件ID逐项完成全部合法选项、代价、结果和基础能力；只有经验证内容进入生产池，未纳入项明确排除并记录，不改变纳入规则/概率，不抽后重试。
- [ ] #2 独立核对Scrap Ooze off-by-one与Duplicator第一幕资格，以及官方PC目标版本和全流随机消费；若未纳入，记录清单归属而非宣称其已实现。
- [ ] #3 耗尽与资格不足有明确诊断；冻结清单内每个事件均有正常渠道获取/执行证据，基本路线归TASK-12.3，严格资格及概率平台验收归TASK-12.5。
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
范围按TASK-47冻结的首发事件ID逐项验收；标题旧“全池”不强制补齐原版全部事件，未纳入内容不得进入随机池。
<!-- SECTION:NOTES:END -->
