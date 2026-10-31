---
id: TASK-25.3
title: 制作并实测精修怪物与Boss样本
status: In Progress
assignee:
  - '@Furinya'
created_date: '2026-10-27 09:48'
updated_date: '2026-10-31 08:38'
due_date: '2026-10-28'
labels: []
milestone: m-5
dependencies: []
parent_task_id: TASK-25
priority: medium
ordinal: 119000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
在真实游戏中验证精修普通怪与Boss的原生美术质量、可用性与真机负载；验证通过再按实际敌人清单分批制作。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 实际战斗中核对两种样本的轮廓辨识、动作、攻击受击显示、生命与意图控件分层。
- [ ] #2 PC与安卓真实设备对照基线、多敌同屏及反复开战和结束清理，确认性能和视觉质量后才放行敌人类别的批量生产。
- [ ] #3 样本文件对应敌人ID，出处和授权可追溯，不复制社区反编译源码中的原作美术。
- [ ] #4 按现有敌人ID和造型规范制作窃金客（looter）和深渊守卫（guardian）的原生精修候选；不以离线PNG冒充可用资源。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 依Owner夜间授权整理当前第一、二幕审计42ID的真实源图与完整提示词来源，仅纳入独立审阅通过项，明确缺口。2. 按源图逐路径Git LFS交付，保留真实contain小图和来源哈希，不绑定运行时、不放行原生批产。3. 完成源码/许可/工程与完整CI及独立审查；原生质量、官方导入、PC/安卓多敌负载和清理门槛保持未验收。

2026-10-30 身份纠正切片：保留旧41张历史源图并标明方向已被取代；另存4张已接受的原神敌人源图基准、提示词和来源，仅记录源图方向认可；不改玩法或运行时绑定。补齐逐路径LFS、许可目录与专项回归，提交draft PR，原生及真机验收仍待办。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮为离线源图Git交付，不关闭原生与设备验收。审计名册42项；当前40项独立源图通过，磐核守卫中断后的一次恢复结果正在独立复核，壳寄生虫输出审核阻断且无源图、不重试。所有验收项继续未勾选。

最终离线交付：42ID名册中41项真实源图独立审阅通过；磐核守卫为一次中断未知输出后获准的唯一恢复（第2次），不称首轮成功；壳寄生虫输出审核阻断，无源图且不重试。目录与来源见art/monsters/README.md、catalog.json；原生失败草稿未入库。源图不绑定运行时，Owner/原生/设备/负载批准仍为false。

本地交付验证：41源图完整SHA/尺寸/字节与真实contain像素核对；35项怪物/旅行者/已审阅资产/LFS/许可专项通过；完整许可inventory、guidance、Backlog、平台日常负载及engineering通过。全部原生/Owner/运行时/设备批准仍false，完整托管Quality/Licenses与独立审查待PR当前SHA完成。

2026-10-30 Owner最新调整：后续怪物源图制作与原生精修延期，优先把已经可用的原生资产用于本轮人工真机测试，不让PNG源图或继续美术优化阻塞测试。4张已接受源图仅保存方向与方法，生成提示词、真实身份参考/画风参考边界、完整画布小图和原始字节保留见art/monster-benchmarks/genshin-v1；不因此启用运行时。任务保持进行中，原生与真机验收未完成，不标Done。

2026-10-31 Owner确认完整怪物统一自绘放到下版本，已创建TASK-94 Low/To Do，记录18套对应19ID、其余23ID缺口及旧41稿不得当可用品。当前优先发版，本轮不启动新增怪物绘制或扩大装配；本任务样本/设备历史和未勾AC保留。
<!-- SECTION:NOTES:END -->
