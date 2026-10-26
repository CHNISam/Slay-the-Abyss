# 职业专属药水接线

第一片仅补Focus Potion（`focus_potion`，普通）与Potion of Capacity（`potion_of_capacity`，罕见）。固定社区反编译源为319009d5，输入摘要见 `tests/fixtures/class-potions-source-lock.json`；不是官方源码或正版PC实测证明。

`abyss_class_potions`在Run.new已经脱离调用者的私有目录注册实际实现的定义；Inventory排BOT行动，CardActions委派给该模块。集中药水复用Focus的ApplyPower路径，获得2集中、Bark为4，正增益不消耗Artifact；已有负集中同样按正入量处理，并同步充能球。扩容药水复用球槽API，增加2槽、Bark为4，上限10；槽为空且不生成球；异职业默认无容器时，仅在实际行动执行期初始化0槽后增加。该初始化保留已获得的集中。

没有修改药水JSON、各职业33项母池、稀有度、概率或随机算法。全局目录可识别新增瓶子，正常职业来源仍由既有character规则决定；Darkness仍保留源身份并明确不可领取，未塞占位定义或重抽。共用PotionText提供本场战斗、Bark数值、集中不影响等离子、空槽及10槽上限说明。

专用 `class_potion_focus_capacity.lua`最初真实Run.obtainPotion为unknown_potion证红；接线后覆盖2/4效力、Artifact、负集中、0/8/10槽、异职业、BOT次序、同battle根引用及失败事务保留瓶子/资源/RNG。Bark自然遗物渠道在本片外，夹具显式提供被动定义，不冒充自然获取。

`class_potion_focus_capacity_channels.lua`不改初始牌组、生命或RNG，真实打赢seed10/28的cultist，按冻结独立oracle前缀同稀有度置换核对结果及RNG词/计数，领取、携带并再战使用；真实初始商店购买/满槽失败不重抽；seed9 Entropic实际生成并使用两瓶，33项母池和调用者数据保持不变。没有全量Quality、完整自然路线或平台验收结论。

第二片在实际Watcher私有目录补Bottled Miracle（`bottled_miracle`，普通）与Ambrosia（`ambrosia`，稀有）。默认Native宿主尚无完整Miracle目录与姿态回合生命周期，因此不注册这两瓶；这是依赖可用性边界，不改变任何职业来源资格。完整共享目录与默认宿主由TASK-59另接，不能用手工跨职业注入冒充正常获得。未实现的StancePotion仍在Watcher33项源池中，抽中后明确报告不可获得，不滤池、不重抽。

瓶装奇迹BOT创建2张奇迹，树皮为4张；复用现有MakeTempCardInHand路径，构造/展示分别经过真实Master Reality升级入口，普通奇迹只升为奇迹+一次。生成牌0费、保留、消耗，基础获得1能量、升级获得2；满手溢出进弃牌，实体UID/UUID全新、无deckUid、不写永久牌组。

仙酒源码虽有2点potency，use完全不读取它，树皮不增加次数：只BOT执行一次ChangeStanceAction("Divinity")，入场+3能量、普通攻击×3，下次自己回合开始退出；已在神格时成功耗瓶但不重复入场/获得能量。Combat新增15行resolvePotionActions，拒绝已有actionQueue或pendingPlay，复用既有queuedHandlers与ActionQueue，不伪造出牌上下文。原玩家BOT药水遗物动作（当前Toy Ornithopter）保持在姿态产生的后续能量/格挡/Flurry动作之前；不改手动出牌或回合生命周期。整个桥接仍在Run.usePotion的原私有快照中。

真实Run最初unknown_potion为RED；`class_potion_miracle_ambrosia.lua`覆盖2/4张、MR、溢出、UID、实际奇迹出牌消耗、同battle引用、神格倍伤/重复喝/下回合退出及实际Vigilance、Mental Fortress、Rushdown、Flurry联动。`class_potion_ambrosia_queue.lua`检查真实事件先转姿态、再Toy治疗（仍未加能量）、最后完成时已+3；故障夹具将手牌上限依赖损坏，使Flurry最后移动失败，观察私有快照已完成姿态/治疗/能量后证实整个事务回滚，并直接检查已有队列的重入拒绝。没有把故障夹具当作自然遭遇。

`class_potion_watcher_channels.lua`以不变初始牌组/HP/RNG真实打赢seed10/109初战，核对冻结oracle同稀有度替换的精确RNG词/计数，领取后再战使用；商店seed3/10购买、满槽失败保持价格/随机状态；独立Python固定源oracle给出Entropic seed392的Ambrosia/Forge/BottledMiracle和计数9，生产实际生成并使用两瓶；seed5仍实际报告中间抽中StancePotion不可获得，后续LiquidBronze不重抽。三份专用测试各低于5秒，保留原30秒时限；未做全量检查、完整自然路线或平台验收。
