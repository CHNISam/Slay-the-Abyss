# PR196 seed-validation 性能根因与最小生产候选

## 结论与边界

当前 PR196 在开始与结束均核对为 9a4cf64fb6c0f435bb8ad61a3f68f0549a2d03bf，原作者没有新头被覆盖。本地未写远端。

根因不是75卡导致selection重复构建世界。原测试只 Run.new 一次，现有 C.new 探针也一直在世界构造前拒绝。新增的真实 startCombat 为每条路径两次调用 RunSeed.forFloor，3360次floor派生内部总共构造36960个随即丢弃的RNG，仅为校验canonical signed64字符串；Run.new里的两次规范化再构造两个。真正需要的5个RNG构造始终保留。

候选不改测试去隐藏它，而是在生产模块原样提取已经存在的同一组严格校验。所有十进制+1、signed long wrap、原始RNG四limb解析/mix及draw算法保持字节不变。没有缓存、第二套规则、数字转换或抽样缩减。

修改仅四个生产文件：
1. src/lua/abyss_randomxs128.lua：原有seed断言提取local validateSeed；fromSeed仍调用它并执行原样数学。导出纯校验API。
2. src/lua/abyss_sts_random.lua：导出相同extra-args拒绝的wrapper validateSeed；现存fromSeed ABI不动。
3. src/lua/abyss_run_seed.lua：normalize只调用纯校验，而非构造并丢弃RNG。
4. src/lua/abyss_map_topology.lua：seedForActOne改用同一纯校验；整个十进制加1逻辑不改。

新增 tests/lua/run_seed_validation.lua 七组持久回归。所有原selection及其余三Gremlin文件、shared helper、生产数值、runner、预算和CI均未改。

生产文件已冻结：FROZEN-PRODUCTION.json 给出四文件基线blob、候选blob及SHA256。候选目录 production-candidate。所有候选、mutant、证据只写本任务隔离目录。

## 实测成本与等价证据

Linux native Lua5.4 单selection原始/候选：
- 每1000指令hook次数：286283 → 9345，下降96.735747%。这是操作量，不是Windows耗时承诺。
- Run.startCombat：1680 → 1680。
- RunSeed.forFloor：3360 → 3360。
- RunSeed.increment：16800 → 16800。
- rules、pool、capture copy分别都是1680 → 1680。
- Random.fromSeed：36967 → 5。只取消校验用途的完整构造。
- 单次纯校验追踪：fromSeed 0，mix 0，validateSeed 420；无隐式RNG构造。

原四分片1/18/5/5共29组双侧全PASS，stdout逐字相同。1680路径、原种子、独立剩余索引oracle、354有序组合、频数、四次强制抽样、原拒绝结果、原state/reference freeze检查全保留。真实构造集成组未作任何替换。

固定source vectors原有25组JS断言完整复用，只把候选模块路径映射到生产src/lua，并用native Lua5.4桥接替代缺失的Fengari。原始/候选各25 PASS，包括10个seed×128原始draw、state carry/high bit、8组bound/rejection、6×80混合wrapper调用、counter wrap、snapshot不别名、132个scaled float精确向量。它们不是官方Fengari CI执行，适配器及断言源保存在evidence/native-tests。

原有API差分：54种输入，覆盖类型、nil、safe integer范围、canonical/非canonical、signed64边界、floor0–17、extra nil及invalid+extra优先顺序。1307行结果逐字相同；错误比较保留原文字，去除不可跨版本保证的文件行前缀。新validator与构造器接受/拒绝集合使用同一段原样断言，未另造规则。

七组新持久回归先RED（缺纯validator API）后GREEN：
- 接受集合及类型/非canonical/范围拒绝。
- safe integer规范化和非法floor优先拒绝。
- literal长整型边界、负数跨零、十进制进位、signed wrap。
- 原wrapper与新增wrapper的extra-args拒绝，primitive既有忽略extra行为保留。
- monkey-patch RNG constructors为抛错时，纯validation/normalize/legacy/increment/forFloor仍通过。
- 来自既有独立source fixture的10个seed初始化state、首draw、wrapper计数。

四类反向变异均失败退出1：
- 删除negative-zero拒绝。
- 删除新增wrapper extra-args拒绝。
- 破坏long max→min wrap。
- 破坏RNG零seed初始化：持久新测试和固定source vectors均抓住。

## 风险与验证限制

四个模块必须作为一组集成，避免调用方切换到validateSeed而导出尚未更新。primitive新API和旧fromSeed一样忽略多余参数，STS wrapper新API和旧fromSeed一样严格拒绝；未偷偷统一掉既有差异。

旧primitive断言文字及检查顺序保持；自然保留其原行位置，没有填充代码强保行号。RNG数学主体和十进制算法逐字核验。

这不是当前SHA完整CI、Windows/Fengari30秒达标、平台编译或实机验证。本环境缺锁定Fengari依赖，未安装，未跑fullnpm，未操作用户电脑。root及其他worker负责独立全场景对照与最终CI。

早先selection-only forFloor缓存实验已按root要求明确拒绝，仅用于归因；目录rejected-fixture-cache和cost-contract.lua不得集成。最终生产候选完全不替换forFloor，也不改任何原测试。

## 交付

- production-seed-validation.patch：四生产文件最小补丁。
- seed-validation-regression.patch：新增七组回归文件。
- 两份patch可同时对精确baseline执行 git apply --check。
- FROZEN-PRODUCTION.json、RESULT.json：机器可读身份和量化结果。
- evidence/verified-source.json：固定head的83份runtime/fixture输入blob。
- evidence/validation-sources.json：固定RNG测试与source vectors的身份。
- production-candidate/tests/lua/run_seed_validation.lua：回归源。
- evidence/validator-red.log、validator-green.log：RED/GREEN。
- evidence/*source-vectors.log、*differential.log、*profile.log、*instructions.log、mutant*：完整日志。

## 精确交付SHA-256（文件与patch身份分开）
- production-seed-validation.patch：52665c918f92eca95be1f5aa925c02c8207b075eff2ad06f09849b6042e46226
- seed-validation-regression.patch：783758906551f728c3b4bc9f14003839c0c4b3f47c17a7599a7996b734da3741
- production-candidate/tests/lua/run_seed_validation.lua：67598a55f0c0b8dbc1d7fe3adb8909e3705bb1907a6f9197cad6f4e01d6d0ccc

差分输入数量以脚本末行54为准。字符串标签改用hex编码后为1307物理行，避免嵌入换行导致原日志1331物理行被误当成更多输入；两次编码下的baseline/candidate均逐字相同。旧口头55是行数反推错误，已更正，未改变测试输入或生产候选。
