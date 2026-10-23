---
id: TASK-25.2
title: 首发荧肖像与卡图制作（先确认原生或低图元替代）
status: In Progress
assignee:
  - '@codex'
created_date: '2026-10-22 16:37'
updated_date: '2026-10-23 01:00'
labels:
  - art
  - launch
dependencies:
  - TASK-10.1
references:
  - docs/experiments/art-portrait/README.md
  - docs/art/AI_ART_SAMPLES.md
parent_task_id: TASK-25
type: task
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
PR26两档拟合虽能导出，256图元仍模糊且27/72椭圆越出画布；首发需换适合路线，不继续堆图元。尚无获批正式荧头像，技术几何头像不能当成品。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 原生荧肖像可用性或手工低图元样张经批准并在游戏显示；直接拟合Lua的溢出风险未解决前不可批用
- [ ] #2 来源和权限明确；肖像/卡图文件与实际可玩卡牌ID映射，无素材缺口伪报
- [ ] #3 手机/主机画布、实际文字可读性和同屏控件成本有证据；独立分支/PR由主Agent审查集成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 仅处理用户两张PNG，保留哈希并做A整图拟合和B裁切编辑。2. 复用固定上游工具导出，按五官、轮廓、插图区和控件预算取舍；角色面部局部B2。3. MCP仅写测试副本，真实导入试玩与基线对照取证。4. 沉淀流程、结论、产物及PR状态，实机未通过不勾验收。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-23 /root，用户重新授权两张已生成图的资产实验，feat/ai-art-samples，基线1217abb。A/B各有Lua与超限GIA，B2角色939控件；星陨剑对应cleave，完整卡面343控件。六份Lua实际绘图表坐标/蒙版检查通过；四份GIA图片数和根蒙版读回通过，558个历史空引用与上游模板完全一致；上游卡面Fengari实例化/文字/蒙版/销毁检查通过。三个测试GIL副本scene_check_client均0错误0警告。官方导入尚未成功：普通执行器焦点失败，标准UAC执行器在旧试玩结算页误判菜单；新建管理员MCP客户端被自动审批拒绝，已请求用户具体授权，未启动。无本次美术实机截图、性能或多设备通过结论，不勾AC，不批产。详细参数/原图哈希/本机证据路径见docs/art/AI_ART_SAMPLES.md。

续测更新：用户明确回复允许专用管理员MCP客户端，已成功启动并重新发现当前游戏窗口；聚焦与一次全屏输入成功。基线run5675094a在导入前菜单识别失败，期间共享桌面记录出现combat-feedback会话run49a81efb。用户随后选择先让另一个会话完成，本会话已停止游戏输入并关闭临时客户端（PID12136已退出）。授权保留，当前等待共享GUI交接；仍无两图实机显示或性能通过证据。PR49保持Draft，TASK保持In Progress。
<!-- SECTION:NOTES:END -->
