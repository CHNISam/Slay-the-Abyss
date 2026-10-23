# TASK-14.1 开战遗物顺序离线切片

2026-10-23，基线 `52f35dd`。本切片只对现有六件开战遗物修复中间执行顺序；数值仍来自 `data/relics.json`，没有增加遗物、抽牌触发器或平衡规则。最终手牌、格挡、能量与能力数值在修复前已符合现有测试，此次没有据此声称发现不同的最终玩法结果。

## 来源与执行顺序

来源链和固定方法定位见 [PR87 独立负向证据](../rules/OPENING_RELIC_ORDER.md)。本次重新读取了固定提交 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的六件遗物方法、`AbstractRoom.update` 与 `AbstractPlayer`，未执行或复制镜像实现。它是社区反编译镜像；自报版本不认证正版 PC 二进制。本次结论仍是方法体推导，未取得正版 hash 或运行录像。

| 阶段 | 遗物／动作 | 已知语义与实际执行顺序 | 本地入口 |
| --- | --- | --- | --- |
| 首回合队首 | Lantern | 回合钩子晚于开战钩子入队，TOP 能量先执行；此时基础能量尚未到账 | `Inventory.opening` / `Run.startCombat` |
| 开战队首 | Vajra、Oddly Smooth Stone、Bronze Scales | 持有列表正序调用 TOP，因此实际能力按持有列表逆序执行；帧中手牌 0，持有 Lantern 时能量 1 | `Inventory.opening` / `Inventory.applyOpening` |
| 基础回合 | 基础 +3 能量、普通抽 5 | 加到开战队首已提供的能量上，不能覆盖 Lantern | `Combat.startPlayerTurn` |
| 开战队尾 | Anchor、Bag of Preparation | 保留两者相对持有顺序，晚于普通抽牌；Anchor→Bag 时格挡帧手牌 5，Bag→Anchor 时为 7 | `Run.startCombat` / `Inventory.applyOpening` |

持有列表“Anchor、Vajra、Bag、Lantern、Stone、Scales”的非视觉动作预期为：Lantern +1 → Scales 3 Thorns → Stone 1 Dexterity → Vajra 1 Strength → 基础 +3 → 普通抽 5 → Anchor 10 Block → Bag 抽 2。

`Combat.new` 只把临时回调传入本次 `startPlayerTurn`，回调不存入状态。下一回合仍重置为基础能量并正常抽牌；下一场战斗重新建立队列。已知遗物的值仍从 `effects` 读取，ID 表只记录经核实的钩子／队首队尾分类。未知开战遗物拒绝 `unsupported_opening_relic:<id>`，不猜测新规则。开战失败的候选状态与 RNG 不提交到 Run；基础能量累加仍保留既有溢出拒绝。

## 红绿验证

可复现入口：

```powershell
node scripts/build-lua-data.mjs
node scripts/test-lua.mjs tests/lua/opening_relic_order.lua
# 保留的原诊断入口转发到同一组回归
node scripts/test-lua.mjs tools/parity/opening_relic_order.lua
npm run check
```

- 修前在 `52f35dd` 用项目 Fengari runner 复现原诊断：3 组通过、11 组失败，退出 1。三个能力帧手牌 5 而非 0，六种排列没有逆序，两种 Lantern 位置的能力帧能量为 3／4 而非 1。
- 原 14 组完整保留，增加两种全部六件混排；修前 3 绿／13 红，修后 16 绿。
- 增加拒绝事务、基础能量溢出、回调不入快照／第二回合不重复、真实出牌完成战斗后再开战，共 20 组。溢出例先出现 `true ~= false` 的独立红例（退出 1），增加上界检查后 20 组通过、0 失败，退出 0。
- 首次组合 `npm run check` 的 JavaScript runner 在第 218 组后持续无新输出；只停止本轮已确认的 PID 9568，命令退出 -1。没有把这一轮报告为通过，也没有修改既有预算／断言。
- 精确复放 `build-ui-input-protection.test.mjs`：205 组，104 通过／101 权限跳过，退出 0；相邻 `build-ui-theme-protection.test.mjs`：46 组，38 通过／8 权限跳过，退出 0。未确定首次 runner 无输出的根因。
- 随后 `npm test` 完整重跑：584 组，469 通过／115 权限跳过、0 失败，退出 0。`npm run test:lua`：54 个脚本全通过（含本片 20 组）；`npm run test:presentation`：15 通过／1 权限跳过，均退出 0。`check:syntax`、`validate:data`、`build:theme` 分别退出 0。所有组合门禁的组成项已独立通过；组合 `npm run check` 本次未重新执行成功，交主线程整合后复验。
- 本地日志 `relic-order-check.log`、`relic-order-js-check.log`、`relic-order-lua-check.log`、`relic-order-presentation-check.log`、两份保护测试重放日志与 `opening-relic-red.log` 保留，不随源码提交。

持有遗物由夹具配置；两场战斗间使用真实 `Run.play/endTurn/claimCardReward/startCombat`，没有设置敌方 HP 或伪造胜利。此例验证开战重建，不冒称自然遗物取得／奖励概率已核验。

## 保留缺口

- 仅支持六件遗物的来源级执行顺序；完整原作调度器、Innate／起手生成／混乱等未支持组合不在本切片结论内。
- 镜像 PC 版本身份、正版构建／原作观察、药水共享层数上限与 `onUsePotion` 队列尚未完成。
- 本切片未开原神、未进行平台编译／副本导出、官方导入或实机验收。TASK-14.1 四项严格 AC 保持未勾，不以离线回归替代上述证据。
