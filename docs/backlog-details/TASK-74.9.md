# 原生结束回合职责

基线 `b4ac63145689b9dd632db100eee49087f6182b39`；完整旧 `abyss_combat.lua` 由 `tests/fixtures/native-turn-end-before.json` 的压缩原文冻结，规范化 SHA256 为 `2e6a406674d95f0037892120301b684857414dc75b9b225fec2052ff8ed6b55a`。测试直接认证旧源，不依赖 Git 历史或改写黄金。

仅治理 `endNativeTurn` 与其内嵌玩家结束清理。十个同模块 helper 分别负责费用重置、玩家预处理、自动结束牌、玩家能力、保留前能力、保留弃牌、玩家清理、敌人组开始、敌人行动快照和轮末。实验协议、开回合、构造器及公共 API 未改。

保留这些语义：

- `resumingRetain` 在原入口捕获，持续传递同一值；`silentRetainResume=nil` 仍在玩家清理原位置，不因新的入口调用重新读取。
- 普通 native 在敌人阶段前清理；V4 在全部敌人行动与组末处理后才清理。原暂停/终局的 true 返回逐层传回。
- Regret/Burn 先形成 UID 快照，手牌数量只捕获一次；致死时保留 `cardInUse`，后续弃牌和能力不执行。
- 敌人统一清 Block 后再逐敌开始效果；行动列表只形成一次快照，新召唤不在当轮追加行动。原每个阶段的 drain/finish 位置不动。

## 指标与验证

机器证据：[native-turn-end-20261105.json](../evidence/native-turn-end-20261105.json)。固定 Node24.18.0、Luacheck1.2.0。

| 同一完整源码集 | 旧 | 新 |
| --- | ---: | ---: |
| endNativeTurn CC / 行数 | 38 / 137 | 12 / 19 |
| 内嵌 cleanupPlayerEnd CC / 行数 | 37 / 66 | cleanupNativePlayerEnd 11 / 16 |
| 新增具名 helper | 0 | 10，最高 CC11 |
| 入口与受影响 helper 总 CC | 75 | 90 |
| 全库函数 / 完整测量 | 4779 / 5102 | 4788 / 5111 |
| CC>15 / CC>30 / 最大 CC | 282 / 78 / 82 | 280 / 76 / 82 |
| 模块 / 唯一依赖对 / 调用点 | 323 / 1507 / 1876 | 不变 |
| 最大 SCC 成员 / 内部调用点 | 104 / 805 | 不变 |
| 精确静态告警 | 15 | 不变 |

总 CC 增加包含新函数的基础路径与保持原退出语义的逐层停止检查；不把局部入口下降称为总分支、依赖环或性能改善。所有新增 helper、原 nativeEthereal 及入口受现有 CC15 硬门禁约束，具名/匿名超限与缺测量负例保持。

本轮证据：

- 展开十个 helper、恢复原 `cleanupPlayerEnd` 嵌套闭包后，**整个 Combat 源码**逐字等于固定旧源；旧规范化 hash 如上。此证明也核对切片外源码没有改动，原文只作机械移动。
- `native-turn-end.test.mjs` 在独立 VM 比较完整旧/新状态图，包括 catalog/rules/data、对象别名、事件、RNG、队列、返回与异常；13场景通过。原始Lua默认只输出摘要，大轨迹仅由专用驱动开启。
- 三项真实源码变异：提前V4清理、把native敌人快照改为实时遍历、保留恢复重复玩家Power，全部被 `[NATIVE_END]` 行为断言拒绝。未把解析/加载失败算kill。
- 主控当前组合16/16通过，完整图对照约17.5秒，变异约1.95秒；该结果不代替后续精确SHA独立审查或Full。
- 13份原回归全部在原预算内通过：owner_end_native_cleanup、owner_end_retention、owner_end_rollback、owner_end_order、owner_end_powers、owner_end_membership、owner_end_pre_cards、warrior_exhaust_endturn、original_v4_lifecycle、original_v4_contract、reptomancer_public、reptomancer、watcher_final_block_retention。逐入口时长见机器证据。
- 统一工程门禁通过，完整测量5111/5111，无新增静态诊断；`git diff --check` 通过。

复验：生成原 `build:data`，安装固定Luacheck；用Node24执行 `node --test --test-concurrency=1 tests/native-turn-end.test.mjs tests/responsibility-complexity.test.mjs`，随后执行 `node scripts/check-engineering.mjs`。13份原Lua回归使用现有 `runLua`，没有改deadline或正常raw输出预算。

TASK-74.9保持 In Progress，AC不提前勾选。精确HEAD独立复审、Full、实际合入提交push验收仍待；无候选构建、官方导入、ready或设备实测，不宣称全库热点已解决。
