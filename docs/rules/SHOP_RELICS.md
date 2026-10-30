# 商店遗物规则接线

固定参照为初代 PC A0 反编译源码 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的对应 relic 类、`UseCardAction`、`ChooseOneColorless`、`CardLibrary.getAnyColorCard` 与 `AbstractDungeon.getRewardCards`。本地实现与实机验收分别记录；本轮不包含官方导入或实机证据。

`abyss_shop_relics` 提供15项原始身份到本地ID映射，不过滤商店队列、不对缺实现结果重抽。

| 遗物 | 本地规则与重要边界 |
| --- | --- |
| Sling | 仅 eliteTrigger 战斗开局获得2力量，不能仅凭敌人tier判断 |
| HandDrill | 攻击破敌人格挡后队尾施加2易伤；人工制品可抵挡 |
| Toolbox | 预抽牌阶段从非治疗无色源池抽出3种不同身份，选1张临时加入手牌；保留原费用，不重复执行Discovery抽样 |
| Chemical X | X效果加2，支付仍按原X；各职业动作实现须分别接线，不能给已经加2的动作再加一次 |
| Orrery | 取得时构建5份独立卡奖，连续消耗同一cardRng与稀有度偏移；每份可选或跳过 |
| DollysMirror | 取得后待选永久牌，调用普通stat-equivalent复制渠道；新UID、不复制瓶装绑定、执行取得回调 |
| OrangePellets | 同一回合攻击/技能/能力各一次，队尾移除减益并重置三类型标记；每回合也重置，保留正力量 |
| PrismaticShard | 永久牌奖励跨所有颜色，完整common76/uncommon160/rare84，包含无色；非Defect且无槽时获得1球槽 |
| ClockworkSouvenir | 开局获得1人工制品 |
| Frozen Eye | 抽牌堆显示真实顺序；只改变展示可见性 |
| TheAbacus | 洗牌时队尾获得固定6格挡，不计敏捷与脆弱 |
| Medical Kit | 状态牌可打出，原不可打出的费用改0，已有正费用保留；打出后消耗 |
| Cauldron | 取得时用连续potionRng生成5瓶药水；逐项领取/放弃，满槽拒绝且保留当前offer |
| Strange Spoon | 仅打出后实际dispose阶段，对将耗尽的非能力牌掷一次cardRandomRng布尔，命中改为弃置；主动消耗和虚无不触发 |
| Brimstone | 每回合开始玩家+2、所有敌人+1力量，敌人的TOP插队顺序倒序执行 |

Prismatic的源实现先shuffle消耗一个randomLong，再在getRandomCard内按source cardID排序后消耗身份整数。实现保留这两个随机消费；重复身份的整个抽样过程继续消费，不从牌池删项。

## 奖励与选牌命令

父Run对下列命令使用原有 `Run.transaction`。模块在函数执行时读取普通Run卡牌/药水取得API，避免另造永久库存通道。

- `Shop.onEquip(run,id)`：自动构建Orrery/Cauldron奖励或Dolly选牌；外部无需传奖励构造callback。
- `Choices.claim(run,token,index,choice)`：卡奖0跳过/1..N选牌，持歌唱碗时可传`'bowl'`放弃该组牌并增加2点生命上限；药水0放弃/1领取。重复、过期、满槽等拒绝，不标已领。
- `Choices.finish(run,token)`：所有5项处理后清理屏幕；仍有未处理项时拒绝。
- `Choices.chooseMirror(run,uid)`：只允许初始候选UID；成功取得复制品后清理待选状态。
- `Shop.beginToolbox(Combat,state)` / `Shop.chooseToolbox(Combat,state,token,index,CardActions)`：由既有战斗动作队列暂停与恢复，使用统一pendingChoice。

UI读取 `run.shopRelicRewards={token,relic,items}` 和 `run.shopRelicChoice={relic,kind='copy',uids}`，必须提供真实处理出口。地图/商店退出应拒绝未完成的待选流程，不得静默清理。

## 本轮离线证据

`tests/shop-relics-missing.test.mjs` 最终3/3通过，约20.2秒。三份Lua切片：`shop_relics_effects.lua` 12组、`shop_relics_acquisition.lua` 8组、`shop_relics_pending_ui.lua` 9组。含5卡领奖、5药水满槽恢复、Dolly升级牌新UID、Prismatic完整320牌及随机流消费、Question Card与Busted Crown组合数量，以及真实Run取得的开局战斗效果。Orrery歌唱碗逐组+2、禁止重复、全血和绽放印记、无获牌回调、旧token拒绝另有实际命令回归。

橙色药丸同时清除独立`player.noDraw`表示的禁止抽牌；保留既有Power顺序与Schedule移除入口。真实战斗专注→攻击→能力的三类型路径后可再抽牌；队列先移除再抽牌、迟到重复处理和死亡拥有者均有断言。

遗物选择模态复用批准的eventView三行选项和底部上一页/下一页，不新增布局或素材。GameUI在待选期间优先显示node界面，处理后回到原phase；原phase和nodeFlow不被UI改写。专项真实控件树mock覆盖map/reward/victory优先级、分页和卡牌永久说明、瓶子不可逃离、Orrery五卡和Cauldron满槽恢复，以及重render、隐藏、换run、busy和迟到Down/Up手势拒绝。它们是离线行为证据，不代表平台字体显示或实体触摸验收。

这些证据不替代最终组合源码的完整门禁、UI接线审查、官方导入或实机验收。
