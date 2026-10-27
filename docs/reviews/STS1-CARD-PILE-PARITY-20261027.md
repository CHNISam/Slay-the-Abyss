# 手牌插值与战斗牌堆查看

基线 `develop@c91f0d22`。复用已恢复卡面、原生拖牌状态机、统一牌面和牌库弹层；未改玩法、卡池、费用计算或随机模块。PR238 的 deck/choice 新职业提示保留给主 session 合并。

## 方法依据与修复

固定只读来源为 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`；这是社区反编译镜像，不是本轮认证 PC 二进制。独立实现行为，不包含上游源码或美术。

| 原版调用链 | 当前差异 | 实现 |
|---|---|---|
| `CardGroup.refreshHandLayout` 设置目标，`AbstractCard.update` 调用 `MathHelper.cardLerpSnap/cardScaleLerpSnap/angleLerpSnap` | 正式 `placeCard` 每次重绘直接瞬移，悬停退出和取消拖牌也瞬移 | 按战斗身份和 UID 保存当前/目标位置；6dt 位置、7.5dt 尺度、12dt 角度，位置阈值按 1920 基准转换，尺度/角度阈值 .003；fastMode 额外一次位置步骤。保留批准稿目标布局和原生直接跟手；取消后从最后真实坐标回位，命中矩形保持稳定。 |
| `DrawPileViewScreen.open` / `ExhaustPileViewScreen.open` → `addToBottom` → 名称、稀有度、状态末尾稳定排序 | 只有牌堆计数，不能查看战斗临时牌与消耗牌 | `deckUI:openPile(run,kind)` 复用统一牌库与卡面；只对深拷贝排序，未知抽牌顺序不泄露；Frozen Eye 保持原复制顺序。 |
| `DiscardPileViewScreen.open` 直接用弃牌组，`AbstractCard.getCost/applyPowers` 显示战斗属性 | 永久牌库不能代替实际弃牌/消耗牌状态 | 弃牌组保留真实顺序，三牌堆读取战斗 definition/preview，显示临时费用、成长和升级；永久牌库继续读永久实例。 |

插值每步的 lerp 因子限制到 1，适配平台长帧，避免超出目标；正常帧参数来自上述方法。原版 hover 的绝对尺度、扇形坐标没有覆盖批准稿。现有拖牌即时跟手保留，不冒称原版拖牌平滑完全一致。`fastMode` 为主入口统一标志，不能把单独设置该字段的测试当作已有玩家设置入口。

## 定向验证

- 新增 `battle_card_motion.lua` 5 组：源码速率、快模式额外步骤、同 UID 换槽重排、长拖取消回位、逐帧零规则预览、重开 UID 隔离、长帧不越界。
- 新增 `deck_pile_view.lua` 4 组：三牌堆顺序、重复同名稳定性、Frozen Eye、临时费用/成长、空堆、失效上下文，以及完整 run/RNG 深比较不变。
- 将原 `card_input_port.lua` 的悬停瞬移预期迁到实际帧后验证，保留原提升/回位/hover 身份断言，增加即时不瞬移断言；12 组通过。
- 原 `battle_ui_drag_source.lua` 10、`drag_response.lua` 3、`game_ui_deck.lua` 6、`battle_ui_card_play.lua` 11、`card_preview.lua` 19 组通过。没有删断言、缩池或改变超时。
- 原模块负对照：新 motion 首组在旧瞬移位置失败，pile 首组因旧模块无 `openPile` 失败；恢复实现后均通过。
- 新入口命中层布局 2 组、既有 UI/牌库布局 12 组通过；stage 直属控件仍 60，安全区、原视觉和全部名字保留。
- 临时按交接 patch 接通正式入口后，`game_ui_pile_entry.lua` 4 组通过：实际生成图标 → GameUI 模态 → 三种牌堆、关闭恢复、演出/拖牌/退出/奖励拒绝、真实升级 True Grit 强制选牌不被覆盖、同一 run 换战斗关闭旧快照。
- 固定 Luacheck 检查 cardView 无诊断且所有函数复杂度≤15；deckUI 保留四项既有 self shadow 诊断，无新增诊断（整合时需按真实新行位重定位原基线）。145 模块/716 边架构、JS 语法和 diff 检查通过。

子 session 测试使用主 session 负责的临时接线：`battle_ui:update(dt)` 调用 `cardView.update(dt)`，以及三个图标的 `hit` 接到 GameUI 模态管理。精确 patch 已交主 session；本子分支不提交共享入口文件，主 session 正式整合后须复验新入口用例。图标下附透明命中层，保持 stage 60 控件；原生派发和层级仍待千星实机验证。

## 未取得的证据与剩余项

本切片没有千星候选、官方导入、鼠标/手机实机或 `verify:ui` 成功，不提升平台 AC。抽牌、弃牌、洗牌、消耗的逐张运动/Soul 轨迹仍需后续对照；本次没有用计数或已有通用反馈冒充这些完整演出。专属插画正式装配仍单独待验。已有提示框避边/分页和选择弹层继续复用，没有将其判作完全缺失。

来源 SHA256：`AbstractCard.java` `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61`；`CardGroup.java` `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8`；`MathHelper.java` `d0b1c377a38fdf26f047c813e44e140a6c9a5dbb9029aa337ea6333cab41133f`。
