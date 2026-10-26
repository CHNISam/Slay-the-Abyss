---
id: TASK-25.2
title: 先做好一张完整样卡和荧的肖像
status: In Progress
assignee:
  - '@codex'
created_date: '2026-10-22 16:37'
updated_date: '2026-10-26 18:01'
due_date: '2026-10-28'
labels:
  - art
  - launch
milestone: m-5
dependencies:
  - TASK-10.1
references:
  - docs/experiments/art-portrait/README.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/49'
  - docs/art/CARD_SHARED_ASSETS.md
  - docs/art/AI_ART_SAMPLES.md
  - docs/backlog-details/TASK-25.2.md
  - docs/DELIVERY-CLOSEOUT.md
parent_task_id: TASK-25
type: task
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
沿用已批准的岩金色、深色和卡框样式，先精修一张完整样卡。荧的肖像也继续验证，暂不批量做新卡图。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 荧的肖像方案经批准并在游戏里显示；存在溢出问题的方案不能批量用。
- [ ] #2 素材来源清楚，每张肖像或卡图对应正确内容，缺图不能装作已齐。
- [ ] #3 手机和主机上文字可读、显示负担可接受，交付经过审查。
- [ ] #4 一张完整样卡先通过你审阅：主体清楚、中文可读、缩放正常，没有明显接缝和溢出。
- [ ] #5 实际比较加载速度和流畅度，反复进出检查清理，说明为什么这个成本可接受。
- [ ] #6 样卡质量、游戏显示、多卡长文和设备测试通过后，才决定批量制作。
- [ ] #7 本任务负责人把获准单样卡和肖像接入完整游戏独立候选，交TASK-25及10.1.2完成正式装配和容量复验；高控件方案未获性能证据不得启用。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
在 feat/dot-card-art-assembly 独立分支仅纳入卡图装配函数修复与定向测试；保留既有主题、卡框及素材，先复核局部背景层序，再通过当前提交完整 Quality，原生视觉与容量验收另行完成。

2026-10-26 Owner授权首批8卡、确认后才考虑其余67张；dot在独立云副本继续逐处精修，先交重剑/整备/透支/磐岩四张视觉评审，未获风格批准。技术切片选择重剑与透支两张144x34真实精修资源，opt-in共享原生控件池，现有Combat/CardDisplay驱动文本；正式主题和默认外观不变，补真实MCP层级/XYZ/输入回归，不改规则或他人文件。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24真实尝试04377b7a在2秒、零步骤失败：无法把game窗口切到前台，无截图/日志，未完成官方导入。解除条件为可用桌面、同级权限且无窗口占用，先做权限与实际焦点预检，再基线到星陨剑，必要时B2；不重复同条件试玩，不把旧候选证据外推。正式装配由25、容量由10.1.2、总审阅由4承接，详见DELIVERY-CLOSEOUT。

2026-10-26：以 develop 4c75a31 为基线复核独立代码切片，范围仅 scripts/art/process-ai-samples.py 与 tests/test_card_art_assembly.py；拟用分支 feat/dot-card-art-assembly。当前 6/6 定向 Python 回归及 8/8 固定导出器边界检查通过，涵盖局部背景层序、几何/蒙版与当前主题卡框保留；未重新拟合、生图或运行完整美术导出。当前提交完整 Quality 尚待运行；官方导入、样卡视觉批准、中文显示、容量及设备验收仍未完成。保持现有任务状态和验收项，不作为 TASK-25.2 完成证据。

本切片执行者：dot；范围限于上述卡图装配代码修复、定向核验及独立 PR 准备。既有任务负责人字段不变。

本轮先后拒绝48图元粗拟合与积木式重绘，不作为量产标准。已修复真实MCP image.children拒绝及assembler输出别名覆盖风险；21定向JS/VM、6 Python及独立审查通过，当前HEAD完整CI、真实GIL/官方导入/手机性能未验。用户认为重剑相对合理，其余一般并要求源图对照，不能将此当风格批准。任务状态、负责人及AC未改变。

2026-10-26 dot 源图对照发现 Image Editor 最小尺寸归一化把部分原生细线放粗。隔离验证已恢复透支34高的19条作者笔宽，保持138图片+3蒙版，未改变颜色、构图或规则；当前仅修复资源精度与来源意图回归，尚待本分支审查/CI/合并。四卡视觉仍未获量产批准，官方XYZ显示及导入、手机性能均未验证；不扩大到剩余67张。
<!-- SECTION:NOTES:END -->
