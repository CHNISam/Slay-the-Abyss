# 职业专属药水接线

第一片仅补Focus Potion（`focus_potion`，普通）与Potion of Capacity（`potion_of_capacity`，罕见）。固定社区反编译源为319009d5，输入摘要见 `tests/fixtures/class-potions-source-lock.json`；不是官方源码或正版PC实测证明。

`abyss_class_potions`在Run.new已经脱离调用者的私有目录注册实际实现的定义；Inventory排BOT行动，CardActions委派给该模块。集中药水复用Focus的ApplyPower路径，获得2集中、Bark为4，正增益不消耗Artifact；已有负集中同样按正入量处理，并同步充能球。扩容药水复用球槽API，增加2槽、Bark为4，上限10；槽为空且不生成球；异职业默认无容器时，仅在实际行动执行期初始化0槽后增加。该初始化保留已获得的集中。

没有修改药水JSON、各职业33项母池、稀有度、概率或随机算法。全局目录可识别新增瓶子，正常职业来源仍由既有character规则决定；Darkness仍保留源身份并明确不可领取，未塞占位定义或重抽。共用PotionText提供本场战斗、Bark数值、集中不影响等离子、空槽及10槽上限说明。

专用 `class_potion_focus_capacity.lua`最初真实Run.obtainPotion为unknown_potion证红；接线后覆盖2/4效力、Artifact、负集中、0/8/10槽、异职业、BOT次序、同battle根引用及失败事务保留瓶子/资源/RNG。Bark自然遗物渠道在本片外，夹具显式提供被动定义，不冒充自然获取。

`class_potion_focus_capacity_channels.lua`不改初始牌组、生命或RNG，真实打赢seed10/28的cultist，按冻结独立oracle前缀同稀有度置换核对结果及RNG词/计数，领取、携带并再战使用；真实初始商店购买/满槽失败不重抽；seed9 Entropic实际生成并使用两瓶，33项母池和调用者数据保持不变。没有全量Quality、完整自然路线或平台验收结论。
