# PR193 兼容接续记录

只针对固定PR193头6fa23b1ce9a4eae8ba3353237e486a44e09e6449，不是它未来版本的通过结论。本目录补丁为独立隔离验证产物，未应用到develop或原执行者分支，不改变TASK14.1归属。

## 接入方式

同目录potion-on-pr193.patch对该精确PR193纯源的git apply --check通过。仅在核对新主线、现有写入者并取得实际任务接续权后使用，不整分支盲合。补丁SHA256为60351b825919508694b7149bf9b8c2d92e5c2f630f75d50090f648f8be024f06。

生产UI三路合成无文本冲突，组合Git blob为39ccfcedf05fbdb2ca223cbf67976973b6f54df7。唯一测试冲突保留药水→明确enemy1确认，再按PR193的cardReward→skip回列表→continue回地图。不改变Run或数值。PR192的任务54、重号修复和门禁必须保留。PR194正文标记旧方案重做，未混入该展示设计。

## 真实组合验证

- 39个目标确认新场景及191项相关既有Lua通过；奖励23状态的5项可读性断言通过。
- 正式seed4地图正常出牌：f1_l1 Jaw Worm→f2_l1 Cultist→f3_l2两只Louse，按新列表真实领取火瓶与11/14金币。第一次点瓶保持库存、HP、能量和事件，新的enemy2确认才扣瓶并击杀第二敌。纯PR193原UI同路线在首次点瓶立即使用处证红，组合证绿。
- 原显式startCombat(Cultist) fixture与正式startRoomCombat/地图入口分开验证；没有把前者冒充新随机地图覆盖。
- 完整非截断tree1383个blob已取；1190个运行时、源码、测试及Backlog文件精确物化，非运行时图像/旧压缩证据未物化，不声称完整资产构建。

## 保留失败与边界

纯PR193与组合都保留4项旧测试前提失败：已移除skipPotion、满槽claim现在允许点击解释、旧固定商店路径耗尽、节点硬编码47而当前92。见[独立评审](https://github.com/CHNISam/Slay-the-Abyss/pull/193#pullrequestreview-5639221845)。未删断言制造全绿，不把它们记为药水候选新增bug。

这里只是原生liblua5.4及Node离线组合验证；未运行组合的完整Fengari CI、官方导入、实机或全地图规则认证。不能直接关闭父任务或据此合并PR193。
