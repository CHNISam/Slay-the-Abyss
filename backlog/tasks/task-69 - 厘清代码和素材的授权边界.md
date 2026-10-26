---
id: TASK-69
title: 厘清代码和素材的授权边界
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-26 09:32'
updated_date: '2026-10-26 09:33'
labels: []
dependencies: []
ordinal: 116000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
公众需要知道非商用代码许可和第三方内容的边界。审计及来源证据见 docs/legal/LICENSE_AUDIT.md；未明权利不视作已经获得商业授权。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 全仓来源及未明授权有可追溯记录
- [x] #2 明确非商用许可与第三方素材边界
- [x] #3 依赖和素材漂移检查及负例通过
- [ ] #4 核对默认分支并提交含剩余风险的PR
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
全仓来源核查；原创代码采用非商用许可并排除第三方；新增独立轻量检查；验证后提交附风险PR。用户已授权本次限定审计范围门禁例外，不变更全局门禁。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
全仓2387文件、436项素材/生成运行时和11项npm依赖已记录。PolyForm非商用仅限可授权原创代码；GPL导出运行时、反编译镜像和游戏IP未清关。3/3负例回归、实际离线SBOM与素材门禁通过；按用户限定例外提交PR，不修改全局门禁。
<!-- SECTION:NOTES:END -->
