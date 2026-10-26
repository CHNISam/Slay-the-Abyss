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
