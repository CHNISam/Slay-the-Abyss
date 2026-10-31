---
id: TASK-94
title: 验证自适应混合图元与无感加载
status: To Do
assignee:
  - Furinya
created_date: '2026-10-31 10:47'
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
