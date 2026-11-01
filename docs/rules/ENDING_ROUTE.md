# 正式第四幕 Run 后端

只允许取得资格和三钥匙的 campaign，在固定第四幕队列下进入 54 层 Shield and Spear 精英、55 层 The Heart Boss。54 必须保有完整三项固定精英队列；55 必须已消费一项，Boss 初始化为 source `ending` 的三项 The Heart。普通战斗、错层和伪造章节队列均拒绝，仍复用正式 roomStreams 和原战斗事务。

正式战斗的奖励构造按 Gold→Relic→Potion→Cards；没有 roomSeed 的旧显式测试路径保持其原固定奖励顺序。Heart 在确认 defeat 分支、保留动作结算和战后遗物之后走专用收口：保留一次 Boss misc[-5,5] 抽样，不把金币入钱包，不调用遗物、药水、卡牌奖励，也不建立宝箱或奖励 bundle。

`Run.finishCombat` 发布 `ending_proceed` 和仅含 version/runSeed/act/floor/encounterId/combatGeneration 的普通表 owner。`Run.proceedEnding(run,expectedOwner)` 在复制前检查真实对象身份和普通表，事务内再次验证完整身份、资格、三钥匙、原 boss flow、实际单敌 Heart、胜利、正生命和无待结算动作。成功才设 victory / true_victory 并完成 flow；旧 owner、重复点击和失败均不推进。Nodes 还须用可信地图重新恢复并验证 55 层路径，不从 owner 自证地图合法。

来源 `sts@319009d5`：TheEnding.generateSpecialMap；AbstractRoom.update 276–346（先隐藏 Boss 金币，再跳过 TheEnding Boss 的奖励页）；MonsterRoomElite.dropReward；CombatRewardScreen.setupItemReward；ProceedButton.update/goToTrueVictoryRoom；AbstractPlayer.damage 与 DeathScreen（双死时仍败北，复活先裁决）。11 份精确 member/hash 固定于 `tests/fixtures/ending-route-source.json`，没有将 Java 复制进产品。

`ending_route_api.lua` 使用真实 Run/Combat，受控已有历史、三钥匙与最终伤害边界；验证隐藏 misc 一抽、没有可领奖励、低生命合法战后治疗、wrong-owner／元方法伪造、七种失败全图回滚、重复 Continue 和双死。它不是自然通关或平台验收证据。

`ending_route_characters.lua` 对四职业各自独立运行：受控跳到 51 层结束边界、已有三钥匙与历史，调用真实 advanceAct、52 休息、53 商店、54 双敌战斗及金币／遗物／卡牌／可用药水领取，然后进入真实 55 层 Heart。测试攻击以真实 Combat.damage 输入基础伤害 999，通过真实无敌 300 封顶和两轮真实 Heart 行动结束战斗，不直接写敌人 HP；这是受控战斗接线验证，不是自然卡组、玩家操作或原生通关证据。Late relic queues 是明确已消耗后的剩余身份，真实稀有度、canSpawn 和空池后备均保留，产品运行时不缩池。四份 Lua 仍各使用默认 30 秒预算。

`ending_route_contracts.lua` 另验拒绝入口、Gold→Relic→Potion→Cards 实际调用顺序、晚卡牌故障全图回滚、旧显式路径固定语义，以及真实 Run.play 最后一张攻击杀 Heart 后 Beat 导致的败北、Fairy 复活和 Mark 阻止 Fairy。

Lizard Tail 当前没有生产定义／致命伤复活 hook，是首发遗物缺口，未在本切片实现或假设通过。此后端只读共享战斗最终 outcome，未来该来源 hook 完成后仍可先裁决复活再进入 Proceed；不能把本轮 Fairy 证据表述成 Lizard Tail 已实现。

本轮有界结果：API 缺失真实 RED→最终 3 组 GREEN（5.425 秒）；明确 `--test-concurrency=1` 的 contracts 与四角色 5/5 GREEN（15.393 秒）。随后新增 97 房间 HP／AI／cardRandom／shuffle 四条完整状态的源顺序预期断言，四角色最终 4/4 GREEN（9.622 秒），含 Defect 两次闪电球的单目标随机抽样。每份 Lua 均保留 30 秒默认预算。早先误用 Node 默认文件并行的首轮仅作诊断，没有作为串行验收证据。
