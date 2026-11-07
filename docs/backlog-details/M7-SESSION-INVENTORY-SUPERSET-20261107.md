# Session、Inventory 与 Watcher 单一并集

基线为 develop `2ad07111e3d5b5cb52b4229860b3b780941e29a9`，承接 TASK-74.19/74.20。PR542（`e750311b`）与PR543（`2fc0cbfd`）在47秒内先后提交了不同Watcher实现。本轮统一到PR543分支，不再让两个Watcher先后合入；保全两个原提交、各自证据及独有测试。PR541的Power/Shop仍独立，不混入未合依赖。

## 选择与保全

- 采用PR543原Watcher effectHandlers实现及Inventory。PR542的额外Watcher映射/升级helper没有新增产品语义，原变体留在其精确提交及原始证据中，不把两套dispatch混合。
- 原字节接入PR542的Session三源码、架构边界、source proof/archive、动态槽位及失败行为测试。奖励准备直接读现有Queries/Rewards固定能力槽；原Hooks门面共享其普通可变字段，Run事务owner不迁移。
- Watcher覆盖两边14个不同fixture，包含原9组及PR542独有5组。保留choosePile和未观察执行入口、18-op AST覆盖及unknown、完整图/别名/事件/RNG/返回/table错误身份。6种不同真实语义变异均绑定精确行为断言。
- 只对4个已核验的源行位置与完整错误正文建立比较映射，实际抛值不改；其他位置/正文/文件和table错误原样保留。没有通配抹除错误位置或减少图字段。
- 共用Watcher静态key只出现一次，匹配当前17个真实职责；Inventory全模块仍受CC15。source组合保留Inventory、Watcher与Session三层鲜读，原N35断言/冻结档案不刷新。
- CI库存登记本轮两份Session JS，加上原Watcher/Inventory项，共750 JS、1403 Lua。只修漏项，仍按原未知成本；未改历史测量、预算或17/13分片。PR541后续合流仍需保留其独立floor与原证明。

## 同口径结果与验收边界

完整333模块、5428/5428函数及初始化测量；相对基线CC>30为58→54、CC>15为237→232、最大75→69。Combat SCC仍81，Session SCC15→12；其内部引用62→52、唯一模块对41→31。全图引用1920→1922，新增能力边不隐藏。14条原静态告警保持，无新增豁免。

本轮分批验证覆盖104个不同测试，最终各项均有通过记录：Session/来源/库存20/20；组合82项首轮77过、5项因隔离目录缺Inventory依赖失败，补齐复制清单后原四份来源测试26/26通过；新补两负控及其余变异/来源/实测范围8/8复测通过。14组Watcher旧新完整图270检查点逐项一致，全部6种独有负控有效；未重复14组大图。源码桥40 owner独审对抗320次正常投影及480次异常拒绝通过。原失败完整输出保留，不将首轮称为全绿。

原两片与Session/Watcher历史结果分别保留，当前并集的源码身份、完整实测及逐文件承接记录见 [本轮证据](../evidence/m7-session-inventory-superset-20261107.json)。精确HEAD独审及托管Full、原生队列、合后push Full分别验收；没有借旧HEAD绿灯或重复本地Full。

剩余81/12两组SCC、54个CC>30热点仍未完成整体治理。正式导入、ready、设备与发布未执行，任务AC不勾。原PR542在确认本轮承接内容完整且远端读回后才可标记被承接，评论提醒不等于暂停其他协调者。
