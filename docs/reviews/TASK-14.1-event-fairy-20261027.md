# 事件致死时触发瓶中精灵

基线21909ca。固定来源仍为aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0镜像；ZIP在根.artifacts/sts1-fixed-source，认证边界延续data/SOURCES.md。源码位置：ScrapOoze.java:56调用player.damage，GremlinWheelGame.java:287–288以HP_LOSS调用player.damage，AbstractPlayer.java:1465起的致死分支检查Fairy，无COMBAT限制；FairyPotion.use按最大生命30%（Bark为60%）的float32结果截断、最低1，销毁原物理槽。MagicFlower.onPlayerHeal仅在战斗房间加成，Bloom阻止自动触发，自动路径不分派onUsePotion。

新增Run.eventDamage：只接受节点相位的明确生命伤害，复用Run.transaction及当前Run的HP、药水槽和遗物。Fairy模块抽出同一份比例/槽位规则，战斗保留原事件与HP钩子；事件调用显式关闭Flower战斗倍率，直接处理当前节点库存。保留的run.combat是历史状态，不参与事件治疗、状态或库存计算。普通生命赋值、最大生命变化和移牌不调用这一入口，已死亡角色与无效伤害拒绝。

接线范围：Scrap Ooze、Wheel及Nodes原damage辅助函数的Goop、Shining Light、Golden Wing。后三项也有明确player.damage来源：GoopPuddle.java:56、ShiningLight.java:65、GoldenWing.java:70。伤害记录、后续随机数、金币/升级/删牌流程保持原时点；复活后事件继续原阶段，无瓶或Bloom阻止时仍走既有defeat结算。

先红后绿：tests/lua/event_fairy.lua在修复前六组均失败，前五组实际0HP而应24HP，最后一组缺eventDamage入口。修复后扩为8组并通过，覆盖真实Run+Map+Nodes的Scrap搜索、Wheel spin→accept、两事件继续离开、Bark/Bloom/Flower/Toy、五槽内第3/5槽依次消费、旧battle隔离、非致死/零伤/无瓶/最低1、其它三条Nodes伤害路线。规则遗物测试对尚无常规获取定义的Bark/Flower/Bloom使用明确持有夹具，不冒称其自然取得。

失败原子性用实际Scrap成功抽遗物路径验证：1HP持Fairy，misc快照{0,99}，强制已存在Anchor队首但删除其内容定义。prepareRelic观察点确认私有候选已复活至24HP、源瓶已消费、misc计数已推进1；最终因relic_content_unavailable拒绝后，整个Run/Map值以及库存、事件、遗物池、misc与deck的live owner全部保留原状。没有以缺内容重抽或跳过遗物来制造成功。

固定Node24.18.0、原单文件预算：event_fairy 8组；既有potion_fairy 6、potion_health 22、scrap_ooze 5、wheel_event 5、node_transactions 11（162拒绝）全部通过。architecture为131模块/650边；固定Luacheck 1.2.0无新增诊断，111条历史诊断不变；git diff --check通过。未改静态baseline，未新增模块或架构例外。

仅离线源码与Lua验证；没有构建新候选、官方导入、实机或桌面输入。Backlog与平台AC由父线程按组合证据处理。
