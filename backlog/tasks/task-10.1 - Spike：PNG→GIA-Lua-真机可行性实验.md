---
id: TASK-10.1
title: Spike：PNG→GIA/Lua 真机可行性实验
status: To Do
assignee:
  - '@codex'
created_date: '2026-10-22 15:57'
updated_date: '2026-10-22 22:50'
labels:
  - technical-spike
  - queued-after-M3
milestone: m-5
dependencies: []
parent_task_id: TASK-10
priority: low
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

用户已手动导入卡牌候选：ART脚本/界面与两个外部Lua源读回匹配，静态检查0错误0警告。导入已成功；当前试玩8fd0a901/f891c7e9在开始前因无法把sandbox切前台失败，窗口工具后续FOCUS_FAILED。已请求用户手动进入试玩，不再重复导入。显示/点击/性能尚未验收。

2026-10-23 当前会话/root已按用户明确要求代办权限，成功启动标准UAC管理员临时测试助手，无需用户重启游戏。23eb92d6实际输入已能离开编辑器/处理大厅提示，后续自动导入仍失败；现屏幕已是ART原生卡牌试玩（截图.worktrees/platform-ui/captures/90a571a9-6056-4ce5-a8ba-357c986e18a8.png），中文费用/6点效果可见。接下来本会话只点击当前已可见的点击检查按钮取证；其他会话请勿并行占用GUI，无正式发布操作。

2026-10-23 当前屏幕实际验证新增：capture 90a571a9为原生卡牌/中文说明/费用1，capture 18d2853b为同一试玩出现点击通过，匹配ART_Probe回调设置，证明显示及一次交互发生。后者在本会话点击助手发送前即出现，不能归因于该助手；本助手editor_input被WINDOW_NOT_FOREGROUND保护拒绝，未强行输入。管理员临时助手IsInRole=True，23eb92d6已真实执行离开编辑器/处理大厅提示；导入框自动化仍未过。用户无需重启或自行配置，后续环境操作由Agent以标准UAC单次助手承担。截图与助手状态在.worktrees/platform-ui/，尚无完整日志/dt/多设备/批量性能证据，不勾整项验收。

用户已手动试玩，截图证实卡框/费用/岩晶/中文说明显示，点击后上方出现点击通过。标题/类型缺失待修：独立Agent7838316仅把两短透明框高度升40、中心字号不变；主Agentv2候选已生成并静态检查0/0，附可见dt指标，尚未实机复验，不批产。详情PR30/docs/art/PIPELINE.md。

2026-10-23：用户v2截图证实完整单卡显示与点击，10秒客户端dt33.3/P9534.0ms（非GPU、无基线）。子门槛10.1.1 Done；25.1共享资产PR42、10.1.2容量PR43分别交付并复审，父Spike仍InProgress，场景/肖像/设备/多卡未通过。

2026-10-23 P0：暂停新技术研究与独立卡牌实验，复用既有工具推进完整游戏实机闭环；不因自动化失败继续无限排查焦点。

用户要求的本轮收口完成：PR30已合入develop ecb69b8，已完成单卡门槛10.1.1与共享资产制作25.1；已集成子PR25/26/27/42/43关闭，分支与工作树清理，截图/GIL/完整分支bundle保存在build/art-closeout-20261023。未实机项仍留待办，不继续本轮实验。
<!-- SECTION:NOTES:END -->
