---
id: TASK-81
title: 按真实职责拆分战斗界面
status: Done
assignee:
  - '@codex'
created_date: '2026-10-28 15:40'
updated_date: '2026-10-28 15:57'
labels: []
dependencies: []
ordinal: 126000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
保留已合入正式设计、卡框、拖牌和失焦恢复行为，治理战斗界面巨大构造器。不得改规则或界面设计。技术边界与验证：docs/reviews/BATTLE-UI-REFACTOR.md。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 主文件不超过1000行，构造器不超过350行，提取模块无巨大共享闭包并纳入门禁
- [x] #2 现有真实UI和输入回归通过，原生控件与视觉及操作行为保持
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 从6fe3a6e2正式UI和输入修复基线隔离工作树。2. 按输入归属、目标选择、卡牌手势、控件绑定和渲染编排拆分，模块只收所需调用端口。3. 对全部Battle模块与函数加入行数门禁，保留复杂度门禁。4. 运行现有真实UI及输入回归和原生树差分，记录实机边界。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
已按真实职责拆成15个小模块；主文件254行、构造器199行、本轮最大函数250行。模块仅接收所需调用端口，装配结束一次性连接，去除热路径转发闭包。现有静态和原生控件正/负向门禁通过，无新增警告；目标输入专项仍在逐组验证。没有实机或导入。

验证：40份现有Lua战斗/输入/控制器回归均有通过记录；最终直接端口装配后check:engineering与45项专项通过，真实Battle预览所有原生树与基线逐项相同。原有30秒期限保留；超时组在同期限下独立复测通过，原基线也有超时。完整证据docs/reviews/BATTLE-UI-REFACTOR.json。

独立分支已重放到正式develop1f260a71，产品代码基线一致；rebase后13项严格源身份/体积/真实UI树差分再次通过。自动审批拒绝向origin推送，要求该目的地明确源码发布授权；本地交付完成，未创建PR/未运行远端CI。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Battle UI按15个真实职责模块拆分：主文件267行、构造器212行、最大提取函数254行。check:engineering与45项最终专项通过，40份现有Lua回归均有通过结果；真实UI树与基线逐项相同。JavaScript语法与现有失焦修复测试通过。未进行新副本导入或实机验收。
<!-- SECTION:FINAL_SUMMARY:END -->
