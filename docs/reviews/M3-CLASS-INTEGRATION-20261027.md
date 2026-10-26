# 三职业独立切片组合记录

基首批`c24d25d8`，分别合入Silent `894ef785`、Defect `5e01f302`、Watcher `0fb2eccc`的业务提交及各自前置共享组件；没有合入三套重复共享历史。合并冲突按行为处理：三职业动作/抽牌/能力回调并列，统一startTurnPending供弃牌/占卜续接，保留实际物理uid与逻辑uuid及永久deckUid；生成牌升级只留一个纯函数定义，由各源站点显式调用。

追加独立复审修复：Burst复制体有新物理uid；Corpse Explosion通过Artifact；Omniscience冻结两次X；Master Reality不升级Dual Wield原实体；Wish/Lesson实际HEALING标记；Centennial Puzzle TOP抽牌不被All for One BOTTOM回手抢先；Swivel免普通费用与真实免费X牌分开处理。

组合定向验证实际通过，未改原时限：

- Silent 75×2真实执行，9.247秒。
- Defect 75×2真实执行/选择/预览/UID，8.745秒。
- Watcher 75×2真实执行，17.097秒；Foreign仍是合并真实目录的组件证据，尚未证明普通Watcher Run完整目录。
- Master Reality Dual Wield八种组合1.526秒；完整来源池Chrysalis三职业成功与显式私有缺失原子拒绝1.752秒。
- 回合开始Foresight占卜→Tools弃牌两次暂停及旧token拒绝经只读探针通过；没有按职业标志屏蔽外色能力。

这些450种执行不是全部合法构筑、自然获取/多幕通关或平台验收。当前仍缺Run完整共享目录、默认宿主完整能力边界、其余六瓶职业药水与完整遗物/章节。历史Profile.prepare入口与正式开关未因组件通过而放宽；后续组合仍须完整检查和当前SHA Quality。

## 后续组合进度（独立于上述450例）

首批PR234的精确头`4a66773b`已通过Quality运行`40387913080`的四个规则分片、engineering-posix、presentation与汇总check，Licenses运行`40387913373`成功；随后squash合入`develop c96a7777`。六个完工干净工作树已清理，原始六分支及失败/成功日志保存在根目录忽略产物`build/m3-pr234-archive-20261027/`，bundle已验证且三个前置提交均为develop祖先。

第二批保留首批原历史，并纳入PR236的完整美术/回归增量。三方合成`4a66773b + 49f7f56c`（共同基线`4beb7a4e`）树哈希`4993de340e6a6ecc7483e91bba79c995810d48ee`与实际`c96a7777`逐字一致；因此在两份源内容均已接入后仅连接squash等价历史，连接前后第二批树哈希一致，没有用历史连接覆盖新增玩法。

本树另接入Falling、Moai、Orb Walker、Shapes、Focus/Capacity/Miracle/Ambrosia/Darkness/类型化Stance及Winding Halls。各自来源和组件证据见对应`docs/rules/`与`docs/evidence/`。Winding明确拒绝四个尚未实现的遗物依赖，Moai持有Golden Idol夹具不代表其正常获取已实现；这些依赖继续待办。

组合到`5f19576e`时工程检查实际通过：152模块/863边、105项历史警告、受管UI绝对复杂度门槛及四项既有语义变异。两处Effects空skip分支合为显式guard，消费组第二成员与胜利清队列条件均保留；其余警告只按已审父提交的文件、源码行、列、代码及归一化消息映射，未新增豁免。Run完整目录和共享回合末顺序仍由独立切片继续；本批完整check/当前SHA CI及平台证据尚未完成。

父线程在此组合源码独立串行执行24份原时限Lua，全部通过，日志`build/combined-slices-r2.log`。Shapes17例4.971秒，Orb Walker3.001秒，Moai三份4.661/1.519/0.580秒，Winding六份0.697–3.096秒；Toy治疗、Darkness三份、Stance四份、普通选择19例、菜单owner初始化及两份死亡队列回归均通过。新增跨片回归以实际打出Buffer/Static Discharge后走Exploder三轮，验证末敌自爆保留一次伤害、Buffer只在未格挡正数生命损失时消耗、THORNS不触发Static Discharge，1.047秒通过。组件固定资源不计自然通关。

逐fixture摘要和实际输入哈希见[机器记录](../evidence/m3-combined-slices-20261027.json)。后续生产变更需要相关复验，不以本轮冻结结果认证尚未接入的目录或阶段改动。

类型化Stance独立只读复审针对原交付`91b34ab9`，32份固定源码摘要吻合；普通卡牌选择端点误投药水token、数值UID误投姿态、变更选项内容、晚失败原身份恢复及Host陈旧触点探针通过，未发现有证据的P1/P2。该审查不替代后续完整300目录组合和平台验收。

完整目录组合到`1538f169`后，父线程原门禁实际通过：商店23.071秒、758变体呈现22.042秒（均原30秒），15份目录Lua全部通过，来源/库存等34项JS全部通过且零跳过。日志为`build/catalog-composition-{gates,short}.jsonl`和`build/catalog-composition-js.log`。独立复审随后又发现逐牌非语义自环及metadata map别名问题，仍在作者片修复；不以这些已绿门禁认证该未完成修复。

同一完整目录组合重跑24份既有组合Lua，22份通过，2份旧夹具前提失败：Darkness假设默认Run无orb容器，而新目录为正常战士创建零槽容器；Stance夹具在Watcher完整目录上重复套用只接受原生红定义的历史adapter，导致Wild Strike校验失败。迁移仅将默认宿主断言明确为零槽/非Defect，并直接使用真实Run已有Fire Breathing；原循环、伤害/回滚/旧输入断言与时限全部保留，两份分别2.617/2.873秒复验通过。未以扩大生产ABI来接受重复adapt掩盖测试前提问题。后续共享回合末改动仍须相关重验及完整CI。
