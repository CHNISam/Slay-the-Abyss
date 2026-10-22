---
id: TASK-10.1
title: Spike：PNG→GIA/Lua 真机可行性实验
status: In Progress
assignee:
  - '@codex'
created_date: '2026-10-22 15:57'
updated_date: '2026-10-22 16:42'
labels:
  - technical-spike
dependencies: []
parent_task_id: TASK-10
type: spike
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
独立验证 PNG 图像经 GIA/Lua 路径在千星客户端实际显示的可行性，为首发视觉资产规格提供证据。关联 TASK-4 的多设备验收、TASK-10 的战斗 UI 与 TASK-24 的原型美术工作；不承担正式美术制作，不以生成文件或编译成功冒充真机通过。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 记录最小样例输入、GIA/Lua 路径、工具版本及图像尺寸/透明度/容量等平台限制，失败也有可复现证据
- [ ] #2 分别记录编译、写入存档副本、真机显示和交互验证结果及截图；保持 MILIASTRA_ALLOW_LIVE_WRITE=0，发布由人完成
- [ ] #3 给出可行或不可行结论、手机与主机适配风险、正式美术可用规格及不可行时的降级方案
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
固定两套上游版本和许可证；干净Agent分别完成单一卡牌UI与肖像小样，主Agent独占MCP/GUI完成场景样例与统一导入实机验收；记录画质/启动耗时/控件数量和降级；按通过门槛拆分制作任务，独立分支PR，主Agent集成质检。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CLAIM 2026-10-23 /root codex，feat/art-pipeline / .worktrees/art-pipeline。primitive_spike和editor_spike只做小样；实机门槛前不批产。

2026-10-23三个干净Agent独立交付draft PR25(原生场景)、PR26(肖像)、PR27(卡牌)。主Agent集成feat/art-pipeline：卡牌副本模板真实索引1073741845/1846，scene_check_client errors0/warnings0，prepare-card-candidate.ps1完整复跑通过。官方导入81b1598a和eaea49f1两轮均因文件框未弹出失败，无游戏日志/截图、性能未测。独立复核修正肖像128像素Y偏移，320位置回归通过；27/72越界椭圆无法裁切，直接拟合Lua退出首发候选。制作任务TASK-25.1/25.2/2.1已建，依赖10.1，保持To Do不批产。已请求用户手动验证导入按钮。
<!-- SECTION:NOTES:END -->
