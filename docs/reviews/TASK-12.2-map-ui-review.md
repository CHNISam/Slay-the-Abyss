# TASK-12.2 地图 UI 与事务边界独立审查

审查基线：`d3c6c412650147d7617c4b04c04006a3fbc1cb3c`。日期：2026-10-23。审查者：`/root/content_review`，未参与本次地图 UI 编写；曾编写底层地图规则，因此本报告的非作者复核结论限定为 UI 切片和协调边界，不另冒充地图规则的独立作者审查。

结论：**当前地图 UI 切片的离线功能范围无阻断。** 宿主入口、节点事务和平台实际显示仍须整合与验证；本报告不勾选 TASK-12 的游戏界面验收，不代表导入或游戏试玩通过。

## 审查与测试证据

逐读 `abyss_map_ui.lua`、`map-ui-layout.mjs`、Lua/JS 对应测试、`MAP_IMPLEMENTATION.md`，对照批准稿 `UI_DESIGN.md`、共享 `ui_theme.json`，实际查看 `screens/map.png`。既有 `map-ui` 工作树未被改动；在单独 `map-ui-review` 工作树复核。

独立执行 `npm ci --ignore-scripts` 后完整 `npm run check`，退出码 0：

| 门禁 | 结果 |
|---|---|
| JS | 87 case，81 pass、6 个 symlink 权限条件 skip、0 fail |
| 真实 Lua | core 15、map 10、map UI 10、run 8、status 26，共 69 case 通过 |
| Python 表现渲染 | 11 case，10 pass、1 个 symlink 权限条件 skip |
| 构建 | 语法、六表校验、地图 schema/geometry、主题生成通过 |

复现命令：`node --test tests/map-ui-layout.test.mjs`，该命令先生成真实 JSON→Lua 数据、主题和同源控件树，再执行 10 组 Fengari UI 行为用例；或直接运行完整 `npm run check`。审查者额外以系统临时 Lua 文件执行真实 Nodes 事务联调和受限全局完整路线，不修改既有测试或实现。

## 导航与事务边界

UI 读取 Map.view/available，onChoose 获得独立节点副本。UI 自己不调用 Map.choose，避免和 Nodes.enter 重复推进；只有回调返回 true 且实际 currentNodeId/floor 已到目标时才报告成功。同步回调期间的重入、已提交后的重复点击、隐藏、恢复中途地图的默认锁、不可达/旧节点/出视窗输入均有防护。

回调拒绝但未提交时允许重试；回调抛异常会释放 choosing 守卫。如果回调已经改变位置，即使随后拒绝或抛异常，UI 也会锁住并重新定位，不会继续选择别的节点。UI 不撤销宿主已提交业务，事务原子性由协调器负责。导航授权只能在宿主确认节点完成后交回，不能仅凭 Map.available 仍非空就解锁。

额外联调使用其他工作树当时尚未提交的 `abyss_nodes.lua`：只读冻结到临时目录，文件 blob 为 `a1b9b72d2e5b3199c6c2e154c389a788e3d5ffde`，**不是该候选模块已包含在 d3c6c41 的证明**。真实 Run/Map/UI 与候选 Nodes.enter 的探针通过：

```lua
local ui = MapUI.new(root, map, function(node)
    return Nodes.enter(run, map, node.id)
end, clickEvent, adapterOptions)
-- 第一次真实控件点击：map.path 仅增加 1，run.floor 同步，进入 combat，UI 锁住。
-- 即使提前错误地 grant，Nodes.enter 仍返回 node_pending，地图不推进。
-- 用实际 Run.play/endTurn 击败全部敌人，领取/跳过奖励并 Nodes.completeCombat。
ui:setNavigationEnabled(Nodes.view(run, map).navigationEnabled)
-- 下一次选择再次只增加 1 层/1 条 path，随后自动锁住。
```

该探针说明当前候选 API 的接口可以正确协调，不替代候选 Nodes 的独立审查，也不代表最终宿主接线已交付。节点业务代码提交或宿主改变调用顺序后仍须按最终组合重跑。

## 可视状态、布局与生产 API

- 15 层 43 节点和全部连线来自真实 Map.view 的 nodes/nextIds；没有用 HTML 演示地图替换规则。逐段滚动测试实际看见所有节点与七类图标，当前/已走/拓扑可前往/不可达状态和真实已走边颜色正确。暂时的业务导航锁还通过 notice 与不可点击 hit 表达；白色路线本身仍表示拓扑上可达。
- 当前层定位、整段滚动、恢复/重新显示定位正确；抵达首领仅显示“已抵达首领 · 请完成首领战斗”，没有把地图终点当作胜利。
- 独立背景在 stage 外铺满，stage 按 1280×720 等比缩放。手机、电脑、主机、宽屏几何测试通过；动态节点含光晕与呼吸范围不越视窗，连线经过几何裁剪，不依赖未确认的 container 遮罩。
- 与批准稿对应：600 高视窗、76 层距、112 列距、圆形节点、共享颜色/图库、右侧七类图例与已走金线。真实规则为三列而非原型最多七列，属于已说明的规则映射。按钮提供不依赖拖拽参数的滚动保底。
- 本机官方 API 镜像确认 game.GetUICanvasSize 返回 x/y 两数，SetAnchoredPosition(x,y)、SetSizeDelta(x,y)、localRotationZ、canControllerFocus 均有对应定义。颜色采用 0–255；生产默认 Color/Enum、测试注入替身，接口形状相符。模块及资源命名在文档中列全，新增模块没有自己的游戏规则或 Run 副本。
- 额外在 package/io/load/loadfile/dofile 置 nil 后，用已加载的模块遍历真实 15 层、更新呼吸、2340×1080 resize，全部通过。此为受限全局离线冒烟，不能代替官方客户端运行。

## 尚需宿主和平台验证

UI module 不是独立场景入口；宿主须创建/挂载生成控件树，调用 new/resize/update，并把点击交给真实 Nodes.enter，在节点完成后按 Nodes.view 授权。已有文档给出接线示例，未伪装已完成宿主集成。

顶部真实玩家 HUD、原生滚轮/拖拽参数、手柄聚焦、图库观感、字体断行、手机触控与实际容器裁剪仍需平台核对。测试只证明 schema、几何和模拟控件上实际 Lua 命令的行为，不能证明引擎实际绘制与输入分发。整节点边缘隐藏与按钮滚动是已明确的保底方案，不宣称原生平台不能支持更好的裁剪或拖动。

审查者未使用 MCP/GUI、未写入或导入存档、未平台编译或游戏试玩。未修改实现工作树、Combat/Run/节点业务/主题/CI，也未自行合并或对作者代码 self-approve。
