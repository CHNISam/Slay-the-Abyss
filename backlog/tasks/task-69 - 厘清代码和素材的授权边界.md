---
id: TASK-69
title: 厘清代码和素材的授权边界
status: Done
assignee:
  - '@Furinya'
created_date: '2026-10-26 09:32'
updated_date: '2026-10-27 15:04'
labels: []
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/218'
priority: medium
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
- [x] #4 核对默认分支并提交含剩余风险的PR
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
全仓来源核查；原创代码采用非商用许可并排除第三方；新增独立轻量检查；验证后提交附风险PR。用户已授权本次限定审计范围门禁例外，不变更全局门禁。

按用户纠正保留非商用许可；仅凭参考/移植不判定复制代码，平台IP说明按官方创作场景表述，逐文件区分MIT运行时与GPL适配片段；修订公开说明，交回待合并PR213。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
全仓2387文件、436项素材/生成运行时和11项npm依赖已记录。PolyForm非商用仅限可授权原创代码；GPL导出运行时、反编译镜像和游戏IP未清关。3/3负例回归、实际离线SBOM与素材门禁通过；按用户限定例外提交PR，不修改全局门禁。

PR218已提交至develop，未合并。补充Windows CRLF/Linux LF跨平台素材哈希回归，原始二进制保持逐字节。现有ownership例外不当通过。

按用户纠正：保留非商用许可；不能由参考/移植认定复制代码，原神内容明确官方平台创作及收益场景。逐文件核对将19项过宽分类改为12项文字框/蒙版适配、6项MIT纯图形和1项原创验证脚本。原审计中整仓定性被本次记录取代；仅修正文档和分类，不改游戏。新一轮3/3及实际门禁通过。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
按用户确认保留原创代码非商用复用及项目方商用权。公开说明改为准确、简洁的范围说明；12项实际编辑器适配输出单独处理，6项MIT输出与原创验证脚本已纠正分类。不凭参考资料推定复制，不将平台内创作写成未经授权。3/3和实际清单检查通过；文档修正交PR218并入待合并PR213。
<!-- SECTION:FINAL_SUMMARY:END -->
