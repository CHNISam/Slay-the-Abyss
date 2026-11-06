---
id: TASK-74.17
title: 拆清GameUI构造生命周期并约束完整函数跨度
status: Done
assignee:
  - Furinya
created_date: '2026-11-04 22:58'
updated_date: '2026-11-06 01:47'
labels: []
milestone: m-7
dependencies: []
references:
  - docs/SPRINT_EXECUTION.md
documentation:
  - docs/backlog-details/M7-HOST-BATCH-20261105.md
parent_task_id: TASK-74
priority: medium
type: task
ordinal: 155000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
GameUI完整构造器跨度1004行，11处私有UI职责复杂度超过15；构造、输入和生命周期相互捕获，后续维护风险高。仅治理既有行为，保留批准UI及M8设备验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 入口文件不超过250行、M.new完整跨度不超过200行，其余函数含嵌套不超过150行；职责模块不超过1000行且全部函数与初始化块复杂度不超过15，当前采集可执行门禁拒绝缺测和超限
- [x] #2 完整旧新Host独立VM差分覆盖状态别名、随机、返回与异常、原生写入顺序、同步重入、双Host和陈旧输入；真实关键语义变异被拒绝，原历史来源验证每次新鲜且不放宽旧合同
- [x] #3 独立深审、精确HEAD与实际合入提交完整CI和原交付验证器通过，未实测设备边界保持未完成
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.认证78e4完整旧Host与历史来源并冻结独立oracle。2.按overlays/view/run/lifecycle/input五个静态职责模块拆分，在原位置安装方法，显式私有owner保持引用及动态查询。3.共享当前AST测量执行入口250/M.new200/其他150/模块1000及全域CC15门禁。4.真实旧新Host完整图/顺序/重入/双Host差分、原历史证明每调用新鲜验证及变异。5.独立深审、精确候选/原生队列/实际推送Full及原合后验收。

6.首轮Full历史来源组合出现CPU开销，先以同源原入口和profile核对新增GameUI配置identity判断；仅对确定不可能匹配的旧输入廉价拒绝或精确当前字节快判，保留每次7源重读、严格等价格式与全部漂移负例，独审及Full重验。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
入口182物理行、M.new151，其余最长109；全GameUI函数及初始化块CC15门禁通过。旧1004及11处热点真实拒绝，27项专项和独立41项/13探针通过，328模块5283测量完整。完整Host对照观察器正补齐原生代理与元表观测，AC2/3未勾。

完整旧新Host57个当前独立用例通过，112份当前VM证据全部成功、最长21.329秒，保留4份已退役宽窗。四个真实解析语义变异均检出，活动战斗cancel具名断言实际命中；旧新源码与历史关联读取独审通过。原既有回放并发三超时保留，隔离BAAB旧新4次输出一致且原三项隔离均过原30秒。当前精确Full及实际合后待，AC3不勾。

PR516首轮Full41958033163暴露旧入口源码断言与仓库内历史副本路径拒绝；原入口自动合并已暂停并读回。保留三份job日志，原数量断言迁到真实view并加安装调用链，全部GameUI模块保留禁止自动电影检查，两份测试7/7通过。路径修复与新候选Full待，不勾AC3。

原历史副本guard修复13专项与独审79输入/28次成功后暖漂移及缺reader反例通过；原event2入口和79543/79757两strict回放通过。profile确认同原event入口20057次旧配置重复解析，原8.221秒identity经保守缺key早拒绝降至0.101秒；每call7源重读及14/7/6读取trace不变，不缓存验证。原strict两回放本机254.180→122.167秒；托管Full与实际合后仍待。

来源97bb的Full41965082090为25成功/2失败/1预期skip，唯一测试失败Win1/14 job127041092812：旧Host seed6结果窗25至27执行done27后触及原30秒，另一失败为汇总；原入口已暂停并读回。原trace43822855bytes保留，单纯细分/直接写出均不作为fix。profile确认每帧187507节点822386字段，重复push proxy分配为热点；单call typed reference proxy复用prototype16.101秒且完整bytes/节点/字段同原，不缓存状态或跨call验证。新8VM及语义变异/独审进行中，预算与所有原窗口保持，AC3仍不勾。

最终保留原四result pairs与全部三checkpoint窗口，拒绝会漏暂不可达对象重现身份的split，真实反例加在原文件防回退。单observe引用代理复用不缓存字段/图/验证；原4pairs8VM全部通过、max17.227秒，353333166解码字节逐侧等原before；4parsed mutants真实kill/12VM成功，strength7及微测试/delta5通过。注册61case/112VM计划不变，只重跑具名切片，不称全61重跑；独立对照旧/新返回与WRITE实际6581bytes一致。原30s/32MiB/128MiB与full图保持，下一精确Full待，AC3不勾。

2026-11-06复核：PR516源码随PR520合入dedb9ed5，来源42057661663/队列42068824052/push42074603577完整Full通过；原merged_passed回执及最终独审已读回，详见M7-DELIVERY-20261106。设备边界未代验。
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Host职责拆分及绝对跨度门禁已随PR520交付；完整差分、真实变异、独立深审和精确三事件Full及原合后验证闭环。详见docs/backlog-details/M7-DELIVERY-20261106.md。
<!-- SECTION:FINAL_SUMMARY:END -->
