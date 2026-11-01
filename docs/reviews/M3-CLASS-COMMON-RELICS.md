# 三职业普通遗物：离线来源与边界

基线：PR238 `0a773c1c8e736b564514c2c61adeaa6af541f023`。仅补 Snake Skull / DataDisk / Damaru，不把 M3、整局自然构筑或实机验收写为完成。

## 固定依据

固定社区反编译镜像 [aeubanks/sts@319009d5](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，非认证 PC 二进制。15份完整源码的 SHA256 见 `tests/fixtures/class-common-relics-source-lock.json`。

| 身份 | 原方法 | 本地接点 |
|---|---|---|
| Snake Skull（类名 SneckoSkull） | COMMON；自身无 onEquip / 回合钩子。`ApplyPowerAction` 构造时，仅玩家来源、目标不同于来源、Poison 才给 incoming Power.amount 和 stackAmount 各 +1；在 Artifact 之前。 | Actor 统一应用，显式排队的卡牌 / Fumes / Envenom 在真实构造接点保存 0/1，执行不重新读取持有权。新 Power 的 9999 cap 之后加1；已有 Poison 使用独立未封顶 stackAmount。原始状态设置与衰减不加成。 |
| DataDisk | COMMON；`atBattleStart` TOP Focus 1，另一个 TOP 仅视觉；无 onEquip。 | 既有开场 TOP 位置和 Focus.apply。Focus 状态为唯一数值来源，不换球容器、球身份、Dark 储伤或 Plasma 数值。 |
| Damaru | COMMON；`atTurnStart` BOTTOM ApplyPower(player, **null**, MantraPower(1),1)；无 onEquip。 | 既有回合 continuation，在回合 Powers 和普通抽牌前构造；Mantra.prepareGain 只计一次，阈值/移除/Divinity 交既有 Mantra 与 stance owner。 |

`Catalyst.use` 只构造 Double/TriplePoisonAction；后者 update 才构造 ApplyPower。BouncingFlaskAction 也在每个 update 构造该次 ApplyPower。因此这两条即时完整执行路径不在卡牌 use 时提前冻结 Snake；显式 Poison、Crippling Poison、Fumes 与 Envenom 则保存自己的 ApplyPower 构造快照。

四职业正式 Run 已有完整共享状态目录及 stance owner，非观者和默认 Ironclad 的外部 Damaru 获取沿用它们，不新增职业框架。仅这三件在 active combat 的外部 obtain 同步既有战斗持有权；不凭空触发开战效果、不改其他遗物旧快照 ABI。重复 obtain 仍由原拥有检查拒绝；外层事务拒绝时同步也回滚。

## 来源渠道

完整 shared + chosen-class 源目录、顺序、5次初始化 randomLong 和缺件 unavailable guard 均未修改。新增定义只让对应原身份可解析，不缩池、过滤、重抽或重新编号。

`sts1_class_common_relics.py` 复用独立整数与 Java shuffle oracle，固定 seed113 的 common 首项（elite roll1、small chest roll25）和 seed17 的 common 尾项。正式商店、宝箱、精英奖励和公开领取 API 覆盖全部三职业；移除定义的负对照保留同 sourceId、价格、队列与 RNG，并拒绝领取。宝箱使用可到达房间类型夹具，精英使用实际伤害建立终态；不冒充整局自然路线。

## 回归与限制

- 原基线先红：三定义不存在；19个效果/生命周期用例中18红，非持有者控制通过。
- 独立复核再抓到 constructor / execution 边界：实际 Foresight 暂停后获取、构造后移除、Envenom 延迟解析3红；增加构造快照后逐项转绿。
- 新用例保留每份 Lua 默认30秒，不增超时；含回滚、重复领取/获取、十个真实回合、跨职业、保留 owner 与下一场真实战斗重建。
- 定向检查结果、源及最终补丁摘要由交付报告记录。没有完整本地套件、远端 CI、游戏构建/官方导入或本轮实机证据。
- checked-integer 边界沿用现有引擎拒绝，不认证 Java 整数溢出、视觉闪光/音效时序或未实现遗物交互；所有其他缺定义来源继续 unavailable。
