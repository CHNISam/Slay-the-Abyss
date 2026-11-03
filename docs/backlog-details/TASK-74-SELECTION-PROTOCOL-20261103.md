# TASK-74 / 74.5：卡牌选择协议职责收敛

源码基线 `aa4d56f57c15727668ef8675e626b44e67a5aaa5`，独立分支 `feat/m9-core-20261103`。本片只治理 `abyss_card_actions.lua` 的候选资格、发起选择、执行单张选择、单选重验与多选提交/切换协议；不重复已合 #341 的消耗helper或 #371 的动作分派表，不触碰在途节点复制、Run初始化、计时/中文切片。

## 实际改动

- 候选牌堆路由与资格判断分开，共用原资格条件；保持每张候选都先调用 `cardDefinition`，不改变其观察顺序。
- 统一选择的序号、pending拥有者及发出事件；保留单候选自动选择、固定数量自动取得、可多选、Dual Wield手动选择四条原分支。
- 具体选牌动作采用有限职责表。Dual Wield保留选中原牌移除、可选牌先归还、其余牌后归还、手动额外复制1张与每张两次created钩子；满手牌恢复分支仍不发resolved事件。
- 单选先检初始UID再检当前资格；多选先检全部已选项，再区分提交和切换。提交前清pending、原选择顺序、TOP抽牌、序号更新、错误/拒绝与公开API语义保持。

## 当前源测量（不是历史附件的118/102）

固定Luacheck1.2.0（工具自行验SHA）与luaparse0.3.1，扫描全部320模块。基线5036/5036项，最终5052/5052项，包含新增函数、匿名函数及主chunk。机器结果：[m9-core-selection-20261103.json](../evidence/m9-core-selection-20261103.json)。

| 职责 | 基线CC / 跨度 | 最终CC / 跨度 |
| --- | --- | --- |
| candidates | 16 / 12 | 6 / 9 |
| selection | 18 / 25 | 12 / 21 |
| M.applyChoice | 26 / 49 | 2 / 6 |
| M.choose | 34 / 51 | 10 / 13 |
| 已有M.apply（未改） | 5 / 11 | 5 / 11 |
| 已有M.drain（残余，未改） | 25 / 24 | 25 / 24 |

20个受影响职责（包括全部新helper）最高CC12，单个最长21行。原4函数到20职责，决策点总数Σ(CC−1)为90→76；含每函数基数的CC总和94→96，不能把拆分数量带来的指标变化当作全局分支消失。模块520→547行，最高CC34→25。

全库函数4716→4732，CC>15数量290→286，CC>30数量83→82；全局最高CC88、最长函数1004行、>1000行文件2个均未变。唯一依赖对1461、调用点1853、最大完整SCC103模块/789内部调用点均未变；依赖对与SCC逐项相同。精确静态告警15条逐项相同，无新增。当前没有整体Core治理完成或运行时性能改善的结论。

新增标准门禁测量整个CardActions模块，不通过将新helper移到段外逃避预算；唯一明确保留的既有队列热点为M.drain=25。主控另将20个职责接入已有静态责任门禁，本片不改其共享脚本/配置。

## 行为、差分与负例

- 新选择夹具6组真实C/A命令：固定恢复数量/顺序与token、多选弃牌抽回/消耗、单/多选实时资格、Dual Wield单候选/手动差异、牌堆/零数/满手/非法动作，以及公开 `C.chooseCard` 中途异常后的完整原对象图回滚并重试。回滚逐表核对所有键值及原引用，包含目录/规则。
- `scripts/card-selection-parity.mjs <基线40位SHA>` 从Git读取完整旧模块，旧/新分别在独立Fengari VM执行同夹具，完整输出逐字相同：选择76、原registry39、原exhaust169，共284边界。包含返回值、四牌堆/对象别名、RNG完整状态、队列、事件和pending/token；序列化仅省略不可变catalog/rules/sourcePools/statusDefinitions，这些仍受完整回滚断言覆盖。三份轨迹哈希、字节数及源码hash在机器附件。
- 3个真实语义变异（跳过实时资格、取消精确数量限制、Dual Wield复制数多1）均由 `[SELECTION_CONTRACT]` 行为断言拒绝，不把语法或进程失败当作kill。
- 原registry首项因全文件hash投影不再认新选择区而先失败。没有更新冻结oracle、删断言或放宽政策：改为只在admission/victory两段精确逆转原锁定relic-round3的两个已批准hunk，保留原oracle SHA及两段逐字相等断言。8个缺项/多项/重复/条件漂移负例均拒绝；没有增加新的整源inverse链。
- exhaust完整轨迹初次超出默认1MiB管道缓冲。重放器改为完整输出直接写日志文件，再逐字比较；保留全部1063471字节，不改30秒VM时限或测试/断言。

## 已运行

使用既有固定Node24.18.0运行：

- 新 `tests/card-selection-protocol.test.mjs` 3/3；基线真实测量中candidates16违反新CC15收敛要求，最终通过。
- `tests/run-choice-transactions.test.mjs`、原 `tests/card-actions-exhaust.test.mjs` 与新选择wrapper组合10/10。
- 原 `tests/card-actions-registry.test.mjs`（补政策负例后）8/8，包含原3组完整历史执行差分。
- 原 `master_reality_dual_wield_source.lua` 全组合通过；`choice_ui.lua` 19组；`atomic_play.lua` 14组。
- `check-engineering-quality`、`check-lua-static`、`check:architecture` 及 `git diff --check`通过。既有依赖与固定工具复用，不安装新包。

重放先按项目入口构建data/ui/theme及map布局，然后运行上述定向wrapper；差分命令为 `node scripts/card-selection-parity.mjs aa4d56f57c15727668ef8675e626b44e67a5aaa5`。原始本轮质量前后、冻结旧源、完整轨迹与汇总保留在此树 `build/m9-core-before.json`、`build/engineering-quality.json`、`build/selection-parity/`。未改历史冻结基线。

最终组合独立复审、精确HEAD必需CI与TASK元数据由主控负责。本片没有候选写入/读回、官方导入、新ready、PC或手机实测；对应产品/设备关口保持未验证，M9全局未达指标也不据此勾完。
