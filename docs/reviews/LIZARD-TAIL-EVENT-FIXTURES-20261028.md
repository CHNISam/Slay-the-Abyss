# 蜥蜴尾巴事件契约迁移

本叶仅修改三份旧事件 fixture 和本说明；生产基线为 `23c50ef6ed1a47b67a8ca326ebd7e441134213d8`，不修改事件、Run、复活协调器或首发验收清单。

旧 fixture 将 `lizard_tail` 直接塞入遗物数组，期待未实现伤害钩子拒绝事件。新基线已经有真实定义、获得初始化和共享伤害接线，因此应使用 `Run.obtainRelic`，验证效果与同局一次性计数。

## 来源

固定来源包：`sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0.zip`，SHA-256 `3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`。下列成员的共同前缀为 `sts-319009d5df0a82d9fb0f23cc22322286c6a87ec0/`。

| 成员 | 原规则位置 | 原始成员 SHA-256 |
| --- | --- | --- |
| `events/beyond/WindingHalls.java` | 80–83：普通伤害后仍创建两张 Madness | `f419f2ad258121a4970dffd289118a85c23ddd8d5025efa1d4a4f4cdbb001d2b` |
| `events/exordium/GoldenIdolEvent.java` | 108：无来源实体的普通伤害 | `3b3cab0799bb027281f7e4784d83efc9c9f6771bf56d039a1d0694e7d02351aa` |
| `events/beyond/SensoryStone.java` | 75、84、113：先建立卡牌奖励，再承受 HP_LOSS | `888b2ea6836850e5b04be7e1c24bfe188a161cebd3b868ce9f7a4b906aba0b61` |
| `relics/LizardTail.java` | 27、35–40：普通治疗后标记 counter -2 | `9ee5bd6aad4aa34a4d79cdd69f97160913b71d0f9e727f9ae8d7b26e2f281b90` |

## 保留与新增覆盖

- 三份原来的非致命 Tail 分支均改为真实获得；事件伤害正常执行，counter 保持 -1。原 Tail 最大生命损失分支、Sensory 的零伤害一组奖励分支各保留为独立用例。
- 每份新增同一 Run 的连续两个事件房间：首次 HP 1 承受真实事件伤害后恢复到 40/80、counter -2；离开并进入下一合法节点后，再次 HP 1 承受事件伤害，正常失败且 counter 仍为 -2。没有第二次获得 Tail，也没有直接写 counter。
- Winding 两轮都保留死亡后两张 Madness、连续永久 UID、金币和三条事件相关 RNG 不变；Golden 保留首次 Golden Idol、下次 Circlet 计数、牌组/UID/金币/RNG 不变；Sensory 保留死亡前两组各三张奖励、无永久牌领取及奖励随机流消耗，第一轮精确核对现有独立 Python oracle 的完整卡牌顺序、卡牌 RNG、misc RNG、稀有偏移及记忆编号。
- 原来的 Fairy、Mark、Omamori、Tungsten Rod、Toxic Egg、空来源 Torii、重复 Circlet、Fruit Juice、Ceramic Fish、资源、RNG 和拒绝后完整状态回滚断言保留。Darkstone Periapt 与 Sensory 的 Question Card/Busted Crown/Molten Egg/Frozen Egg/Singing Bowl 仍验证拒绝和回滚；没有将这些内容顺带放开。

节点事件类型和两轮开始时的 HP 是 fixture 的受控输入；初始来源随机种子为 42，Sensory 第一轮使用已有 oracle 的合法初始稀有偏移 -17。进入、选择、离开、Tail 获得及计数更新都调用生产接口。本叶证明离线受控事件生命周期，不证明自然路线、存档导入、实机 UI 或整个 M3 已完成。

## 实测记录

改动前的精确基线原 fixture 串行 RED：

| 原 fixture | 结果 | 时长 | 原失败位置 |
| --- | --- | --- | --- |
| `act3_winding_outcomes.lua` | status 1，`true ~= false` | 4003 ms | 32 |
| `golden_idol_costs.lua` | status 1，`true ~= false` | 2561 ms | 28 |
| `sensory_stone_outcomes.lua` | status 1，`true ~= false` | 4562 ms | 36 |

三者都已真实接受新 Tail 事件路径，原断言仍期待拒绝。完整 RED/GREEN 标准输出、标准错误、退出码、时长及最终 fixture 的规范化 LF SHA-256 保存在 [配对记录](LIZARD-TAIL-EVENT-FIXTURES-20261028.json)。三份修改后的 Lua 5.3 解析和 `git diff --check` 已通过。

修改后三份 fixture 在独占窗口串行 GREEN：

| fixture | 结果 | 时长 |
| --- | --- | --- |
| `act3_winding_outcomes.lua` | status 0，原完整 fixture | 3620 ms |
| `golden_idol_costs.lua` | status 0，原完整 fixture | 3156 ms |
| `sensory_stone_outcomes.lua` | status 0，原完整 fixture | 5248 ms |

共 12024 ms。每份沿用 `runLua` 默认 30000 ms，没有 case selector、删减用例或修改 runner、mock、预算。复现命令为 `node scripts/test-lua.mjs tests/lua/<上述文件名>`，须先执行 `node scripts/build-lua-data.mjs`。本叶只验收三份旧事件契约迁移；父集成的其它接线、自然取得、平台、实机和整体里程碑验收分别记录，不由本次 GREEN 代替。
