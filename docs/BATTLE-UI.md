# 战斗界面接入（TASK-10）

`abyss_ui.lua` 是唯一生命周期入口，挂在 `AbyssBattle` 客户端控件树根部。`abyss_battle_ui.lua` 只绑定点击和刷新视图，命令进入 `abyss_run.lua` / `abyss_combat.lua`。不使用轮询或额外游戏规则副本。当前界面是战斗演练，重复遭遇只用于检验永久奖励入组，尚未表示完整第一幕。

构建：`npm ci --ignore-scripts`，`npm run build:data`，`npm run build:ui`。UI 构建调用已有 Python 中文表现渲染器，`ABYSS_PYTHON` 可指定解释器。运行卡牌原始名称和 `sts_name` 不进入显示；缺少表现条目会报错。产物是 `build/lua/abyss_data.lua`、`abyss_presentation.lua`、`battle-ui.json`，均不提交生成副本。

存档副本接入顺序：MCP 读取 workflow/platform-rules，保持 `MILIASTRA_ALLOW_LIVE_WRITE=0`；`scene_set_client_script` 放入 actor、effects、combat、run、battle_ui、data、presentation、ui 八个脚本，name 与 file 去除 `.lua` 后完全一致；每次传入上一次返回的 mapPath。再用 `scene_add_client_ui` 传入生成 JSON 和当前 mapPath，最后 `scene_check_client`。模块不挂控件，不需要生命周期函数。

鼠标和触控共用同一点击事件：选存活敌人，再点击卡牌；出牌后立即刷新手牌、能量、生命、格挡和牌堆。结束回合直接运行敌人队列再刷新。敌人意图明确标记基础伤害，避免把未应用力量/虚弱的值冒充实际伤害预览。状态名称和层数来自实际 actor 的复制视图。获胜三选一卡或跳过，失败可重新启程。

全部控件连同子节点在最小 1280×720 画布内，十手牌槽分两排，点击区最小 44 像素。`npm run check` 自动验证布局和真实规则驱动的菜单、出牌、拒绝、回合及胜利奖励交互。这不能替代官方手机/主机预览和实机点击验证。

2026-10-23 首次平台接入：八模块写入工作区 `.gil` 副本，`scene_check_client` 返回 `ok:true, errors:0, warnings:0`。第一次 `playtest_start` 在导入前因 Windows 拒绝切换游戏前台失败（run `96417ad4-7f09-409d-b741-35a02a86684b`，`无法把窗口切到前台：game`），无日志或截图；不计为游戏内通过，验收项保持未勾选。
