# 地图界面接入与批准稿对照

设计依据：[已批准 PR #19](https://github.com/CHNISam/Slay-the-Abyss/pull/19)、[UI_DESIGN.md](UI_DESIGN.md)、[map.png](screens/map.png)。本切片延续 TASK-12 的真实地图，替换此前尚未提交的「三页各五层、矩形文字节点」界面方案。只交付可构建的原生控件布局、Lua 适配器和自动验证，不包含节点业务。

## 已实现

- `scripts/map-ui-layout.mjs` 读取 `data/presentation/ui_theme.json`，输出 `build/map-ui.json` 原生控件定义，以及 `build/lua/abyss_map_layout.lua` 几何契约和 `abyss_map_controls.lua` 同源控件树。后者供测试或工具读取控件 schema，不作为游戏规则。
- 地图模块 `src/lua/abyss_map_ui.lua` 读取 `abyss_theme` 的 0–255 颜色、地图尺寸和图库编号。1280×720 的 `stage` 等比缩放，背景是 stage 外的独立图片；宽屏侧边也被背景覆盖。
- 600 高视窗、76 层距、112 列距，普通节点 56、首领 96；圆形节点、当前节点光晕、可前往节点 1.4 秒呼吸（支持减少动效）、七类节点图标及右侧图例。暗金已走过、亮金当前、白色可前往、灰色不可达，图例以同色圆环示意（不再用颜色文字）；视窗可上下拖动滚动；只有真实路径上的连线变金。
- 15 层内容连续滚动。进入或重新显示时定位**当前层**，首层/首领处限制到内容边界。左右两侧安全区保留；左侧三个 148×52 按钮支持向上看后续、回到当前、向下回顾，触屏无需拖拽。图例同时提供文字，状态另有文字说明。
- 数据只来自 `Map.view`、`Map.available`；节点位置和连线遍历真实 `view.nodes` / `nextIds`，不解析节点 id 来重建规则，不使用 HTML 原型里的随机演示地图。

## 宿主接线

生成源码产物（不会操作 MCP、编辑器或存档）：

```powershell
npm run build:data
npm run build:theme
node scripts/map-ui-layout.mjs
```

把 `build/map-ui.json` 的 controls 接到界面宿主，或由后续导入流程创建同名控件。将 `abyss_map_ui.lua`、`abyss_map.lua`、`abyss_random.lua`、`abyss_theme.lua`、`abyss_map_layout.lua` 与核心所需模块一起提供给客户端。控件树的根必须同时包含 `mapBackdrop` 和 `stage/mapPanel`；本构建器不擅自指定战斗脚本入口。

```lua
local MapUI = require("abyss_map_ui")
local ui

-- OnStart（map、coordinator 为宿主持有的真实对象）
ui = MapUI.new(script.object, map, function(node)
    -- 这个同步事务负责 Map.choose；例如 return Nodes.enter(run, map, node.id)。
    -- 只在实际提交成功时返回 true；拒绝时返回 false, reason 且不改地图。
    return coordinator:chooseNode(node.id)
end, Enum.CursorEventType.CursorClick)
ui:resize(game.GetUICanvasSize())
script:EnableUpdate(true)

-- OnUpdate(dt)
ui:update(dt)
-- 画布尺寸改变时再调用 ui:resize(game.GetUICanvasSize())。
```

`onChoose` 收到 `Map.available` 给出的独立节点副本。UI **不调用** `Map.choose`，因此不会和 `Nodes.enter` 重复推进。宿主负责展示目标节点和完成业务；`ui:setNavigationEnabled(true)` 只能在该节点已处理完后调用。已进行过的地图在新建适配器时默认锁住；显示地图不代表节点已完成。

接口：

PR #29 的统一宿主使用 `MapUI.new(mapPanel, map, onChoose, clickEvent, {embedded=true, color=Color, imageSource=Enum.ImageSource.StaticReference})`。此时直接绑定当前 `mapPanel`，外层唯一 stage 负责画布缩放；嵌入式 `resize` 只记录尺寸，地图内部保持 `scale=1`。上面的独立模式及构建入口仍保留。`buildMapUI(outputDirectory)` 供完整构建器同时生成地图控件与 Lua 几何/控件契约；地图身份变化会重置滚动及默认锁，节点与奖励完成后由宿主显式重新授权。

| 调用 | 行为 |
|---|---|
| `render()` | 刷新真实视图；发现外部位置推进时重新锁住导航 |
| `setVisible(boolean)` | 隐藏时屏蔽全部地图输入；重新显示定位当前层 |
| `setNavigationEnabled(boolean)` | 外部协调器明确交还/收回导航权限；刷新可点目标 |
| `focusCurrent()` | 定位当前层，不前瞻或推进地图 |
| `setScroll(basePixels)` | 限制到 `[0, maxScroll]`，只改视图 |
| `scrollBy(basePixels)` | 正数查看更高层，负数回顾；隐藏时拒绝 |
| `resize(width, height)` | `min(width/1280, height/720)` 等比缩放；背景独立铺满 |
| `update(dt)` / `setReducedMotion(boolean)` | 更新呼吸或改为静态；隐藏时停更 |
| `choose(nodeId)` | 重验 `Map.available` 后发命令；返回 `true` 或 `false, reason` |

滚轮/拖拽由宿主在确认客户端回调参数后接到 `scrollBy`：先把物理像素除以 `ui.scale`，再按所需滚动方向传入。基础按钮始终可用。本切片没有假定尚未验证的拖拽位移或滚轮事件。

重复/重入选择、隐藏、未解锁、非法或不可达节点都被拒绝。事务回调必须同步；异步返回值不被当作成功。回调返回 true 但地图未实际推进会返回 `selection_not_committed`。回调抛异常返回 `choice_callback_error`；若回调已改变位置，即使随后拒绝或抛异常，也会刷新并锁住，防止继续进入另一节点。该防护不会撤销宿主已经执行的业务。

地图 `view.complete` 仅表示抵达首领，文案为「已抵达首领 · 请完成首领战斗」；不把它当作通关或结算。

## 与 map.png 的差异和验证边界

| 项目 | 当前实现及原因 | 状态 |
|---|---|---|
| 节点布局 | 原型示例最多七列且含演示随机图；真实核心是三列、43 节点，居中按主题 112 列距绘制，15 层首领终点保持原规则 | 真实 Lua 验证；无规则改动 |
| 顶部玩家 HUD | 本切片只显示真实层数标题；生命、金币、药水、遗物、卡组由共享 HUD 宿主接入，不复制截图中的假数值 | 待宿主整合 |
| 图标/字体 | 使用主题中的千星图库编号和平台字体，替换 CSS 矢量示意 | 源码接入；实际图库观感待平台核对 |
| 滚动输入 | 三个原生可聚焦按钮提供完整保底；保留 `scrollBy` 给宿主连接滚轮/拖拽 | Lua 控件点击验证；原生输入和手柄聚焦待平台验证 |
| 视窗裁剪 | 本地 API 文档未提供可确认的 container 子控件遮罩开关。连线按视窗几何裁短；节点连同呼吸/光晕范围将出界时整颗隐藏，边缘不会显示半颗圆 | 几何测试通过；这是待平台验证的临时降级，不声称平台必然做不到原型裁剪 |
| 当前光晕/可前往呼吸 | 光晕图库图垫底，呼吸通过有界 `localScaleX/Y` 实现 | 数值范围/减少动效测试通过；观感待平台验证 |
| 背景效果 | 主题纯深岩灰蓝底色，无 CSS 渐变；遵循批准稿“不依赖渐变”约束 | 几何验证；观感待平台验证 |

## 自动验证

```powershell
node --test tests/map-ui-layout.test.mjs
# 上一条会生成数据/主题/控件树；也可先运行上述三个构建命令
node scripts/test-lua.mjs tests/lua/map_ui.lua
npm run check
```

JS 覆盖主题引用、原生控件 schema、名称契约、最小字号/触控区域、手机/电脑/主机/宽屏安全区。Lua 直接使用构建器生成的同一棵控件树，以真实 `abyss_map` 和 Fengari 执行 10 组测试：全图各节点可见性/图标、合法推进与连线、不可达/回退/隐藏/出界输入、完整 15 层及首领、恢复定位、事务拒绝/重试、异常提交锁、四种画布尺寸、实际边与路径颜色、呼吸范围及视图刷新。

这些测试证明源码行为与几何契约，不代表千星客户端编译通过、导入成功或实机观感通过。本切片**未调用 MCP、未平台编译、未写入存档、未游戏试玩、未核对图库**；TASK-12 AC3 留待主 Agent 整合审查及平台验收，不在此自行勾选。
