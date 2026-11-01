# 映光石龛：永久牌拓印

TASK-13.1.2 的 Duplicator 玩法切片；不修改原两幕事件目录、顺序、条件、抽取或随机流。公开标题与说明为本项目独立文字。

## 规则来源与边界

规则参考固定到社区反编译镜像 [aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0](https://github.com/aeubanks/sts/tree/319009d5df0a82d9fb0f23cc22322286c6a87ec0)，不是官方开放源码或商业授权证明；下列 Lua 为独立实现，未复制 Java 实现或原事件文案。

| 参考路径 | Git blob | 核对的行为 |
| --- | --- | --- |
| `events/shrines/Duplicator.java` | `966bf6acb9641e617d25b8d4343868c9ba6e1db0` | 复制/忽略；从完整永久牌组选择一张；stat-equivalent copy 后清除三类瓶装标记；获得后离开 |
| `cards/AbstractCard.java` | `bc88307d010bdd37cf55a4b60b79209fa78b0aa6` | `makeStatEquivalentCopy` 保留升级与永久属性；不把原牌 UUID 交给新牌 |
| `vfx/cardManip/ShowCardAndObtainEffect.java` | `1905199265294006a78eaeeb56e4ec75048236ff` | 御守在获得前阻止诅咒；获得回调早于主牌组插入 |
| `cards/red/SearingBlow.java` | `e5ae6bf747375d9e251901421ad1fba6ac3e0721` | 构造型 makeCopy 与属性等价复制不同，不得丢失已有特殊升级基线 |
| `screens/select/GridCardSelectScreen.java` | `3221a5d9f31b2c98b06848be5d261b5030841752` | 源调用是不允许取消的单牌选择，不能新增选择后的取消奖励 |

`Run.prepareCardCopy(run, permanentUid)` 只接受唯一的存活永久 UID，产生与原牌分离的获得提案；`Run.obtainCardCopy` 用真实 Run 事务准备并提交该提案。现有普通 `prepareCard` / `obtainCard` 不继承此复制状态。

模型中的 `upgraded`、`upgrades`、`searingBlowCopyUpgrades`、`misc`、`costOverride` 保留；全新永久 UID 在提交时分配。瓶装绑定、战斗临时所有权与选择器状态不复制。御守、陶瓷鱼、黑石护符、熔火蛋继续走共同获得管线，不在事件内另算一遍。复制属性必须在 `onObtainCard` 之前就位；晚期拒绝回滚整个房间命令。

**防御性空输入处理，不冒充原作规则：** 空牌组时禁止进入不可能完成的强制选择器，Copy 返回 `no_copyable_card` 且状态/牌组/RNG 不变；原先的介绍页 Leave 仍可用。不新增奖励、自动跳过、候选重抽或事件资格过滤。

## 接线合同

- `prepare(run,event)` → `intro`。
- `options(run,event)` 提供 `copy` / `leave`、选择态 `select`、结果态 `leave`。
- `cards(run)` 返回完整永久牌组的深复制；瓶装牌、诅咒均可选，不能套用移除牌的筛选。
- `choose(run,flow,choice,uid)` 在外层 Nodes 房间事务内执行。`intro → choose_card → result → complete`，或介绍页放弃后 `result → complete`。选择态只允许 `select`，没有取消。
- 选择器必须携带永久 UID 和现有事件身份/快照所有权；旧 UI 请求不得在另一个房间里生效。Nodes/UI 的共同接线与架构注册由集成执行者统一修改。

## 证据分层

`tests/lua/duplicator_event.lua` 是真实 Run 事务的受控房间测试，不是自然路径通关；`tests/lua/permanent_card_copy.lua` 验证永久复制接口及下一场真实战斗中原牌/新牌的 Ritual Dagger 属性与费用。费用用受控的永久 `costOverride=0` 检查模型边界，不声称已有自然可达的改费事件。Combat 只增加该永久字段的构造传播；原费用公式与没有此字段的牌不变。覆盖新 UID/瓶装清除、完整选择、升级与 Searing Blow 基线、御守/蛋/获得遗物顺序、旧 UID/重复 UID/非法属性、晚期回滚、重放和空输入。

这份规则说明本身不证明公共入口已接线、全套 CI 通过、官方导入成功或 PC/手机实机通过。完成声明须绑定最终整合 SHA 的对应证据。
