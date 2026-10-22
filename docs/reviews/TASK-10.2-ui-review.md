# TASK-10.2 原生战斗 UI 独立审查

审查者：`/root/content_review`，非 TASK-10 作者。初审代码基线：`3648a27`，最终功能复审基线：`8966ef27876401f3efadf0e37513815eb54d3327`。审查分支：`feat/task-10-2-review`，日期：2026-10-23。

结论：**在上述固定代码基线的原生 UI 功能范围内无剩余阻断。** 初审发现的奖励页状态同步问题已由主 Agent 修复，合入该提交并通过独立复验。以下证据属于离线 UI 控制器和资源构建；审查者未操作 MCP、GUI、存档或游戏。后续视觉对齐代码不在本结论中，须在提交后追加审查。

## 范围及方法

读取 `abyss_ui.lua` 生命周期入口、`abyss_battle_ui.lua`、真实 `abyss_run.lua`/Combat 接口、布局与构建脚本、Lua UI 测试、布局 JS 测试、CI presentation job 和接入文档。独立执行 `npm ci --ignore-scripts`、`npm run check` 与 `npm run build:ui`，现有门禁及资源构建通过。

既有 Lua UI 测试使用控件替身模拟原生 API，但规则命令是实际 Run/Combat，不是第二套游戏规则。审查者额外用系统临时 Lua 文件测试替身未覆盖的路径；未修改生产实现或既有测试。

在最终基线独立完整重跑门禁，保留 npm 退出码为 0：85 个 JS case（79 pass、6 个 symlink 权限条件 skip），4 UI + 15 core + 8 run + 26 status + 10 map 真实 Lua case 通过；六表校验与 theme 生成通过。Python 11 个 case 中 10 pass、1 个 symlink 权限条件 skip。独立再次 build:ui 后加载最新生成的 presentation，真实手牌标签渲染探针通过。

## 初审阻断：奖励页仍显示战前临时战斗对象

位置：`abyss_battle_ui.lua` 的 render 玩家 HUD 分支。

UI 在 reward 阶段仍优先读取 `run.combat.player`。Run.finishCombat 已把战斗生命同步至永久 run 并应用战后遗物回血，而保留的 combat 是结算前快照。因此奖励页的玩家生命与下一场实际生命不同；能量、格挡和状态也来自已结束的临时战斗。

最小额外真实 Lua 复现（复用已提交 UI 测试的 setup 控件替身）：

```lua
local ui, root, click = setup()
click("start")
ui.run.combat.player.hp = 50
ui.run.combat.enemies[1].hp = 1
for i, c in ipairs(ui.run.combat.hand) do
    if Combat.cardDefinition(ui.run.combat, c).type == "attack" then
        click("card" .. i)
        break
    end
end
assert(ui.run.phase == "reward")
assert(root.children.player.text:find("生命 " .. ui.run.hp .. "/", 1, true),
       "reward HUD shows stale pre-heal combat hp")
```

观察：实际点击攻击获胜后，`run.hp=56`，`combat.player.hp=50`，HUD 为“生命 50/80 … 能量 2”。独立断言失败，runner 返回 exit 1。建议只有 combat 阶段读取临时战斗 HUD，其他阶段读取 run 持久态并清除临时状态展示。

**复审已解决**：该提交仅在 fighting 时读取 battle.player、能量与牌堆，其他阶段显示 run 生命并清除临时展示。原最小失败文件未经修改再次执行，返回 exit 0，观察 `run=56 / battle=50 / HUD=56、格挡0、能量0`。正式 UI 测试增加第 4 项回归，还断言 reward 阶段状态为空且不展示已结束牌堆。其余独立多敌闭包、拒绝、重开探针在修复后保持通过。

## 额外独立行为证据

- 在 combat 阶段直接触发隐藏的 start/skip/continue/card10 回调，递归比较完整 run 未变；阶段守卫与空槽拒绝有效。既有测试覆盖实际能量不足拒绝，不扣生命、能量或手牌。
- 将真实 Run 置于合法第 6 层三哨卫遭遇，通过 enemy3/2 控件点击验证闭包索引正确；点击实际攻击牌只伤害选中敌人，其他敌人生命不变。
- 为实际 actor 设置力量/虚弱后 render，状态名称与层数正确；攻击意图明确带“基础”，没有把未计算力量/虚弱的数值冒充最终伤害。
- 让敌方真实行动致死，失败页显示重开并隐藏结束回合；点击重开后是 10 张初始牌组、80HP 新 Run，未泄漏上一局牌组。
- 既有测试通过实际可用牌点击赢下战斗，奖励进入永久牌组，下一场真实 draw/hand 中能找到所选卡牌；不是只修改显示文本。
- 执行真实 Python→Lua presentation 构建，然后将生成的 `abyss_presentation` 传入 UI，真实手牌标签匹配生成名称和效果文本；补足既有 Lua 测试中 `DISPLAY_*` 占位显示不能证明生产资源接入的覆盖边界。

## 布局、生产 API 与单源

布局 JS 测试按最小 1280×720 画布检查顶层和子控件绝对边界，所有 10 个手牌槽存在、点击区最小边长 44。人工核对控件层次和控制器动态生成名称一致，阶段互斥的菜单/奖励控件在相同区域复用，不把菜单覆盖战斗卡牌视为实际同屏遮挡。离线边界检查仍不能证明实际字体断行、手机触控或手柄焦点体验。

只读核对本机 `D:/MiliastraTools/genshin-miliastra-mcp` 的官方 API 镜像 `knowledge/official/guide/mhtakr07vej4.md`、`src/scene/client-api.json` 和 writer `src/scene-save.mjs`：生命周期、script.object、GetChild、文本属性、SetVisible、AddCursorEventListener 与 CursorClick 均有对应。writer 对未指定 active/visible 的控件默认开启，不能套用旧示例中“新建控件需 SetActive”的不同情境误判本次布局。社区 scene_check_client 主要核对字面量名称，动态 enemy/card 控件路径与点击行为仍须此类测试及实机证据。

UI builder 调用已验证的 Python 中文展示渲染器，以 data/cards.json 数值和 presentation overlay 合成展示，再序列化 Lua；UI 控制器只发 Run/Combat 命令，不自行保存第二份伤害或费用。生成 Lua 和布局 JSON 位于忽略的 build 下。CI presentation job 已增加 builder，实际在本机额外构建通过；该 job 未显式 pin Node 版本是可改进项，不能据此宣称远端 CI 已运行通过。

合入的 theme builder 将颜色转为官方 Color 所需的 0–255 通道，覆盖资源/字体校验和真实 Lua 加载测试通过；Lua 数据导出保护的直接、相对、hardlink 路径用例通过，symlink 用例按权限条件跳过。本次功能基线的原生 battleLayout 尚未消费新增 abyss_theme，主题构建、静态设计图和原生视觉实装必须分开报告。主 Agent 已安排另一个实现者进行视觉对齐；本审查没有追踪其未提交工作，也不批准之后的变化。

## 验收边界

当前是初始牌组战斗演练，重复 cultist 遭遇仅用于验证奖励入组与再次战斗；地图导航、七类节点及完整第一幕未由此 UI 实现。平台副本检查、导入和前台试玩由主 Agent 单独取证；审查者没有独立复验该结果，更未把离线绿色门禁当作原神内实际显示、点击、触控或手柄验收。
