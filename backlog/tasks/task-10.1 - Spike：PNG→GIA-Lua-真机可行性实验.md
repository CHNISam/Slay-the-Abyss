---
id: TASK-10.1
title: Spike：PNG→GIA/Lua 真机可行性实验
status: In Progress
assignee:
  - '@codex'
created_date: '2026-10-22 15:57'
updated_date: '2026-10-22 22:29'
labels:
  - technical-spike
dependencies: []
parent_task_id: TASK-10
type: spike
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
独立验证 PNG 图像经 GIA/Lua 路径在千星客户端实际显示的可行性，为首发视觉资产规格提供证据。关联 TASK-4 的多设备验收、TASK-10 的战斗 UI 与 TASK-24 的原型美术工作（已合入的 PR #19 界面设计与原型）；不承担正式美术制作，不以生成文件或编译成功冒充真机通过。
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

用户已手动导入卡牌候选：已读回ART_Spike、ART_Card、ART_Probe及5个静态宿主/探针控件，两个external_lua_file源码与候选匹配，静态检查0错误0警告；官方导入门槛已过。18秒当前存档试玩8fd0a901/f891c7e9均在开始前报无法把窗口切到前台sandbox。现成窗口工具一次聚焦成功后也FOCUS_FAILED，停止重复尝试；已请求用户手动进入试玩。显示/点击/dt/多设备未验收，原任务保持In Progress。

新增实机证据：用户进入试玩截图UfuVVv（SHA8c264f3c...）确认卡框/费用1/岩晶/中文伤害说明可见，但标题打击和类型攻击缺失；点击后截图d70MTN（SHA793a0d9d...）上方已显示点击通过，点击事件及原生文本更新通过。editor Agent提交7838316最小兼容候选，仅两个透明框h22/h18→40，中心/字号不改；3项差异回归、Fengari15控件通过。主Agent已生成abyss-art-card-text-v2.gil，静态0错误0警告；增加可见Metrics回调dt，数值尚未实测。v2待复验，性能/多设备/场景仍未验收，不放行批产。

2026-10-23：用户v2实机两张截图确认完整单卡显示与点击，10秒客户端dt均值33.3/P9534.0ms（非GPU、无基线）。子门槛TASK-10.1.1已Done，TASK-25.1小套共享资产制作与TASK-10.1.2容量样本独立Agent启动；父Spike仍InProgress，场景/肖像/设备/多卡未通过。

集成最新develop时保留TASK-24关联与本分支实机记录；新增共享资产PR42和容量PR43均已独立复审，容量P2旧索引问题已修正。五份实际MCP副本静态0/0，官方试玩待测。
<!-- SECTION:NOTES:END -->
