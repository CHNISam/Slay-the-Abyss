# Nodes 职责治理与离线验收

## 2026-10-29 本地三切片组合（未推送）

以本地已审 `dd1cd69fc96e7f4ac449c7f0bd84f867063c82ab` 为基准接入当前 #309 `18297e533fb27e7e1af29cc6e02d19309f9a11a6`，原两提交保留作者并逐项带 `-x` 来源；不包含 #312。仅 architecture 和既有历史 UI helper 两处真实冲突作组合取舍，Nodes 五个生产文件逐字采用原 #309；其余运行时和数据逐字保留原组合。1,726 份生产/工具/夹具源码字节核对通过，252 个分类及全部无关配置字段保持原值；没有改任务、认领、状态或验收项。

单纯并排保留注册曾真实触发原配置门禁失败（11项中5项失败），新投影占位实现另有4项失败记录。新增仅测试用的三切片完整源码证明，冻结组合配置 `df2d5866...`，精确恢复原 Battle+MaxHP `2cca90fb...` 和原 Nodes-only `4c98aac4...` 两份完整身份，再由原 helper 链处理。原 fixture、冻结哈希、内部 helper 实现、断言与时限未改；三份配置专项测试仅显式读取各自原证明拥有的精确投影，新测试另行核对真实组合全部新增分类、顺序和无关字段。24项逆变换/源码测试通过，包含对20项实际新增分类的87个部分删除、重复、改名、错层、换序和无关字段负例，以及缺失/错路径/未知目标拒绝。

原72场景差分完整通过（18×4、总55.196秒，最慢3.699秒/片，原30秒时限），既有 Battle 原生场景差分、12组完整选择接续回滚、实际 Geo/Raiden MaxHP 边界、当前 Battle/Tail 所有权回滚、原生启动变异、11组 MaxHP 生命与7组 Ironclad 获取渠道均通过。既有22组 Node手势、8组 Battle动作所有权、11组点击所有权及 #319 原7组药水失败回归按原时限串行通过；相关 Sapphire/Mark 源合同与内容验证通过。

本组合原生 Luacheck 1.2.0 实测792项职责测量、37条明确历史告警且零新增；Nodes为167项/max15、主文件670/1000行，Battle render为3/10；架构251模块/1395边通过。完整测试/当前组合SHA的远端Full仍未执行，不复用任何单PR旧绿灯；没有GIL、导入、前台输入或实机通过，M3完整内容/自然/平台验收不因此推进。本轮证据在独立云目录 `/tmp/sta-pr309-integration-evidence-20261029/`，由总控对冻结本地HEAD独立复核后决定后续，未推送、创建PR或合并。

## 最新集成基准

当前对齐 develop `03b11fa5d5576f91cf19a2b2ed671b628762a543`，保留上游完整卡牌选择接续回滚、批准稿界面、原预算分片及全部既有门禁。五个Nodes生产文件与已审 `2a1a7bd` 的Git blob完全一致；架构配置仅在上游新增四个Nodes core注册。上游已提供原10组class-choice回归的两片实现，本PR不再携带此前重复的五片测试或其守护脚本，也不修改上游测试断言。

本组合本地13项预算/API坐标政策测试、Backlog检查通过；架构235模块/1324边；原生静态792个受门禁测量，60条明确历史告警、零新增。Nodes仍167项实测/max15，主文件670行。重新生成离线UI夹具后，node_ui_gestures 22组通过（13.622秒，原30秒），奖励来源/所有权守护回归通过；未操作前台或客户端。

此前基准432eebb1上的Full运行40741285548已完整成功。两既有Lua夹具首次超过30秒，在不改源码/断言/时限的一次失败作业重跑中分别25.024/21.771秒通过，原失败及重跑日志均保留。合并前真实目标ref检查发现develop前进，因此该旧组合成功不替代当前基准CI。本次合并需当前头与cec690c1组合的全新Full成功和独立审查，离线证据不代表实机通过。

cec基准首次Full在两个JavaScript分片发现历史UI源守护同时冻结了完整architecture文件，四个新增Nodes/core注册触发原哈希。测试投影现仅识别layers对象末尾精确四行；移除后完整源码必须严格恢复原cec架构哈希0c15a29f，随后原UI各层完整哈希/位置/断言继续执行。没有重置任何原冻结哈希或修改原守护断言，没有修改生产UI或CI。新增两项测试含11个拒绝变体，原8项UI逆变换、12项相关源守护与历史回放，共22/22通过、零跳过；独立增量审查通过。初次本地实现过宽地接受了历史混合，原拒绝断言正确报错；完整cec哈希限制已修正该问题，原失败日志与最终通过均保留于nodes-core-architecture-*.log。

7300c880/cec的Full 40763694404随后完整成功；既有药水失败夹具初次超时，原30秒本地7组20.185秒通过，单次失败作业重跑通过。最终取证前遇到自动权限审查超时，恢复时真实develop已前进至48cb48ce，严格目标ref检查再次拒绝复用旧组合。本次对齐仅继承上游#319预算分片和正式交付合同；architecture字节未变，原精确投影及冻结哈希继续有效。最新51项政策/源守护/正式交付合同测试全过、零跳过，原生792测量/60历史告警零新增、架构235/1324和Backlog通过。当前头的Full仍须重新取得，不把旧基准绿灯当成新基准证据。

等待48基准Full期间，develop合入#303完整选择接续回滚修复；因此继续对齐03b11fa5并保留其Run源码和新增定向回归。Nodes五个生产blob和精确测试投影没有变化，原生792/60零新增、架构235/1325及Backlog复核通过。后续以实际03基准组合取证，不复用48基准作业。

关联 TASK-74.3；基线 origin/develop `1f260a71972b03dae5b63e8d6f12d055973a4c83`。本切片为纯重构，不修改规则、Run/Combat/UI实现，不占用前台或键鼠。

## 完成标准

- `abyss_nodes.lua` 实际物理行数不超过1000。
- Nodes主文件及全部 `abyss_nodes_*.lua` 的每个函数、匿名闭包与初始化块，原生Luacheck圈复杂度不超过15。
- 保留原对外API、参数个数、返回值、拒绝顺序、事务边界、状态身份、共享别名与随机流顺序；覆盖进入、奖励、回滚、第一幕接第二幕和第二幕结算。

## 职责拆分

- common：既有状态查询、资格/升级判断和完成标记。
- entry：原顺序的入口校验、未知房间解析、内容准备、私有战斗暂存、Emerald绑定和提交；进入仍由主服务的Run.transaction包裹。
- events：在原服务表安装事件API；章节处理分别封装，旧事件以有序匹配/执行表表达，保留首个匹配及默认离开行为。
- sources：房间来源的形状、坐标与地图归属校验；先形状再索引，不改变短路顺序。
- 主服务继续负责原API、事务调度、奖励领取、商店支付与重补库存边界、跨幕与结算。新增所有辅助函数同受15门禁。

## 原生实测

工具 Luacheck 1.2.0，二进制SHA256 `0f1c69c4d09f1ebb4d8df14c215e4553e2e639bd4cb7bf3c639b0daa6198317b`。

基线主文件1109物理行，最大复杂度101（enter和chooseEvent）；prepare=25、treasureSource=64。全函数原生报告由 `npm run check:lua-static` 输出至 `build/lua-complexity.json` 和 `build/responsibility-complexity.json`，行数报告为 `build/module-size.json`。

| 文件 | 物理行数 | 函数/闭包/块测量数 | 最大复杂度 | 源码SHA256（原字节） |
|---|---:|---:|---:|---|
| src/lua/abyss_nodes.lua | 670 | 74 | 15 | `12c120637386d4e3668a59155054aecccb2052b92015ee7ada98ed8ecba4e683` |
| src/lua/abyss_nodes_common.lua | 75 | 11 | 14 | `188e967f815e0c7adb9a77a673577ad42778b0ad251d97e7add01ef8b486a784` |
| src/lua/abyss_nodes_entry.lua | 310 | 23 | 14 | `100e9419c6aa738f0d9646af48d9b5ffd4a7ce5c1359caeb13e6afb9d685e83b` |
| src/lua/abyss_nodes_events.lua | 296 | 54 | 15 | `c0881e45c2671dbd5d6f70fe723314668f4bb20711e12e2fbe7b92bef1a2920d` |
| src/lua/abyss_nodes_sources.lua | 46 | 5 | 15 | `daf8bf82db53dc1fd1c8ef38d0356cc2c226d223d60d4883c8a27c96ff9ac310` |

共167项测量，无缺失或重复。主文件与所有辅助函数均达最终标准；没有通过代码压缩或放宽预算达标。现有工程门禁已加入主文件1000物理行和所有Nodes模块15复杂度预算；正负测试覆盖1000/1001、15/16、未点名函数和嵌套匿名函数。

## 行为与API证据

`tests/nodes-governance-baseline.lua` 为基线原模块的冻结副本。本机原字节SHA256为 `a9be0139a86f12f88e0061a91a595504041d1e64b819aa2ffcb3983d62375f5d`；测试核对跨平台LF规范化SHA256 `74ffe0af91db89dc800878d1385bddba27eeef6b232099336eccad04c2859a04`。Git blob为 `85950a2d345cfb28a16031fcab68fca5c828b994`，与基线原文件相同。差分使用真实Run/Map/内容模块及事务，不以复制的新实现充当预期。

72场景逐一比较API全部键与参数数、pcall状态/全部返回值、运行状态与地图的完整图结构、双向共享别名、根/牌组/遗物/钥匙/节点/map/path/data替换行为，以及同一显式外部entropy replay之后的流状态。覆盖四类房间现代/旧版进入、九种旧事件的有效/离开/无效命令、camp、进入失败/内容异常回滚、宝箱领取/来源、战斗胜/逃/败/待奖励、第一幕真实接第二幕及第二幕competition胜利结算。

差分执行分为18段，每段4场景，沿用runLua默认30秒预算；JS包装断言每段精确编号与总72项无遗漏无重复。冻结camp原hash保留；Sapphire仅逆转本轮可审查提取缝以检查实时helper正文，原hash未更新，新增helper RNG/Boss池突变负例。

## 本轮验证

- `npm ci`：依赖安装成功，锁文件未改。
- `npm run check:syntax`：全部JavaScript语法通过。
- `npm run check:architecture`：224模块、1286依赖边通过，四新模块显式注册core。
- `npm run check:lua-static`：通过；Nodes自身零诊断，仓库保留73条历史警告；599项受治理职责测量。
- `node --test tests/nodes-budget-policy.test.mjs tests/responsibility-complexity.test.mjs tests/lua-static.test.mjs`：12/12通过。

- 72场景差分：18段×4项全部通过，总71.98秒，最慢5.61秒/段；其后加强第71/72项的明确成功断言，单独原预算复跑2/2通过（2.941秒），证明第一幕实际进入第二幕、第二幕实际competition胜利。最终组合源码的全72项由总控集成复跑。
- 既有Nodes：11片、21组全部通过，最慢9.301秒/片；`build/nodes-targeted-results.json`保留每片完整stdout及耗时。
- Ruby/Sapphire：原默认预算10/10个Node子测试通过，含Ruby15组与Sapphire21组；Sapphire四片26.264/20.112/18.177/12.409秒。第一次并发验证时Sapphire第二片曾30秒到时，低负载原预算复跑通过；没有改runner或扩大默认预算。
- Beggar15组、Heart Proceed core4/UI3组、Neow历史4/入口UI8组、source token6组、source-owner4组、unknown随机向量6组通过。
- Neow host：独占原30秒预算复跑5/5组通过，17.273秒。首次批次在原预算打印4/5组后到时；复跑前全部其他重例已结束，没有扩大预算，也未将部分输出判作通过。

## 未验证范围

未执行官方编译、候选写入、官方导入、实机、UI验收或发布；不借用旧日志或截图证明此源码实机通过。全仓完整check与PR当前SHA CI由总控集成验收，不以本切片定向通过冒充全仓通过。

## 每函数原生测量

包含所有匿名闭包和五个模块初始化块；complexity来源为固定原生Luacheck的W561测量，不是估算。

| 文件 | 行 | 函数/块 | 复杂度 |
|---|---:|---|---:|
| src/lua/abyss_nodes.lua | 1 | main chunk | 1 |
| src/lua/abyss_nodes.lua | 40 | function 'validateEntryMap' | 14 |
| src/lua/abyss_nodes.lua | 59 | function 'M.enter' | 6 |
| src/lua/abyss_nodes.lua | 67 | function | 1 |
| src/lua/abyss_nodes.lua | 80 | function 'M.beginNeow' | 6 |
| src/lua/abyss_nodes.lua | 82 | function | 5 |
| src/lua/abyss_nodes.lua | 92 | function 'M.advanceAct' | 9 |
| src/lua/abyss_nodes.lua | 96 | function | 2 |
| src/lua/abyss_nodes.lua | 108 | function 'shopOffer' | 7 |
| src/lua/abyss_nodes.lua | 124 | function 'validateShopPotion' | 5 |
| src/lua/abyss_nodes.lua | 133 | function 'restockShop' | 5 |
| src/lua/abyss_nodes.lua | 147 | function 'M.restoreMap' | 7 |
| src/lua/abyss_nodes.lua | 156 | function 'endingOwnerMismatch' | 10 |
| src/lua/abyss_nodes.lua | 163 | function 'endingFlowMismatch' | 5 |
| src/lua/abyss_nodes.lua | 168 | function 'M.endingProceedSource' | 15 |
| src/lua/abyss_nodes.lua | 173 | function | 1 |
| src/lua/abyss_nodes.lua | 181 | function 'M.proceedEnding' | 5 |
| src/lua/abyss_nodes.lua | 188 | function 'eventView' | 10 |
| src/lua/abyss_nodes.lua | 206 | function 'M.view' | 12 |
| src/lua/abyss_nodes.lua | 233 | function 'recallEligible' | 1 |
| src/lua/abyss_nodes.lua | 237 | function 'M.recallSource' | 3 |
| src/lua/abyss_nodes.lua | 243 | function 'M.recall' | 8 |
| src/lua/abyss_nodes.lua | 255 | function | 1 |
| src/lua/abyss_nodes.lua | 256 | function | 2 |
| src/lua/abyss_nodes.lua | 267 | function 'M.rest' | 1 |
| src/lua/abyss_nodes.lua | 268 | function | 4 |
| src/lua/abyss_nodes.lua | 274 | function | 3 |
| src/lua/abyss_nodes.lua | 293 | function 'M.claimRestReward' | 1 |
| src/lua/abyss_nodes.lua | 294 | function | 12 |
| src/lua/abyss_nodes.lua | 308 | function 'M.upgrade' | 12 |
| src/lua/abyss_nodes.lua | 321 | function 'purchaseCommand' | 15 |
| src/lua/abyss_nodes.lua | 344 | function 'purchase' | 1 |
| src/lua/abyss_nodes.lua | 345 | function | 1 |
| src/lua/abyss_nodes.lua | 348 | function 'M.buyCard' | 1 |
| src/lua/abyss_nodes.lua | 349 | function 'M.buyCardSlot' | 5 |
| src/lua/abyss_nodes.lua | 353 | function 'M.buyRelic' | 1 |
| src/lua/abyss_nodes.lua | 354 | function 'M.buyPotion' | 5 |
| src/lua/abyss_nodes.lua | 359 | function 'removeCard' | 8 |
| src/lua/abyss_nodes.lua | 375 | function 'M.removeCard' | 1 |
| src/lua/abyss_nodes.lua | 376 | function | 1 |
| src/lua/abyss_nodes.lua | 379 | function 'M.leaveShop' | 2 |
| src/lua/abyss_nodes.lua | 384 | function 'openSourceTreasure' | 5 |
| src/lua/abyss_nodes.lua | 394 | function 'M.openTreasure' | 1 |
| src/lua/abyss_nodes.lua | 395 | function | 3 |
| src/lua/abyss_nodes.lua | 401 | function 'treasureRewardCoordinatesMismatch' | 11 |
| src/lua/abyss_nodes.lua | 408 | function 'treasureRewardOwnerMismatch' | 5 |
| src/lua/abyss_nodes.lua | 413 | function 'treasureRewardShapeMismatch' | 8 |
| src/lua/abyss_nodes.lua | 419 | function 'M.treasureRewardSource' | 11 |
| src/lua/abyss_nodes.lua | 430 | function 'takeSourceTreasure' | 8 |
| src/lua/abyss_nodes.lua | 444 | function 'M.claimTreasureReward' | 4 |
| src/lua/abyss_nodes.lua | 447 | function | 1 |
| src/lua/abyss_nodes.lua | 450 | function | 1 |
| src/lua/abyss_nodes.lua | 451 | function | 11 |
| src/lua/abyss_nodes.lua | 464 | function 'finishBossTreasure' | 10 |
| src/lua/abyss_nodes.lua | 476 | function 'M.leaveTreasure' | 1 |
| src/lua/abyss_nodes.lua | 477 | function | 3 |
| src/lua/abyss_nodes.lua | 486 | function 'claimTreasure' | 13 |
| src/lua/abyss_nodes.lua | 508 | function 'M.claimTreasure' | 1 |
| src/lua/abyss_nodes.lua | 515 | function 'invalidLegacyTreasureShape' | 5 |
| src/lua/abyss_nodes.lua | 521 | function 'legacyTreasurePair' | 10 |
| src/lua/abyss_nodes.lua | 533 | function 'modernTreasurePair' | 10 |
| src/lua/abyss_nodes.lua | 543 | function 'treasureRoom' | 10 |
| src/lua/abyss_nodes.lua | 556 | function 'M.treasureSource' | 15 |
| src/lua/abyss_nodes.lua | 580 | function 'treasureChoiceSource' | 10 |
| src/lua/abyss_nodes.lua | 589 | function 'M.chooseTreasure' | 2 |
| src/lua/abyss_nodes.lua | 593 | function | 1 |
| src/lua/abyss_nodes.lua | 594 | function | 10 |
| src/lua/abyss_nodes.lua | 614 | function 'claimSourceBossRelic' | 7 |
| src/lua/abyss_nodes.lua | 625 | function 'claimBossTreasure' | 13 |
| src/lua/abyss_nodes.lua | 643 | function 'M.claimBossTreasure' | 1 |
| src/lua/abyss_nodes.lua | 644 | function | 1 |
| src/lua/abyss_nodes.lua | 648 | function 'escapedCombat' | 5 |
| src/lua/abyss_nodes.lua | 653 | function 'unfinishedCombat' | 4 |
| src/lua/abyss_nodes.lua | 658 | function 'M.completeCombat' | 13 |
| src/lua/abyss_nodes_common.lua | 1 | main chunk | 1 |
| src/lua/abyss_nodes_common.lua | 7 | function 'find' | 4 |
| src/lua/abyss_nodes_common.lua | 11 | function 'owns' | 3 |
| src/lua/abyss_nodes_common.lua | 18 | function 'endingKeyEligible' | 14 |
| src/lua/abyss_nodes_common.lua | 30 | function 'playable' | 3 |
| src/lua/abyss_nodes_common.lua | 35 | function 'upgradeable' | 8 |
| src/lua/abyss_nodes_common.lua | 44 | function 'upgradeCards' | 3 |
| src/lua/abyss_nodes_common.lua | 52 | function 'healingPreview' | 2 |
| src/lua/abyss_nodes_common.lua | 57 | function 'matchingMap' | 5 |
| src/lua/abyss_nodes_common.lua | 62 | function 'pending' | 5 |
| src/lua/abyss_nodes_common.lua | 69 | function 'complete' | 2 |
| src/lua/abyss_nodes_entry.lua | 1 | main chunk | 1 |
| src/lua/abyss_nodes_entry.lua | 31 | function | 1 |
| src/lua/abyss_nodes_entry.lua | 32 | function 'unownedRelics' | 14 |
| src/lua/abyss_nodes_entry.lua | 44 | function 'goldenAttack' | 12 |
| src/lua/abyss_nodes_entry.lua | 58 | function 'prepareEvent' | 9 |
| src/lua/abyss_nodes_entry.lua | 76 | function 'prepareBossReward' | 4 |
| src/lua/abyss_nodes_entry.lua | 88 | function 'prepare' | 14 |
| src/lua/abyss_nodes_entry.lua | 117 | function 'M.available' | 9 |
| src/lua/abyss_nodes_entry.lua | 123 | function 'validateEntryIdentity' | 6 |
| src/lua/abyss_nodes_entry.lua | 129 | function 'validateRunEntry' | 11 |
| src/lua/abyss_nodes_entry.lua | 138 | function 'entryNode' | 9 |
| src/lua/abyss_nodes_entry.lua | 149 | function 'endingDoor' | 5 |
| src/lua/abyss_nodes_entry.lua | 154 | function 'enterEnding' | 13 |
| src/lua/abyss_nodes_entry.lua | 167 | function 'drawEvent' | 4 |
| src/lua/abyss_nodes_entry.lua | 178 | function 'resolveUnknown' | 8 |
| src/lua/abyss_nodes_entry.lua | 194 | function 'validateEvent' | 11 |
| src/lua/abyss_nodes_entry.lua | 204 | function 'prepareFlow' | 7 |
| src/lua/abyss_nodes_entry.lua | 220 | function 'prepareEmerald' | 8 |
| src/lua/abyss_nodes_entry.lua | 231 | function 'stageCombat' | 10 |
| src/lua/abyss_nodes_entry.lua | 249 | function 'commitEmerald' | 4 |
| src/lua/abyss_nodes_entry.lua | 260 | function 'commitCombat' | 2 |
| src/lua/abyss_nodes_entry.lua | 273 | function 'commitRoom' | 4 |
| src/lua/abyss_nodes_entry.lua | 292 | function 'enter' | 13 |
| src/lua/abyss_nodes_events.lua | 1 | main chunk | 1 |
| src/lua/abyss_nodes_events.lua | 22 | function | 1 |
| src/lua/abyss_nodes_events.lua | 24 | function 'legacyOptions.living_wall' | 7 |
| src/lua/abyss_nodes_events.lua | 30 | function 'legacyOptions.fountain' | 1 |
| src/lua/abyss_nodes_events.lua | 33 | function 'legacyOptions.cleric' | 2 |
| src/lua/abyss_nodes_events.lua | 39 | function 'legacyOptions.purifier' | 1 |
| src/lua/abyss_nodes_events.lua | 42 | function 'legacyOptions.upgrade_shrine' | 3 |
| src/lua/abyss_nodes_events.lua | 45 | function 'legacyOptions.golden_shrine' | 3 |
| src/lua/abyss_nodes_events.lua | 51 | function 'legacyOptions.goop' | 1 |
| src/lua/abyss_nodes_events.lua | 56 | function 'legacyOptions.shining_light' | 3 |
| src/lua/abyss_nodes_events.lua | 59 | function 'legacyOptions.golden_wing' | 2 |
| src/lua/abyss_nodes_events.lua | 69 | function 'M.eventOptions' | 7 |
| src/lua/abyss_nodes_events.lua | 76 | function 'option' | 1 |
| src/lua/abyss_nodes_events.lua | 90 | function 'damage' | 1 |
| src/lua/abyss_nodes_events.lua | 92 | function 'invalidCurseIdentity' | 7 |
| src/lua/abyss_nodes_events.lua | 98 | function 'invalidCurse' | 8 |
| src/lua/abyss_nodes_events.lua | 104 | function | 2 |
| src/lua/abyss_nodes_events.lua | 105 | function | 2 |
| src/lua/abyss_nodes_events.lua | 110 | function | 4 |
| src/lua/abyss_nodes_events.lua | 111 | function | 5 |
| src/lua/abyss_nodes_events.lua | 119 | function | 2 |
| src/lua/abyss_nodes_events.lua | 120 | function | 1 |
| src/lua/abyss_nodes_events.lua | 123 | function | 2 |
| src/lua/abyss_nodes_events.lua | 124 | function | 7 |
| src/lua/abyss_nodes_events.lua | 136 | function | 2 |
| src/lua/abyss_nodes_events.lua | 137 | function | 1 |
| src/lua/abyss_nodes_events.lua | 140 | function | 2 |
| src/lua/abyss_nodes_events.lua | 141 | function | 1 |
| src/lua/abyss_nodes_events.lua | 144 | function | 2 |
| src/lua/abyss_nodes_events.lua | 145 | function | 6 |
| src/lua/abyss_nodes_events.lua | 152 | function | 2 |
| src/lua/abyss_nodes_events.lua | 153 | function | 6 |
| src/lua/abyss_nodes_events.lua | 168 | function | 2 |
| src/lua/abyss_nodes_events.lua | 169 | function | 3 |
| src/lua/abyss_nodes_events.lua | 174 | function | 2 |
| src/lua/abyss_nodes_events.lua | 175 | function | 2 |
| src/lua/abyss_nodes_events.lua | 181 | function | 3 |
| src/lua/abyss_nodes_events.lua | 182 | function | 4 |
| src/lua/abyss_nodes_events.lua | 190 | function 'chooseLegacy' | 4 |
| src/lua/abyss_nodes_events.lua | 197 | function 'chooseLivingWall' | 3 |
| src/lua/abyss_nodes_events.lua | 204 | function 'chooseAct1' | 7 |
| src/lua/abyss_nodes_events.lua | 216 | function 'chooseAct3' | 7 |
| src/lua/abyss_nodes_events.lua | 226 | function 'chooseAct2' | 5 |
| src/lua/abyss_nodes_events.lua | 236 | function 'chooseNeow' | 3 |
| src/lua/abyss_nodes_events.lua | 243 | function 'chooseFountain' | 2 |
| src/lua/abyss_nodes_events.lua | 250 | function 'chooseEvent' | 15 |
| src/lua/abyss_nodes_events.lua | 269 | function 'M.chooseEvent' | 1 |
| src/lua/abyss_nodes_events.lua | 270 | function | 1 |
| src/lua/abyss_nodes_events.lua | 273 | function 'M.upgradeEvent' | 1 |
| src/lua/abyss_nodes_events.lua | 274 | function 'M.chooseAct2EventCard' | 4 |
| src/lua/abyss_nodes_events.lua | 279 | function 'M.chooseAct1EventCard' | 4 |
| src/lua/abyss_nodes_events.lua | 284 | function 'M.chooseLivingWallCard' | 4 |
| src/lua/abyss_nodes_events.lua | 289 | function 'M.purgeWing' | 1 |
| src/lua/abyss_nodes_events.lua | 291 | function 'M.purifyEvent' | 5 |
| src/lua/abyss_nodes_sources.lua | 1 | main chunk | 1 |
| src/lua/abyss_nodes_sources.lua | 9 | function 'M.invalidMapOwner' | 6 |
| src/lua/abyss_nodes_sources.lua | 14 | function 'M.invalidRoomOwner' | 11 |
| src/lua/abyss_nodes_sources.lua | 21 | function 'M.roomMapMismatch' | 7 |
| src/lua/abyss_nodes_sources.lua | 28 | function 'campSource' | 15 |
