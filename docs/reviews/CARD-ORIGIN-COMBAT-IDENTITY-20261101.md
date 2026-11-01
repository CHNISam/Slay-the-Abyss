# 战斗生成牌来源身份短修

基线：`a7666ca0ff63eba43f2c54e5add00b5972661f8a`。承接 TASK-4.7，仅修复只读来源视图，不修改实际升级、生成UID、原子事务或新增来源链。

## 反例与修复

永久牌组删除过牌后UID可不连续，例如普通攻击UID1、已升级愤怒UID3。普通战斗副本使用局部UID1/2，通过 `deckUid` 指回永久实体。`abyss_card_actions.fresh` 为战斗新生成牌分配下一局部UID3，并明确清空 `deckUid`。

原 `abyss_card_origin_view.describe` 使用 `combat and instance.deckUid or instance.uid`。当生成牌没有 `deckUid` 时，Lua表达式回落到局部UID；相同cardId又碰撞永久UID3时，误显示另一实体的“永久升级 · 来源：营地锻造 · 第 2 层”。未升级的生成牌同样会误显示该永久来源。已有永久换卡/降级身份测试没有覆盖两个UID命名空间的碰撞。

新增回归调用真实 `fresh` 生成同卡ID/相撞UID反例，修复前两项失败，显式 `deckUid` 和永久卡组正控通过。修复显式选择身份：战斗视图只使用 `instance.deckUid`，没有它就不匹配永久实体；非战斗详情继续使用 `instance.uid`。原有cardId、升级标志及次数校验保留。生成的已升级牌显示本场临时升级，不借用永久来源。

## 本轮验证

- `node --test --test-isolation=none tests/card-origin-identity.test.mjs tests/card-origin-ui.test.mjs tests/card-upgrade-origins.test.mjs`：Node24.18.0，4/4通过，5.81秒；包含12条身份用例、Astrolabe三张替换UID、真实DeckUI只读来源及事件/遗物/临时升级来源。日志：本树 `build/card-origin-identity-tests.log`。
- `node scripts/check-architecture.mjs`：318模块、1833依赖边，0错误。
- 固定Luacheck1.2.0单模块检查：0诊断；复用已有二进制，SHA256 `0f1c69c4d09f1ebb4d8df14c215e4553e2e639bd4cb7bf3c639b0daa6198317b` 与配置一致。日志：本树 `build/card-origin-identity-luacheck.log`。
- `git diff --check`：通过。原有8条身份断言保留，仅将包装器通过标记总数由8改12；不改时限、预算或核心状态。

未跑全量CI，未构建GIL、官方导入、真实ready、PC或实体手机验收。既有M3证据的源码身份与模拟器边界继续保留；此短修不追认任何设备或发布完成状态。
