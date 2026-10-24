# TASK-4.6 战斗卡牌数值反馈

依据用户提供的实施包（SHA256 `ebf4be4e0ac30195f4396e7bc3131fd174c4df240ec62b49f4b4073b58b61a71`），按 README → DECISION → 02_SPEC → 03_QA读取。原始基线develop `695d94d`，已集成编号修复 `35fc111`。计划见[执行计划](../plans/2026-10-25-card-value-feedback.md)。

## 最终表现：原句内数字变色

参照包内固定原版镜像`fc379c875c11e008e9c10548ac8e394c301c532f`的`AbstractCard.getDynamicValue/renderDynamicVariable`：动态数字仍处于原说明句中，只有变化数字局部红绿。紧贴数字的↑/↓是本项目无障碍补充，不冒充原版已有箭头。

- 例：“为自己增加 3↓ 点格挡。”只对3↓着色，其他文字不变。双效果分别比较、分别着色；多段显示每段值，不合计改写。
- 保留原卡面、插图区图标、费用、类型、完整说明、148×208卡片、132×92说明、最小字号14及原命中区。**不新增独立数值面板，不替换卡面图标。**
- `abyss_card_display.values`只读同index的cardDefinition.effects与cardPreview（low==high）；升级/永久成长后的定义为基准。`format`只编码同一个动态数字的原生颜色标签与箭头，不改战斗状态或公式。
- 仅damage/damageAll/block可比较；最终等于基准时中性。Body Slam沿用中性当前值，状态层数、抽牌、固定药水/遗物值不套战斗数字色。
- 瞄准目标只传给正在瞄准的牌；取消、换目标、状态移除、重排、奖励复用时每次生成完整说明，旧色与箭头随之消失。费用禁用色独立。
- 专用主题色`#7DC77A`/`#EF7672`，不改全局positive/danger；原说明底`#1C1E27`理论对比8.164:1、5.935:1。灰阶仍可用↑/↓，不宣称整游戏WCAG认证。

## 原生行内能力已实测

已读MCP workflow/platform-rules。1849为独立能力探针，仅用于验证原生文本解析；不是交付构图或完整游戏验收。

- 候选SHA256：`5a7fad26ad09d64178509c6eb685fde0d80f2e779cdb03b2cab7a9571c3c652d`。
- run：`e4c4cfaa-4977-41ee-a32a-46e5711126d7`，显式`clientScriptLog:true`，本轮新日志打印`CARD_INLINE_PROBE_READY`。
- 真实截图确认同一132×92原生文本框可解析`<color=#EF7672>3↓</color>`、`<color=#7DC77A>8↑</color>`，正常中文换行、箭头有字形、混合效果可分别红绿，其余文字保持中性色，未显示字面标签。
- [原生探针截图](../evidence/card-value-feedback/native-probe/inline-colour-1849.png)只裁掉底部UID区，未修改文字/颜色。完整原图、请求、日志与存档在根`.artifacts/card-inline-probe`和`.artifacts/card-native/live/playtests/<run>`。
- 上述只证明原生行内能力；**真实卡牌倾斜、状态刷新、触摸与手机适配须用最终同源候选另验**，不能复用探针认证。

生产控件使用已实测的原生颜色语法，不接收HTML/CSS。`native-inline-preview.mjs`仅将原生颜色标签转换为离线浏览器预览，不能当成平台渲染证明。

## 测试与复现

`npm run build:theme`、`npm run build:ui`、`node scripts/test-lua.mjs tests/lua/card_value_display.lua`、`node scripts/test-lua.mjs tests/lua/card_preview.lua`、`node scripts/test-lua.mjs tests/lua/growing_card_text.lua`、`node scripts/test-lua.mjs tests/lua/card_value_fixture.lua`、`node --test tests/card-value-feedback.test.mjs`、`npm run check`。

离线预览：`node scripts/battle-ui-preview.mjs <新目录>`，包含neutral/frail/dexterity/weak/mixed/aim/cancel/ten/ten-selected，见[截图](../evidence/card-value-feedback/offline/value-mixed.png)。它们使用实际核心状态和生成树，图库是原型字形替身，不是实机。

普通候选独立审计：`node scripts/audit-native-candidate.mjs --source <完整SHA> --candidate <gil> --output <新目录> --bgm`。严格UI门禁：`npm run verify:ui -- <同一普通候选.gil>`；不改全局验收清单刷绿。

原生专项夹具：`node tools/card-value-feedback/build-fixture.mjs <普通候选.gil> <新目录>`，只在测试副本增加fixture模块并修改入口。受控八阶段为无状态/脆弱/敏捷/虚弱/瞄准/取消/混合/十牌。夹具可认证渲染，不认证自然状态获取、真实拖动、物理手机触摸或完整通关。全程`MILIASTRA_ALLOW_LIVE_WRITE=0`，不发布。

## 验证纪律与防复发

最初B档独立标签被用户否决，相关旧候选和旧测试不认证新版。错误在于未先实测行内能力，就把局部数字反馈改为额外信息面板。现已撤销；卡片结构回归在旧版证红、撤销后转绿，并核对运行中图标仍可见。保护放在本项目测试，不增加全局规则。

群攻保留现有第一存活敌人显示和逐敌预览的既有局限，不把显示值声称为所有敌人的相同结果，不为本任务发明范围或改核心。奖励/商店/牌库/营地不调用战斗数值格式化。

原695d94d独立归档的card_preview基线15组通过；旧标签版完整check通过只属历史。新版专项已有展示10组、预览19组、成长11组、夹具8阶段和布局4项通过；完整检查、最终候选、电脑/手机和全UI结果以专项报告为准，不提前记PASS。

TASK-51已记录免费模型额度耗尽、窗口未知；本轮仅只读核对CLI/模型目录，没有发推理请求或收费回退，Codex额度节省未知。
