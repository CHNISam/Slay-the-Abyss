# 活墙读取移除战斗反向引用

`abyss_living_wall.lua` 仅为 `purgeCards` 中唯一的 `C.copy(card)` 导入 Combat。本切片只将该导入换成现有 `abyss_copy`；其余完整模块字节不变。旧源固定 `b4ac63145689b9dd632db100eee49087f6182b39`，与7d组合该模块相同；完整旧文件及SHA认证保存在 `tests/fixtures/living-wall-copy-before.lua`。

合法事件命令仍通过原 `Run.removeCard/obtainCard` 提交，不移动单局所有权。这些 choose 路径仍可合理加载 Combat；只承诺模块读取与卡牌筛选不再加载它。未改 Combat、实验结束阶段或公共静态门禁。

新增 `living-wall-copy-isolation` 结构边界，禁止 LivingWall 直接或延迟导入 Combat；复用现有 AST 检查器。真实恢复旧导入、在函数内部重新 require 的负例均按具体边界拒绝，不靠解析失败冒充有效门禁。

## 本轮证据

固定 Node24.18.0。机器证据：[living-wall-copy-20261105.json](../evidence/living-wall-copy-20261105.json)。

| 同一模块集仅对照该导入 | 旧 | 新 |
| --- | ---: | ---: |
| 新鲜VM读取并执行purgeCards后，已加载abyss模块 | 75 | 35 |
| Combat是否被加载 | 是 | 否 |
| 全图模块 / 唯一依赖对 / 调用点 | 323 / 1507 / 1876 | 不变 |
| 最大SCC成员 / 内部调用点 | 104 / 805 | 104 / 804 |

每个数值样本都启动全新CLI VM，不预热、不先替换传递依赖；机器报告保留两份真实模块清单。减少40个读取路径加载模块与一条SCC内部反向引用，不表示整个SCC已消除，也不外推游戏首启时间、内存或FPS。

- 原实现上新专项出现真实红灯：读取阶段被Combat加载阻断；模块计数仍75，生产结构规则尚缺。修复后专项4项通过。
- 固定完整旧源与新源在独立VM跑同一复制筛选fixture，完整输入/输出/重复查询的图序列逐字相同；保护诅咒的源ID与本地ID、三类瓶装、卡组顺序、循环、对象别名、table key、每张卡独立复制、返回副本写入隔离、RNG不变均有行为断言。
- 恢复旧导入在冷VM阻断中仍失败，防止测试误预热而失效。直接/延迟回退由真实生产边界拒绝。正常raw入口摘要输出，不打印大型差分。
- 与原 `living-wall-slices.test.mjs` 组合5/5通过，保留原11类事件与72个有序变换来源槽位、精确随机流、stale UID/瓶装及失败原子断言，未修改黄金或断言。
- 补齐原生成的UI展示/主题模块后，原 `living_wall_ui.lua` 4个交互模拟场景通过，包括忘却、成长、变换及空卡组；不是官方客户端实机验收。
- 源码恢复单行导入后与固定旧源逐字一致，仅作为本轮证据；正常测试不冻结整个当前行为正文，后续合法事件修改仍通过行为合同验收。`git diff --check`通过。

复验：用Node24执行 `node --test --test-concurrency=1 tests/living-wall-copy-dependency.test.mjs tests/living-wall-slices.test.mjs`；UI模拟需先按原 `build:ui`、`build:theme` 生成前置。完整模块清单及图日志留在 `build/living-wall-copy/`，正常测试无需这些本地产物。

本轮不并发修改Backlog；交主控统一记录TASK-74.11进度。独立复审、精确组合HEAD Full与实际合入push验收分别保留待验证；无候选构建、官方导入、ready或设备实测。
