# TASK-52.1：旧路线诊断领奖与节点推进

2026-10-24。本地修复、定向回归和独立审查通过；当前提交的 CI 仍由集成线程核对。本报告不代表千星试玩、原版完整规则一致性或正常通关。

## 修复范围

- `tools/diagnostics/core_route_seed42.lua`：原选牌/跳牌后调用诊断专用领奖函数。成功进入节点后，按真实 `nodeFlow.type` 进入原有处理分支，支持问号实际解析为战斗、商店、宝箱或事件；未知类型直接报错。
- `tools/diagnostics/finish_combat_rewards.lua`：只使用公开 Run/Nodes API。未决药水有空槽时领取；满槽保留原瓶并明确放弃新瓶；既有 `unavailable` 内容也明确放弃。日志分别记录领取及满槽/内容不可用的放弃原因。随后领取尚未领取的失金，离开奖励，再完成地图战斗节点。
- `tests/lua/diagnostic_reward_protocol.lua`：直接执行上述函数及真实诊断脚本，不能只让另一份测试实现通过。

不把 `manualContinue` 当作必有失金；不重复领已领取/放弃的瓶子或失金；不将任意领取失败转换成放弃。真实 API 失败立即通过 `assert` 传播，没有重试循环。诊断不会自动修复失败状态；测试中的显式重试仅验证部分成功后不重复领取。

原 seed42、地图排序与节点选择、战斗选牌与目标、奖励选牌、商店购买、营地和事件策略均保留。生产 Run/Nodes/Combat/UI、数据、原 m2 审计策略、工作流和测试预算均未改；无甲虫未合候选。

## 来源与先红后绿

基线为 [develop b91a461](https://github.com/CHNISam/Slay-the-Abyss/commit/b91a461bb759ff71fa66a6368ffe0289c36641f2)，tree `cd1ec120967b0d1d6310438b4e04ae92394a62d8`，包含 PR181/182/183。取得真实 `3c3b660 → b91a461` 比较，并对实际使用的 src/data/scripts/tests/tools 与关键说明共 432 个 blob 逐一核对。未将较旧 PR183 本地副本的目录名当作新来源凭据；补齐差异后才构建、测试。

1. 原诊断在该基线上真实首战后报 `core_route_seed42.lua:56: reward_pending`，exit1。新集成测试先直接执行原脚本，同样失败。
2. 迁移领奖后通过首战并完成13层、7胜，随后暴露旧节点分派缺口：`f14_l3` 的地图类型是 event，真实解析为 shop，旧代码取不存在的 `node.event.id`。失败日志保留，没有删除后续测试或把13层当完整路线。
3. 经确认只将进入后的分派改为真实类型。新增四类问号实际脚本测试中，原分派的 treasure/shop 两组先红，再随修复转绿。

## 最终验证

运行方式是系统 `liblua5.4` 的现有 ctypes runner，不是 Fengari，也不是千星客户端。未安装依赖或更改测试预算。

```sh
node scripts/build-lua-data.mjs
LUA_PATH='./build/lua/?.lua;./src/lua/?.lua;;' LUA_INIT='' \
  python /workspace/shared/slay-signed-status-cap-20261023/run-lua.py tests/lua/diagnostic_reward_protocol.lua
LUA_PATH='./build/lua/?.lua;./src/lua/?.lua;;' LUA_INIT='' \
  python /workspace/shared/slay-signed-status-cap-20261023/run-lua.py tools/diagnostics/core_route_seed42.lua
```

- 新 fixture：47/47，通过。36种组合覆盖药水无/待领/满槽/已领/已弃/不可用 × 失金无/待领/已领 × 选牌/跳牌，全部使用真实 Run/Nodes 构造和处理奖励。另测真实药水拒绝、失金溢出、稀疏药水槽、部分成功后显式重试、最终节点拒绝、四类问号分派、未知类型拒绝和完整自然路线。
- 组合夹具明确使用完成战斗/失金账本前提，不伪称真实 Looter 偷钱或自然胜利；没有直接修改奖励字段。自然路线测试不注入 HP、牌组、金币、奖励或胜负，不绕过地图节点；拒绝任何 STOP，只接受真实 victory/defeat，败局必须执行原 LOSS_GATE 和 FRESH_RUN 断言。
- 原有六份窄回归均通过：potion_reward_independence 3、looter_rewards 5、looter_potion_rewards 10、potion_rewards 7、nodes 21、run 8，共54组。
- 13个隔离负变异全部被捕获：漏药水决策、满槽强领、重复处理瓶子、误把手动页当失金、重复领失金、漏领失金、漏 leave、漏节点完成、吞药水错误、旧诊断调用、旧节点分派、漏未知类型错误、被 END 掩盖的提前 STOP。基准测试自身47/47，变异各自exit1；未修改交付源做变异。
- 独立审查对冻结源码重新运行47/47通过，另4个边界通过；再次核对基线 blob，无生产 src/data 改动。未发现阻断缺陷。

## 自然 seed42 结果

真实首战完成领取 dexterity_potion 并回图；后续按原路线领取 fire_potion、regen_potion。第14层实际商店完成原购买策略后继续，第16层 Guardian 战斗自然败亡，未改血量、强制胜利或调整路线。

终态：floor16、defeat、0 HP、188金币、7胜、3瓶药水；共30回合、68次出牌。Guardian剩20 HP，最终战斗第7回合。原断言输出：`LOSS_GATE run_defeated available=0`；新局为80 HP、99金币、10牌、1遗物、0药水。脚本exit0代表诊断诚实走到正常败局，不代表通关。

## 证据与边界

交接归档保留 `source-proof.json`、`3c3-to-b91.json`、`baseline-red.log`、`fixture-red.log`、`route-event-probe.log`、`resolved-dispatch-red.log`、`fixture-green.log`、`route-green.log`、`narrow-results.json`、`final-mutation-results.json` 及独立审查日志。失败日志不覆盖为通过。

本切片没有重跑全量重型检查；集成线程负责当前 SHA 的正式 CI。本环境未找到既有 Fengari 安装，因此不冒称其兼容性或30秒预算已实跑。未认证 Boss宝箱路径、新候选编译/官方导入、平台日志、实机 UI 或完整规则同源一致性。TASK-52父任务和其他来源待定的规则工作不由本切片关闭。
