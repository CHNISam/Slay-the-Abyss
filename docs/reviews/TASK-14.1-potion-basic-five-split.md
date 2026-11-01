# 五瓶药水测试按语义独立执行

基线 `0b34ca6aef4c95640166a1e3365f50d2935a7a8b`。CI40139999800中原药效夹具触发30秒预算，本片只拆分测试，不修改生产、数据、超时或任何药效预期。

| 独立夹具 | 原组号 | 语义 |
|---|---|---|
| `potion_basic_five.lua` | 1、11 | 五瓶真实库存预览/非首槽消费，非法目标/阶段/槽位/溢出原子性 |
| `potion_basic_five_draw.lua` | 2–6 | Swift抽3、手牌上限、空堆无疲劳、No Draw、源shuffle消费 |
| `potion_basic_five_status.lua` | 7–10 | Weak/Fear、Artifact、Ancient叠加、Thorns反击与不递归 |

三个进程各自建立原始fixture helper与prototype状态，没有选择性开关或按组过滤运行。11个原test块保留原始Git字节，包括所有循环、初始值、source ID和断言；原header/helper原文移到`support/potion_basic_five_fixture.lua`，只追加导出与计数结束标记。原acquisition夹具和JS中的定义检查/acquisition测试正文不变。

JS仍为原三项：定义检查、全部药效、获取轨迹。真实药效caller顺序执行三文件，要求三个独立marker分别为2、5、4且合计11；每个仍采用既有默认30秒。没有提高预算、减少种子/数据或跳过用例。字节证明与实际Node22结果见[机读证据](../rules/evidence/sts1-potion-basic-five-split.json)。

在父线授予的独占窗口，用`C:\Program Files\nodejs\node.exe`实际v22.22.1执行`--test tests/potion-basic-five.test.mjs`一次，3/3绿、0skip/0fail。三片分别10270、2642、5479毫秒；原acquisition JS项3755.679毫秒，总gate22296.973毫秒。均低于原30秒预算；这只证明本轮定向门禁，没有把分片合计误作单片预算，也不替代当前SHA完整CI。测试结束立即释放窗口，没有额外重跑。

没有完整套件、完整构建、GUI、push或merge；没有把独立Flex/Speed特性加入此修复。测试仅使用所需的原数据单模块生成，无新UI缓存生成。
