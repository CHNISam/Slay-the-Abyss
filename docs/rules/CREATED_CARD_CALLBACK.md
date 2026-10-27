# 生成牌升级入口

`CardActions.created(combat,state,card)`只处理Master Reality存在时非状态／诅咒牌的升级。由源构造／效果站点显式调用，不在`fresh`统一插入，不用于检索。

HandAction构造与ShowHand各调用一次；普通DiscardEffect一次。已升级普通牌不能再升级，可重复升级的Searing Blow按实际调用次数处理。Watcher Final委派共用函数；Silent Shiv生成保留原UID／溢出／满手／Accuracy／事件校验，只迁移旧不支持断言。

`watcher_master_reality_shivs.lua`先红后绿，覆盖基本／已升级Shiv、Accuracy、11张溢出、UID不重用和Infinite Blades起回合。此接口不表示跨职业全部组合或平台已验收。
