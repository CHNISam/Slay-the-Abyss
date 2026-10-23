---
id: TASK-19
title: M4 验收与缺口如实报告
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 13:48'
updated_date: '2026-10-23 09:29'
due_date: '2026-10-29'
labels: []
milestone: m-5
dependencies:
  - TASK-18
  - TASK-5
  - TASK-25
priority: high
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
按发布前检查表逐条核验；未完成项必须如实记录，不得宣布为通过。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 按发布前检查表逐条核验并勾选
- [ ] #2 未完成项与内容缺口如实写入报告
- [ ] #3 列出已知问题与规避说明
- [ ] #4 同一候选确认赛事资格、报名入口与作品GUID，发布前人工复核；收益已由用户确认，不重复设阻塞
- [ ] #5 发布候选核对M2/M3规则账本与M4反馈/体验验收，实际首发内容无未核实规则或未修正实质偏差才可声明严格一致；可选元素/第二幕未启用不得列缺口阻塞必选投稿。10/30准备硬线不因扩展延后。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-10-23 /root：仅推进不依赖原神的候选取证与缺口报告切片。固定本批source SHA和候选hash，真实MCP编译/副本构建后独立只读核对28模块同源、1590树控件/max50/六列模板与22节点结算挂载；记录完整本地/当前CI结果和仍失败的地图golden，不据此放行官方导入/实机/严格一致性或发布。BGM另用默认关闭与显式试听副本区分。

2026-10-23 可复用只读取证工具片：固定完整source SHA，隔离生成预期；用实际MCP读回模块/完整UI/模板/图/参数，比较源码仅允许BOM与换行规范化、按源树算控件口径，候选hash前后相同，所有差异结构化issues并非零退出。BGM必须显式选项且双参数/两图正确，不认证编译语义/实机。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
赛事入口正式确认从TASK-1迁入本M4候选关口；不可用时不放行M5。

本轮用户明确暂不开原神、授权跨Backlog离线持续并行；TASK5/18/25依赖及所有正式发布前AC仍未满足，领取只做离线报告切片。源139de94规则候选已真实构建，独立只读报告在根.artifacts/continued-batch-139de94/readback-verification.json。不是正式发布候选放行。

PR99/100已在各自当前head两个Quality成功后合入1182814/14979df。源139de94规则副本28模块同源、1590树/max50/6列/22节点结算已启用；源cf6969e显式BGM叠加29模块同源、22+83节点两图启用、参数true。两者静态0error17warning，输入底图及候选只读前后hash相同。docs/P0-SMOKE与两份docs/evidence记录路径/hash/读回报告/源码换行口径。地图golden仍0/12，未导入/开游戏/试听/放行正式发布，所有AC未勾。

3a9a4b0工具独立实现：5组真实响应裁剪fixture比较测试通过；139普通候选28/28与cf BGM29/29实际复读ok，输入hash不变，均0error17warning；错cf SHA核139候选实际exit1并报MODULE_MISMATCH/MISSING。根.artifacts/reusable-audit-139de94-final、reusable-audit-cf6969e-final与reusable-audit-wrong-source-r1留原始响应。仅scripts/tests/docs，无游戏源/依赖/CI变更，CLI详见NATIVE_CANDIDATE_AUDIT.md。与root d12fe89候选证据记录同时保留，全部AC未勾，整体未放行。

独立复审3a工具抓到阻断漏报：未比界面hidden/输入flags/name以及全字符串hex大小写容差。d6e9672新增真实fixture否例先5过2败，最小修复后7/7绿；现在完整界面元数据/未知键比对、仅语义颜色字段规范化，正文/资产/脚本公共字符串保真。139/cf两实际候选在interface-fix新目录复读ok，hash不变，0error17warning；待独立复核完成后再合入。第二批完整检查JS641项526过115skip，遭遇覆盖默认15秒一次超时；同预算隔离重跑6秒退出0、115组全过，预算未改，组合门禁需在最终head重跑，不把首次中断写成通过。

候选审计d6e9672独立复审7组及此前漏检否例通过；实际139普通报告28模块、cf BGM报告29模块与两图/双true参数复核，无新增阻断。root最终d3e9d76完整check exit0（JS643/528pass115skip、全部Lua、Python15pass1权限skip）；先前超时和Fat旧fixture冲突如实保留，未放宽预算。将按d3e9d76构建下一普通副本并只读取证，不把图身份/挂载检查写成编译参数语义认证。全部正式发布AC仍未勾。

真实普通副本d3e9d76构建在scene_check_client被1个SCRIPT_VARIABLE_NOT_FOUND拦下：PR99后abyss_ui读nativeBgmEnabled但普通manifest未注册；显式BGM构建单独true所以此前绿。未绕过检查或把失败副本当成功。默认manifest注册boolean false，先红3pass1fail后包清单/BGM图7组绿，重新构建另开新目录；失败原始响应保留根.artifacts/continued-rules-d3e9d76。
<!-- SECTION:NOTES:END -->
