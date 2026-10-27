# Swivel与X费牌付款

组合基线`1f0ba294`把Swivel的FreeAttackPower混入pendingPlay.freeToPlayOnce，导致真实Swivel后3能量的Whirlwind造成3轮伤害却不消耗能量；同时，实例真正的freeToPlayOnce在排队前被清理，单独使用时反而消耗X能量。

固定319009源FreeAttackPower.onUseCard仅消耗能力层数。Whirlwind.use将卡牌自身freeToPlayOnce交给WhirlwindAction，后者仅在该标记为假时消耗当前全部能量。Swivel不让X动作免费。此结论来自项目已审计社区反编译ZIP，未声明正版PC二进制认证。

最小修复仅在清除实例标记前捕获`automatic ~= nil or instance.freeToPlayOnce == true`，供现有X队列付款逻辑使用；Swivel仍通过原非X费用适配和onUse耗层。未改X快照、实际命中次数、来源池或职业规则模块。

新`free_attack_x.lua`使用真实Watcher Swivel和真实Ironclad Whirlwind定义构造受控混色战斗，经实际C.play/queuedCard执行。基础/升级各5场：普通X付款、Swivel仍付款、显式免费保能量并清一次性标记、两种标记共存、自动牌保留真实能量且使用独立energyOnUse=2快照。原头10场中4红，修复后10绿（1.408秒）；原autoplay_class_continuation与autoplay_lifecycle定向继续绿（1.051/1.660秒）。该混色夹具不冒充待接的统一全色获取目录已完成。

没有运行重矩阵或平台验证；未更改集成树、Defect树、Backlog或基线。
