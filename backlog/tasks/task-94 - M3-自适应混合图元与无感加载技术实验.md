---
id: TASK-94
title: M3自适应混合图元与无感加载技术实验
status: To Do
assignee:
  - Furinya
created_date: '2026-10-31 06:21'
updated_date: '2026-10-31 06:21'
labels:
  - art
  - technical-spike
milestone: m-4
dependencies: []
references:
  - docs/art/art-pressure-results.md
  - docs/art/READY_ASSET_INTEGRATION.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/390'
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/379'
priority: medium
type: spike
ordinal: 132000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
M3 独立验证「同等观感下更少图元、更快加载、连续出牌无美术重建」是否可行，为 M4 的开场/选角立绘、战斗背景/角色、卡牌插画与轻量分层动画提供有证据的技术路线。优先复用既有矩形转换器、TASK-93 的样品、PR #390 的 Delaunay 三角面片和官方图库；候选包含 Geometrize / Primitive 的椭圆、旋转矩形、透明叠层与自适应混合近似。只做实验和 Go/No-Go，不改正式游戏、发版资源、玩法数值或 M4 已定的官方原生场景优先策略；不阻塞当前 Beta 候选冻结。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 同源 A/B/C：至少覆盖一张背景、一张战斗角色图和一张卡牌插画，固定输入、显示尺寸、透明底/合成方式及画质要求，比较现有矩形、PR #390 三角和混合候选；保存可重放参数、预览及人物/文字辨识度人工评审。
- [ ] #2 量化每档方案的实际控件/图元数、生成耗时、数据/候选体积、画质误差和关键细节；记录图元减少与视觉失真取舍，不把不同图片的 13201/361、4315/2010 数量比当性能倍数。
- [ ] #3 复核 Geometrize、Primitive、WASM 版本的实际代码、许可与输出；测试椭圆/旋转椭圆、矩形、三角及 Alpha/层序和必要的后处理。网上「1600 椭圆比三角省料 60%+」仅作为待复测说法，不写成结论；曲线/SDF 等平台不支持的形状先排除。
- [ ] #4 用既有模拟器、官方导入/读回及同候选 PC/实体手机测试，区分 Lua 更新、控件创建、首次可见、缓存切换与真实帧耗时/P95/P99；核对三角 rotX/rotY、透明度、重叠接缝、设备负载及包体。若无法导入或实测，给出可复现阻碍，禁止宣称通过。
- [ ] #5 验证连续抽/拖/出/销毁卡牌和选角/战斗资源切换：已就绪资源不因单次出牌重新构造整幅插画；试验有界缓存、预加载、容器动画及低/高 LOD，记录 1/5/10 卡高负载和错误清理；不靠无限常驻控件换取速度。
- [ ] #6 M3 产出包含同画质对照、可复现源码/候选、风险及 Go/No-Go 的技术结论，明确 M4 的可采纳环节和前置条件；冷载 <1s、缓存切换 <100ms、理想 60FPS/兼容 30FPS 只是目标，不因离线结果或模拟器 0.1–1.2ms 断言已经达成。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. 复用 TASK-93、PR #390 与当前矩形压缩和性能基线；调查 Geometrize/Primitive/WASM 成熟实现，确认开源许可及千星图片图元实际可表达能力，不引入大型框架。
2. 在隔离样品上先跑纯矩形、纯三角、自适应混合；椭圆/透明叠层作为可选候选，用统一误差与实际控件成本选优。离线计算可复杂，游戏运行时不做像素求解/三角剖分；对多尺寸提供按需 LOD。
3. 先验证官方 GIA 与 rotX/rotY/Alpha 兼容，再对同源冷启动、复进、静态背景、战斗卡牌连续交互及分层角色动画做模拟器→PC→安卓分级取证；每个结果标明设备、构建 SHA、创建预算和时间口径。
4. M3 只给出可证伪研究结论；通过后由 M4 的 TASK-25/25.2（角色/卡面）、TASK-4/4.2（开场/战斗场景）、TASK-10.1.2/38/42（容量与设备）分工接入和验收。官方原生资源仍是默认回退，不新增版本发布依赖。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
成熟参考：https://github.com/fogleman/primitive 、https://github.com/Tw1ddle/geometrize-haxe 、https://github.com/taiseiue/primitive-playground （WASM/透明组合）；原项目与派生项目分别核验许可证和实际可移植代码。已知原生图元/控件成本与 GPU 绘制调用不同，父容器只降低逐帧 Lua 更新，不能证明整场景真实渲染快。PR #390 是独立三角实验，TASK-93 是初步低成本样品；本项专门研究跨资源混合压缩和无感运行生命周期，避免重做两者。
<!-- SECTION:NOTES:END -->
