# TASK-74：节点与事件直接使用纯复制模块

基线：`aa4d56f57c15727668ef8675e626b44e67a5aaa5`（2026-11-03 fetch 后的 `origin/develop`）。仅修改 `abyss_node_ui_camp`、`abyss_node_ui_rewards`、`abyss_drug_dealer_event` 的复制依赖；不涉及在途 PR486 的初始化模块或共享配置。

## 变化与兼容边界

三个模块原本只使用 `Combat.copy`，现在直接捕获 `require('abyss_copy').copy`。`abyss_combat.lua:140–141` 原本就将同一函数公开为 `Combat.copy`，本轮保持该兼容API与复制算法原样。

物理依赖变化：这三个模块各移除1条到 `abyss_combat` 的直接边，共少3条 Combat 入边；各新增1条到 `abyss_copy` 的直接边。总直接边数没有因此减少。模块其他依赖仍可间接加载 Combat；不声称完整SCC缩小、少加载三个模块、设备提速或内存下降。

全仓检索的现有 `Combat.copy` 运行时猴补丁位于 `tests/lua/potion_candidate_boundaries.lua:96`，作用于药水效果复制异常边界，本轮未改其调用者，原14项拒绝/异常测试通过。任意外部代码若故意替换 `Combat.copy` 来拦截这三个模块的复制，替换后将不再拦截；仓库未查到这种使用，不将这种动态替换视为已保留合同。公开函数本身仍可调用且与纯复制函数相同。

## 本轮证据

- 新 `tests/node-event-copy.test.mjs` 在旧源上先红：真实加载营地模块时由 `[COPY_DEPENDENCY] ... directly imports combat` 拒绝；三模块修改后通过。
- `tests/lua/node_event_copy.lua` 实际执行营地行同步/升级预览、Duplicator/净化/Library/Neow行同步、增幅师候选过滤，核对循环、共享子表别名、源隔离、独立复制调用、升级预览只读、保护诅咒与随机计数不变，以及 `Combat.copy == Copy.copy`。加载探针只拦每个模块自身导入，不把已预热的真实传递依赖算作直接依赖。
- 在本树 `build/node-copy-baseline.mjs` 从上述精确Git基线读取三个完整旧模块，以相同调用夹具执行旧/新版本；仅导入断言按旧版依赖调整，全部行为断言不变，两边通过且输出一致。浅复制错误变异由同一 `[COPY_GRAPH]` 别名/循环/隔离断言拒绝。该临时对照保留在独立树 `build/node-copy-baseline/`，不引入历史源码inverse或冻结金样。
- 标准定向入口 `node --test tests/node-event-copy.test.mjs tests/camp-rest-upgrade-origins.test.mjs tests/reward-upgrades.test.mjs tests/act2-choice-events.test.mjs tests/event-card-picker-ui.test.mjs`：**9/9通过**。原营地/奖励两个wrapper在改动前亦2/2通过；既有事件测试覆盖实际Nodes事务、两卡移除/随机/取得顺序、失败回滚及原生选择所有权。
- `node scripts/test-lua.mjs tests/lua/copy_graph.lua`：通过，核对图复制/键/隔离/memo/原API；`node scripts/test-lua.mjs tests/lua/potion_candidate_boundaries.lua`：通过。
- `npm run check:architecture` 首次因隔离树可解析依赖缺少 `luaparse` 而未运行成功（`ERR_MODULE_NOT_FOUND`）；随后核对既有 `ci-stability/node_modules/luaparse` 版本为0.3.1，仅在本树 `node_modules` 建junction复用，检查通过：320模块、1853条边，未改配置或安装包。

只执行本地定向检查，不重复完整CI；最终组合独立复审及必需CI由主控负责。本轮无候选构建/写入、官方导入、ready或设备验证，不据此勾选相关平台验收。
