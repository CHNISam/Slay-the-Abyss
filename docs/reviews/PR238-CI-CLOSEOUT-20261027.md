# PR238 当前失败候选的集中修复

远端失败候选为 `28869011c26bcead7f925e78f00dbda454daa231`，Quality `40428128797` 未通过，未合并。接手保存了所有15个dirty工作树的185个文件、tracked/index补丁和HEAD，逐文件SHA256一致，目录为根 `build/pr238-resume-20261027-091929`。根develop和其它会话改动没有覆盖。

主集成保留cf4f09c1的Gold四片与稳定shop负例，接入最终UI五片91b516e7和药水9c691538。未重复整套本地check；以下只记录必要定向结果，完整云端结果以同一PR最终精确SHA为准。

临时属性归还的最终值原本正确，但ownerEndClearLoss清除debt/order后未更新刚发出的状态frame。生产只补一次完成态frame；8个普通/实验路径、两属性与Artifact用例通过，旧gain帧仍独立。原card_feedback、Flex、Artifact power/runtime与signed caps全绿。Regen原10组12570ms通过，保留heal10、50HP/10层→敌回合50/9→受击44/9及RNG，见[来源迁移](PR238-regen-queue-boundary.md)。静态遭遇reference补齐真实Run的masterDeck/RNG/药水元数据，保留原比较并加强永久UID和私有快照，见[迁移证据](PR238-static-encounter-compat.md)。

| 原夹具及完整覆盖 | 每片实际秒数；原30秒不增 |
|---|---|
| node_transactions 11组：1–7 / 8–9 / 10 / 11 | 23.392 / 7.655 / 1.836 / 7.465 |
| spike_slime_l 17组：1–5 / 第6组三片 / 7–17 | 2.595 / 11.404、10.787、8.808 / 1.740 |
| small_slimes 18组：1–6 / 7–11 / 12–17 / 18 | 7.634 / 9.007 / 9.409 / 21.676 |
| potion_flex_speed 11组：1–3 / 4–7 / 8–10 / 11 | 6.451 / 3.783 / 2.916 / 8.382 |

small_slimes与Flex/Speed原完整入口实际超时，没有伪称GREEN。Large Spike第6组整块单跑仍30秒超时，故按原六种历史分三片，每片两种历史×原100掷点；实际marker证明200+200+200，128个HP seeds及其它原输入均保留，未改构造。其余已绿片未重复执行。

[覆盖锁](../../tests/fixtures/pr238-lua-budget.json)只逆变换明确的登记/range harness，再比较整个原文件SHA256，锁定全部输入、helper和断言；small_slimes采用已审查reference迁移后的正文。JS门禁核对57个原逻辑组与600个历史掷点无重漏，Lua每片核对登记及执行数。node原入口仍接受ABYSS_MUTATION_CASE，选中时越过普通分片，M3 assertion origin与marker仍在原文件。

14项runner/分片/变异派发回归通过，最终覆盖门禁再单跑通过；M1–M4全为killed_by_assertion，M3为3310ms。原失败和后续替代结果完整保留在[机器记录](PR238-CI-CLOSEOUT-20261027.json)。

没有增加timeout、删断言、缩池或改变玩法范围。本地专项通过不代表最终云端、全池组合或平台通过。没有新GIL、官方导入、实机日志/截图或verify:ui通过，没有本轮键鼠授权；M3及对应全量AC保持未完成。
