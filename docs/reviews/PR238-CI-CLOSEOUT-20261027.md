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

## 云端包装调用修复

候选a717d381的Quality 40433213848在rules4的JS阶段发现遗漏调用点：potion-flex-speed.test.mjs仍只调用分片第一入口并要求单文件输出11。未合并；原始日志保存在根归档a717-rules4.log。包装现执行全部四片，逐片校验status、组数与实际原始索引，最终严格要求1–11各一次；不把旧11降成3。其它三个夹具的JS/配置调用点已搜索核对。

仅对原Flex/Speed JS文件和覆盖门禁定向复验，3项通过、0跳过；四片5853/3501/2610/7578ms。没有重复其余已绿夹具或整套本地check。新提交仍须同一PR全部必要CI成功，a717部分通过或旧日志不能代替它。

## 同步已有develop基线

c15de6f8在GitHub标为CONFLICTING，故该SHA没有触发PR CI，不能把无作业当通过。同步既有develop 364833a0，保留已合PR231的卡牌交互/原生卡面装配和本PR全部改动，唯一内容冲突为luacheck历史警告行号。逐项以file、原源行、column、code、去行号message及被引用源行，对照两个父版本的多重集合证明当前104项全部已有，新增警告身份0；未直接放宽baseline。证明保留根归档baseline-merge-proof.json。

冲突解决后实际静态通过：104项历史警告、0新增，battle render≤10且受检函数≤15；架构159模块/920边通过。PR231的UI用例迁移与最终五片边界均保留。最终合并仍等待同步后的精确SHA全量必要CI。

## 7593 云端失败后的完整收口

Quality 40434608172 对精确候选7593e827：四个JS分片、presentation、engineering-posix成功，四个Lua分片失败；licenses成功。它没有满足合并条件，37个失败Lua入口全部保留原始日志。

生产修复限定在现有接入的回归：Forge/升级命令排除Status与Curse但保留可重复Searing Blow；高级回合接回既有遗物atTurnStart；Rampage按UUID同步同一实例成长；状态移除重新发布数量和完成态frame；Silent/Watcher最终卡描述从目录定义取得；压缩Shifting说明以完整保留伤害、归还和例外信息。

固定源码319009d5的AbstractCard.canUpgrade、Rampage/ModifyDamageAction/GetAllInBattleInstances、AncientTeaSet/HappyFlower/ArtOfWar支持这些修复。另核实DarkEmbrace的抽牌addToBot排在DiscardAtEndOfTurn的TOP弃牌之后，旧错误oracle改为exhaust1/hand3/discard9/draw0，四个牌堆断言均保留。来源文件SHA见机器记录，固定ZIP的SHA256为3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458。

旧夹具迁移保留原语义：静态遭遇reference补齐masterDeck/RNG；Power夹具登记获取顺序；当前combat的连续奖励RNG也注入失败；职业药水使用实际职业Run并额外保留缺定义原子拒绝；商店用本轮真实货架与报价；旧native DeckUI用原生目录，现行完整Run路径另有26组UI覆盖。Deus Ex渲染先验证真实抽牌衍生，再通过既有recoverExhaust操作取回同UID原牌，避免把Miracle当原牌。

完整目录下普通Run的零槽法球宿主与75张Silent/Defect目录按现行契约验明，来源池71不变。Looter种子1真实起手战斗在第3回合取胜，偷款30、未领奖金币69、普通奖励15、先领奖84、归还后114；四种领取顺序和跨房间/同时死亡断言保留。Rod获取冻结实际来源队列seed5、实际宝箱seed91、实际商店seed2/格1/报价302；未修改运行时母池或重掷，资金为显式购买边界。

| 后续超时分片 | 保留覆盖 | 最慢片秒数 |
|---|---|---|
| Sneaky / Growing / Inventory / Vulnerable / Character / GameUI / Nodes / Gremlin | 8+36+12+52+16+26+21+19=190个原组 | 11.905 |
| Boss事务 | choice0–3、normal/elite各3种子、未完成/失败/重复完成，全7片 | 3.962 |

所有入口仍为原30秒。Sneaky自然战斗保留0–127全部种子；Growing/Vulnerable原1–128搜索上限不改，按原break语义实际执行前缀1–49与1–26，分片遍历每个原实际输入一次，成功叶保留取得奖励、次战使用、后续重置全部断言。首个成功边界单独断言锁定；原HP/伤害/牌组/实际构造不替换。两份新增覆盖门禁逆变换后锁整个原正文SHA及所有case/seed范围，Gremlin helper同锁，不以跳过正文的登记探针冒充通过。

37个原失败入口均有最后一轮定向通过证据，未重复整套本地check。四份正文覆盖门禁通过；M1–M4全部killed_by_assertion且原文件未变；静态104项历史警告、0新增身份，battle render≤10、受检函数≤15；架构159模块/921边。所有本地失败尝试与最后替代记录均留在根归档，不复用旧CI或旧实机结果。

当前修复仍须推送后同一PR精确SHA的全部必要CI成功才可合并。TASK-14.1/16.1的全池与平台AC及M3整体保持未完成，无新GIL/导入/实机/UI验收证据。
