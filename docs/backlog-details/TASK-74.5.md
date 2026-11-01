# 卡牌消耗动作整理

本切片仅整理 `abyss_card_actions` 的五种消耗动作：随机消耗、焚烧之火、消耗非攻击牌、重振精神、指定UID消耗。四个同模块局部函数按动作职责承接原循环；两种非攻击牌动作共用同一职责。选择、队列推进、伤害治疗、战斗构造器、RNG与回滚实现均未改动。入口仍在原分支位置分派，保留原TOP插入及抽牌钩子顺序。

基线为 `a5da67aaaf018bfd6d92e32af5c7bcd9a0866a59`。机器证据摘要见 [core-exhaust-20261029.json](../evidence/core-exhaust-20261029.json)。原始报告、冻结旧源与轨迹保存在本切片工作树 `build/exhaust-parity/`。

| 指标 | 整理前 | 整理后 |
| --- | ---: | ---: |
| 模块物理行数 | 433 | 446 |
| 完整入口跨度 | 157 | 137 |
| 入口圈复杂度 | 118 | 102 |
| 随机消耗helper | — | 5 |
| 焚烧之火helper | — | 3 |
| 非攻击消耗helper | — | 6 |
| 指定消耗helper | — | 2 |
| 入口与四helper复杂度之和 | 118 | 118 |
| 全库模块/依赖调用点 | 258 / 1441 | 258 / 1441 |
| 完整依赖强连通分量成员/内部调用点 | 76 / 496 | 76 / 496 |
| 精确静态告警 | 37 | 37 |

依赖对与告警列表逐项相等，既有调用点行号随函数移动。helper及其嵌套函数接入已有≤15职责门禁，附缺入口、缺测量及超限真实失败对照。入口102与其他既有热点仍未治理；此切片没有减少总分支，也不代表核心Lua整体完成。

本地验证：

- 固定Node24.18.0，原完整旧源与新源分别在独立Fengari VM运行同一fixture，169条真实入队及动作边界轨迹逐字一致。双方输出SHA256均为 `0c224d441be16c2bbe343ac04977711fdef897a185dfab7ba218a21b6da5a754`。轨迹覆盖RNG调用参数/结果/counter、四牌堆顺序及实例引用、队列、事件和暂停恢复；仅省略不可变catalog/rules/sourcePools/statusDefinitions。真实C.play异常回滚另逐表核对所有原引用和键值，包含这些不可变目录。
- 五种真实源码变异（单牌漏RNG、快照数量减少、非攻击筛选颠倒、TOP变BOTTOM、指定UID错误）全部由行为断言拒绝；退出码或解析失败不能算kill。
- 原始combat、atomic_play、warrior_status_build、三份warrior_exhaust、两份corruption_cost，加新fixture，共9个Lua入口全过；原测试含正常Fiend Fire/Second Wind/Sever Soul及实验路径。新fixture直达本切片实际分支，弥补只测另一路计划器的不足。
- 31项相关JS工具与行为检查通过，0失败/0跳过；原M1–M4四项关键语义变异全部被真实断言杀死。质量、架构、静态、语法及原生UI合同门禁通过。
- 初次差分因完整不可变目录反复输出超过原runner预算失败，改为仅省略上述不可变目录后成功；未提高预算。原生UI合同首次因独立树未生成地图布局失败，按原构建步骤生成后4项全过；没有修改合同断言或产品修复。

重放：先执行 `npm run build:data`、`npm run build:ui`、`npm run build:theme` 与 `node scripts/map-ui-layout.mjs`，再运行 `node --test tests/card-actions-exhaust.test.mjs tests/responsibility-complexity.test.mjs`。旧新差分的旧源按上述固定提交的完整文件及机器证据中的规范化hash核对后预载；fixture设 `ABYSS_EXHAUST_TRACE=true` 开启边界轨迹。普通回归不打印大型轨迹，不引入新的全源码inverse链。

远端当前HEAD完整Quality与独立PR审查尚待。没有构建候选、官方导入、真实ready或实机测试，不据此关闭任何产品关口。
