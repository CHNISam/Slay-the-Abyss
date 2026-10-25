# 坐标边界回归夹具成本最小候选

## 结论

仅修改 `tests/lua/play_area_coordinates.lua`，不改生产、共享 support、预算、CI 或 Backlog。保留原31组、39次独立 setup、全部 NaN/±Inf 的两轴上下事件、C模式、旧触摸、反馈与资源/牌堆状态断言。候选在真实 native Lua5.4 下31过0败；没有 Fengari 安装，也没有实际 Windows CI 重跑，不能把本机耗时当作30秒门禁通过。

## 冻结与变更

- PR196 开始及结束核对均为 `9a4cf64fb6c0f435bb8ad61a3f68f0549a2d03bf`，open/未合并。
- 119个实际源文件逐 Git blob 对齐该头，12个 build产物由其数据/构建脚本重新生成。详见 `evidence/baseline-blobs.json`、`generated-blobs.json`。
- 唯一候选15行辅助函数加两处调用替换。固定数据和种子1的冷 Map.generate 只执行一次，每次请求返回完整深拷贝。H.setup照常执行，离开 setup 时包括异常路径恢复原 Map.generate。
- 缓存没有复用已运行 host、Run、Combat、control、反馈状态；断言拒绝意外不同数据对象或种子。固定夹具数据在此文件各用例中不改写。
- `candidate.patch` SHA256：`b0d6a31aaf5f26a8bba331459e57b305bf13d9fd1f1236b1389eed6d38f56062`。
- 候选文件 SHA256：`463514fdc839e6c0fae1f3b706b3878bb3ead6dbb0fb345c1e977262a616ce15`。

## 根因与实际量化

原夹具每次GameUI.new/start重复生成同一张冷地图。最初带计数剖析：78次Map.generate累计0.433秒，占总CPU1.261秒34%；1170次RandomXS.fromSeed累计0.057秒，只占4.6%。本文件forFloor验证成本不是主要项。

构造计数：Map.generate 78→1；GameUI.new 39→39，Run.new 78→78，Combat.new 78→78，Run.startCombat 39→39。真实出牌/反馈输出也逐行相同。

交替顺序7轮、每次新native Lua进程的最终基准：
- baseline 中位wall 1.195397s / CPU 1.193633s。
- candidate 中位wall 0.754302s / CPU 0.753513s。
- wall减少 36.90%，CPU减少 36.87%。这是本环境相对成本证据，不是Fengari30秒达标证据。

## 安全性和测试敏感性

1. 先红后绿：外置cost-contract先在baseline的完整31组通过后，以真实Map.generate计数78而非1失败；候选完整31组及次数1通过。原31组测试体/预期在仅归一化setup调用后字节完全一致。
2. 逐setup完整可达表图快照：字段、别名、循环、数字精度、函数源位置，39/39 baseline/candidate字节一致。原始函数的私有upvalue不序列化；真实构造函数及闭包创建路径未改。记录在 `evidence/setup-equivalence.json`；每份原始快照gzip保留。
3. 每次地图及其全部子表与既有setup不共享引用，当前host.map与mapUI.map的原始别名关系保持。深拷贝与第一个模板隔离。
4. 异常负控：故意使31次H.setup都抛错，原31组按预期失败后，Map.generate仍恢复原函数。`evidence/restoration.txt`。
5. 五种内存中生产故障注入，baseline/candidate相同用例及相同错误，唯一归一化的是因插入辅助函数造成的源行号：
   - 丢失显式非有限数字标志：同18败，包含全部12个值/轴/Down/Up用例。
   - 拒绝位置缺失C模式：同4败。
   - 忽略释放触摸owner：同2败。
   - 重读坐标getter：同2败。
   - 取消释放移动阈值：同1败。
   生产文件均未落盘改动。详见 `evidence/mutation-equivalence.json`。
6. patch已在冻结baseline执行git apply --check通过；最终cost-contract fresh native执行31过0败、真实冷地图1次。

## 范围边界

AGENTS/debug/TDD已读。backlog CLI不存在，只报告不安装不更改任务库。未运行full npm、完整项目suite、CI、安装工具、用户电脑、用户Codex或远端写入；这些是父任务显式禁止/保留给唯一owner的工作。此候选能减少本文件重复冷构造，不声明整个PR通过，也不声明全量suite通过。后续由root决定是否整合并在当前新头验证真正CI。
