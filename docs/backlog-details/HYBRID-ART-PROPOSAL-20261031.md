# PR410原提案存证

来源：PR410，固定头`800521062323c3ecaf466d9ef4955f71998a8329`。以下原文仅保留当时M3/M4提案和技术证据；当前处理见[规划收口](PLANNING-CONSOLIDATION-20261031.md)，不恢复旧排期或实施计划。

```markdown
---
id: TASK-94
title: 验证自适应混合图元与无感加载
status: To Do
assignee:
  - Furinya
created_date: '2026-10-31 12:29'
updated_date: '2026-10-31 12:29'
labels:
  - art
  - technical-spike
milestone: m-4
dependencies: []
references:
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/397'
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/390'
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/392'
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/400'
  - docs/art/art-pressure-results.md
  - docs/art/READY_ASSET_INTEGRATION.md
  - experiments/art-tech-lab/README.md
priority: medium
type: spike
ordinal: 132000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
M3 独立技术突破实验：在千星奇域真实平台限制下，寻找同等画质更少控件、加载更快、连续出牌无美术重建的可复用方案；结论供 M4 改善选角大立绘、战斗角色和背景、卡牌插画及轻量动画。承接未合的 PR #397（规划）、#390（三角面片）、#400（低多边形集成尝试），复用已合 PR #392 / TASK-93 的低成本样品、现有矩形 compact/budget 与官方图库。**这是实验和 Go/No-Go，不是当前 Alpha/Beta 或参赛发版的阻塞依赖，也不直接启用大量自绘图元。**
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 选同源的真实背景、荧立绘/战斗形象和卡牌插画（含多卡），固定源图、分辨率、显示尺寸和透明底；复用现有最好矩形 compact/budget 基线，比较纯矩形、PR #390 三角和候选混合，提供原图/各方案的可审阅截图，保护人物辨识度和重要细节。
- [ ] #2 研究并尽量复用成熟算法：矩形合并/自适应分割、Delaunay 三角、Geometrize/Primitive/WASM 椭圆或旋转图元、Alpha 叠层、必要的局部修正及 LOD；核对实际源码/许可证和平台是否可表达。未证实的「1600 椭圆省 60%+」不当成结论；不为不支持的贝塞尔/SDF 增加复杂运行时。
- [ ] #3 交付可复现的同画质 A/B/C：记录视觉质量与误差、边缘/人脸细节、控件与容器数、离线生成成本、数据/包体、透明与接缝问题。优化目标是画质和真实平台开销的权衡，绝不将 13201/361 或 4315/2010 的不同图对比冒充加速倍数。
- [ ] #4 用现有模拟器→官方 GIA/编辑器→同候选 PC 与实体安卓逐层验证：旋转（特别是 rotX/rotY）、Alpha、层序、创建/首次可见/缓存再进、动态帧耗时 P95/P99、峰值控件/内存及官方容量；标清每份证据的来源、候选 SHA 和缺项，未实机不得宣称性能通过。
- [ ] #5 验证运行时无感交互：预加载、有界缓存、复用控件池、低/高 LOD 和父容器动画；在 1/5/10 手牌、连续抽/拖/出/销毁及选角/战斗切换中，已就绪插画不因每次出牌被整幅销毁重建；记录生命周期、回退、内存和实际交互卡顿，不能以无界常驻控件换速度。
- [ ] #6 M3 给出可运行样品、复现实验、优势/失败和明确 Go/No-Go；背景冷载 <1 秒、缓存切换 <100ms、理想 60 FPS / 兼容 30 FPS 只是研发目标。只有经用户批准、同源画质及官方手机证据支持，M4 才考虑迁移正式资源，不默认替代官方原生场景/图集。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 查重和复用 TASK-93、PR #390/#392/#400 的有效资产、脚本、模拟器、压力测试与现有最优矩形压缩；旧 PR 已关闭不代表研究数据消失，按具体提交恢复，不重新制作同一探针。
2. 独立实验中先用成熟实现构造纯矩形/纯三角/混合候选，测试椭圆/透明形状的实际平台成本；离线计算图元，运行时不实时拟合图片。不强制混合胜出，不引入大型新框架。
3. 先做同图同质量对照，再验证官方导入/手机性能；同时对原有卡牌运行时试验有界缓存、父容器动画和重复出牌不重建。各 Agent 按现有 PR/Backlog 协作，独立小切片，避免多人修改同一文件。
4. 根据证据给出 M4 采用/继续研究/放弃建议。接入责任继续由 TASK-25/25.2、TASK-4/4.2、TASK-10.1.2/38/42 承担；不改玩法、正式发布配置、既有 AC、UI 审批或官方平台门禁。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-10-31 主线核对：PR #397/#390/#400 均已关闭但未合并；PR #392 已合并且 TASK-93 仍在研。#390 的三角面片 / 3993 节点模拟器数据，不等于官方真实 FPS；#392 的 103 控件原生图库方案与精品插画不是同一画质。M4 原定官方原生战斗场景优先决策保持，只有本实验同源、同设备证据支持才提请改判；本任务不影响当前发行节奏。
<!-- SECTION:NOTES:END -->

```
