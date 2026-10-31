---
id: TASK-94
title: 下版本补齐并统一两幕怪物自绘资源
status: To Do
assignee:
  - Furinya
created_date: '2026-10-31 08:37'
labels:
  - next-version
  - art
dependencies: []
references:
  - art/monsters/README.md
  - data/presentation/native-monster-art.json
  - docs/backlog-details/PLAYTEST-20261030.md
priority: low
type: enhancement
ordinal: 132000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Owner于2026-10-31决定本版优先稳定发版，完整统一怪物自绘延期至下版本。当前两幕名册42个敌人ID，原神身份方向18套原生资产对应19个ID，另23个未有该方向可直接接入的资产；候选现仅准入草史莱姆r02。41张旧原创造型已被否定，保留历史但不能计入可用资源。后续不得把官方图库和自绘混装当作统一资源完成。与TASK-25.3样本验收、TASK-25.5既有资产接入衔接，不阻塞本版发布，不擅自恢复旧稿。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 逐项核对两幕42个敌人ID的自绘资源映射、来源、身份与实际可用状态；缺项明确列出，不能用旧弃稿充数
- [ ] #2 同一候选统一使用经确认的自绘怪物资源，不静默回退官方怪物图标；自动检查能拒绝漏绑定和混用
- [ ] #3 最终同候选完成实际装配读回、官方导入ready、PC与实体手机多怪显示及负载和清理验收，未验证项保持未完成
<!-- AC:END -->
