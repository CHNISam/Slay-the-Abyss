---
id: TASK-4.6
title: 让战斗卡牌数字显示增减颜色和文字提示
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-24 17:08'
updated_date: '2026-10-24 18:13'
labels: []
milestone: m-5
dependencies: []
references:
  - docs/evidence/card-value-feedback/REPORT.md
parent_task_id: TASK-4
priority: high
type: enhancement
ordinal: 92000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按用户提供的动态数值反馈实施包，复用现有战斗预览，补数字颜色与不依赖颜色的方向提示。技术约束、矩阵和分层验证见 docs/backlog-details/card-value-feedback.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 逐效果使用本卡当前定义和预览比较，支持增强、削弱、中性及瞄准取消，战斗规则不变。
- [ ] #2 数字采用主题增减色并有文字方向，保留费用、完整描述和输入隔离；本地自动回归通过。
- [ ] #3 同源候选完成构建回读，真实记录原生电脑与手机验证和严格UI门禁，未测项明确保留。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 撤销B档额外标签和图标替换；2. 对照原版方法级证据验证原生行内色；3. 实现原句内数字红绿与紧邻的克制非颜色线索；4. 重做布局、输入、数值与原生/手机分层回归；5. 当前SHA CI成功后合并develop。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
用户明确否决割裂的独立数值标签及替换卡面图标；当前PR194不得按B档标签版合入。改为原说明行内局部数字颜色，保持卡面/图标/原句整体；先实测原生行内能力，必要时在说明区做独立原生数值片段，不再占用插图区。旧本地PASS只认证被否决候选，不认证重做结果。

原生1849探针已确认同一文本框支持句内局部颜色；已撤掉独立标签和图标替换。生产展示冻结bd7620d，夹具6e22f20。1851受控卡牌实测六状态/混合/十牌及鼠标选中，有33条本轮日志、50模块与UI官方读回匹配；普通候选49模块/2339控件/0错误32警告，见docs/evidence/card-value-feedback/evidence.json。CI 40118154321当前实现提交两个作业成功。新版本地JS1108过118跳过；全量在gremlin_gang 30秒超时，独立重跑29组19.332秒通过，不把首次全量记PASS。手机、真实拖动全路径和严格UI门禁仍待验，AC2/3不提前勾选。
<!-- SECTION:NOTES:END -->
