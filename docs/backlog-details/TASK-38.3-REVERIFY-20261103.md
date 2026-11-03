# TASK-38.3 结算用时独立复验（2026-11-03）

复验者：Codex 独立验证代理 `/root/verify_elapsed`。源码基线：`568da4e4aabca7c67d148a7e970c01344b7de10d`；生产修复为已合入的 PR #442 / `b0f64d49fdf88d05c1aa52ae29a4c252256ee603`。本轮没有改源码、回归断言、Backlog、候选或正式存档，没有桌面输入。

结论：AC1、AC2 的源码与离线共用路径复验通过；AC3 的正常/异常输入回归通过，同候选实体手机证据未运行，AC3 必须保持未完成。当前官方入口采用明确不可用方案，不能据此宣称官方计时准确。

## 源码与验收映射

| 要求 | 当前源码和本轮证据 | 边界 |
| --- | --- | --- |
| AC1：可靠输入可读，非法/无法保证时明确不可用，不伪造零 | `abyss_game_ui_menu_view.lua:14` 的 `clock` 对非数字、NaN、负数、正无穷返回“暂不可用”；整数格式化由 `pcall` 保护，失败同样降级。`tests/lua/game_ui_timer_safety.lua` 验证真实零为 `00:00`、62.25 为 `01:02`、3725.9 为 `62:05`、864000 为 `14400:00`，以及 nil、false、字符串、负数、正负无穷、NaN、超出格式化范围的数值。 | 这是受控 Host 输入的可读计数，不是官方前后台计时准确性证明；没有任意截断长时长。 |
| AC1：官方入口不泄露异常数值 | `abyss_ui.lua:148` 显式传入 `runTimeUnavailable=true`；`abyss_game_ui_menu_view.lua:116` 的失败/胜利共用四格统计通过该标记调用 `clock`。计时回归真实执行公开 `OnStart/OnUpdate`，合理 62.25 和 0、3074457345、184467440737.0955、无穷、负数、NaN 均显示“暂不可用”。 | 公开 Lua 入口 + mock API，不是官方客户端。当前官方入口即使内部计数合理也不显示数字。 |
| AC2：失败、胜利、重新启程 | `game_ui.lua` 第6例 `same-run result records active time and victories, freezes on results and resets on restart` 验证 62.25→63.25、失败 `01:03`、终局不再增长、重启归零、新局3秒胜利显示 `00:03`；第4/5例分别走真实失败/完整关卡胜利后的状态替换。`game_ui_timer_safety.lua` 另外验证 native 降级失败后重启归零、模拟大间隔更新后的胜利仍降级，且 `settle()` 成功。 | 大间隔更新只是输入模拟，不能称为真实手机切后台。 |
| AC2：结束并结算、退出结算 | `game_ui.lua` 第7/8/11例验证失败/胜利各只提交一次、失败可重试、结算请求后不能重新启程。`game_ui_exit.lua` 原第3/5例验证反馈期间退出、状态/计数冻结、失败重试和防重复提交；`game_ui_exit_slice_2.lua` 原第8例验证已获胜结局走共享退出入口仍提交 victory。源码 `confirmExit` 只按结局调用共用 `requestSettlement`；用时格式化仅改变展示字符串，不参与提交或重启条件。 | 原生降级+直接settle有专用回归；退出按钮与降级标记的组合依据共用源码及退出既有回归，未新增重复测试。平台实际收到信号/结算页未验证。 |
| AC3：回归保留与设备 | PR442 的 `tests/game-ui-timer-safety.test.mjs` / Lua 夹具均仍存在并在本轮通过。 | 无本轮候选 GIL 身份/哈希、写入读回、官方导入、新 ready、实体手机型号/系统/结算页截图。不能勾手机验收。 |

## 实际执行

先读了 `AGENTS.md`、`backlog instructions overview`、`backlog instructions task-execution`、`backlog task view TASK-38.3 --plain`、`docs/TOOLCHAIN.md` 工具索引，以及 verification-before-completion 技能。任务读取时为 High / To Do / Furinya，三项 AC 均未勾；本代理没有修改任务状态。

为避免覆盖共享 build，在系统临时目录建立 HEAD 的离线副本：`C:\Users\ADMINI~1\AppData\Local\Temp\abyss-task383-reverify-3e66b2ebab814b62b025c9dbdda23a23`。实际成功的归档命令为 `git archive --output=<临时目录>/source.tar HEAD src tests scripts data tools config docs package.json package-lock.json`，随后 `tar -xf` 解包。复用根目录现有 `node_modules` junction；无安装。Node 为本机 `v22.22.1`，构建使用默认关闭可选美术的 UI fixture。本轮不重复全套测试。

下列命令均在该临时副本执行，生成物仅留临时副本：

| 命令 | 退出码 / 结果 |
| --- | --- |
| `node scripts/build-lua-data.mjs` | 0；`Validated Lua data module built.` |
| `node scripts/build-ui.mjs` | 0；`Native battle UI and Traveler display module built.` |
| `node --test tests/game-ui-timer-safety.test.mjs` | 0；1通过、0失败、0跳过，3945ms；包装断言同时检查 `TIMER_VALUE_SAFETY_PASS` 与 `NATIVE_TIMER_FALLBACK_PASS`。 |
| `node scripts/test-lua.mjs tests/lua/game_ui.lua` | 0；`LUA_GAME_UI_PASS 16`，35893ms；包含上表第4/5/6/7/8/10/11例。 |
| `node scripts/test-lua.mjs tests/lua/game_ui_exit.lua` | 0；`LUA_GAME_UI_EXIT_PASS 5`、`GAME_UI_EXIT_SLICE 1 5 5`，14803ms。 |
| `node scripts/test-lua.mjs tests/lua/game_ui_exit_slice_2.lua` | 0；`LUA_GAME_UI_EXIT_PASS 10`、`GAME_UI_EXIT_SLICE 6 15 10`，5980ms。 |

环境尝试亦记录：Node 子进程执行 git 的首次临时副本尝试报 `spawnSync git EPERM`；直接完整归档碰到 git-lfs 子进程 signal pipe 权限失败，改用上述排除 art 的确定目录归档后成功。UI 首次沙箱执行报 `spawnSync python EPERM`，经审批的离线子进程权限重跑后成功；Fengari 定向测试沿用同类权限执行。无测试断言失败、无放宽超时或重试失败测试。

## 后续实体手机验收

需以同一候选记录源码 SHA、候选路径/哈希、官方导入和新的 ready 证据，记录手机型号/系统，并在该手机拍摄失败、胜利/退出结算及重新启程。当前发布策略下结算用时应为“暂不可用”；确认无3074457345等数字、旧局无污染、重新启程和结束并结算可用。没有本轮这些证据前，设备状态维持 `NOT_RUN / UNVERIFIED`，不以本报告的 mock 日志中的 ready 冒充客户端 ready。

## 本轮退出与不可用时钟组合补验

2026-11-03 后续补齐此前仅从共用路径推断的缺口：`tests/native-exit-timer-regression.test.mjs` 调用新增 Lua 夹具，使用真实 `abyss_ui.lua` 的 OnStart/OnUpdate 与生产 Host、原生生成控件。合法开局、首房战斗、三HP敌人实际回合致死；不赋值 phase、不直接调用 settle。endTurn 原生监听器之后分别确认反馈和失败揭幕由 OnUpdate 实际推进，结果页用时保持“暂不可用”。

真实 exitEntry/open → runMenu/abandon → exitPanel/cancel/confirm 触摸链验证：取消保留终局、失效旧重启手势、新手势重启归零；第二局真实失败后 ServerSignal 首次抛错仍能取消重开并重试，失败手势不重复发送，最终只接受一次信号，终局计时冻结。新组合包装在本轮集成树默认预算1/1通过（约6.14秒）；独立时钟安全回归、原生合同6项亦通过。去掉不可用标记和手势消费的两个内存变异被断言拒绝。

原 `game_ui_exit.lua` 本轮30秒预算曾在第2例超时，此失败保留，不计入本轮通过；120秒诊断包装自身报错，亦不计通过。上文的16/15例是此前批次证据，不冒充本轮重跑。新组合覆盖补齐AC2退出按钮缺口，AC3同候选手机仍NOT_RUN，未操作用户电脑、客户端、官方导入或发布。最终精确HEAD完整托管CI另验。
