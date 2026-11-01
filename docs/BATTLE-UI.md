# 战斗界面接入（TASK-10）

`abyss_ui.lua` 是统一生命周期入口，只配合 `game-ui.json` 的完整控件树，创建菜单、地图、战斗和节点宿主。`abyss_battle_ui.lua` 绑定点击和刷新视图，命令进入 `abyss_run.lua` / `abyss_combat.lua`。完整接线见 [CLIENT_UI.md](CLIENT_UI.md)。`battle-ui.json` 仅供独立 BattleUI 控制器测试，不能直接搭配统一入口导入。

构建：`npm ci --ignore-scripts`，`npm run build:data`，`npm run build:ui`。UI 构建调用已有 Python 中文表现渲染器，`ABYSS_PYTHON` 可指定解释器。运行卡牌原始名称和 `sts_name` 不进入显示；缺少表现条目会报错。生成的 Lua 数据、表现、主题、地图布局及 `game-ui.json` 均不提交副本。

存档副本接入顺序：MCP 读取 workflow/platform-rules，保持 `MILIASTRA_ALLOW_LIVE_WRITE=0`；按 CLIENT_UI.md 注册全部源模块及同源生成模块，name 与 file 去除 `.lua` 后完全一致；每次传入上一次返回的 mapPath。再用 `scene_add_client_ui` 传入 `game-ui.json` 和当前 mapPath，最后 `scene_check_client`。模块不挂控件，不需要生命周期函数。

鼠标和触控共用同一点击事件：先选卡，需要目标时再点敌人，无需目标时点击明确的战场出牌区域；再次点击原牌取消选中。出牌后刷新手牌、能量、生命、格挡和牌堆。结束回合运行敌人队列再刷新。敌人意图显示规则计算的当前修正数值，后续状态衰减仍可能改变行动结果。药水显示效果数值，当前目标有金边与文字提示。获胜三选一卡或跳过，消费奖励后才能继续地图，失败可重新启程。

战斗保留批准稿的 148×208 卡面、扇形手牌、选牌抬起与四态按钮。完整宿主由外层 stage 统一缩放，嵌入式控制器不重复缩放。`npm run check` 验证布局和真实规则驱动的菜单、出牌、拒绝、回合及胜利奖励交互；不能替代官方手机/主机预览和实机点击验证。

历史首次平台接入（2026-10-23、整合前独立演练版）：八模块写入工作区 `.gil` 副本，`scene_check_client` 返回 `ok:true, errors:0, warnings:0`。第一次 `playtest_start` 在导入前因 Windows 拒绝切换游戏前台失败（run `96417ad4-7f09-409d-b741-35a02a86684b`，`无法把窗口切到前台：game`），无日志或截图；不计为游戏内通过。本次完整宿主未执行平台编译或实机验收。
