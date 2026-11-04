# Combat Reactions：首个职责切片

本轮接续核对已有远端 `feat/combat-reactions@1bd99a285832029d0b9690356c56bf3699fc2110`（当时无 PR），与本地 `7fe5ee11c4f735b10e050b93501efe71ad4e0003` 属同一切片。唯一开放实施 PR 为 #511：复用旧分支的命名兼容门面、Actor 单次导入、固定 Oracle 与四种变异；保留本地坏政策、必需入口、两字段 nil 恢复和候选清单测试。原提交与分支均保留，不把已有成果归为本轮新写。

协助既有 TASK-74（Furinya / In Progress），不接管 TASK-74.5。基线 `c1cf79dfa8e81189546d95277d3bb891d831ba6e`，落实[领域实施计划](../plans/2026-11-03-domain-architecture-implementation.md)的首个入队边界；不是全库领域化完成。[机器证据](../evidence/combat-reactions-20261104.json)记录口径与当前源码身份。

## 行为与兼容

`abyss_combat_reactions` 逐字承接原两个入队函数；Actor 直接使用该窄能力，保留 player-source 断言。CardActions 仍提供普通读取、调用、赋值可用的 `enqueue` / `enqueueReaction`，通过两属性门面共享同一入队函数槽：旧测试替换 enqueueReaction 仍能观察 Actor，legacy 仍动态调用可替换的 enqueue。其余字段保持普通 Lua 表行为。

这有明确的反射成本：两入口不再是 CardActions 的 raw slot，rawget 为 nil，pairs/next 或据此复制表会遗漏它们；getmetatable 改变；rawset 或替换 metatable 可以遮蔽/破坏转发。源码和错误栈位置也变化。已检查源码及测试调用者，未发现依赖此类反射的消费者；不将这些操作宣称为兼容接口。未增加 __pairs、回调注册表、反向注入、全局事件总线或另一套队列。普通动态替换/恢复、nil 后恢复及重入恢复有独立断言。

队列优先级、top/bottom、默认 source、effect/instance 引用、nil 返回和 typed 校验错误沿用原实现。Combat 的 drain、事务、RNG 与胜败/暂停策略未改。真实 plated armor、复活尾巴与 Act 3 测试保留，覆盖暂停续动与失败后的状态、RNG、对象身份恢复。

Nob 的 `beforeCard` 也接入 `Reactions.enqueue`，仅替换其单一依赖；保留 enemy source 和旧 legacy 入队，即使存在 typed actionQueue 也不改路由，不替换成 `enqueueReaction`。共享门面确保现有 `CardActions.enqueue` 动态观察仍有效。新政策禁止 Nob 再导入 CardActions；规则缺失先红，恢复实际旧导入的负例由原分析器拒绝。

## 结构约束与测量

现有 analyzeSources 复用同一次 AST 的全部 edges，按 dependencyBoundaries 拒绝 Actor→CardActions 及反应入口→Actor/CardActions/Combat；延迟导入不豁免。原 Actor 延迟例外删除，新模块显式分类 core。规则数组、重复、空值、未知模块有负例；生产规则删除/清空有语义防回退测试。新入队模块和两个门面函数均受原 CC15 硬门槛约束。

| 同口径完整图 | 前 | 后 |
| --- | ---: | ---: |
| 模块 | 322 | 323 |
| require 位置 | 1876 | 1876 |
| 唯一依赖对 | 1506 | 1507 |
| 最大 SCC 成员 | 105 | 104 |
| SCC 内部引用位置 | 809 | 805 |
| SCC 内部唯一依赖 | 542 | 539 |

Actor→CardActions 两处直接引用消失；Nob 接入窄入队入口后退出大 SCC，SCC 数量仍为 1。Actor、CardActions 加新模块的 CC 总和（包含模块 chunk）从 927 增至 934；Nob 自身 CC 总和仍 16、最大 6。Actor 最大 CC60、CardActions 最大 CC25 的旧热点仍在，新模块最大 CC4、两个门面各 CC3。不能据拆文件声称全局复杂度下降或运行时提速。

## 验证与退出边界

测试先固定原入队函数 Oracle，再验证新模块独立加载；top/bottom、typed 所有权、引用复制与意外 drain 四种负对照均被行为断言拒绝。原 action registry 的完整历史 fixture/hash 不变，只将当前 supports 窗口的结束标记改为提取后实际存在的 reactionRetained；原历史窗口仍截止 enqueue，全部政策漂移负例保留。

已有分支附件报告的 Node24.19/Linux 结果（聚焦61、历史20、候选9、原生UI6及七个真实Lua入口）属于该提交的历史证据，不冒充当前 HEAD 已通过。本轮 Node22.22.1/Windows 重新测量前后指标；初版工程门禁通过，38项伤害、选择、职责与 Run 回合/选择/保留牌晚奖励失败回滚通过，原注册器三组完整状态/队列/返回值/RNG差分通过，Plated Armor 49场景通过；集成后重新运行固定Oracle、四种反应变异、独立加载、候选清单、AST边界及复杂度测试。候选清单包含新依赖，不把离线清单检查当作官方导入。

本切片不修改工作流、Required Checks、Ruleset、超时、原阈值或历史黄金。全分支独立审查、精确 HEAD 托管 Full、合后 squash/push 验证另验；官方导入、ready 与设备未测，父任务最终 AC 不勾，正常门禁合并由主控协调，不自动发布。

Nob 接线后本轮实际验证：独立入队/架构 7 项通过；既有 `gremlin_nob_ai.lua` 12 组通过（含全部 100 roll × 9 histories、128 HP seeds、32局12回合历史、失败出牌事务回滚），`basic_curses.lua` 19 组通过（含 Pain 先于 Enrage、致死 Pain 取消 Enrage）。这些是离线真实生产调用，不冒充设备或合后验证。

## 原生队列基线整合

#508 正常合入后的实际 `develop@a73e6a8ffa9d3299f09e88e90f031738d83549b4` 为本次新集成基线。原测量基线 c1cf79df 保留；Git 逐项核对两基线的 `src/lua` tree 及 `config/architecture.json` blob 完全相同。领域切片以四个线性提交重放，源码 tree 与架构 blob 与原已审 1d6b38b7 相同；重算完整图匹配上述指标。完整原历史在 `archive/pr511-before-integration-20261104@1d6b38b7907d622330d795d4499d794abb46b734` 可恢复。

旧 8bb93734 的 Full 失败来自三份历史逆投影测试的架构身份未适配；本轮精确逆转本切片的注册/边界/旧 deferred 变化，保留所有原 hash、断言与 linked-owner 检查。新基线上的最终组合独审、托管 Full、真实队列合并与合后验证仍须分别取证；旧 CI 不冒充新组合通过。
