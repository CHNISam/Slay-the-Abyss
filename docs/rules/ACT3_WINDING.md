# Winding Halls 本地切片

按 PC A0 固定源接 Winding Halls；没有批准译名，因此保留本地源名。此切片是实际公开 Nodes 事务与原生 UI 组件，不代表整幕齐备、完整自然通关、当前 SHA Quality 或平台验收。

## 来源与事务

[独立源锁](../../tests/fixtures/act3-winding-source.json)记录本地审计 ZIP `319009d5df0a82d9fb0f23cc22322286c6a87ec0` 的20个实际成员 SHA256，没有改旧锁或复制素材，也没有运行原作PC二进制。来源包括 WindingHalls、DamageInfo、AbstractPlayer/Creature/Dungeon、ShowCardAndObtainEffect、Soul/SoulGroup、两张牌及相关遗物/药水。

INTRO只有继续，随后三项固定为 Madness、Writhe、减最大生命；存在选择时没有免费离开。三项均留下 RESULT，下一次离开才回地图。参数在构造时按输入先转 f32、乘 f32比例、Java正数round缓存：最大生命×.125普通伤害、×.25治疗、×.05减上限。独立 Python/JS IEEE32 oracle覆盖0.5边界、.05精度、最大生命先转float及合法整数边界；不以直接double比例近似。

Madness分支先 `DamageInfo(null, amount)` 默认NORMAL对应的 `Run.eventNormalDamage`，再逐份复用 `Run.obtainCard`。房间转换已清Powers和block，不读历史combat。null owner本来不调用Torii.onAttacked，测试使用max32/伤害4的阈值内反例，不能误减为1。Outside Fairy使用原 `Run.eventDamage` 已有入口，不复制拦截或治疗逻辑。

伤害致死后源仍创建两个ShowCardAndObtainEffect。AbstractDungeon在DEATH screen更新后仍更新effectList，ShowCard.update→SoulGroup.obtain→Soul.obtain没有死亡过滤，因此两个永久Madness仍获得。实现只有所有获得成功后才由Nodes正式complete/defeat；未提前提交败北。未被Fairy救也有两个新唯一永久UID，原卡/瓶装字段不改。

Writhe分支先复用 `Run.heal`，再复用 `Run.obtainCard`，Bloom禁疗、事件外Flower、Omamori阻止、CeramicFish获得金币沿既有边界。Omamori被消耗时不分配UID；其阻止与治疗也可整体回滚。减上限分支对应 `AbstractCreature.decreaseMaxHealth`：先将新上限最低限制1，再夹当前生命，完全不治疗或触发Fairy。Moai是直接改上限/先夹HP/最低1后治疗，两者不能共用近似事务。

公开命令回归验证两新UID、原牌字段、RNG及Map保持，缺牌定义在伤害/治疗后完整失败，真实第二UID溢出、第二次实际获得后return/throw、Omamori阻止后晚失败都回滚生命/金币/牌/计数/UID/败北状态。旧原生回调和复用触点拒绝，新点击可以继续；致死后没有可重复领取按钮。

## 尚未接齐的依赖

不在事件中伪造共享遗物hook。持有canonical `tungsten_rod`或`lizard_tail`时 NORMAL伤害命令明确拒绝；Madness选择遇`toxic_egg`、Writhe选择遇`darkstone_periapt`也明确拒绝，保持资源不变，其他已可执行选择仍开放。实际伤害、致死复活、技能获得升级、诅咒获得加最大生命的共享实现及正常获取，归TASK-14.1后续切片；不把owner夹具计为自然获得。Molten/Frozen Egg对Skill/Curse不触发，不能错误套用它们的升级规则。Omamori与CeramicFish使用已存在的真实API取得并检验。

Source pool的七普通事件、神龛及once历史不删不重抽。seed11的边界未知房间未设置eventId，由真实完整来源池抽中Winding Halls，只删除该普通项；event/selection/misc完整字状态与独立整数解释器一致，body本身不消费规则RNG。此夹具只证明自然来源选择组件，未走完整地图路线。默认Act1库存仍记explicit-only，当前正式入口不改。

## 验收证据

初始RED为公开Nodes.enter的event_unavailable，1.057秒。最终六份专用Lua均默认30秒内通过：入口0.765秒、分支2.249秒、回滚3.064秒、舍入1.453秒、自然池0.760秒、原生UI1.479秒。源锁/库存JS19项全绿。受影响Falling3.311秒、Moai4.870秒、旧Fairy8例4.334秒通过。[机器记录](../evidence/m3-act3-winding-20261027.json)保存输出与依赖。

架构151模块/853边通过。Luacheck整体未绿：仍有本树基线已有且本片未改的abyss_effects.lua:197/199两条W542，分别是groupStart已消费第二member和victory选择性取消动作的空skip分支；交父线程在组合中治理，没有加入豁免。新增模块无告警，14条历史NodeUI警告仅一对一位移；受管UI复杂度报告errors为0，原Battle render≤10/受管函数≤15门禁不放宽。不宣称完整static/check通过。

```powershell
$node = 'F:/New folder/build/tools/node-v24.18.0-win-x64/node.exe'
& $node scripts/test-lua.mjs tests/lua/act3_winding_event.lua
& $node scripts/test-lua.mjs tests/lua/act3_winding_outcomes.lua
& $node scripts/test-lua.mjs tests/lua/act3_winding_rollback.lua
& $node scripts/test-lua.mjs tests/lua/act3_winding_rounding.lua
& $node scripts/test-lua.mjs tests/lua/act3_winding_natural.lua
& $node scripts/test-lua.mjs tests/lua/act3_winding_ui.lua
& $node --test tests/act3-winding-source.test.mjs tests/launch-content.test.mjs
& $node scripts/check-architecture.mjs
& $node scripts/check-lua-static.mjs
```

没有全check、平台、前台、键鼠或新候选操作；TASK62和整体M3仍按全部未完成关口验收。

## 合法 Fruit Juice 变化纠正

此前将合法最大生命变化当成陈旧命令会错误锁住三选，现保留构造时缓存的伤害/治疗/损失，作用到当前 owner；选项 before→after 也读当前最大生命。非法生命输入及原生旧回调/触点保护保持。真实用瓶、三成本及新旧触点回归见 [纠正证据](../reviews/M3-EVENT-FRUIT-CACHED-COST-20261027.md)。
