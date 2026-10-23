---
id: TASK-39
title: 拒绝空文件或目录冒充验收截图
status: In Progress
assignee:
  - '@dot'
created_date: '2026-10-23 12:55'
updated_date: '2026-10-23 13:00'
labels: []
milestone: m-5
dependencies: []
references:
  - scripts/verify-ui-acceptance.mjs
  - docs/design/ui-acceptance.json
priority: high
type: bug
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
现有UI验收脚本只检查路径存在，目录或零字节文件也能被当成参考图与实机截图。只修已有证据文件校验，不新建验收体系，不将合成测试夹具当游戏验收。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 参考图与实机截图必须是非空普通文件，目录、空文件、缺失或无法取得文件信息的路径被拒绝。
- [ ] #2 有效文件、已有关键检查项及可注入测试接口保持兼容，CLI错误退出且不给出通过结论。
- [ ] #3 新增真实文件负例先红后绿，独立评审及当前SHA相关CI通过；不改变TASK19/24归属或平台验收状态。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 固定最新源码构造本地无害负例，确认CLI错误接受目录。2. 最小增加普通文件与非空校验，保留既有接口。3. 跑Node内建测试、CLI正负控与独立复审，按正常PR/CI集成。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
真实文件负例最终基线3过6败，候选9/9通过；CLI目录冒充截图由错误exit0改为exit1。默认校验要求普通、非空、可读文件，单字节读取且finally关闭，保留可注入谓词与全部关键检查。独立207项API/CLI矩阵通过；22次证据检查仅读22字节，故障注入后描述符全部关闭。主线验收manifest未改，仍拒绝11个pending/partial画面。未运行被拒绝的本地npm全量检查、未安装依赖；等正式当前SHA CI。不是图片内容/来源真实性校验，也不是游戏验收通过。
<!-- SECTION:NOTES:END -->
