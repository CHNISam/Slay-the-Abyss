# 战斗卡牌动态数值反馈执行计划

用户已指定实施包的 DECISION 与 02_SPEC 为已确认设计，并授权提交、合并 develop。基线 origin/develop `695d94d`；任务 TASK-4.6。采用现有 cardDefinition/cardPreview，只读逐 effect-index 比较，不改任何战斗公式。

1. 运行原有 card_preview 与全 Lua 基线；先新增展示模型红测覆盖包内 T01–T19/T24/T30/T31。
2. 新增 `src/lua/abyss_card_display.lua`，输出 base/current/direction/text/colourKey；不支持或无稳定基准的效果保持中性。
3. 核查原生文本 API。先交付 B 档候选：说明全文保留，插图区内按效果放置小型中性标题与独立红绿数字/箭头，背景采用深色主题面板；仅变动项显示，不修改卡片尺寸或命中区。A 档内联颜色尚无原生验证，不宣称平台不支持。
4. 在 `ui_theme.json` 增加专用颜色和布局 token，生成树最多两个反馈项（当前所有卡片 eligible effects 最大为2，加入数据回归防止静默溢出）。支持净零、混合方向、升级成长、仅正在瞄准的牌更新和每次重绘清理。费用语义独立。
5. 扩充真实生成树回归：RGB、文案、可见性、40高文本/14最小字号、1/5/10手牌与缩放安全区、输入/只读不变量及非战斗隔离。
6. 执行 build:theme/build:ui/test:lua/check、对比度检查。构建同源副本，独立回读与静态检查；尝试官方导入和PC专项取证，手机若无设备明确待测。严格运行 verify:ui，不改全局验收清单刷绿。
7. 将包内T01–T32映射至真实证据，按报告模板区分本地/候选/导入/PC/手机/全UI。CI当前SHA成功后 squash PR至develop，保存可恢复历史并清理本轮分支。

免费委派：TASK-51记录用户已报告限额、窗口未知；本轮仅只读确认CLI和模型目录，不发推理请求，不轮询额度，由Codex完成。
