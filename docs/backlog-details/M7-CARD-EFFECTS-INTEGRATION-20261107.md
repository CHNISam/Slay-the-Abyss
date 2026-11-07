> 历史两片集成记录：以下指标和59项结果只对应 [PR543 原提交 2fc0cbfd](https://github.com/FurinyaWorks/Slay-the-Abyss/commit/2fc0cbfd4dbb96eaafccfc6855dd5681b5b1a3cb)。追加Session及双方测试后的结果见 [最终并集](M7-SESSION-INVENTORY-SUPERSET-20261107.md)，不能把本记录当作新HEAD验收。

# Watcher 与 Inventory 效果职责集成

接续 TASK-74.20，以实际 develop `2ad07111e3d5b5cb52b4229860b3b780941e29a9`（#539）为基线，集成已独立实施并深审的 Watcher `1bccd73a` 与 Inventory `a6a4d8f9`。具体行为、冻结来源和负控见 [Watcher](M7-WATCHER-EXECUTION-20261107.md) 与 [Inventory](M7-INVENTORY-RESPONSIBILITIES-20261107.md)。同轮 Power 候选已与两者做本地组合验证，但因在途 [PR #541](https://github.com/FurinyaWorks/Slay-the-Abyss/pull/541) 已承接重叠职责，本次交付不含 Power、Shop 或其依赖配置，避免重复 PR 和 Full。

## 同口径结果

[本轮机器证据](../evidence/m7-card-effects-integration-20261107.json)记录基线和当前所有333份源码摘要、目标全函数、残余高CC及SCC成员。采用原完整AST、固定Luacheck 1.2.0和全部即时/延迟边口径，没有修改测量器或原基线。

- CC>30：58→54；CC>15：237→232；最大CC：75→69。
- 全函数/初始化完整测量：5386→5428，无缺测。基线比原切片的2c85多一项测量，来自已合#539，不能混用5385。
- Watcher execute：75→2，16个私有执行函数最大13；原无关withCards24、choose22保持为待治理，不宣称整个模块已达CC15。
- Inventory energyBonus/opening/validate/apply：20/33/34/53→4/9/6/6；36项全模块测量最大14，全部含未来helper、匿名函数和初始化块受CC15。
- SCC仍为81/15，内部位置623/62、唯一内部依赖对400/41均不变。全图333模块/1920依赖位置不变。本次不计入另一Power候选的81→74降幅。
- 14条历史静态告警不变，无新增豁免。Combat和Run继续持有原状态提交及事务回滚；无新注册框架或模块。

## 集成合同与限制

共享CC门禁取两个切片并集；来源逆桥逐次校验Watcher与Inventory当前完整owner，再进入原M7/N35来源链，旧archive/oracle及原读取次数断言保留。CI库存保留#539既有增量，再加入两份JS与Watcher Lua，均以原未知成本进入完整库存，不编造实测或调整分片预算。

#541还会修改同一静态门禁、CI库存及TASK-74.20；后合方须保留双方并集，#541的独立规划floor及其证明也不能被覆盖。双方运行时代码没有重叠，本PR不预先纳入未合依赖。

本轮精确范围6份JS专项共59/59通过（0失败/0跳过），包含两片完整旧新VM行为、真实语义负控、来源、库存及原静态/职责门禁。独审四种入口、37个实际owner、双包装来源桥获得296次正常/恢复投影与444次异常/缺失/漂移正确拒绝；完整依赖图与基线逐项相等。共享工程采集、指引、Backlog范围/doctor及diff检查通过。精确提交由独立交付收据绑定。早期三片试验的稀疏检出缺失.github/.cursor/.codebuddy导致库存/指引失败，已保留失败日志并补齐真实仓库文件，未删断言或改检查器。三片组合的64项通过只证明该实验组合，不替代本次两片精确范围验收。

不重复本地Full。托管PR、原生队列和实际合后Full分别按精确源码验收；尚未合并不勾任务AC，剩余54个CC>30和81/15依赖环继续待治理。官方导入、ready、设备与发布均未执行。
