# TASK-4 卡组查看离线验证

2026-10-23，基线 `origin/develop be5093f`。沿用 PR #19 `openDeck` 的遮罩、六列网格、卡牌和右上关闭；各页共用入口，永久 UID 位于卡面下方。RGB 与透明度分开传入导入器，遮罩取主题 `backdropVeil` 的 80% alpha。按钮提供 normal / hover / pressed / disabled 原生状态。

界面只读永久 `run.deck` 快照；不会按手牌、抽牌堆或奖励列表重建卡组，不会继承本场战斗的临时成长。打开期间底层地图滚动/聚焦/选路、节点交易、出牌/药水/结束回合和奖励命令均被门禁拦截；拖牌与选中状态取消，关闭后恢复对应模式。菜单、结算和反馈播放期间不能打开。索引基值先由单项 `RefreshItems` 回调读取，下一 update 填满列表，兼容延迟及复用回调；旧会话回调失效。

## 可复核结果

- `npm run check`：JavaScript、Lua、数据和 Python 离线检查通过。真实 GameUI 夹具有 16 项行为测试，其中新增 6 项覆盖卡组查看；JS 布局测试验证六列、卡面文案区、原生四态按钮、设备安全区和每容器不超过 60 个子控件。
- Lua 行为覆盖 40 张滚动复用、同名不同 UID、0/1 索引校准、延迟和过期回调、重复开关、永久升级费用 / X 费用、临时成长隔离、空卡组、防止底层规则或随机数改变、反馈/结算门禁和关闭恢复输入。
- 从固定原始底图 `F:/New folder/.artifacts/m1-offline-be5093f/source-base.gil` 完整运行 `build-native-candidate.mjs` 成功；SHA-256 `6e82decfb9b113310ba97c0cad5cf541288c0cada5cb52644a0dd8785004a432`，源文件未改动。
- 从零新增候选：`.artifacts/deck-fresh-final/wmvkeu50t-0/working.gil`，SHA-256 `63decf186c4aaf0cf0989503a0c8bc0e9c3b2743ca330194a7c12915563343dc`。
- 在完整候选副本上再次 `replace:true` 写入模板及界面，读回并对比模板索引、全部控件 ID、结算图、信号与实体图挂载完全一致。结算图仍为 `1073741825 / _GSTS_ABYSS_SETTLEMENT / 22` 节点，无重复挂载。
- 最终重入候选：`.artifacts/deck-verified-release/scenes/saves/abyss-deck-offline.gil`，SHA-256 `512959f6d3ae49c26d83cda6e726b24e72808e60b7d66751fdd416711fd5f680`。
- 两条构建路径 `scene_check_client` 均为 `ok=true, errors=0, warnings=15`。15 条都是检查器不追踪跨模块 Lua 控制器方法而报的 `UNKNOWN_METHOD`（`cancel/begin/open/close/setActive/setVisible/render/setNavigationEnabled/resize/update`），没有信号未监听或新原生 API 错误。

本地原始日志与结构读回在本 worktree 的 `.artifacts/deck-fresh-final/`、`.artifacts/deck-verified-release/`；最终测试日志 `.artifacts/deck-check-final.log`。`.artifacts` 不提交。早期对派生 `original.gil` 的调查结果不作为本轮验收证据。

## 复验

```powershell
npm run build:data
node scripts/build-ui.mjs
npm run check
node scripts/build-native-candidate.mjs 'F:/New folder/.artifacts/m1-offline-be5093f/source-base.gil' .artifacts/deck-recheck
```

MCP 只写副本，`MILIASTRA_ALLOW_LIVE_WRITE=0`。本次**未启动原神、未导入官方客户端、未做设备预览、未做真机试玩**。原生滚动手感、手机/主机可读性、遮罩与实机画面对照、图库选型仍待真实客户端验证；TASK-4 实机 AC 保持未勾选。
