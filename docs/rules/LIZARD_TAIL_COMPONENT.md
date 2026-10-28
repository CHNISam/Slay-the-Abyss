# 蜥蜴尾巴独立回调组件

固定来源为 `sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。九份精确成员/hash/关键行与原归档身份见 `tests/fixtures/lizard-tail-source.json`。本片没有Data定义、获取渠道、共用致命伤、Run/事件/跨战、HUD或平台接线，不能单独称为完整遗物实现。

`abyss_lizard_tail` 零模块依赖，只有以下API：

| API | 约定 |
| --- | --- |
| has(owner) | 只读识别 `lizard_tail` 或 source `Lizard Tail`；无持有返回false。 |
| onObtain(owner) | 调用者已合法加入遗物且确保是新的获得，再初始化counter=-1。移除后重新合法获得可重置；不是每次开战的入口。 |
| bind(owner) | 无持有返回false；仅counter缺失时首次设-1，保留现有-1/-2；非普通table或其它值直接报错，不悄悄重新武装。 |
| state(owner) | 无持有返回nil；持有且counter合法时返回available、spent或blocked_by_mark，不创建或改写counter。已用-2优先显示spent。 |
| tryRevive(owner,actor,healFn) | 仅持有、HP<=0、counter=-1且无Mark时触发。无触发返回false；正常调用返回true,base amount。 |

Mark识别内部与source两种ID，阻断时不调用heal、不消费Tail或瓶。父coordinator必须先处理Mark/Fairy，Fairy触发即返回，不能先调用此组件或等Fairy后净HP为0再消费Tail。本片不检查药水，不包含普通hpChanged触发。

源AbstractPlayer.damage:1477在调用Tail之前明确把HP归零，本组件同样将负HP先归零。基数来自LizardTail.onTrigger:35–39：`max(1, maxHp整数除2)`，不是float32乘50%；2147483647→1073741823，81→40，1→1。随后调用一次healFn(base)。普通治疗、MagicFlower等遗物/Power钩子与封顶全由该callback负责；组件不复制这些规则，也不消耗RNG。

源heal为void。callback正常返回（包括nil或false）即表示治疗策略执行完毕，随后counter置-2；需拒绝必须抛异常。抛出时组件尚未消费counter，但callback与HP归零可能已经改图，父事务必须恢复整个owner/actor/库存图后重试；组件不建第二套快照或把异常吞掉。

当前调用约束：owned counter必须先经真实onObtain或显式首次bind初始化；缺失counter的state/致命触发均拒绝。只有新的真实onObtain允许重置已用值；普通bind、state、重复致命不重置。counter放在owner.relicCounters.lizard_tail，父负责battle/Run双向同步、同局跨幕/地图恢复与实际HUD状态，避免每场重新onEquip。退出重进磁盘续档不在本片内。

验证使用纯owner和普通heal callback，非真实战斗/自然获取证据：11组覆盖双ID、fresh/reacquire、nil/invalid/spent绑定、只读三态、奇数/最小/整数上限、治疗委托、Mark两ID、spent/living/unowned不触发、原Snapshot下的throws/完整引用恢复与重试、非法actor/callback先拒绝。初次require缺模块真实RED96ms，最小实现后11组GREEN230ms；最终含非法counter容器和独立源锁的Node2/2 GREEN304ms（Lua11组226ms），原单文件30秒不变。固定Luacheck1.2.0二进制SHA-256与仓库登记相符，新模块零诊断，Lua5.3解析通过；未运行整体架构门禁，新增模块core分类由父集成负责，未新增豁免。
