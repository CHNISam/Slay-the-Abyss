---
id: TASK-25.2
title: 先做好一张完整样卡和荧的肖像
status: In Progress
assignee:
  - '@codex'
created_date: '2026-10-22 16:37'
updated_date: '2026-10-27 04:15'
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
priority: medium
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

2026-10-27 02:54 UTC Owner明确要求修复最新develop卡牌布局并提交PR：在fix/dot-approved-card-layout独立树恢复批准nameBand30/art64，文字兼容高度与背景分离，复用共享card-face覆盖战斗/奖励/牌库/商店；卡图占位保持明确，不拉伸144x34旧稿，不改规则。原生Agent负责最小产品修复和测试，dot根唯一Backlog/Git/PR写入者，负责前后预览与独立审查。先保留失败回归再修复，相关测试与当前SHA完整Quality分层记录；未经实机不宣称视觉验收。此前八张稿未获风格批准，不扩量。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-24真实尝试04377b7a在2秒、零步骤失败：无法把game窗口切到前台，无截图/日志，未完成官方导入。解除条件为可用桌面、同级权限且无窗口占用，先做权限与实际焦点预检，再基线到星陨剑，必要时B2；不重复同条件试玩，不把旧候选证据外推。正式装配由25、容量由10.1.2、总审阅由4承接，详见DELIVERY-CLOSEOUT。

2026-10-26：以 develop 4c75a31 为基线复核独立代码切片，范围仅 scripts/art/process-ai-samples.py 与 tests/test_card_art_assembly.py；拟用分支 feat/dot-card-art-assembly。当前 6/6 定向 Python 回归及 8/8 固定导出器边界检查通过，涵盖局部背景层序、几何/蒙版与当前主题卡框保留；未重新拟合、生图或运行完整美术导出。当前提交完整 Quality 尚待运行；官方导入、样卡视觉批准、中文显示、容量及设备验收仍未完成。保持现有任务状态和验收项，不作为 TASK-25.2 完成证据。

本切片执行者：dot；范围限于上述卡图装配代码修复、定向核验及独立 PR 准备。既有任务负责人字段不变。

本轮先后拒绝48图元粗拟合与积木式重绘，不作为量产标准。已修复真实MCP image.children拒绝及assembler输出别名覆盖风险；21定向JS/VM、6 Python及独立审查通过，当前HEAD完整CI、真实GIL/官方导入/手机性能未验。用户认为重剑相对合理，其余一般并要求源图对照，不能将此当风格批准。任务状态、负责人及AC未改变。

2026-10-26 dot 源图对照发现 Image Editor 最小尺寸归一化把部分原生细线放粗。隔离验证已恢复透支34高的19条作者笔宽，保持138图片+3蒙版，未改变颜色、构图或规则；当前仅修复资源精度与来源意图回归，尚待本分支审查/CI/合并。四卡视觉仍未获量产批准，官方XYZ显示及导入、手机性能均未验证；不扩大到剩余67张。

PR236 首轮完整CI被既有 phase_four_presentation.lua 的30秒超时阻断，其他分片与新增美术回归通过。独立复现后仅将原21组展示断言拆成4组真实UI矩阵与17组语义回归，保留原代码段、602种基础/升级渲染和历史哈希780875649；不改运行器、阈值、生产逻辑或其他执行者共享夹具。拆后两文件在原30秒预算内分别完成，后续仍以新HEAD完整CI及独立审查决定合并。

2026-10-26 dot 已向Owner交付招架还击/震慑敌阵两张新源变体的同窗口对照和离线评审包；它们仍是未批准实验候选，非八卡完成。此独立分支只保存两份34高JSON/Lua并扩充四card_id装配数据，复用已有裁切证明和装配器，不启用正式UI、不覆盖PR231等共享入口。实际原生图层143/166控件（不含宿主）；GIA严格像素等价未过，诊断文件不入库。后续以新HEAD完整CI与独立复审决定资源合并；剩余67张未启动，平台与动态接线验收仍缺。

2026-10-27 dot本轮布局代码切片：背景30/插图区64、透明名称/类型40；统一原生图库按源尺寸等比contain，占位仍40方形，旧144x34几何未拉伸或正式绑定。Owner已明确同意仅六个溢出升级后缀移到现有type行，完整牌名/绿色保留。组件及跨屏定向、2538标题变体、602实际渲染、静态/架构与独立审查已通过。完整本地npm check正在收尾，已发现ci-downloads真实PowerShell用例因Linux未安装pwsh失败，不改无关测试或冒充等价通过；正常PR当前SHA的GitHub Quality继续实际验证。未官方导入、未写存档/实机，视觉验收不勾选。

PR240首候选f7fc855已发布。完整本地Node终态1594通过/1失败/零跳过，唯一失败已确认spawnSync pwsh ENOENT；后续完整阶段未运行，不以旧切片PASS冒充。发布时develop刚合入PR232至fc51f198，现保留全部上游事件/节点改动并同步；唯一冲突静态baseline依最新106历史警告重新精确核对17条源行/声明行迁移，零新增豁免。新组合的相关回归及精确SHA完整CI继续收口。

同步fc51f198后的51项定向全部通过；新增上游3份NodeUI测试fixture原缺SetSizeDelta导致7项失败，现仅补与平台一致的严格数值记录方法，原断言不变，失败和通过均保留。2538标题、178旧文案、四屏/卡图回归、143模块705边架构与106历史警告静态检查通过；相对最新develop仅本切片18文件。前后布局和八张占位卡面离线图已交Owner，不等于正式插画/实机验收。

51999448完整Quality40444817317的四个Windows Lua分片失败，原因是三份旧独立NodeUI mock缺SetSizeDelta；已复现10入口全红，并仅补严格API记录后10入口75组全绿，新增删除API必失败负控且optional-method变异被原断言捕获。随后同步develop e25a0d6的手柄/地图改动，保留全部上游逻辑；通过纯续行格式保持原警告行位，luacheck-baseline现与最新develop原字节一致。e25组合52项JS/事件和18个Lua定向入口已通过，静态106历史/零新增、架构144模块713边通过。旧499入口全Lua因新base停止，仅33入口完成，明确未作全量通过；最终完整CI仍待新精确SHA。
<!-- SECTION:NOTES:END -->
