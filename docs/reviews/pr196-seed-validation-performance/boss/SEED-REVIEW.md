# 共同 seed validator 候选的独立 Boss 复核

## 可用结论

四文件真实生产优化在原 boss_reward_rarity.lua 上独立复核通过。原测试逐字未改，无stub、缓存、入口拆分、缩种子/池/断言；可将此证据交给root作为候选评审的一部分。原生Lua结果不认证Fengari30秒预算，也不替代准确新SHA的完整CI。

## 冻结与独立来源确认

- 原PR196 head：9a4cf64fb6c0f435bb8ad61a3f68f0549a2d03bf，01:50 UTC只读查询仍相同。
- 原src/lua/abyss_randomxs128.lua、abyss_sts_random.lua、abyss_run_seed.lua、abyss_map_topology.lua四件均重新通过GitHub connector从精确head读取，与本基线逐byte及Git blob相同。
- 候选复制自sta-gremlin-selection-cost-0141/production-candidate；四件candidateGitBlob及SHA256逐个等于该worker冻结清单。来源内容在context/seed-originals-remote.json，候选冻结清单在context/seed-production-frozen.json。
- 新副本seed-candidate从本任务已封存baseline复制，唯一四件差异是上述生产文件。不是此前被拒绝的lazy诊断或fixture-cache。
- boss_reward_rarity.lua仍为原blob4fdaf222a6cdb8dc153d1258fb036442a0bb143f / SHA256 9f19279de2d76cdaaee745babd369654869a1db81504c3ac0e33c31717165254；helper也逐字未改。

## 实际对照结果

1. 原始完整128seed文件在两侧各5轮交错运行全部exit0。未包装native Lua5.4中位数：baseline0.825419838秒，candidate0.484456970秒，下降41.3078%。详见evidence/seed-benchmarks.json。所有轮均包含全部128seed、全部16张rare可达。
2. 观测探针两侧均128次Run.new、128次startCombat、128次finishCombat、896次顶层assert、384次顶层tostring。完全保留原计算/样本/断言流程。奖励顺序、legacy seed、hp/gold/victories/nextDeckUid/phase、cardRng两word/counter及offset的128条trace逐byte一致，整个observe输出SHA256 6348b9b2644bc55d4d023e8f7a50505d61fbfad0d15c53acf08648bab1cac3ca。
3. 更强对照：对每seed的new/start/finish三个边界序列化完整Run对象图，包含所有表键值、number类型、table别名/循环及metatable。共384快照，双方输出各48,421,631字节，逐byte完全一致；SHA256 ed8bdcea628b334de15e9f7e4114456abb5a4f33c55a29f15aea763a68fede25。单快照hash索引在evidence/seed-full-state-hashes.json；完整输出在evidence/{baseline,seed-candidate}-observe_full_state.log。
4. Random.fromSeed9856次降至1152次；恰好移除RunSeed.normalize4608次与MapTopology.seedForActOne4096次的丢弃实例构造。所有其余8处实际owner/battle/potion/queue构造来源次数原样保持。画像日志在evidence/{baseline,seed-candidate}-profile_seed.log。

## 代码审查意见

原primitive的signed64类型、长度、canonical decimal、negative zero、上下界断言原样提取；fromSeed仍调用它，再执行原来的word转换、hash/初始化逻辑。新增STS wrapper验证保留extra-argument拒绝。RunSeed.normalize与MapTopology.seedForActOne改调用validator而非创建随后丢弃的RNG，没有改seed math、draw、state owner、数值或概率池。此处实际状态对照支持等价性；非法seed/API拒绝与固定向量由seed worker的独立契约测试另行提供，不把本128正seed复核冒充全部ABI覆盖。

## 复跑

从baseline/与seed-candidate/各执行：

python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py tests/lua/boss_reward_rarity.lua
python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../observe.lua
python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../observe_full_state.lua
python /workspace/scratch/331215e8236a/signed-cap-review/run-lua.py ../profile_seed.lua

基准计时只使用第一项；其余为观测包装，不能拿其耗时作修复性能。全部实际生产函数仍被执行，无结果stub。

## 未做与后续门禁

无安装、全量npm、用户机器/Codex、CI触发、远端/Backlog写入。云环境Fengari仍ERR_MODULE_NOT_FOUND，所以Fengari30秒结果未验证。root应将合法候选合入授权分支后确认准确SHA实际CI；本任务没有宣布PR ready或游戏/平台验收。原lazy诊断实验无收益，继续不合入。
