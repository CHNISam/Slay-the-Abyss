# 独立复审

独立执行者：`/root/experiment_review`；源码提交：`89cc82d9`。评审覆盖实验运行时、布局、原生图装配、候选构建/读回和真实手牌Tween适配；执行者未修改源码、未操作客户端。

最终结论：当前评审范围内无未解决P1/P2，可提交独立实验Draft PR。此结论不包含官方动画、真实通信或设备性能验收。

已复现并关闭：

- 3D采样丢动画回执后退回2D却误报PASS。修复后原负对照得到 `valid=false / metrics=nil / pairValid=false`，没有PASS。
- UI读回错误比较整根布局和未处理原生默认值。现在使用既有精度合同，仅规范已核实的空children和minFontSize=20；完整实际UI读回相等，minFontSize=21及1像素差异继续拒绝。
- 头像底板残留、三敌人槽深度重叠、busy/missing_actor回执无谓等待。已修复，并保留HP、名称、意图和点击靶区。
- Tween在resize后、下一帧前的旧完成回调可写回旧目标。统一所有权验证后，八类状态先变再回调的负对照均取消且样本无效。最终 `card-tween.lua` SHA256为 `d7b7f28478350a64df2d8a138be8461962e7ac56b383c5c6b1bd2b81b2b0522c`。

独立动态验证还包括真实GameUI/Run八命令轨迹、卡牌B完整正式文本/真实出牌/旧UID拒绝，以及实际变换CardView注入完整GameUI后的A/B归位、普通重绘保持原生x、命中盒局部几何和迟到回调。

这些测试中的桥与Tween引擎为mock；只证明规则与所有权适配，不能替代当前GIL的官方导入、新ready与设备实测。
