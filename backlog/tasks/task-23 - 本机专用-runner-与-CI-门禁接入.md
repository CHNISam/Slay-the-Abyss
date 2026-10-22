---
id: TASK-23
title: 本机专用 runner 与 CI 门禁接入
status: In Progress
assignee:
  - '@Codex'
created_date: '2026-10-22 14:36'
updated_date: '2026-10-22 15:06'
labels: []
dependencies: []
ordinal: 23000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户要求本机为 Slay-the-Abyss 独立运行 GitHub Actions，并让测试与代码规范持续执行。现有 PR #1 提供待整合的数据门禁，其他项目 runner 必须保持独立。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 专用 Windows 服务自动启动且 GitHub runner 在线
- [ ] #2 PR 与 develop/master 推送执行语法、测试、数据校验并实跑成功
- [ ] #3 记录维护命令、分支门禁与发布边界
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1.复用并核查 PR #1 门禁。2.独立安装和注册专用 runner。3.接入 Actions 并实跑。4.文档和 PR 交付。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本地 npm run check：48/48、语法、完整内容数据通过。专用服务已 Running/Auto/Network Service，runner 在线。最新官方包下载过慢，改为仅复制既有官方 2.337.0 的 bin/externals/启动程序，未复制凭据或工作目录，新 token 独立注册，保留自动更新。首跑因直连 Actions 下载/TLS 超时失败；确认 runner 空闲后，仅为新 runner 配置本机 Clash 7897 代理并重启，第二次执行中。GitHub 分支保护 API 403：当前私有仓库套餐不支持，未改套餐或公开仓库。草稿 PR #4。

整合 develop 已合入的 PR #1/#6，保留其成果。真实执行定位 Windows 服务 PATH 无 bash，已改原生 PowerShell；job defaults 使用 github 上下文选择 shell，GitHub 已成功解析。新增 Python 文案测试在 Windows 因符号链接权限失败，安排零依赖 Ubuntu presentation 作业跑完整10项，避免提升服务权限。
<!-- SECTION:NOTES:END -->
