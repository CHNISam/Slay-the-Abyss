# PR262 Host 夹具规范图迁移

后续并发集成更新：远端79e76774也修复了history/event/deck夹具，并从PR263保留两份完整原文/范围守卫。合并保留它更完整的两次真实Run.advanceAct准备与新增restore/nodeFlow断言；另加断言证明Run.new持有独立数据，事件选择不会污染共享F.Data。保留本片exit与exit_swipe修正。下述RED/GREEN和正文SHA描述的是本片ee575d02的独立历史，不能冒作最终合并文件执行结果；组合将重新运行受影响入口。

实际组合复核：两份源/覆盖守卫、ending-history完整入口及event-combat-ui共9/9 Node测试通过（9.581秒，history Host4.089秒/event4.135秒），然后完整deck6组通过8.782秒，零跳过；退出15组与swipe5组文件未再变化，沿用本片最终串行结果。没有放宽默认30秒或修改生产源码；当前精确提交完整CI仍须重新核对。

基线 `5dc62874fedbd02c96375c789b1893cbc48e521f` 的前置校验保护真实 Run 幕诞生事实和原始规范图。两份现有 Host 夹具跳过真实换幕后仍带第一幕上下文；另外两份将第一层节点直接改成营地/商店。这些准备方式不再满足入口合同，不是生产规则或超时失败。

真实本地原始入口 RED（固定 Node v24.18.0，各使用原默认30秒）：

| 夹具 | 原始失败 | 耗时 |
| --- | --- | ---: |
| ending_history_host.lua | 第24行 `map_birth_context_unavailable`，首组通过后第二组终幕入口拒绝 | 4287ms |
| event_combat_ui.lua | 第23行 `map_birth_context_unavailable`，原手改事件节点 | 1357ms |
| game_ui_exit.lua | 第82行 `invalid_snapshot`，前三组通过后手改camp节点入口拒绝 | 7651ms |
| game_ui_exit_swipe.lua | 第19行 `invalid_snapshot`，全部5组在同一手改shop准备处失败 | 3653ms |

修正只涉及四份夹具的准备：受控第三幕终点先设定幕编号、调用真实 `Run.freezeMapContext` 再生成规范图；事件用独立测试数据的既有 `rules.events.encounterId` 指定事件，保留全部真实规则与事件行为，再按已有 `map_routes.to/at` 沿合法路径到真实event节点。退出与滑动分别沿原seed的规范图到真实camp/shop。先前房间只做受控导航，没有模拟自然战斗；不伪称自然换幕、事件概率、通关或原生验收。

所有原测试组、命令、断言、输入ID/旧手势失效、遮罩和反馈队列、重试、历史持久化失败、显式seed资格锁、事件HP/来源队列/奖励返回/Mark行为保留。未修改生产代码、Map/Nodes校验、mock、workflow、种子或时限。

最终四份完整raw串行GREEN：history3组3896ms；event3组4207ms；exit15组12419ms；swipe5组4857ms，共26组，零失败，单份最大12.419秒。命令均为 `node scripts/test-lua.mjs tests/lua/<fixture>.lua`；独立树 `build/canonical-host-fixtures/*-green.log` 保留实际完整输出。前两份另一次初始修复GREEN为3914ms和4478ms，最终采用复用既有路径helper后的上述完整复核，不混用旧输出。

同类离线扫描：`game_ui_deck.lua:119` 同为Host启动后改camp，已由另一线程独立处理，未改该文件；`game_ui.lua` 的局部node类型更新作用于 `Map.available` 返回的副本；Ruby/Sapphire组件直接 `Run.new` 无出生事实，仍使用明确保留的legacy API；Reptomancer UI直接开战，地图UI章节夹具只导航，不经新Nodes入口。本次未运行完整Quality或其他Lua，无GUI/键鼠、远端或Backlog写入。
