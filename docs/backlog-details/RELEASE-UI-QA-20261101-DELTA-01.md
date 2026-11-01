# 发版增量 01：基础卡框近乎不可见，核对跨场景共享皮肤

编号 `QA-DELTA-01`，承接现有 `TASK-25.4`，必要时联动 `TASK-4.20`。这是用户在上一轮修复后提供的两张新截图及口述，不并入旧 R2-01 的拖牌出屏问题。产品优先级 P1，发版前待修。本文是定位和验收交接，不是运行时修复或验收通过记录。

## 现象与复现

用户明确说明这是其当前最新版。图 A 为奖励选牌界面上打开的“卡组 · 10 张”，初始普通攻击、防御、破防斩的外框非常暗，视觉上像没有完整卡框；图 B 关闭卡组后，三张奖励牌有清楚的银灰外框。两张原图均为 2048×1152。含 UID/GUID 的原图不复制到仓库。

复现：战斗结束进入三选一奖励，打开卡组观察初始牌外框，再关闭回到奖励页对照。记录卡牌 ID、稀有度、升级/选中态；后续必须用同一张牌跨页面验证，不能只比较不同稀有度来判定组件缺失。

## 已核实源码：有共享组件，不是两页完全各写一套

核查基线 `develop@0b9c9b848d916212111f6cb608cbfe0f53f7c2ac`，已包含 #449。相关代码：

- [scripts/card-face.mjs](https://github.com/CHNISam/Slay-the-Abyss/blob/0b9c9b848d916212111f6cb608cbfe0f53f7c2ac/scripts/card-face.mjs)：`cardFaceChildren` 为 battle/deck/node 共用装配，包含可见的 `roundFrame`、`roundBody`、标题带、类型标签和费用圈。旧矩形 `border` 控件默认隐藏，不能只检查它就声称外框已修。
- [scripts/deck-ui-layout.mjs](https://github.com/CHNISam/Slay-the-Abyss/blob/0b9c9b848d916212111f6cb608cbfe0f53f7c2ac/scripts/deck-ui-layout.mjs)：牌库模板明确调用 `cardFaceChildren(theme, 'deck', false)`；`false` 是交互装配参数，不是取消卡框。
- [abyss_deck_ui.lua](https://github.com/CHNISam/Slay-the-Abyss/blob/0b9c9b848d916212111f6cb608cbfe0f53f7c2ac/src/lua/abyss_deck_ui.lua) 的 `fill` 和 [abyss_node_ui_faces.lua](https://github.com/CHNISam/Slay-the-Abyss/blob/0b9c9b848d916212111f6cb608cbfe0f53f7c2ac/src/lua/abyss_node_ui_faces.lua) 的 `fillCard` 均调用 `CardSkin.apply`。
- [abyss_card_skin.lua](https://github.com/CHNISam/Slay-the-Abyss/blob/0b9c9b848d916212111f6cb608cbfe0f53f7c2ac/src/lua/abyss_card_skin.lua)：`frame` 根据 `definition.rarity` 取色，并同时给旧 border 和可见圆角框着色；选中态另有统一强调色。

## 可直接解释截图的原因：基础牌外框配色过暗

[data/cards.json](https://github.com/CHNISam/Slay-the-Abyss/blob/0b9c9b848d916212111f6cb608cbfe0f53f7c2ac/data/cards.json) 的初始牌组为 5 strike、4 defend、1 bash，三种均为 `basic`。

[ui_theme.json](https://github.com/CHNISam/Slay-the-Abyss/blob/0b9c9b848d916212111f6cb608cbfe0f53f7c2ac/data/presentation/ui_theme.json) 同时在 `color.rarity` 与 `cardSkin.rarities` 中给 basic 指定 `#34363C`，common 指定 `#8C929D`；卡主体为 `#161820`。

按这些源色值计算外框对卡主体的相对亮度对比，basic 约 **1.47:1**，common 约 **5.66:1**。这是源颜色诊断，不是设备测量或无障碍认证。截图局部像素也吻合该配色差异：图 A 首张卡区域可见近 `(52,52,62)` 的暗框，图 B 首张奖励卡区域可见近 `(140,145,157)` 的银灰框。截图抽样只证明呈现差异，不绑定构建 SHA。

因此首要处理的是**共享皮肤中的基础牌外框辨识度**，而不是为卡组补另一套卡框。基础牌可以保持基础牌的视觉层级，但不能靠近乎不可见的边界区分稀有度；不得把游戏数据中的 basic 改为 common 来绕过问题。

## 复用上的实际维护隐患，勿当作已证实的截图根因

DeckUI 与 NodeUI 在调用共享皮肤之前还会分别写 border/nameBand/nameRule 等颜色；共享皮肤又维护 `decorations` 缓存。这是重复样式写入，应核对首次绘制、同状态刷新、列表控件复用后是否仍由同一来源决定外观。

目前可见圆角框由共享皮肤着色，旧矩形 border 默认隐藏；本轮没有证明缓存导致可见框消失。不要据此臆造缓存根因或扩大成全 UI 重构。修复应优先调整共享主题，并消除与实际可见结果冲突的重复写入；不在卡组、奖励、商店各追加一份颜色补丁。

## 本项验收要求

- [ ] 基础牌在深色卡面及当前遮罩背景上也有清晰、完整、与奖励卡同一结构的外框；费用、牌名、类型和效果不受影响，稀有度及选中态语义保留。
- [ ] 同一张牌、相同升级/选中态在手牌、卡组/抽弃牌堆、奖励、商店与锻造遵循同一共享皮肤规则；允许场景缩放，不允许遗漏外框或单独复制实现。
- [ ] 定向回归包含 basic/common/uncommon/rare、首次打开、重复刷新、筛选/排序后控件复用和选中/取消；检查可见 roundFrame 而不只断言隐藏 border 的颜色。不得修改规则、牌池、费用、RNG、UID 或领取行为。
- [ ] 同候选 PC 和实体手机按上述路径复验，保留卡组/奖励对照；离线控件或浏览器投影不替代设备结果。

## 候选身份与交付边界

图 A 仍可见长排序标签“排序·初始顺…”及底部“保留打开牌组时的展示顺序。”；所查基线的 DeckUI 已是短标签“初始”，普通浏览长说明已在 #448 移除。这是**候选身份/装配核对线索**，不能仅凭截图断言用户运行旧版，更不能以此否认卡框反馈。构建/导入方应记录当前源 SHA、候选哈希与实际导入对象，核对生成资源是否进入本轮候选。

本轮完成源码调用链核对、两图尺寸/局部像素核对及源色值对比计算，未修改运行时代码，未执行项目自动测试、构建、官方导入或设备操作。本环境无法解析 GitHub 主机以克隆仓库，且 `backlog instructions overview` 返回 command not found；已用 GitHub 连接读取固定源码，不手改 Backlog 文件。后续执行者通过 Backlog CLI 在 TASK-25.4 补充本项未完成 AC，保持现有负责人 Furinya；不重复建单、不勾旧设备验收。
