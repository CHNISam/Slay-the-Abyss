# Orichalcum 回合末调用与旧护甲断言

完整目录让普通Run具备跨色能力后会进入实验机制派发；该旧路径未调用已实现的Orichalcum回合末钩子。原common_relic_hooks九例实际前八通过、最后一例失败。新队列回归进一步复现：双派发必须先观察遗物资格，再执行格挡6、Metallicize3、球触发，随后原BOT Juggernaut伤害和Frost2；原六例三过三败，日志`build/orichalcum-prelude-red.log`。

固定源GameActionManager.callEndOfTurnActions先派发遗物、再前置能力与球。Orichalcum是TOP固定6格挡，资格在派发时观察；当前共用prelude把它放在能力/球之前，既有Juggernaut BOT桥接保持原顺序。新增纯资格查询供正常两派发复用；直接旧钩子及原创V4原调用保留。只有此遗物、无球/能力时也进入既有Core快照，没有按角色补规则或新建队列。

原九例全绿1.514秒；新八例全绿1.201秒，涵盖已有格挡不触发、末敌死亡后Frost保留、Dark同步增长、三次实际目标RNG、只有该遗物时的晚失败原对象恢复和一次重试。既有六个球回调例全绿1.186秒。静态105项历史警告、无新增；没有提高预算。

相邻Act2旧断言也已在精确前置基线确认失败：14次普通命中去除Parasite最后一层Plated Armor后，当前正确表示为nil而非0。固定PlatedArmor.wasHPLost排ReducePower，降至零则RemoveSpecificPower并ARMOR_BREAK。仅把旧期待改为移除，保留14击/眩晕/80范围重抽，并加强下一轮不再获得护甲格挡；原34组6.237秒全绿，未改敌人生产规则。

本轮新锁`tests/fixtures/orichalcum-end-source-lock.json`记录原ZIP与相关方法成员摘要，旧47成员锁、既有随机向量、来源池和PC/平台待验状态未改。本片不是完整所有遗物、自然通关或平台验收。
