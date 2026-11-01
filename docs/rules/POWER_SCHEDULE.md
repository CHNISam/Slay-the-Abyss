# Power 获得顺序与回合阶段调度契约

## 范围与固定来源

2026-10-25 的独立 phase4 组件。只新增 `abyss_power_schedule.lua`、`tests/lua/power_schedule.lua` 与本文件；未修改共享 Actor/Combat，也不迁移 `orbPowerOrder`、`cardTriggerPowerOrder`、`postDrawPowerOrder`。组件保存与枚举 Power 成员顺序；各阶段有哪些 hooks、执行哪些业务、即时变化还是排队、死亡停止与事务边界均由宿主负责。

固定社区反编译镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)。从已缓存固定 ZIP 只读复核以下方法与 SHA-256；归档哈希 `3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`。这是声称 V2.3.4 的社区反编译资料，未经官方 JAR 认证，组件测试不是原版客户端或平台实测。没有复制 Java 方法体。

## 源排序、叠层与移除

[AbstractPower.java:57、357–358](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/AbstractPower.java#L357-L358) 的默认 priority 为 5，比较器按 priority 升序。[ApplyPowerAction.java:135–162](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ApplyPowerAction.java#L135-L162) 对已有同 ID 的 Power 调用 stackPower；新 Power 则 append 后 Collections.sort，再调用 onInitialApplication。Java Collections.sort 的稳定排序契约使同 priority 保留加入先后；叠层不替换旧实例，也不重新加入。

[RemoveSpecificPowerAction.java:46–50](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/RemoveSpecificPowerAction.java#L46-L50) 先调用 onRemove，再真正移出 Power 列表。移除后重新获得是新对象、新加入位置。[ReducePowerAction.java:41–47](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/ReducePowerAction.java#L41-L47) 只有减量足以移除时才排一个 RemoveSpecificPowerAction；构造减量或移除动作时不能提前更改获得序。

源 ApplyPowerAction 对 `Night Terror` 有同 ID 不合并的特例；当前 status map 与本组件只支持每 ID 单成员，尚不表示这一多实例特例。

数量和成员资格是两件事。零或负数仍可能是已存在的 Power；组件使用 `rawget(statuses,id) ~= nil` 判断成员，不以数量大于零或 kind=buff 筛选。各 Power 是否在该数量下触发，由对应 hook 的源契约决定。Artifact 等导致应用失败时，不应记录获得；初始应用中若未来实现 onInitialApplication，宿主还需确保它看到已排序的新成员。

## 新回合的构造与执行顺序

[GAM:331–352](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/GameActionManager.java#L331-L352) 依次同步调用 relics、pre-draw cards、cards、powers、orbs。Power 的普通开回合与 post-draw 遍历分别在 [AbstractCreature:518–532](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/core/AbstractCreature.java#L518-L532)，均按 Power 列表顺序；当前阶段的遍历不能按硬编码 Power ID 列表替代。

关键边界是 GAM350 的 `addToBottom(new DrawCardAction(...,true))`：

1. 前述开回合 hooks 同步构造的动作已在队列中，尚未开始执行。
2. [DrawCardAction:27–30](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/actions/common/DrawCardAction.java#L27-L30) 构造函数同步创建 PlayerTurnEffect。
3. [PlayerTurnEffect:43–49](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/vfx/PlayerTurnEffect.java#L43-L49) 同步 energy.recharge，再调用 relics.onEnergyRecharge、powers.onEnergyRecharge。补能即时发生，早于已排队的 pre-draw 动作执行。
4. [EnergizedPower:46–49](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/EnergizedPower.java#L46-L49) 与 EnergizedBluePower 在回调中立即 gainEnergy，随后 BOT 排移除；这一移除位于已有 pre-draw 尾部之后、普通 Draw 之前。其他回调若使用 TOP，仍须尊重其明确插队行为。
5. 完成构造函数返回后，普通 Draw 才真正加入队尾。随后 GAM351–352 同步构造 post-draw relic/power 动作，它们按各自 TOP/BOT 规则排入；不是等普通 Draw 已抽完才首次调用 post-draw hook。
6. 实际执行时，BOT 情况依次为 pre-draw 动作 → recharge 回调尾部 → 普通 Draw → post-draw 尾部。中途抽到 Void 等又排出的动作须按当时队列位置处理，不能把“phase 名称”当作独立清空队列的理由。

[DrawCardNextTurnPower:27、36–39](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/powers/DrawCardNextTurnPower.java#L27-L39) priority=20，post-draw 排抽牌与移除；因此即使先获得它，默认 priority=5 的其他 post-draw Power 也在其之前被调用。组件不硬编码此例，宿主须在该 status definition 上提供 `priority=20`。能量保留遗物、未支持的新 hook、动画与原生输入不在本组件验收范围。

## 数据与 API

每个 actor 独立保存纯数据：

```lua
actor.powerScheduleSerial = 3
actor.powerScheduleOrder = {
    {id='late', priority=20, order=1},
    {id='alpha', priority=5, order=2},
    {id='beta', priority=5, order=3},
}
```

存储表按获得序排列，序号递增；移除不重置 serial。`list` 返回的副本才按 `(priority, order)` 排序，不用 Lua table.sort 的稳定性推断同优先级顺序。priority 来自 actor.statusDefinitions（没有时使用 state.catalog.statuses），缺省为 5；定义必须固定，不能应用后偷偷改 priority。组件对有限支持的源 priority 提供排序，不宣称模拟 Java 极端整数比较器溢出。

- `recordApplied(state, actor, id, before)`：实际成功应用后调用，`before` 必须是应用前的原始 amount 或 nil，不能传 `old or 0`。新成员返回 true，叠层返回 false 并保持原 slot。已有成员缺历史不能伪装为新应用。旧人工夹具中的其他未记录状态可暂时存在；本函数不为它们猜位置，实际 phase 枚举仍要验证所需记录。
- `remove(state, actor, id)`：在真正移除成员时调用，位于 onRemove 之后。可在清空 statuses[id] 前或后调用，只移除获得序记录，不改数量、不执行业务。已记录返回 true；旧夹具未记录的成员返回 false，不合成顺序。新获得必须重新 record。
- `list(actorOrState, filter?)`：可传 actor 或具有 player 的 state。返回 `{id,priority,order,amount}` 副本，amount 是枚举时快照；后续业务如需动态读取，应重新查宿主状态。filter 是 `{id=true,...}` 的集合，用于当前 phase 已支持 hooks，业务过滤由宿主指定。false 项被排除。

完整 `list` 严格检查当前全部成员均有记录、记录没有陈旧成员且 priority 一致。只有完全没有历史的旧人工夹具、成员数至多一时，可以只读 fallback；返回的单项含 `fallback=true`，不写入 actor。

有 filter 时，先过滤再检查相关记录与相关成员。一个相关旧人工成员可单项 fallback，无关手设 Strength/Weak/Artifact 或已删的非 filter 记录不会让该 phase 排序失败；两个相关成员缺记录必须报错，不能按表遍历、字母序或硬编码源 ID 猜序。部分相关成员已记录而另有相关成员缺记录同样拒绝。正常游戏所有真正 Apply/Remove 路径都应接线记录；fallback 只容纳旧人工夹具，不是存档迁移方案。

接口只保证自身拒绝时不替换获得序存储；实际 Actor 应用已可能发生。宿主应把应用、顺序记录、事件与完整出牌/结束回合放在原有事务中，失败时一起回滚对象引用、UID、RNG与获得序。死亡中止、清理动作保留、别的 Power 获得序模块迁移与序列化兼容均需宿主专项验证。

## 验证

私树实际执行 `node_modules/.bin/fengari tests/lua/power_schedule.lua`，输出 `POWER_SCHEDULE_PASS 24`。覆盖稳定 priority（含20）、真实 Actor.applyPower 与叠层、零/负 Strength、buff/debuff、Artifact 拒绝、不共享 actor 顺序、移除重获、快照隔离、过滤前后 fallback、多个缺历史拒绝、陈旧记录、非法记录与序号溢出。测试宿主在共享核心尚未接线时显式调用 recordApplied；已有宿主新成员记录则不重复登记，仍使用真实 Actor 的应用与事件路径。

这是组件及宿主调用契约测试，不冒充 Actor/Combat 已自动接入、真实回合 phase 集成测试、全量检查或完整原版 Power 覆盖。本轮不运行全量。

## 源文件 SHA-256

| 文件 | SHA-256 |
| --- | --- |
| powers/AbstractPower.java | `37a6e97bc1a7a3d0cbfe93fd07e9f809690f7c02f24fd45ec34892466b6e0f9f` |
| actions/common/ApplyPowerAction.java | `f64ce8511f961a1990f1909e2c55654fa6dbf1dc2f4f1f3d3a7156c2ec2a9d47` |
| actions/common/RemoveSpecificPowerAction.java | `c6262b3ce8528f75045f9610026d524a8ae63c526547593e4549f7c5a01a1ad8` |
| actions/common/ReducePowerAction.java | `c38b05e84a781f97d4f87fa8bf374ef145a7c72137e16f8a388f7a612f9425a8` |
| actions/GameActionManager.java | `a47d1ee9c6b2e194b7d3ef311328f2a15e38f5630330689e438e46685b94d6c3` |
| actions/common/DrawCardAction.java | `67d02ba84c1d7e60fbb2a4a83f2b2d3ebbd81a84d29c16ccb98ecc9dd1a17e18` |
| vfx/PlayerTurnEffect.java | `014ddd04c526de9d81b15a4080f80cf0c04e0f3243b60fcb208cdaab9ced4d0d` |
| core/EnergyManager.java | `82c676fdd86d3b409cd7bc38c294e65ee6c2b3a2bea5bce38a8bf98d56dd4383` |
| core/AbstractCreature.java | `3db6e08c6bd033192aa368e29ad53f4614194898ccf0f525480fe20cb8799f2b` |
| powers/EnergizedPower.java | `e827aec6f7a1561fa4c595d289713251f1e0f4e29d798d0b203c2e1b887859d0` |
| powers/EnergizedBluePower.java | `2b9e5cfc9c7e3155d5059f74142b6accf4cdad28904cf21c7a23ecfbe8e181d3` |
| powers/DrawCardNextTurnPower.java | `7f43052db3e11d82b83b24753cac3eedd81a162eedf20465288a16bda2118407` |
