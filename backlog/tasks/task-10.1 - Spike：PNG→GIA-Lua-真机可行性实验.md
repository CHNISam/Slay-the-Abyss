---
id: TASK-10.1
title: Spike：PNG→GIA/Lua 真机可行性实验
status: To Do
assignee: []
created_date: '2026-10-22 15:57'
updated_date: '2026-10-22 22:21'
labels:
  - technical-spike
  - queued-after-M3
milestone: m-5
dependencies: []
parent_task_id: TASK-10
type: spike
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
独立验证 PNG 图像经 GIA/Lua 路径在千星客户端实际显示的可行性，为首发视觉资产规格提供证据。关联 TASK-4 的多设备验收、TASK-10 的战斗 UI 与 TASK-24 的原型美术工作（已合入的 [PR #19 界面设计与原型](https://github.com/CHNISam/Slay-the-Abyss/pull/19)）；不承担正式美术制作，不以生成文件或编译成功冒充真机通过。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 记录最小样例输入、GIA/Lua 路径、工具版本及图像尺寸/透明度/容量等平台限制，失败也有可复现证据
- [ ] #2 分别记录编译、写入存档副本、真机显示和交互验证结果及截图；保持 MILIASTRA_ALLOW_LIVE_WRITE=0，发布由人完成
- [ ] #3 给出可行或不可行结论、手机与主机适配风险、正式美术可用规格及不可行时的降级方案
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
美术技术探针属于M4发布表现前置，不阻塞M1基础C档操作；现有PR25/26/27/30/42/43及根工作区未提交子任务均保留，不把未合并成果计为交付。
<!-- SECTION:NOTES:END -->
