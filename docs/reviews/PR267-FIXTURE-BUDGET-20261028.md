# PR267 原30秒夹具的可靠性修复

基线：`9bab0cfd2c36a43c8f818fe121cdd79d082b683e`，实际主线 `4a3167808006f67c0c267b453fb188fb6e370a0c`。本地独立目录执行，原整合目录与其他脏树不动。复用 TASK75，无新任务、无用户 Codex、无新依赖或大图下载。

## 真实失败与定位

[Quality 40642815774](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40642815774) 的以下三个独占夹具触及原30秒超时；PR283独占调度已经生效，不能再次归因于短夹具并发，也没有重试旧失败冒充修复。原始失败行、完整证据文件的SHA256及本地前后原始输出保留在同名JSON。

| 夹具 | 原失败 job | 本地原基线 | 测试层修复后 |
|---|---:|---:|---:|
| silent_natural_build | 122664784215 | 24.67秒 | 21.47秒 |
| intent_artifact_playback | 122664784243 | 20.52秒 | 13.70秒 |
| elite_relic_reward_ui | 122664784259 | 19.60秒 | 两片11.64 / 6.25秒 |

本地Linux通过不代替Windows完整Quality；所有调用仍使用原`runLua`及30000毫秒上限。

## Intent：保留连续双回合及每帧完整状态比较

该夹具只有一个连续case，第二回合依赖第一回合，因此没有按独立case拆开。采样热点位于测试helper的递归比较器；原来对每个相等scalar也调用Lua递归函数并重复检查类型。

优化只让相等scalar在当前层完成比较。所有table无论是否同一引用均继续递归，仍遍历两侧键集合，每个原0.05秒帧检查全状态，原400帧上限、owner identity、最终状态及recovery断言全部保留。完整原case SHA256与helper完整旧正文的精确逆向证明均锁定。独立差分覆盖所有scalar组合、false/nil、每个嵌套字段的增删/类型/值变化、共享引用及NaN，要求旧/新比较器连错误路径文字也一致。当前完整fixture stdout与原基线逐字相同。

## Elite：六个独立原组完整分片

沿用既有Jaw Worm分片模式，仅增加1–3 / 4–6选择边界和第二raw入口。六组均fresh host，第三组原有refusal/exception两次创建及恢复注入代码不变。全部原正文可精确逆转回 Git blob `9b5ad319c0002e83dc30a85db1e2a8d4f1660607`、SHA256 `e622c8b6338eaa7bc0c23e75504b5d65bddead802d2ba789382d45f137b0793d`；40处显式assert及循环/递归断言均不删减。注册数、执行数、raw目录发现、无重漏覆盖、wrapper原文和负例均验证。两片的六条原组结果与原基线按序一致。

## Silent：完整图机械遍历，不弱化重建证明

原fixture在同一Lua实例内，以同一源seed177136完整执行两次四房流程，再比较完整canonical状态。此语义原样保留；没有删第二次、收窄71奖励源池、跨尝试缓存或替换为固定golden。

采样主热点是生产`abyss_snapshot.capture`的完整回滚图遍历，非canonical或测试选牌。经整合负责人明确批准，仅采用机械快路径：以显式栈顶替代反复长度计算/`table.remove`，入栈时标记去重，但仍完整访问所有table key/value、alias/cycle。没有data/catalog免检、跨事务快照缓存、规则改变，`restore`、`ownedRestore`、`release`完整正文不变。

旧实现原字节另存test support，SHA256 `a1367e95fd997d70dc3d5f4791c69d3474d3c457dff18a8fc78c57c0e38beb28`，Git blob `c0992daa9582633d335f3bd0765e3ee6f31c746d`。精确hunk逆向锁定其他所有生产字节。96次旧/新图试验检查共享引用、环、表键、字段增删、真实false值、单次owner、只经table-key可达的独立分量和只经data/catalog可达的定义；两侧另测20000节点深链。刻意漏掉key-only节点、false值或data/catalog的三个变异均被拒绝。独立审查指出的false表达式和key-only覆盖缺口已修正并实际重验。

额外诊断仅在原fixture结束处输出已有`first`，不改变任何命令/断言：旧/新在同一实例各自两次完整四房流程后，完整canonical输出6488字节逐字相等，SHA256 `5c14edb0607b023933d94c7d8b007564f7487d234e2a5cb75e21636916159d46`；该组旧26.41秒/新22.68秒。最终未插桩原fixture21.47秒通过且stdout与原基线逐字相同。没有把一次本地余量当成Windows通过证明。

## 已完成验证

- 新旧源码/分片/比较器等价4项及snapshot身份/差分先红后绿；加强后proof共7项全部通过。
- 原worker/runner及第一批proof共12项JS通过，原runner、调度权重、工作流和预算未改；原Run/Combat单次owner9组实际通过。
- 六个Intent入口全部通过（15组），新Elite两片六组通过。
- 最终生产组合14个定向raw入口（原三故障对应四入口及10个事务/回滚入口）全部通过，总137.53秒；具体完整输出在JSON。
- 架构214模块/1237边，Luacheck1.2.0保持84历史warnings零新增、418职责测量；4个原语义变异全部被断言杀死。最初工具symlink被项目root边界拒绝后，仅复制此前授权且SHA锁定的本地二进制到本树regular文件，未改验证器、未下载新工具。
- Backlog、JS syntax、网络策略通过；新增片保持未知/重夹具独占策略，不用降低timing制造并发。
- 三项故障的本地候选和证明已完成；托管Windows完整Quality与真机均未宣称通过。下一步由root审查精确候选并在既有PR267运行完整Quality。
