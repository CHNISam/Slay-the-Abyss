# 2026-11-01 移动端上线前验收：遮罩细边、结算用时与目标伤害预览

本轮依据用户录音、补充说明及 `IMG_1254.png` / `IMG_1255.png`。源码核对基线为 `develop@2d06741de47f2a65eb2772705e33064c16ccdce3`；提交前已同步 PR439 的 `a7193e1c5d63ab0c2b4892912312d4597e84c642`，下文涉及的卡面、选敌、出牌和结算展示入口没有变化。截图尚未关联构建 ID，不能据此认证当前源码候选。本文交接修复范围、源码证据和验收要求，未修改运行时代码，未新增官方导入或实体设备通过记录。

## 任务承接

| 本轮问题 | 承接任务 | 本轮处理 |
| --- | --- | --- |
| Bug 1：进入页遮罩仍有细边、少量留边 | TASK-38 | 追加独立验收项；原大块两侧露空按用户确认记为已修复 |
| Bug 2：结算“用时”显示 `3074457345` | TASK-38.3 | 新增 High / To Do；上线前必须消除错误显示，允许隐藏或明确不可用 |
| Bug 3：待出牌缺少当前目标伤害预览 | TASK-4.5、TASK-30 | 复用既有任务，补固定源对照、具体接线缺口和确认前预览验收 |

负责人沿用 Furinya。同步 PR439 后，当前 High 已满五项；优先处理用户明确的紧急用时缺陷，将尚未开始的原作身份清理 TASK-4.18 调为 Medium，为 TASK-38.3 留出执行位。身份清理的首发范围、负责人、To Do 状态及三条验收全部保留。已在执行的其他 High 任务保持，上游对 TASK-16.1 的排序说明完整保留。

## Bug 1：覆盖问题已改善，剩余细边仍需处理

用户本轮明确肯定：此前屏幕两边空着、UI覆盖不全的问题已经修复。保留这一人工验收结论，不重新把大块露空列成当前缺陷，也不据此勾选 TASK-38 中包含其他内容的复合验收项。

`IMG_1254.png` 的启程页仍有少量边缘留边，主画面左侧可见断续蓝绿色细线，视觉衔接不完整。此次处理的是这个残留样式问题。截图不足以认定遮罩、背景层、安全区或缩放中的某一项为根因。

验收：实体手机横屏重新进入启程页，遮罩覆盖区域收边完整，无残留细缝和漏出的底色；已经修复的两侧覆盖效果保持。

## Bug 2：错误用时必须在上线前消除

`IMG_1255.png` 的失败结算页“用时”为 `3074457345`。用户明确允许两种交付结果：可靠计时时显示准确、可读的用时；无法保证准确时隐藏该项或显示 `N/A` / “暂不可用”。不能继续显示错误数字，也不能用伪造的零时长掩盖不可用。

本轮只读检查：`src/lua/abyss_game_ui_menu_view.lua` 的 `clock` / `presentStats` 直接格式化 `run.elapsedSeconds`，没有显示不可用的分支；`abyss_game_ui.lua` 的更新入口累计 `dt`，`abyss_run_initialization.lua` 初始化为零。后续须核对当前候选的计时输入、单位、累计与格式化结果；本轮未确定截图中的大整数来自哪一层，不预设是溢出或单位错误。

验收沿实际共用路径覆盖失败、胜利、退出结算及重新启程；异常值与正常计时均有定向回归。实体手机确认用时字段的交付状态，且“重新启程”“结束并结算”仍可用。结算不可用的原状态提示与用时不可用是不同字段。

## Bug 3：按原版迁移明确目标到预览、确认的完整链路

用户要求：一张基础伤害 6 的普通攻击，面对有易伤的敌人，选到该目标时当前牌面应自动计算并显示 9，玩家不应心算；移动端点选、实际拖动及手柄等输入要按原版实际实现核实。用户关于“原版是否只有甩牌”“手柄理论上应更新”的表述是待核查的问题，不作为猜测式设计依据。

### 固定源码证据

沿用项目 `data/SOURCES.md` 的社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不混用另一镜像的行号或把它称为认证发行版。

| 需要核实的问题 | 固定源码结论与位置 |
| --- | --- |
| 是否只能按住拖放 | 支持拖放，也支持短点击后的携牌及后续确认；见 [AbstractPlayer 1091–1105、1137–1232](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1091-L1232) |
| 确认前是否更新数字 | 当前目标交给 `calculateCardDamage` 后绘制当前牌，再用 `applyPowers` 恢复玩家侧修正；见 [renderHand 1730–1766](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1730-L1766) |
| 手柄切目标 | 左右改变 `hoveredMonster`，渲染读取新目标；select/confirm 另行提交；见 [1003–1049](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1003-L1049) 与 [904–934](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L904-L934) |
| 是否有触屏路径 | 明确含 `Settings.isTouchScreen` 的位置偏移、瞄准停靠及释放分支，共用目标渲染；见 [1143–1232](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java#L1143-L1232)。不能据此认证千星实际触点事件或 Android/iOS 发行版 |
| 6 为什么变成 9 | [AbstractCard.calculateCardDamage 2298–2330](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java#L2298-L2330) 包含目标受伤修正；[VulnerablePower 57–68](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/VulnerablePower.java#L57-L68) 对普通伤害默认乘 1.5；牌面使用修正后的 `damage`，见 [AbstractCard 1775–1792](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/cards/AbstractCard.java#L1775-L1792) |

这里的 6→9 排除力量、虚弱、Paper Frog 等额外修正。9 是牌面攻击伤害，不能把有格挡时的实际生命减少量也硬断言为9。原版预览临时改卡的显示数值后恢复，不等于预览必须执行真实出牌。

### 当前源码的明确缺口

以下位置均指本轮核对的 `2d06741`：

1. `abyss_battle_card_view.lua:161–180` 的 `currentAim` 只接受 `view.gesture or view.carry` 且要求 `moving`；`bodyText` 只有命中该牌 UID 才向 `Combat.cardPreview` 传目标。
2. `abyss_battle_actions.lua:179–189` 的点选仅设置 `owner.selected`。`abyss_battle_target_bindings.lua:62–74` 的手柄敌人 Focus 更新 `owner.target` 并重绘，但没有建立移动手势。因此，**非拖动的手柄明确选敌没有进入卡面目标预览链**，卡面调用 `Combat.cardPreview` 时仍未传入该明确目标。
3. `abyss_battle_target_bindings.lua:39–60、76–127` 的敌人 Click 会直接提交所选目标牌；Down/Up 只维护输入身份，不建立可见的目标预览。不能把现状误写成“点敌只选中，之后还有确认”。
4. `abyss_battle_render_actors.lua:108–118` 的敌人扣血投影也限制在移动手势，不能拿敌人高亮或详情文字证明牌面预览已接通。

这证明一条具体的数据流缺口，尚不能包办用户那次手机操作的所有根因。实现者须沿真实生成控件的输入、选牌、明确目标、渲染及提交链补回归，并用同候选手机事件与连续画面复验。

### 保留的边界与验收

- **不能无条件用 `selected + owner.target` 兜底。** 当前 target 会被默认成第一个敌人，并不总是玩家明确瞄准；否则仅选牌也可能误套易伤。普通手牌包含玩家修正，当前明确瞄准的牌才加入该目标修正。
- 分别记录手机点选、手机实际拖动、PC点击携牌/拖放、已支持手柄选牌和切目标的“选牌→明确目标→数值可见→确认→结算”。预览必须在提交之前发生；仅证明最终打出9不足以通过。
- 基础6攻击对易伤目标显示9，切普通目标恢复6，切回显示9；取消、移出目标、切牌、状态移除及回合/战斗变化不残留旧目标值。预览不扣费用、不移牌、不造成伤害。
- 保留既有点选保底、双击取消、手机无效释放和触点身份保护。原版单目标分支并非所有无效释放都立即取消；TASK-30的手机无效释放取消是已有项目要求，须记录这种差异，不伪称逐字一致。
- 依据原版与平台证据完成等效迁移，不擅加确认按钮或改成两次点敌。目标来源统一后再验证输入手感，不能只改显示文案。

TASK-4.5旧记录的 `renderHand 1678–1715` 保留为历史排版引用；本次固定镜像核实位置为1730–1766，核心为1761–1764。原已勾离线证据不撤销，也不扩展为新候选手机通过。

## 本 PR 验证范围

任务修改使用 Backlog CLI 1.53.0；新旧任务去重、负责人、父子关系、High上限与首发排期由现有 `verify:backlog` 检查，回归使用 `tests/backlog-roadmap.test.mjs`。原始截图留在本次会话，本文不转写玩家账号标识。

本 PR 交付的是修复任务与已核实源码证据。实现修复、官方候选、当前设备交互与上线许可仍需各自的实际结果，不因这份文档通过而关闭。
