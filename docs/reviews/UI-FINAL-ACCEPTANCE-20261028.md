# 本轮 UI 最终集成与逐屏验收

当前为执行中的追溯记录，**整体未验收**。代码合并、原生控件导出、官方预览、游戏内操作分别记录。所有屏幕的本轮原生预览和 PC/实体手机实测仍为 NOT_TESTED，不复用旧候选证据。

## 设计与源码身份

- 正式基准画布为 **1280×720**，安全区左右40、上下20；最小字体14。1920×1080 ui-canvas 是设计参考，须落到原生控件和运行时布局后验收。
- 现行 `docs/design/ui-canvas/` 与其中较晚的明确交接修订优先；未覆盖页面使用 PR19 原型、screens 和后续批准决定。设计仍有无法判定的冲突时保留待裁决，不自行发明方向。
- PatchNotes 已废弃。`PatchNotes.dc.html` 仅保留历史，不恢复公告按钮、页面、脚本或玩家公告流。
- 初始远端 develop：`d2e0baa3e798aac5b5220e40a815006b18b47fbd`。#292 精确候选 `adf2575a5b0532dc22bbf580d284e1b9fda16d89` 当时仍为 Open；不能称已合并。#290 正式选角 `6b171428025ba40474eabf77b4b1477f3dc0ec51` 已在 #292 父系中。
- 已完成的 `feat/start-flow-polish` 中 `04bcc621d411cecb90439483de3cd271ca5c14bc` 和 `ba79edcd5f2391afd0f6bd4ea6189bea9815bb4b` 已完整 cherry-pick 进入隔离集成分支，分别为 `3802affe`、`404ce0c4`。附带原提示词文档保留；本轮不生成角色/卡牌插画。
- `feat/formal-battle-ui`、`feat/card-face-complete`、`feat/native-ui-parity` 初查仍在 develop 旧头上且有未提交改造；`feat/ui-focus-return` 为独立失焦修复。不得读到脏文件就算入正式候选。等待各自提交/PR交接后逐笔集成，所有原工作树保留。
- `feat/m3-molten-egg` 最新头 `1bfb188e` 含候选外的提交父系，不能按 #292 旧冻结头直接宣称无新工作或清理。不得用旧分支整树覆盖 #292 已保留的药水职责治理。

## 逐屏追溯

控件路径均相对正式原生 `stage`。以下“有实现”仅表示读到正式代码，**不表示视觉与实机 PASS**。

| 屏幕 | 设计要求 | 实际控件/代码 | 当前实现与差距 | 本轮原生预览/测试 |
|---|---|---|---|---|
| 主菜单 | 正式标题、启程、操作说明、角落版本号；无废弃公告 | `menuPanel/title,start,codeVersion`；`game-ui-layout.mjs`、`abyss_game_ui.lua` | 启程进入选角，四格结果与平台结算保留；基线缺现行公共菜单和操作说明，待公共UI交付 | NOT_TESTED；菜单原生布局/开局行为继续验证 |
| 角色选择 | 五入口、旅行者四元素、真实初始信息、选中才确认、返回不建局；已批准美化 | `characterPanel/details,elements,character1..4,traveler,confirm,cancel`；`abyss_character_select*.lua` | #290 状态机保留，ba79edcd 卡式信息与元素主题已保留；正式肖像仍有明确占位，不伪装成已交付新画 | NOT_TESTED；布局、安全区和八选择专项待组合复验 |
| 战斗 | 右半场敌阵、无头像方框、具体HP/格挡/能量；并列意图、状态折叠；14星点与准星、伤害预演 | `battlePanel/hero,enemy1..5,statusInfo,dragLayer`；`ui-layout.mjs`、`abyss_battle_*_view.lua` | 已有真实数值与瞄准底座；基线仍有复合意图角标、头像框等旧布局，正式战斗交付处理中；五敌为现有池容量，不新增第六敌玩法 | NOT_TESTED；必须复验最多合法敌人、最大手牌和模态输入 |
| 牌库 | 原生六列滚动、真实UID/升级/全文，共享完整卡框，关闭后不误触 | `deckPanel/grid,close`、`AbyssDeckCard/face`；`deck-ui-layout.mjs`、`abyss_deck_ui.lua` | 原生Grid及模板已存在；卡框交付须同步手牌、商店、奖励、锻造和牌库，不能只改手牌 | NOT_TESTED；基础布局回归通过，原生滚动和字体待验 |
| 奖励/选牌 | 金币、药水、卡牌独立领取，满槽说明、真实卡面、跳过及回图，底层战斗禁用 | `battlePanel/rewardList,rewardStage,card1..10,skip`、`combatRewards`；战斗奖励视图及host | 独立奖励列表和选牌台有实现；须在共享卡框和公共菜单组合后复验；示例数值不替代核心 | NOT_TESTED；领取/跳过与回图行为待组合复验 |
| 地图 | 四周雾气、点线路径、主角菱形令牌、官方节点；取消旧查看按钮/状态图例，营地官方篝火 | `mapPanel/mapGroup*/node*,edge*`；`map-ui-layout.mjs`、`abyss_map_ui.lua` | 基线仍有三个查看按钮、状态图例与实线；公共UI分支正在处理，最终需确认隐藏控件不可获焦、不能误点 | NOT_TESTED；基线35/36定向通过，地图原27用例在Node22和Node24均原30秒超时，不记通过 |
| 商店 | 全部真实货架、价格独立、红价/售罄/满槽/删牌确认，商人不遮价 | `nodePanel/shopView/card*,price*,relic*,potion*,removal,detail`；`abyss_shop_ui.lua`、`abyss_node_ui.lua` | 已有七张真实货架、遗物药水与删牌服务；PR19五卡示例不削减真实商品。离线1280对照已检查，卡框仍待共享交付 | NOT_TESTED；离线对照与结构检查不能代替买卖/触控验收 |
| 营地 | 休息/锻造双选项，真实回复数；选卡、升级前后、确认与结果 | `nodePanel/campView/rest,forge,result`、`pickerView/forgeGrid,before,after` | 双选项与真实升级前后已经存在，离线对照可见；需复验网格/分页及最大长文案 | NOT_TESTED；基础节点布局回归通过 |
| 宝箱 | 关闭→开箱爆发→全部奖励；各奖励独立领取/互斥提示，离开明确 | `nodePanel/treasureView/closed,open,burst,rewardItem*,take,details` | 已逐层核对GameUI固定enhancedRooms=true→NodeUI→TreasureUI全奖励分支；正式配置真实显示两项奖励并逐项绑定事务。旧直接NodeUI预览为兼容分页入口，不能误作正式host | NOT_TESTED；开箱及全部奖励待组合定向测试 |
| 事件 | 左图右正文、完整选项/灰态原因、结果和继续；复杂选牌与多阶段不串输入 | `nodePanel/eventView/art,name,body,option*`、`pickerView`；`abyss_node_ui.lua` | 基础结构/条件/结果已接；事件图当前为官方元素替代；受限池内部文案出现在基线离线预览，须复核正式配置与清除内部解释 | NOT_TESTED；已检查圣职者离线几何，不能代表全部事件 |
| 药水 | 可读效果、使用/目标/取消、对自身与对敌区别；空/满槽和丢弃安全 | `potionEntry,potionPanel`、`battlePanel/potion*,potionHelp,dragLayer`；药水视图/输入模块 | 栏位、说明和丢弃流程已存在，战斗新版共用瞄准待整合；须验证按住/中断/多指/失败不耗瓶 | NOT_TESTED；新增同候选药水门禁，不借历史药水证据 |
| 退出/结算 | 全屏可发现菜单、继续/退出确认阻断底层；取消不改变资源；实际平台结算 | `exitEntry,exitPanel/cancel,confirm`，`menuPanel/result,settle`；host/退出适配 | 基线直接退出入口及确认已有；已保留无法保存的既有说明。公共菜单与失焦修复仍待合流，不用界面字样代表平台已收到结算 | NOT_TESTED；退出基础布局回归通过，平台/手机动作未验 |

## 跨屏容量与证据纪律

基线实际生成树：battlePanel 992节点/每层最多60；mapPanel 1106/50；nodePanel 1170/34；menuPanel 80/24；deckPanel 62/10；potionPanel 152/15；characterPanel 231/15；exitPanel 44/9；牌库模板20/16。最小字体14。此为adf候选的静态数值，新卡框和组合完成后必须重测，不能沿用。

- 60是单父级直接子控件上限，不是整屏资源或帧率保证。整屏节点数、十张手牌、最大合法敌人、滚动列表、多重弹层及星点每帧更新均需真机性能审查。
- `withViewport` 在 stage 外使用拉伸底色，stage 内按 min(width/1280,height/720)缩放；物理手机平台按键区、刘海/窄高比、原生字体和触摸分发仍缺本轮证据。
- 现有 `verify:ui` 已新增 character/potions/exit；每屏增加原生1280×720、PC与手机安全区、字体图层、输入、容量性能审查。设计身份纳入有效ui-canvas，PatchNotes不参与。未实测不勾PASS。
- 本轮隐藏浏览器离线对照位于根 `.artifacts/ui-final-node-preview/`；已核对旧13场景及正式host启用的强化房间14场景；当前全部27个场景的离线文本拟合未检出裁切。它们是运行真实Lua控制器后的控件树，用系统字体/示意图标绘制，**不是官方原生预览**。
- 本轮未占用桌面输入，无官方导入、ready、客户端新日志、PC/实体手机逐屏测试。实机窗口需遵守AGENTS单独协调。

## 验证与交接

- 初始定向：36项中35通过，地图30秒超时；Node24.19串行复验仍超时，原日志保留。没有增大预算或删除原用例。
- UI证据门禁第一次定向通过；增加每屏检查后继续复验，不声称本轮源码全绿。
- 最终UI组合尚未形成，**没有最终develop SHA**。不得提前向构建者把d2e旧头或adf候选称作最终版本。
- 最终构建交接必须固定实际合入后的40位develop SHA，完整游戏GIL，全部Lua模块/原生UI/六列模板/结算图/场景与BGM参数，附输入源身份、hash、静态检查及独立读回；不得只做UI小样或简化占位包。由用户亲自导入验收，构建不冒称平台通过。

接续：#292 已更新为 `e3cd8492b2c05e3acc13c26168fdc476668b2468`，新增最新源父系与账本更正；本轮必须按新头的Quality核验，不复用adf头。已核对差异为六个文档/账本/回归文件，未丢药水职责治理。

已独立保留 #293 `4b0ad423f98854c353f79e8ac38667a80a84b8e2` 父系；输入永久锁定有红绿复现，候选中的单模块实验GIL不作为本轮完整游戏交付。

新增门禁与选角布局专项共4/4通过、零跳过；真实设备与官方预览仍未验。`node-ui-preview.mjs` 现优先导出正式host强化房间的14个场景，并保留旧直接节点兼容场景，避免只截图旧分页入口造成错误验收。

最终审计追加修复：正式战斗模块漏登记已修，219模块/1253边架构通过；真实隔离伤害预演7项通过。复合意图改为三个完整图标横排、攻击优先、数字在攻击图标左下；状态补金/紫底框与深色计数底，第十项起+N，正层数99+且保留负号。5项原生呈现/容量专项通过，保持旧命中路径；最终组合仍须重验。

卡框真实提交9ed2ad20合流：保留所有生产卡框、皮肤helper、六组运行状态与原始83407/hash579244945场景副本（tests/fixtures/ui-final/card-skin-trace.lua）；历史证明冲突保留#292正式入口/内容逆变换与所有原始档案，最终组合另建精确来源逆变换及当前逐写入校验，不拿单独卡框的83407条当组合预期。
