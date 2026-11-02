---
id: TASK-95
title: 对照验证美术、交互与动效设计工具
status: To Do
assignee:
  - Furinya
created_date: '2026-11-02 02:19'
labels:
  - design
  - technical-spike
dependencies: []
references:
  - docs/HANDOFF.md
  - experiments/art-tech-lab/README.md
  - 'https://ai.google.dev/gemini-api/docs/models'
  - 'https://help.figma.com/hc/en-us/articles/31722591905559-Figma-Make-FAQs'
priority: medium
type: spike
ordinal: 137000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
用户2026-11-02要求优先M4非美术、非交互设计工程；设计、美术与动效工具仍在实验，应先取得适用样品与结论，再做对应正式优化，不阻塞性能、稳定性、明确缺陷修复或现有方案验收。复用TASK-93已有独立样品、TASK-94图元/加载研究和TASK-10.1.2正式多卡容量验收，不重开同类技术实验。

用户反馈原样保留（用户报告，不作为官方效果结论）：「反正目前试了grok bot，不行。cursor这些更加不用想，gemini正在试，准确来说是在试google ai studio的gemini 3.8 flash，antigravity则还没有试，antigravity主要是用起来有点bug如果真要用也得处理一下，而且据我所知在google ai studio用的效果才是最好的，比如gemini 4 argon在ai studio才能充分发挥。然后就是open design可以试试，以及figma make。实践出真知」

当前Google AI Studio试用由用户进行，不是本任务已实测；Grok本轮不采用，Cursor本轮不投入，不扩为永久平台评价。候选为AI Studio、Figma Make、用户所指Open Design（具体项目待确认）及可用后再评估的Antigravity；无需强制遍历所有工具。Antigravity使用bug作为本任务内阻塞子项，不拆独立任务，也不串行阻塞其他候选。本文不授权登录、付费、安装、上传项目、用户桌面操作或正式接入。

正式采用范围：TASK-25新增/重做源美术；TASK-29.1新增动效方案；TASK-4.12神像成品与对话整体方案；TASK-4.13地图整体视觉交互新方案；TASK-4.16新信息架构。各混合任务内已知修复、批准稿还原、现成资产接线及现有方案试听/设备验收可继续。未来领取纯设计优化子任务时，须以本任务为正式依赖并明确适用结论；本任务整体Done不替代该方案Go。现有混合任务与M4父任务不新增泛化硬依赖。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 对选定候选使用相同需求、批准布局/资源、目标尺寸与代表性场景，对比美术清晰度、信息层级、交互反馈及动效；保存可追溯输入、版本/入口、产物与实际观察，未运行或排除项说明原因。
- [ ] #2 Antigravity阻塞子项记录实际症状、版本/环境、最小复现及修复后复验，或如实标记未获条件/不可用并给替代路线；不以猜测修复、无限重试或其他工具成功代替。
- [ ] #3 分别标识静态预览、可操作原型、Lua/平台可移植性和同候选官方/设备证据；网页或React原型不等于Lua可移植或游戏验收，不复用旧设备结果。
- [ ] #4 明确候选的素材许可、导出/编辑能力、实际账号与费用条件；Open Design身份先确认，需要登录、付费、安装或项目上传时停在授权边界。
- [ ] #5 交付按方案/场景划分的Go、No-Go或条件性结论及可复现样品，说明取舍与待验证项；仅打开工具或生成截图不能完成，用户认为AI Studio效果最好不替代对照证据。
- [ ] #6 将适用结论交给对应正式设计优化切片，并保留Owner确认与原有质量/容量/设备门槛；明确不适用范围和未解决问题，不把所有M4、性能bugfix、已有明确缺陷或现有方案验收串行阻塞。
<!-- AC:END -->
