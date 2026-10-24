# 药水选敌与使用前说明：交付记录

本次对应 TASK-14.1.1，复用 TASK-14.1 的药水事务、TASK-4.4 的分组分页说明、TASK-10.5.1 的卡牌关键词帮助和 TASK-41 的触摸归属保护。父任务的完整原版与实机验收不随此本地切片关闭。按用户要求只提交，不新建 PR。

## 输入与审计身份

- 用户附件：`STA2_Potion_Targeting_Status_Research_20261025.zip`，SHA256 `ff915609e5f8bb6eac067bc0af4d2a136957eece85c2b04dde9de6bdcf503928`。
- 从 README 的渐进索引读取 EXECUTION、CURRENT_PROJECT、SOURCE_LEDGER、STS1_RULES、POTION_TARGETING/POTION_CASES、STATUS_EXPLANATIONS/COPY_DECK/STATUS_CASES、VALIDATION/HANDOFF。
- 开工 fetch 后基线 `695d94d`，包内审计为 `1bdf181`；实施期间又同步最新 `35fc111`（任务编号检查修复）。根 develop 的原有未提交工作保留，所有实现位于 `fix/potion-targeting` 独立工作树。
- 实现固定提交：`951c2bb47bda3ce62d66272447bb4eb81ecdd624`。后续收口提交只补任务与证据，不改变候选源码。
- 包内事实依据为初代 PC A0 的固定第三方反编译镜像和 Wiki 交叉记录，未认证正版 PC 二进制或原作实机录像；没有复制原作代码或素材。
- 固定来源：[PotionPopUp](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/ui/panels/PotionPopUp.java)、[PoisonPotion](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/potions/PoisonPotion.java)、[PoisonLoseHpAction](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/unique/PoisonLoseHpAction.java)。完整百分比、目标策略和职业限制按附件 SOURCE_LEDGER / STS1_RULES 核对。

## 实现与取舍

目标药水原先直接把 `self.target` 交给 Run；新战斗默认值为 1。现在点击火瓶或隔离毒瓶只建立瞄准意图，随后明确点击存活敌人才调用一次原有 `Run.usePotion`。意图绑定 Run、战斗、回合、库存表、物理槽/药水 ID，以及敌人对象和存活快照；敌方触点额外绑定该次瞄准对象。先点敌人的旧焦点不会自动确认药水。

再点同瓶或战场空白取消；换瓶、卡牌操作、状态说明、牌库、顶栏药水管理、缩放、停用、回合/战斗/终局变化都会取消或失效。敌人死亡、同索引换对象及 EndDrag 不会把旧触点传给新对象。卡牌与药水只保留一个待执行动作。自用五瓶仍短按生效；固定槽位、库存原子事务及旧指针所有权保持。

七瓶定义新增 `targetPolicy`：2 个 `enemy_one`、5 个 `self`。Run 的只读可用性采用该策略；校验器拒绝缺失、未知及与当前效果不符的策略。`enemy_all` / `random_enemy` 保留分类语义，当前没有对应可玩效果；隔离群体投掷反例证明 `isThrown` 不会强制单敌选取。没有上线新瓶，没有改数值、稀有度、概率、职业池、奖励或战斗算法；毒瓶仍无 Ironclad 自然获取入口。

每瓶旁增加独立“说明”点按入口，手机无需先冒险用药。悬停与长按瓶子也能打开同一个 `statusInfo`；长按松手/Click 被消费，不会用药或进入瞄准。详情先写实际效果与对象，再复用卡牌/当前状态的关键词行，保持分页与只读行为。中毒说明包含不立即扣血、自己的回合开始失去当前数值生命、无视格挡、随后减层；虚弱/易伤解释普通攻击的固定百分比与剩余回合；脆弱/敏捷限定卡牌格挡。卡牌普通/升级文本和敌人意图使用“回合”单位；卡牌帮助保留临时/本战持续时间。人工制品拦截时显示“人工制品抵挡／未施加中毒”等真实原因。

药水按钮摘要区保留可读字号，扩大内部文字框容纳双行；说明按钮按共享主题布置，单独容器保证每层不超过 60 个子控件。原版 PC 的“使用/丢弃弹框→瞄准”在此采用“点瓶→选敌”功能等价轻量适配；顶栏原有丢弃确认继续使用。沿用批准稿色彩、字体和共享详情卡，并非原版菜单的逐像素复刻。

## 红绿证据

原始 `695d94d` 独立归档快照加载最终交互测试，结果 **1 过 / 11 败**；P01 直接记录点火瓶造成第一敌人 20 伤害。见 [baseline-red.log](../evidence/potion-targeting-20261025/baseline-red.log)。自用瓶原本正确，保留为负控。

补充红测分别发现并修复了 EndDrag 后瞄准未退出、卡牌持续单位和帮助持续时间、人工制品缺少拦截原因、商店缺少对象摘要、原生按钮文字高度不足、瞄准空白区沿用出牌文案。原型内嵌牌面也同步相同的回合单位，未改布局。完整检查曾发现 Shockwave/Large Spike 的旧“层”断言及 Python 原型/牌面旧文本快照，均更新到新文案契约，交易、数值、状态顺序和演出行为断言保留。红测日志与最终绿测分开保存；其中早期测试路径笔误和被替代的部分全量运行不作为成功证据。

| 包内用例 | 自动验证入口与断言 | 本轮边界 |
|---|---|---|
| P01–P04 | `potion_targeting.lua`：先瓶无事务、选第二怪只耗一次、同瓶/空白取消、固定伤害先抵格挡且不受攻击修正 | 本地 |
| P05–P08 | 同文件：替换/死亡、回合/战斗/库存/终局/牌库/状态/顶栏/resize/停用失效、EndDrag 与迟到触点；保留三份旧药水输入回归 | 本地；实际原生事件顺序待验 |
| P09–P11 | 同文件及 `battle_ui.lua`：槽3稀疏库存，1/2/5敌人，第三怪明确确认，自用五瓶无需选敌 | 本地；手机触控待验 |
| P12 | 七瓶策略与生产校验；`potion_status_rules.lua` 的隔离 thrown/group 反例 | 不新增群体可玩瓶 |
| P13 | 第二怪 Artifact1 阻止施毒但正常耗瓶；检查可见拦截反馈 | 本地隔离毒瓶 |
| S01–S02 | 独立说明点按与长按；药水尚未使用、对象/实际数值/中毒时间及下一层数 | 本地 |
| S03–S06 | 毒6逐次6/5/4/3/2/1，总21；Barricade保留10格挡；普通攻击百分比不影响毒；毒4+6=10，弱2=6、易伤2=12 | 隔离纯净规则模型，21不当作保证预测显示 |
| S07–S08 | 卡牌与升级文本/关键词、临时/本战持续；尚未执行的意图；当前毒6→5说明实时更新 | 本地 |
| S09–S11 | 脆弱卡牌格挡3、敏捷2+脆弱后格挡5、固定瓶12；旧 `card_preview` 多段与库存固定火伤回归 | 本地；不改核心计算 |
| S12 | 帮助/render 对 Run 可变状态（含 RNG）、战斗、事件、库存、卡牌和目标的深比较；独立计时字段除外 | 本地只读 |
| S13–S14 | 长按不误用、共享详情分页、原生行高、安全区、互不重叠；13个离线预览场景无裁切 | 原生游戏/物理手机仍待验 |

最终定向日志：[药水交互](../evidence/potion-targeting-20261025/targeting-final-green.log)、[状态规则与说明](../evidence/potion-targeting-20261025/status-final-green.log)。完整检查、候选身份与独立读回见同目录 [receipt.json](../evidence/potion-targeting-20261025/receipt.json)。

## 分层验收与复核入口

L1：最终完整 `npm run check` **退出0**：JS 1226项中1108通过、118跳过、0失败；180个Lua文件全部通过；Python 22项中21通过、1跳过、0失败。Python跳过是Windows符号链接权限，另有硬链接别名用例验证。专项交互12组、状态规则与说明10组均通过；原生控件树安全区/行高/独立说明触点检查通过。完整日志见 [full-check.log](../evidence/potion-targeting-20261025/full-check.log)。最终检查及候选审计期间游戏源码哈希未变化。

L2：最终候选 `F:\New folder\.artifacts\potion-targeting-candidate-final\wmvmor9te-0\working.gil`，SHA256 `7d978a106508b364e9406c9d27baa20c0a04d56aec86e1da2245cf6a11b75ea2`。编译/导出退出0，静态0错误/32警告（明细保留）。针对固定提交951c2bb独立归档重建并只读审计，48模块逐byte一致，2391控件、最大直属子控件59、UI与模板匹配，结算图身份/启用挂载/非空载荷检查通过，候选读前读后hash不变。图的完整编译参数和语义不由这份身份审计认证。见 [candidate-readback.json](../evidence/potion-targeting-20261025/candidate-readback.json)。初次候选不作为最终版本证据。

L3/L4/L5：本轮未官方导入、未启动游戏、未物理手机测试，无本轮客户端 ready、截图或日志可供实机验收；`verify:ui` 不宣称通过。离线截图使用系统字体和原型字形代替图库图，不能证明原生文字、触摸或正式美术验收。

下一次平台验证复用 TASK-14.1 / TASK-4.4 / TASK-38：固定本次最终候选，`clientScriptLog: true` 确认本轮 ready，实测“先瓶不耗→第二怪确认→只耗一次”、取消/失效、说明与长按松手，并为物理手机独立取证。毒瓶只在明确隔离夹具验证，不冒充首发职业自然掉落。

免费委派按 TASK-51 已记录的限额暂停路径处理，本轮由 Codex 接管，没有发起模型请求；费用节省未知。
