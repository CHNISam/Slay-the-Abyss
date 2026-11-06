---
id: TASK-75.7
title: 降低完整回滚快照的表分配开销
status: In Progress
assignee:
  - Furinya
created_date: '2026-11-06 06:56'
updated_date: '2026-11-06 06:56'
labels: []
milestone: m-7
dependencies: []
parent_task_id: TASK-75
priority: medium
type: enhancement
ordinal: 162000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
托管Jaw Worm完整尾段触及原30秒aggregate；本轮画像Snapshot.capture约占81%，守卫减冗余仅约1.8%整体收益。Owner已批准完整图扁平快照设计，目标减少内部容器分配而保持全部回滚语义，禁止裁剪状态、缓存旧快照或放宽预算。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定原Snapshot完整源码oracle，旧新完整原图、别名、环、table-key、falsy值、返回错误和owner单次生命周期等价，真实语义负控检出
- [ ] #2 每次仍捕获全部可达raw图，不排除子树或复用旧许可；仅内部键值缓冲与表边界改变，原公开API和原表恢复保持
- [ ] #3 同环境前后配对保留全部384轮16种子及rollback，完整轨迹与输入身份一致；保留失败及较慢样本，有实测净收益才采用
- [ ] #4 独立深审、当前精确HEAD原Full与队列及合后验证通过，原30秒/2worker/输出预算及有效回归保持
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
按Owner批准先记录设计与独立旧源码身份，建立完整raw图和owner合同及负控；实现扁平键值缓冲与表边界，只改变私有表示。配对真实Jaw尾段和完整回滚轨迹、相关事务回归，维护历史来源精确逆投影；独立深审后按原门禁集成。
<!-- SECTION:PLAN:END -->
