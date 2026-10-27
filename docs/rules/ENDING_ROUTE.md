# 正式第四幕 Run 后端

只允许取得资格和三钥匙的 campaign，在固定第四幕队列下进入 54 层 Shield and Spear 精英、55 层 The Heart Boss。54 必须保有完整三项固定精英队列；55 必须已消费一项，Boss 初始化为 source `ending` 的三项 The Heart。普通战斗、错层和伪造章节队列均拒绝，仍复用正式 roomStreams 和原战斗事务。

正式战斗的奖励构造按 Gold→Relic→Potion→Cards；没有 roomSeed 的旧显式测试路径保持其原固定奖励顺序。Heart 在确认 defeat 分支、保留动作结算和战后遗物之后走专用收口：保留一次 Boss misc[-5,5] 抽样，不把金币入钱包，不调用遗物、药水、卡牌奖励，也不建立宝箱或奖励 bundle。

`Run.finishCombat` 发布 `ending_proceed` 和仅含 version/runSeed/act/floor/encounterId/combatGeneration 的普通表 owner。`Run.proceedEnding(run,expectedOwner)` 在复制前检查真实对象身份和普通表，事务内再次验证完整身份、资格、三钥匙、原 boss flow、实际单敌 Heart、胜利、正生命和无待结算动作。成功才设 victory / true_victory 并完成 flow；旧 owner、重复点击和失败均不推进。Nodes 还须用可信地图重新恢复并验证 55 层路径，不从 owner 自证地图合法。

来源 `sts@319009d5`：TheEnding.generateSpecialMap；AbstractRoom.update 276–346（先隐藏 Boss 金币，再跳过 TheEnding Boss 的奖励页）；MonsterRoomElite.dropReward；CombatRewardScreen.setupItemReward；ProceedButton.update/goToTrueVictoryRoom；AbstractPlayer.damage 与 DeathScreen（双死时仍败北，复活先裁决）。精确 member/hash 见原 Heart/Spire 来源锁及本轮只读来源审计交接。

`ending_route_api.lua` 使用真实 Run/Combat，受控已有历史、三钥匙与最终伤害边界；验证隐藏 misc 一抽、没有可领奖励、低生命合法战后治疗、wrong-owner／元方法伪造、七种失败全图回滚、重复 Continue 和双死。它不是自然通关或平台验收证据。四职业正式 52→55 路线将在同一切片追加独立证据。
