# TASK-4.6 战斗卡牌数值反馈

依据用户提供的 `Slay-the-Abyss_Card-Value-Feedback_Research_20261025.zip`，SHA256 `ebf4be4e0ac30195f4396e7bc3131fd174c4df240ec62b49f4b4073b58b61a71`。按 README → DECISION → 02_SPEC → 03_QA读取；没有重新解释已确认规则。基线 develop `695d94d`，完整执行计划见 [计划](../plans/2026-10-25-card-value-feedback.md)。

## 实现

- `abyss_card_display`只比较当前 cardDefinition 的 effect.value 与同 index 的 cardPreview.low（且low==high），输出数字、方向与主题键；不参与结算。
- 支持 damage/damageAll/block，升级与永久成长的当前定义为基准；最终抵消为原值时中性。Body Slam、抽牌、回血、状态层数等不套方向色。
- 每次 render 清空反馈文本、颜色和可见性，再只为当前实例生成；瞄准目标只传给正在瞄准的牌。费用禁用色保持独立。
- B档：全文说明不变，在插图区内放深色小面板、独立数字及↑/↓、中性效果名；变化时临时取代图库示意图，不改变类型条、牌名、费用、卡片尺寸或命中区。数字在左半边，避免10牌扇形遮住新信息。多段标为“每段”，双效果分行，各自比较。当前全部基础/升级卡最多2个可比效果，测试锁定容量。
- 专用主题色 increase `#7DC77A`、decrease `#EF7672`，不改全局 positive/danger。实际反馈底色 `#272A36`：理论对比7.019:1、5.103:1；非整游戏WCAG认证。

## 原生能力与限制边界

已读本机MCP workflow/platform-rules；平台规则有实测 `text` 与 `fontColor=Color(...)` 当帧更新。离线官方API目录来源为“附录/客户端控件API文档 mhtakr07vej4”，有fontColor、raycastTarget、disableCursorEventPassthrough，未提供已核实的文本局部颜色接口。**这不证明平台不能内联着色**，没有向生产控件注入HTML/富文本标签。本轮选择已知独立文本控件B档，A档内联着色仍未验证，不冒充A档。

新增对象不含cursorArea/presetButton/focusable/blockCursor/blockKeys；原有card/hit在它们上面。源树/本地输入回归不是实际触屏派发的证明。

群攻保留既有第一存活目标的显示语义和逐敌预览；它不代表所有敌人的最终伤害相等，不发明范围或改核心。奖励、商店、牌库、营地不调用本战斗反馈模块。

## 可复现检查

`npm run build:theme`、`npm run build:ui`、`node scripts/test-lua.mjs tests/lua/card_value_display.lua`、`node scripts/test-lua.mjs tests/lua/card_preview.lua`、`node --test tests/card-value-feedback.test.mjs`、`npm run test:lua`、`npm run check`。

离线可视化：`node scripts/battle-ui-preview.mjs <输出目录>`；新场景value-neutral/frail/dexterity/weak/mixed/aim/cancel/ten/ten-selected。这是实际核心状态+生成树的离线浏览器图，**不是千星实机**。

普通候选：`npm run build:native -- <底图.gil> <新目录>`；独立读回用`node scripts/audit-native-candidate.mjs --source <固定SHA> --candidate <gil> --output <新目录> --bgm`。

专项原生夹具：`node tools/card-value-feedback/build-fixture.mjs <普通候选.gil> <新目录>`。它只在独立副本加入fixture模块，修改入口为受控八阶段（无状态/脆弱/敏捷/虚弱/瞄准/取消/混合/10牌）；生产模块保持同源，但入口与状态是测试夹具，**不能作自然获取、真实拖动、手机触摸或完整通关的证据**。夹具自身有8阶段本地回归。

正式同候选全屏门禁为`npm run verify:ui -- <普通候选.gil>`，不改全局清单刷绿。

## 证据与任务状态

本地基线：从695d94d归档的独立目录生成并运行原有card_preview，15组通过。早先全Lua“基线”与实现修改重叠，其失败不能归为原基线缺陷，已保留日志并作废该口径。

本轮专项：展示模型10组、完整原生树预览19组、夹具8阶段、布局/对比度4项通过；完整check及原生验证结果见后续专项报告，不提前宣称通过。

免费委派：TASK-51已记录用户额度耗尽、重置窗口未知，本轮仅只读核对CLI/模型零定价，不发推理请求，不回退收费模型；Codex额度节省未知。
