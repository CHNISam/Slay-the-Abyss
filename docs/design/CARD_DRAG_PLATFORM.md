# TASK-30 原生拖牌离线交付与平台待验

2026-10-23。基于批准稿 `UI_DESIGN.md` 的 A 档跟手拖动；C 档点选备用仍保留。本文记录离线证据，不作为桌面或手机实机验收。

## API 依据与限制

本机 MCP 附带的官方指南离线副本：
`D:/MiliastraTools/genshin-miliastra-mcp/knowledge/official/guide/mhtakr07vej4.md`
（页 ID `mhtakr07vej4`，标题「附录/客户端控件API文档」）。

- 枚举表第 431–439 行列出 `CursorDown`、`CursorUp`、`CursorDrag`、`CursorBeginDrag`、`CursorEndDrag`、`CursorClick`。
- `ClientUICursorEventAreaControl` 第 823–827 行声明 `AddCursorEventListener(eventType, callback)`，回调接收 `CursorEventData`。
- `CursorEventData` 第 835–844 行声明只读 `dragging`、`touchId` 和 `GetUIPos()`、`GetPressUIPos()`、`GetUIPosDelta()`。`GetUIPos()` 返回以画布左下为原点、与布局同单位的坐标。
- `ClientUIContainerControl` 第 929 行声明可写 `disableCursorEventPassthrough`。代码在拖动捕获容器上设置该属性，避免通过捕获层操作其他控件。

本次只读取本机文档和源码，没有调用 MCP 或启动官方客户端。MCP 的 workflow / platform-rules 内容分别对应本机 `src/server.mjs` 的 `WORKFLOW` 和 `docs/PLATFORM_RULES.zh-CN.md`，已阅读相关约束。

以上声明证明接口存在，**未证明**跨控件拖动时 `CursorDrag`、`CursorUp`、`CursorEndDrag` 的具体派发顺序或捕获语义，也未证明手机触摸与桌面等价。因此同时监听起始卡牌和可见拖动捕获层的拖动/抬起/结束事件，按同一个触点与手势去重；这仍需实机核对，不能用模拟回调替代。

## 当前行为

- 按下后保留普通点击语义，移动达到共享主题中的 8 个设计单位才进入跟手状态。以实际画布大小及 stage 缩放将左下原点坐标换成中心原点坐标，宽屏留边也参与换算。
- 无目标牌依据 `Combat.canPlay(uid, nil)` 判定，拖至金线以上的战场区域松手提交一次 `Run.play`；防御、能力、群攻采用同一入口，不按牌名判断。出牌区、门槛及线位置均读 `ui_theme.json`。
- 需要敌人的牌必须落在存活敌人的头像命中范围，并再次通过核心校验；空地不使用默认目标，即使只有一名敌人也取消。
- 金线和「松手出牌」提示显示合法性；目标牌只高亮当前合法敌人。无效松手恢复手牌布局。金线以上区域止于顶部控件下方，不包含手牌、药水、结束回合或屏幕外。
- 手势绑定 run、battle、回合与 touchId；抬起前重新校验。先消费手势再调用出牌，防重复 Up/EndDrag 和晚到 Click 使用移动后的手牌槽。新的物理 Down 才恢复点击输入。演出、换战斗、失活、缩放中断均取消手势。
- 平台枚举不可用时保留点选说明和点选路径；原生入口传入真实 `Enum.CursorEventType`。未增加未经文档证明的指针或触摸 API。

## 验证账本

| 层级 | 本次结果 |
|---|---|
| 离线 Lua / UI 控制器 | `battle_ui.lua` 36 项通过；其中 6 项新增拖动场景组，覆盖真实 `Run.play` 和核心状态，不是 HTML 原型回归 |
| 代表无目标牌 | 防御、能力和群攻代表：defend / inflame / cleave / thunderclap；不声称全部卡池拖动覆盖 |
| 取消与保护 | 空地目标牌取消、非法区域、重复 Up/EndDrag/Click、跨触点、不可用条件牌、能量变化、敌方回合、演出锁、失活、移除卡牌、替换战斗、连续出牌及移动中缩放 |
| 画布坐标 | 离线覆盖 1280×720、1600×900、1920×1080、1560×720；不代表这些设备已实际操作 |
| 完整本地检查 | `npm run check` 通过；Python 13 项中 1 项因 Windows 无符号链接权限跳过，原有硬链接测试仍执行 |
| 平台 Lua 编译 / 存档写入 | 本次未执行 |
| 副本导入 | 本次未执行 |
| 游戏内鼠标 / 手机触摸 | 本次均未执行；用户要求暂不打开原神 |

## 下一次平台验收

使用存档副本、保持 `MILIASTRA_ALLOW_LIVE_WRITE=0`。分别记录桌面与手机：拖起后跨过金线空地松手、回手牌取消、拖到两个不同敌人、空地取消攻击、连续出牌、滑过结束回合/药水后取消、能量不足、演出期间触摸、拖动时改变窗口尺寸。核实回调归属和触点 ID，并观察画面、能量、手牌、目标及日志。

若捕获语义不能满足要求，应记录实际派发顺序和缺失事件，保留 C 档，同时明确 TASK-30 仍未完成；不能将点选可用、离线测试或原型效果当成拖牌实机通过。
