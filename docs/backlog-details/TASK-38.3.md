# TASK-38.3：结算用时明确不可用

基线 `develop@a7193e1c5d63ab0c2b4892912312d4597e84c642`。承接待合 PR441 的 TASK-38.3；任务不存在于此基线，未重复创建或手改任务文件，合入后再由 Backlog CLI 更新执行记录。

原入口 `abyss_ui.OnUpdate(dt)` 原样传入 GameUI，有限非负 delta 累加到 `run.elapsedSeconds`，结果页直接用 `%02d` 格式化。截图未绑定候选，也没有官方引擎 delta 单位与当前设备取证，不能断言 `3074457345` 是溢出、单位错误或原生格式化问题。

按用户明确允许的降级，结果页现有“用时”格统一显示“暂不可用”，删除不再使用的格式化函数。失败和胜利共用同一展示入口，不更改计时、评分、事件资格或重新启程逻辑，不用伪造零时长或猜测阈值替代真实测量。恢复准确时长须先验证官方候选的计时输入及显示。

新增真实生成控件/GameUI回归，修改前失败于 `unverified duration leaked into defeat`。覆盖正常、超大、负数、NaN、无穷、字符串、布尔及缺失用时；结果展示不修改原计时。无效delta仍拒绝，失败/胜利显示降级后重新启程、正常结算及主动退出结算继续可用。既有本局计时、结果冻结、新局清零与其他统计断言保留。

本轮仅离线源码与mock原生API验证，没有官方候选写入/读回、导入、新ready、实体手机截图或发布许可。TASK-38.3设备验收保持未完成；不将降级显示当作原计时根因已修复。

本轮 Node v24.19.0：`npm run build:data`、`npm run build:ui`通过；`node --test tests/result-duration-unavailable.test.mjs tests/game-ui.test.mjs` 8/8通过（含既有GameUI、牌组、开场三套真实Lua夹具，约71.7秒）；`check:architecture`通过（318模块、1838边）；`verify:backlog`、新Node入口语法与 `git diff --check` 通过。未运行完整Quality，最终精确SHA CI独立跟踪。
