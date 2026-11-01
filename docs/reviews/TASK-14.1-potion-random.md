# 完整战士药水纯采样模块

基于 `6457b61f9f600178ad8279839243c82f52b772cd`，复用 TASK-14.1 / TASK-13.1。本片只提供未来获取入口共用的纯随机 owner 与完整33项采样，**没有接 Run、商店、战后奖励或正常概率池，不代表33瓶效果已齐或可用**。

来源仍为固定社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`；直接复核指定 ZIP 的 PotionHelper.getPotions/getRandomPotion 和 AbstractDungeon.returnRandomPotion/returnTotallyRandomPotion。不是已认证 PC 二进制。逐文件身份复用[来源清单](../rules/evidence/sts1-ironclad-potion-pool-sources.json)；33目录与规则见[完整池附件](TASK-14.1-full-ironclad-potion-pool.md)。

`abyss_potion_random` 的 `new(rawSeed)` 创建 `{potionRng=...}`；`snapshot/restore/clone/commit` 使用原有 `abyss_sts_random` 值状态，不做按层派生或截断 seed。连续调用同一 owner 延续该流；调用者可 clone 后采样，并在整笔外部事务成功时 commit。commit 也保留准备值的独立性。无效参数在抽样前拒绝，不消费原流。

- `sample(owner, {rarity=可选common/uncommon/rare, limited=可选boolean})`：未指定 rarity 时先抽0..99，边界65/90；再反复从原始33项抽索引直到匹配。不能改成同类桶，也不能为缺效果或 acquisitionPending 删项或重抽。
- limited 总会浪费第一候选，后续同时满足稀有度且不是 Fruit Juice 才接受；普通模式允许 Fruit。显式 rarity 不抽稀有度。
- `totallyRandom(owner)`：仅抽一次完整池索引，不抽 rarity。
- 返回 `{sourceId,id,sourceIndex,rarity,attempts}`，sourceIndex/attempts 是0基原池索引，仅含身份/稀有度和采样轨迹，不创建药水、发奖、查库存或执行效果。`pool()` 返回脱离内部常量的完整目录视图。

私有33行保留目录原顺序与每个 proposedProjectId，特别是 ElixirPotion→elixir、SteroidPotion→flex_potion、FairyPotion→fairy_in_a_bottle，未用字符串改写猜 ID。适配测试逐一核对全部33映射、独立 oracle 的 sourceId/rarity 列表，以及当前已有定义的 ID/稀有度；不把目录历史 currentProjectId=null 误当新的过滤条件。

`tests/sts1-potion-random.test.mjs` 直接 require 实际 Lua 模块，以原 runLua 默认30秒预算运行。既有独立 Python oracle/九个 signed64 固定向量保持不改，核对每个候选索引、所有 word/counter 和持续消费；外部掉落 draw 仅在适配器中按向量上下文复现，不在本模块实现掉落修饰、Sozu 或获取政策。另有64/65、89/90、全部33均匀索引、limited首样/Fruit、计数器回绕、clone/commit隔离及无效参数原子性检查。

CI共用宿主期间未运行测试或构建；主线释放独占窗口后，4项适配测试先因缺模块全部失败，再安装本模块，实际4/4通过（总耗时2029ms，各Lua调用仍用默认30秒预算）。红绿、33类声明复核和恢复记录归档于根 `.artifacts/sts1-potion-random-20261025/`。未运行全量检查、构建或平台实测，未接正常游戏。
