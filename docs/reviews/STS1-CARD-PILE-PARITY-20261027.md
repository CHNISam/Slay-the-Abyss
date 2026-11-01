# 手牌插值与战斗牌堆查看

基线 `develop@c91f0d22`。复用已恢复卡面、原生拖牌状态机、统一牌面和牌库弹层；未改玩法、卡池、费用计算或随机模块。PR238 的 deck/choice 新职业提示保留给主 session 合并。

## 方法依据与修复

固定只读来源为 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`；这是社区反编译镜像，不是本轮认证 PC 二进制。独立实现行为，不包含上游源码或美术。

| 原版调用链 | 当前差异 | 实现 |
|---|---|---|
| `CardGroup.refreshHandLayout` 设置目标，`AbstractCard.update` 调用 `MathHelper.cardLerpSnap/cardScaleLerpSnap/angleLerpSnap` | 正式 `placeCard` 每次重绘直接瞬移，悬停退出和取消拖牌也瞬移 | 按战斗身份和 UID 保存当前/目标位置；6dt 位置、7.5dt 尺度、12dt 角度，位置阈值按 1920 基准转换，尺度/角度阈值 .003；fastMode 额外一次位置步骤。保留批准稿目标布局和原生直接跟手；取消后从最后真实坐标回位，命中矩形保持稳定。 |
| `DrawPileViewScreen.open` / `ExhaustPileViewScreen.open` → `addToBottom` → 名称、稀有度、状态末尾稳定排序 | 只有牌堆计数，不能查看战斗临时牌与消耗牌 | `deckUI:openPile(run,kind)` 复用统一牌库与卡面；只对深拷贝排序，未知抽牌顺序不泄露；Frozen Eye 保持原复制顺序。 |
| `DiscardPileViewScreen.open` 直接用弃牌组，`AbstractCard.getCost/applyPowers` 显示战斗属性 | 永久牌库不能代替实际弃牌/消耗牌状态 | 弃牌组保留真实顺序，三牌堆读取战斗 definition/preview，显示临时费用、成长和升级；永久牌库继续读永久实例。 |
| `AbstractPlayer.draw` / `CardGroup.moveToHand` 设置抽牌堆起点和 `.12 → .75` 尺度，再刷新手牌目标 | 后续真实抽牌/回收的卡直接出现于目标位置 | 根据相邻显示 frame 的牌堆 UID 识别已有牌进入手牌，在批准稿抽牌图标位置以 `.12/.75` 相对尺度进入，沿既有同源插值到手牌。只读 frame，不增加事件、控件或 RNG。 |

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
- 追加 `battle_draw_motion.lua` 4 组：真实抽牌正常/fast位置与成长、空抽牌堆真实洗牌、新生成 UID 不冒认抽牌，以及正常 Shrug It Off 出牌后的反馈 frame 新 UID 实际入手。完整 run/RNG 只读断言通过；该测试直接更新战斗视图，排除 GameUI 正常计时器增长。旧 input12 组与 motion5 组在追加后通过。前一切片负对照在抽牌起点断言失败。

子 session 测试使用主 session 负责的临时接线：`battle_ui:update(dt)` 调用 `cardView.update(dt)`，以及三个图标的 `hit` 接到 GameUI 模态管理。精确 patch 已交主 session；本子分支不提交共享入口文件，主 session 正式整合后须复验新入口用例。图标下附透明命中层，保持 stage 60 控件；原生派发和层级仍待千星实机验证。

## 未取得的证据与剩余项

本切片没有千星候选、官方导入、鼠标/手机实机或 `verify:ui` 成功，不提升平台 AC。首帧开战手牌没有前一 frame 的来源信息，暂保留直接初始布局；新生成牌的专属出现动效、逐张弃牌/洗牌/消耗的 Soul 轨迹仍需后续对照。相邻 frame 无法看到的中间往返不伪造；本次没有用计数或通用反馈冒充这些完整演出。专属插画正式装配仍单独待验。已有提示框避边/分页和选择弹层继续复用，没有将其判作完全缺失。

来源 SHA256：`AbstractCard.java` `bcd472ececfd8ce4150ccd4eb6dd07a2e2dc43e139196fe00de34705cf1a2a61`；`CardGroup.java` `03de4e22ab22bedf1d90df72bdc83f033ff6aa776ad9d8f7259e1ee9293f7fa8`；`MathHelper.java` `d0b1c377a38fdf26f047c813e44e140a6c9a5dbb9029aa337ea6333cab41133f`。

## 2425ad6 组合回归修复

修复真实 resize 回归：取消拖动并隐藏捕获层后，卡牌还保留旧拖动坐标，原第46组要求立即回手的断言失败。cardView 现在在画布宽高变化时丢弃旧位置缓存，重新使用当前布局；没有修改这个原断言。原45–47三组在修复后通过。

原第4组要求点击选择就瞬间达到悬停尺度，已迁为当帧仍为原尺度、随后推进80个1/60帧。原来的选中、能量、手牌 UID、精确悬停尺度和出牌断言全部保留。两行插入须唯一出现，逆变换后仍匹配原53组正文 SHA256 `d97b7f1b44cb4c4655f9ae06ec429f88f40bfd322ddb1aa8ab30e4c2d08b9678`。

标题回归仍逐一检查八角色所有牌的基本/升级版本、名称、字号、标题带、升级标识及写入控件。完整目录组合后，四个原版角色各366条、四个原创角色各203条，共4552个变体；更新原2538总量并增加每角色精确数量断言。六个溢出标题的原身份与标识断言保留。4552变体与六个标识通过（7.913秒）。数量只用于防漏测，不作为卡牌规则或正常渠道验收。

`card_input_port.lua` 在原30秒内完成前11组后超时；按原有工程做法拆成1–6、7–10、11–12三个进程，仍各30秒。新增合同逆变换恢复完整原文件 SHA256 `62b56bbabbe457f0c6480f576cc2f83d34d71e698d354d0a4644820f2a47fa14`，保留每个原组、输入、种子、循环、helper与断言，逐名称核对一次执行覆盖。三片合同通过（16.258秒）。

本轮还通过卡面/布局/原型24项、卡图装配Python6项，以及旧牌库6组、pile4组、正常入口4组、motion5组、draw4组、drag response3组、drag boundary、拖牌source10组、gestures、card play11组和preview19组。固定cardView Luacheck无诊断、复杂度≤15，JS语法与diff检查通过。

**原53组当前完整合同尚未通过，不作全绿声明。** 两次完整合同分别在第46组旧坐标断言和原片2的60秒预算失败；后者已保留原27–38片及全部六个seed、每seed最多20动作和完整状态/RNG比较。独立收集片2也曾在60秒超时，前33组完成，正在第34组实际路径内；未改片2、预算、种子或断言。主 session 要求暂停继续分片，等远端实际结果再判断CPU争用和必要调整。原始本地日志与状态表保留在独立树 `work/card-regression-*.log`、`work/card-regressions-summary.json`，没有删除失败记录。完整CI、同候选构建和实机仍由主 session 验证。

随后原第34组独立运行全部六个seed、每seed最多20动作及完整状态/RNG断言，通过52.912秒；原27–38合片几乎没有剩余预算。主 session 据此明确授权只按组边界进一步拆分：1–26、27–33、34、35–38、39–44、45–47、48–53，共七片，各沿用原60秒。`scripts/test-lua.mjs` 仅给新增6/7片加入同一fixture白名单，保持原layout注入、错误处理、maxBuffer和既有所有超时。

新增纯元测试先核对完整正文原hash与七片文件/范围一次覆盖；原实际执行合同仍在完整CI中执行全部七片并逐个核对53个成功组号。原34正文没有修改，原片2的其余27–33七组实际通过8.594秒，35–38四组通过3.114秒；纯元测试及runner诊断7项通过，额外验证新增片仍注入layout且默认60000/显式321毫秒原样传递。没有重复运行已通过的52秒第34组，也没有重复本地整套53组；当前新SHA的完整结果仍等远端CI。

第34组52.912秒证据对应原样提交到 `6da4016d1e5d54f15f6af5baba815861a97178d6` 的运行时快照（启动时尚未提交，不冒充新提交的干净HEAD重跑）；`battle_ui_cases.lua` Git blob `7e081effa45d88d28b2d277887345329f37eee3c` / SHA256 `b0e2914345609fac6ae48956df6ff0b5591f5cce393ce24999458104954d19f2`，cardView Git blob `39838706f71f012dd5e8bb554c2078e3e9ddaa09`。本次分片前后support正文逐字节相同，仍保持全部六个seed。原日志 `work/battle-ui-case34.log` SHA256 `8d3c5ab13f3e08caab38016f29118438e657d7d25394e00a08996056bd33e4d1` 保留。
