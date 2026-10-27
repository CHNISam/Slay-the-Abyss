# PR238 五瓶药水最终预算分片

基线 `28869011c26bcead7f925e78f00dbda454daa231`。父线程保存的该提交 CI 中，原 `potion_basic_five.lua` 30111ms超时，仅完成第一逻辑组。因此旧本地23597ms和图比较优化不能当作最终云端预算通过。

本片只拆测试：原第一组五瓶保持单文件；原第二组的拒绝路径按 Swift/Weak 两瓶、Fear/Ancient/Liquid Bronze 三瓶、四个 overflow 组合分为三文件。不是把第二大组整块搬走。每个文件继续使用原默认30000ms，生产、数据、双向图比较、原型缓存、种子、瓶数和全部断言不改。

[覆盖锁](../../tests/fixtures/potion-basic-five-budget.json)固定原288690三个循环正文 SHA256、绑定、全部输入和其它三份原fixture/完整helper SHA256。新增JS门禁比较实际文件正文，检查原五瓶正常路径、原五瓶拒绝路径和四个溢出组合各一次、拒绝分片大小恰为2与3。正文中的 slot、target、phase、逃跑/死亡、overflow、整Run及关键表身份断言逐字节保留。原 draw/status/acquisition 文件与双向helper逐字节不变。

| 原逻辑 / 文件 | 独立逐片ms | 最终整JS中的ms |
|---|---:|---:|
| 第一组五瓶 / `potion_basic_five.lua` | 19276 | 13665 |
| 第二组 Swift/Weak / `potion_basic_five_refusals_a.lua` | 17083 | 12938 |
| 第二组 Fear/Ancient/Bronze / `potion_basic_five_refusals_b.lua` | 20665 | 19498 |
| 第二组四个溢出 / `potion_basic_five_overflow.lua` | 4521 | 5037 |
| 原 draw五组 | 未重复单跑 | 9245 |
| 原 status四组 | 未重复单跑 | 18913 |

随后仅运行一次完整 `node --test --test-concurrency=1 tests/potion-basic-five.test.mjs`：五项JS全部通过，零跳过；acquisition1为2821.172ms，保留的图比较6组为1867.955ms。总串行84223.304ms，各Lua均未增加原30秒预算。四个物理分片仍映射原两个逻辑组，加原draw5与status4，原逻辑覆盖仍为11；运行时断言13个物理test都执行，再对完整分片的逻辑组去重计为11。

原超时没有重烧。证据见 [pr238-potion-final-budget.json](pr238-potion-final-budget.json)；原始完整输出保留本树 `build/potion-five-final-budget-green.log`。没有改Backlog、CI配置或任何门限；本地预算已经验证，最终集中云端CI仍由父线程执行，未提前宣称云端修复通过。
