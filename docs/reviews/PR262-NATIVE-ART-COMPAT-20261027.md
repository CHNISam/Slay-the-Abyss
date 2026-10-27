# 原生呈现记录与已接受样卡接线的兼容复核

PR262 的 82de 测试实际组合不是旧 REST `base.sha` 返回的 7fe，而是 GitHub 合并预览 b9a5bce5 的两个父提交：develop 77262d98（已合并 PR261，父为 7fe）和 82de。旧测试因此正确发现两项完整源码身份变化；不是业务断言、超时、换行差异或运行中源码泄漏。原失败日志保留，未改成绿色。

保留 PR261 全部 51 个已接受路径及其美术、LFS 限制、生成器和默认关闭的 opt-in 接线。受影响的冻结身份只有两处：BattleUI 向 CardView 传递 `platform` 的一个实参，和严格测试 API 的三行 `transform3` helper。合同先钉住两份当前完整源码的 SHA256，再各逆转一次精确的已审 hunk，恢复 c5 历史源码身份；删除、重复、任意额外源码变化仍拒绝。没有通配豁免或刷新历史 hash。

在实际 b9 组合树 b92b28f9 上，以普通默认构建、没有原生样卡 registry/选项，执行原完整呈现用例。原 `77278 / 1948853637` 断言通过。独立附加记录捕获 **全部 77,278 条**真实序列，逐条与不可变 `current.json.gz` 完全相等，序列 JSON SHA256 为 `b2e877cb6e922658dd55c02f2afda0411853879c3e43de0e4f0666cfac3a3df8`；全部 72,915 条旧写入仍按序保留。捕获 18.234 秒，原 30 秒预算未改变。不是新造 golden，也不是只比计数/滚动 hash。

GameUI、NodeUI、DeckUI、CardDisplay、BattleCardView 和默认构建路径均纳入组合源码复核：没有样卡池或 registry 时不产生新原生写入。历史 `review.json`、baseline/current 压缩记录、严格 recorder、原 Lua 用例和断言逐字保留。完整样卡导入/视觉能力沿用 PR261 自身验收范围，本次不另行宣称。

原始证据位于本轮独立工作区 `pr262-native-proof-772-evidence/`：`actual-default-capture-receipt.json` 记录完整输入 hash、实际提交/树、默认模式和逐条比较；`actual-default-entries.json` 为真实捕获；`capture-default.mjs` 为只读记录传输。没有 PNG/LFS 下载、客户端、键鼠或远端写入。本地 Node v24.22.1，正式 CI 仍固定 v24.18.0；当前组合完整 Quality 及最终实际目标分支仍须另验。
