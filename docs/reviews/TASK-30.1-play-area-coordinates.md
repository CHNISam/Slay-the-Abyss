# TASK-30.1 出牌确认坐标保护

## 变更范围

固定基线为 `develop` 的 `3c3b66054c40280fb4a9b8bac9f2edfa579fe54d`（树 `61e292536b41cfb69aca66cf816c701c94635003`），任务认领头为 `97ac2976327c74a5703690cac90d6e51f4ebf61a`。相关 425 份源码、数据、脚本、测试、工具与关键合同文件逐 Git blob 核对相同；原 UI blob 为 `456f4f9626a535c03071254c78d868d1093cd453`。本修复不包含 PR182 或甲虫颜色候选。

仅修改 `src/lua/abyss_battle_ui.lua`，新增独立用例 `tests/lua/play_area_coordinates.lua` 和本记录；不改规则、数值、布局、原型、规范、Backlog、任务状态或 CI 预算。

## 根因与修复

选中防御后，在战场确认区以有效坐标按下，释放明确提供 NaN 或 Infinity 时，`point()` 原先返回空坐标；`releaseAction()` 的 `not x` 又把它当作无坐标兼容路径，随后 Click 真实提交：能量 3→2、格挡 0→5、手牌 2→1。

`point()` 保留所有既有调用者使用的前两个返回值，仅在任一轴明确为 NaN 或正负无穷时增加第三个标记。战场区域 Down 不建立这种输入的许可；拥有按下身份的 Up 消费身份后不建立释放许可，迟到 Up/EndDrag/Click 不能补发。完整缺少坐标 API、单侧缺失、nil/非数值未知坐标、无触点 ID 和纯 Click 的既有兼容行为不变。场上确认的每次 Down/Up 仍只采样一次 GetUIPos，不因状态标记再次调用 getter。

有限坐标仍使用既有有效区域与位移门槛；取消后允许新手势。卡牌拖动等其他 `point()` 调用者仍只读取原有两个值，未重构控制器或扩大异常输入政策。

## 已执行离线证据

- 原独立最小四例：修前正常与无 API 两例通过，NaN/Infinity 两例真实扣费而失败，exit 1；修后四例通过，exit 0。
- 新增生产逻辑专项：先在未修改生产代码上得到 **13 过、18 败，exit 1**；应用最小修复后 **31 过、0 败，exit 0**。失败均为坏坐标错误扣费，不是载入或环境错误。
- 覆盖 NaN/±Infinity 双轴的 Down/Up、另一轴未知、有限区域/位移门槛、兼容模式、迟到事件、另一触点、手牌槽及选牌变更、取消后重试、有状态 getter 和真实 Feedback。
- 既有窄相关九文件：卡牌交互 11、点击归属 11、手势 11、动作兼容 8、动作手势 8、药水兼容 11、药水手势 9、拖放边界 7、卡牌反馈 10，共 **86 过、0 败**。
- 负变异 **9/9 被行为断言捕获**：去掉 Up 或 Down 拒绝、分别去掉 x/y 非有限识别、误拒绝缺 API、误拒绝未知返回值、重复读取 getter、放宽位移门槛、去掉有效区域判断。每个变异独立在加载时替换测试模块，没有改写生产文件；最后原修复对照仍 31/31。
- 重新生成 data/UI/theme/map 布局后，全部 **173 个 native Lua 文件通过**，其中 BattleUI 通过本轮 `battleLayout()` 生成的 wrapper 驱动。使用仓库相同模块路径 `LUA_PATH='./build/lua/?.lua;./src/lua/?.lua;;'`，清空 `LUA_INIT`；运行器仍是下述 native Lua 5.4，不是 Fengari。
- **62 份纯 Node 测试共 1090/1090，通过；Python 22/22，通过**。纯 Node 清单排除了 20 份引擎相关或混合测试文件，不代表完整 Node 测试命令通过。JavaScript 语法、内容数据校验和 Backlog 只读排期校验均通过。

首次全部 native 尝试遗漏 `LUA_PATH`，158 文件通过、15 文件因模块寻址失败退出；记录没有覆盖或删除。失败文件为 `game_ui.lua`、`game_ui_boss_treasure.lua`、`game_ui_deck.lua`、`game_ui_exit.lua`、`game_ui_prologue.lua`、`game_ui_result_gestures.lua`、`map.lua`、`map_floor_boundaries.lua`、`map_gesture_ownership.lua`、`map_no_crossings.lua`、`map_treasure_placement.lua`、`map_ui.lua`、`native_bgm.lua`、`native_bgm_host.lua`、`number_display.lua`。只修复外部运行命令的模块路径后重新执行全部 173 文件，全部通过，未为此修改生产代码。这些环境错误与上述真正 18 个红测失败分开记录。

运行入口：在仓库根目录执行 native Lua 5.4 shared-library helper，对 `tests/lua/play_area_coordinates.lua` 及既有脚本逐文件运行。仓库 `scripts/test-lua.mjs` 会自动发现新 `.lua`，无需改 CI 注册或时间预算。

## 独立评审

独立评审未发现阻断问题，另写行为矩阵 **96/96 通过**；换回固定原 UI 后 **22 过、74 败**，失败真实表现为错误扣费/出牌。矩阵额外覆盖另一轴为 nil/字符串/布尔值、无触点、真正没有指针枚举的 Click-only、四种画布尺寸、非场上动作和卡牌的既有 C 档。评审者独立重跑提交专项 31/31，以及七份相关回归 66/66；再次核对 425 份基线 blob 和冻结代码/测试 hash。

已成功释放后，重复普通 Up 被忽略，匹配 EndDrag 或新 Down 依既有规则撤销许可；本切片修的是拥有按下身份的坏坐标释放，不改变已经消费后的重复事件策略。

## 证据边界

本次为生产 Lua 的软件事件注入，使用真实生成的 GameUI 树、Run、Combat 和 Feedback；控件 facade 负责提供宿主事件，不模拟核心出牌结果。没有证据表明官方手机宿主实际产生 NaN/Infinity，因此不称为手机实测故障。

运行器是 native Lua 5.4，不是仓库 Lua 5.3/Fengari。未安装依赖，未执行官方平台编译、候选写入、导入、鼠标/手机实机或 UI 验收门禁。当前提交的远端 CI 与最终集成另验；父任务 TASK-30 的平台状态和验收项不变。
