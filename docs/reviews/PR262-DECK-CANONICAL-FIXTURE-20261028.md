# 牌组覆盖层使用真实营地上下文

后续并发集成保留远端79e76774的同类合法路径实现及更强restore/nodeFlow断言。本文件下述正文SHA及RED/GREEN绑定独立b41129e3叶提交；最终组合另行执行，未把叶结果冒作新文件通过。

基线 `5dc62874fedbd02c96375c789b1893cbc48e521f`。CI [40579383322 / rules 7](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40579383322/job/122455072286) 在 `game_ui_deck.lua:120` 失败：节点覆盖层用例把 Host 真实地图的第一节点改为营地。新增 canonical-map guard 按 Run 冻结的出生上下文恢复地图，正确拒绝了这个改写后的房型。

夹具现在保留 Host 启动时的 Run、出生上下文和地图，沿 `Nodes.available` / `Map.choose` 推进合法源路径，定位地图中已有的营地，再用原 `mapUI:choose` 入口进入。跳过的前置房间属于明确测试准备边界，不代表自然通关。

从原节点进入断言到文件末尾，所有原断言字节完全一致；六组用例、NodeUI 覆盖层阻断/纯度/恢复休息/继续、战斗及奖励覆盖层验证保持。生产 Nodes/Map/guard、JS 包装器和原单文件 30 秒 runner 预算均未修改。

独立串行实测：原完整 fixture RED 4.818 秒，同一第 120 行失败；迁移后完整六组 GREEN 9.950 秒，保留 `LUA_GAME_UI_DECK_PASS 6`。Lua 5.3 字节解析及 `git diff --check` 通过。原始输出与逐字断言证明保存在本树 `build/pr262-deck-audit/`；本轮无 GUI、推送或实机通过声明。
