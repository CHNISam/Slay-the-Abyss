# M3 事件选项与交易证据独立复核

基线 `e1ae599e17e5470c1fa4b5e4963477489a5c92df`。本轮独立树只补测试和报告，生产事件、原池顺序、资格、随机算法、主题均未改。没有操作Backlog。范围 TASK-13.1、TASK-13.1.2、TASK-61 的事件部分；商店、宝箱、营地和整套掉落不在本轮补测中。

## 与既有55路径的差集

55条公开比赛池路径证明24条第一幕/31条第二幕、42个身份各有至少一条 `Nodes.enter → view → chooseEvent → map` 完成链。它不是全合法选项矩阵。固定源逆向材料 `event-production-source-inverse` / `m3-event-delivery-source-inverse` 证明完整源码归属、精确历史重建及拒绝未知改动；这些测试本身不执行每个选项，也不能替代结果oracle。

既有77项经济复验覆盖价格、binary32、完整遗物队列、奖励升级和reward owner等。它不是42事件全部交易源×所有目标结果×持有遗物交互的笛卡尔积。下列原有专项已提供实质行为证据，不应重新当作尚未实现：

| 事件域 | 可查现有执行证据 | 精确边界 |
| --- | --- | --- |
| Cleric、Goop、Shining Light、Golden Wing、Upgrade/Golden/Purifier神龛 | `cleric.lua`、`unknown_events.lua`、`node_transactions.lua`、原生Node/UI专项 | 有资格、价格、空组、UID和重复拒绝；不能由这些局部例子推出全经济来源覆盖 |
| Living Wall / Transmogrifier / Fountain | 对应 `living_wall*.lua`、`transmogrifier*.lua`、`fountain_event*.lua` | 有移除/转化/升级、源池选择、空组、旧UID和故障回滚；与所有onRemove/onObtain效果的组合仍须看各hook专项 |
| Big Fish / Sssserpent / Blacksmith / Bonfire | `act1_event_content.lua`、`act1_event_ui.lua` | 含全部主选项、curse/relic顺序、Omamori/Fish、缺依赖与移除hook；不是实机 |
| Scrap Ooze / Wheel / Lab / Woman in Blue / We Meet Again | `scrap_ooze.lua`、`wheel_event.lua`、`potion_events.lua`、`we_meet_again.lua`，对应UI与fairy专项 | Wheel六结果；三种同局交易、空类别不耗随机、槽位身份、缺遗物回滚；付出来源与获得结果不是全目标矩阵 |
| Golden Idol / Mushrooms / Dead Adventurer | `golden_idol_{event,costs,rounding,gold,channels,rollback}.lua`、`mushrooms*.lua`、`event_combat_route_reducers.lua`及enemies/terminal/bridge | 前两者已有真实Nodes和hook组合；Dead大量固定源向量先在独立module reducer运行，公开正常完成链另有集成 |
| Match / Duplicator | `match_event_{commands,sampling,integration,ui}.lua`、`duplicator_event_integration.lua` | 有配对token、倒计时owner、重复/非法UID、空牌组、复制的hook失败；仍无官方平台验收 |
| Beggar / Addict / Mausoleum / Nest / Ghosts / Back to Basics / Library / Joust | 对应事件体和UI专项；`act2_event_ui_hooks.lua`、`library_event_rng.lua` | 既有选项/空组/资格/交易/hook及来源向量证据；Library完整选择池和Joust概率不等于所有42事件独立概率oracle |
| Tome / Altar / Augmenter / Vampires | `cursed_tome_event.lua`、`forgotten_altar_event.lua`、`drug_dealer_event.lua`、`vampires_event.lua` | 实际Nodes路径包含阶段费用、三个Tome结果、选牌顺序、重复/缺内容/晚失败回滚及特殊遗物；补以`act2_event_relic_acquisition.lua`的真实获得/失去及后续战斗效果 |
| Designer / Skull / N'loth / Face Trader | `m3_relic_choice_events.lua`、`face_nloth_skull_events.lua` | 主体fixture是直接 `module.choose + Run.transaction`，不是所有分支都经Nodes dispatcher；N'loth130遗物使用受控已有库存，证明牺牲/清计数，不证明130项自然获取及所有onEquip结果 |
| Masked Bandits / Colosseum | `event_combat_route_{reducers,enemies,colosseum,terminal}.lua`、`event_combat_bridge.lua`、公开完成链 | 战斗准备/第一二轮/奖励/失败事务有专项；不能以受控战斗补给声称自然通关 |

资格并非只测happy case：`unknown_events.lua` 已含Cleric34/35、Dead/Mushrooms6/7、Woman49/50、Designer74/75、Skull12/13、Nloth1/2遗物及幕别、诅咒资格与一次性生命周期。`unknown-events-fixtures.test.mjs` 使用独立冻结向量；公开55路线再证明合法上下文的真实source draw。不需要为了“资格不足”再把这些阈值重新计数。尚不能声称每一种禁用上下文都经原生UI/官方设备实际执行。

## 本轮新增的公开生产边界

`designer-public-option-matrix.test.mjs` / `tests/lua/designer_public_option_matrix.lua` 用真实比赛profile、第二幕地图和实际 `Nodes.enter`。仅控制房间类型/Designer身份和资产，未改事件构造boolean或处理器。seed1真实构造 selected-upgrade / transform，seed2真实构造 random-upgrade / remove；两组覆盖四个服务的行为分支：

- 支付40后选定升级1张或随机升级2张；60后移除1张或按点击顺序变换2张；90后移除再升级剩余1张；Punch失去3生命。
- 每组均公开完成、回地图仍有出口、重复命令拒绝；mandatory picker不可离开，非法/重复UID不能付款第二次或改资源。
- 空组、全瓶装、真正已有定义的不可净化Necronomicurse、39金币不足组均拒绝不可行cleanup/full而保留资源、owner及随机；源Punch仍可执行。
- 已付60后真实onObtain晚异常：公开命令完整回滚，保留先前已提交费用；恢复后相同UID有且仅有一次成功。

不是新事件功能，不修改生产实现。新增测试先正常执行，再对真实生产源码作两次临时变异来验证灵敏度：40费用错为39，以及删除受保护组可行性检查，两者均明确RED；还原逐字源码后GREEN。记录见 `docs/evidence/m3-event-options-20261031/`。初稿曾引用当前data不存在的AscendersBane作为保护牌导致内容错误，已改为当前真实定义Necronomicurse；该夹具错误不记作生产缺陷或RED证据。

本轮标准新测试1/1通过（约2.1秒）；相关 `m3-relic-choice-events`、`act2-choice-events`、`m3-event-completion-routes` 共9/9通过（约10.1秒），未调大30秒预算。没有重复全量测试；最终CI由主控统一执行。

## 逐AC可证范围与尚未证明的具体内容

| AC | 现可支持的离线事实 | 仍须保留未完成的部分 |
| --- | --- | --- |
| 13.1 #4 | 冻结两幕事件全部42身份的公开至少一条链；各事件专项含多项选项/资格/负例；本轮补Designer全服务公开分支 | 没有统一逐选项×所有源结果×全部永久hook的覆盖账本；未知房、营地、宝箱须另域合证；官方原版结果对照不能以源码逆向测试代替 |
| 13.1 #5/#6 | 完整typed来源和经济77专项已存在；事件相关永久交易/掉落有独立专项 | 本次不补全商店每类货架×折扣/删牌组合及全掉落稀有度/领取顺序/共享随机组合；不能因本报告勾整条 |
| 13.1 #7 | 本轮公共Dispatcher拒绝/回滚和既有故障专项有可执行证据 | 同候选严格平台极端价格、重复领取、失败资源不丢失仍缺 |
| 13.1.2 #3 | 24个第一幕比赛身份公开可完成；原目录25保留，Note跨局留卡按批准延期 | 第一幕每个合法选项、全部生成结果与资格资产组合尚无逐AC统一穷尽证明；已有专项不是缺实现结论 |
| 13.1.2 #5 | 配对/转化正式Nodes、原生mock、永久事务有独立专项 | 官方平台验收仍缺；不能用当前新增Lua替代 |
| 13.1.2 #6/#8 | 全身份映射/公开完成、缺映射/准备失败回滚与合法出口已有证据；本轮增加公开Designer负例 | 不是自然概率遇到全部事件，也没有本轮同候选实机seed/eventId/日志截图。用户旧截图缺真实seed，不能推断其具体事件 |
| 61 #2 | 第二幕31条公开完成及大量源锁交易/事件战斗专项；本轮Designer分支补实际Nodes边界 | Skull各奖励结果、Face全部shuffle结果、Nloth130牺牲中大量断言仍是模块事务fixture，不能一概称“全部公开生产路径”；未穷举各交易源×所有取得/失去hook效果；平台仍缺 |
| 61 #1/#4 | 事件部分不能否定既有地图/遭遇/Boss及正常规则离线通关证据 | 本报告不审核三Boss/全路线，也不补同候选平台正常双幕连续通关 |

另外，Designer已付费后外部状态把候选组缩到不足时，生产view明确给出`source_undersized_mandatory_grid`边界；本轮只证明付款前不可行组拒绝，未把这种源缺陷边界伪装成已获批准自由退出/退款。没有足够原版或批准范围证据就不猜改生产行为。

本轮没有发现需要最小生产修复的确定性新缺陷。可合入新增公开路径测试，但不能由此把上述混合平台AC整体勾选完成。
