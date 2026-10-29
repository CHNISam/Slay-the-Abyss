# TASK-4.7 持有遗物图标站位报告

## 已落地
- 新增 `src/lua/abyss_relic_view_ui.lua` + `scripts/relic-view-layout.mjs`：持有遗物面板，每行 = 图标盘 + 中文名 + 状态签（剩余次数/耗尽）+ 说明，分页浏览。
- 顶栏圆形遗物盘（32px / 36 步进，对齐原型 topBar()）；节点顶栏原“遗物 N”文本交给共享盘位行。
- 牌组模态新增 `inspectRelics` 钩子，复用牌组弹窗生命周期，战斗/地图输入门控保持只读。
- `ui_theme.json` 新增 `layout.relicView`；`config/architecture.json` 登记新模块为 ui 层。
- TASK-4.8 中文文案修复提交已在本分支。

## 图标来源
- 全部绑定 `Theme.icon.relic` 已有的原神/千星官方图库 ID，**未自绘、未新增任何 SVG/图片**。
- 主题中已有的占位图标保持占位，待专属美术替换（见 relicView.note）。

## 测试
- 通过：tests/relic-view-layout.test.mjs、tests/owned-relic-view.test.mjs、Lua owned_relic_view(4)、relic_top_bridge、elite_relic_reward_ui、relic_camp_ui、check:architecture。
- check:quality 本机缺 luacheck（需 `npm run setup:lua-static`），属环境问题。

## 仍未关闭
- 真机/编辑器内实机验收（图标显示、点击打开、分页）未做，TASK 不标记 Done。
