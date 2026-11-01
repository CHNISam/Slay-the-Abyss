---
id: TASK-94
title: 验证自适应混合图元与无感加载
status: In Progress
assignee:
  - Furinya
created_date: '2026-10-31 10:47'
updated_date: '2026-11-01 15:00'
labels:
  - art
  - technical-spike
  - competition-deferred
dependencies: []
references:
  - docs/backlog-details/PLANNING-CONSOLIDATION-20261031.md
  - 'https://github.com/CHNISam/Slay-the-Abyss/pull/410'
  - experiments/art-tech-lab/README.md
priority: medium
type: spike
ordinal: 134000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
保留PR397/410独立实验意图，复用TASK-93及PR390/392/400。当前停止底图优化并准备发行，本实验延期，不占比赛M3/M4，不新增日期；未来另获授权后再评估条件接入，不默认启用图元。
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 固定真实背景、荧角色和卡图的同源同画质条件，对比最好矩形compact/budget、三角与成熟混合图元，记录截图、控件、体积和生成成本。
- [ ] #2 核对成熟算法许可和平台表达边界；不同画面节点数及未经证实的椭圆节省比例不能当加速结论。
- [ ] #3 官方GIA、同候选PC和实体安卓分别记录创建、缓存切换、P95/P99、内存及官方负载；模拟器结果不冒充实机。
- [ ] #4 验证1/5/10手牌连续交互不整幅重建，缓存有界、生命周期和回退可复现。
- [ ] #5 交付可运行样品与Go/No-Go；冷载1秒、缓存100ms、60/30FPS仅目标，正式接入需证据及Owner批准并交既有品质任务。
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
2026-11-01 用户重新授权：仅重启离线同源基线审计小切片，复用现有 rectangles 与 compact 数据，对真实三张卡输出重建图、误差、数据身份和生成成本。算法研究不阻塞其他 M4；保留完整未来实验范围，正式接入仍另需批准。父级完整 AC 本轮不勾选。
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
本轮范围不含新拟合引擎、大 benchmark、官方导入、设备性能或生产接入；背景源预览在当前工作树为 LFS 指针，明确拒绝作为图片输入。

离线审计结果见 experiments/art-tech-lab/baseline-audit/README.md、results/comparison.png 与 results/results.json：strike/defend/bash 同源 144×64，918/835/916 矩形，既有 compact 编码逐字节复现；MAE 15.408/12.847/14.077，PSNR 19.927/20.949/20.653dB。已查看实际对照图，compact 明显丢失细节，不称同画质胜出。5项定向测试通过，含确定性、LFS指针/非法输入拒绝与已知误差校验。只是离线生成成本，不是官方加载/FPS。完整仓库CI、官方GIA、设备及混合算法未验证；父级AC保持未勾，待独审。
<!-- SECTION:NOTES:END -->
