# 问骨回声：Knowing Skull 机制合同

范围：PC A0、第二幕 once 事件；原创中文表达，无原版叙事/素材复制。固定参考为社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，不是官方 PC 二进制认证。

## 来源与机制

所有链接均固定到上述提交；仅提取机制事实，不执行或纳入第三方源码。

| 文件 | GitHub 返回的 blob SHA | 核对方法 |
| --- | --- | --- |
| [KnowingSkull.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/events/city/KnowingSkull.java) | `1b182b2f7bc5c9839a42f58e19969c045b7fa1ed` | constructor、buttonEffect、obtainReward、setLeave |
| [AbstractDungeon.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/dungeons/AbstractDungeon.java) | `9059f4da5c8002e9645bf38f200e5527d1212ac0` | returnColorlessCard(rarity) |
| [PotionHelper.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/helpers/PotionHelper.java) | `271f568db6a9b78f3d1f0e38416cf44f27c4e8bf` | 无参数 getRandomPotion |
| [AbstractPlayer.java](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/characters/AbstractPlayer.java) | `dc0f077c70ff36bad5d602f2128be1db1a0ee5b7` | obtainPotion(AbstractPotion) |

1. 既有 once 池入口条件保持第二幕且当前 HP>12；未缩小概率池、未增加入口重抽。
2. 初始叙事不扣血。交易页四项初始代价均为6 HP_LOSS。每次索取药水/金币/卡牌先伤害，再仅把该项代价增加1，再发放奖励。离开固定扣6并进入结果页；结果页再离开返回地图。
3. 金币90，走永久 gainGold（含 Ectoplasm）。药水走职业完整均匀池和持续 potionRng；Sozu 仍付生命且涨价，但完全不抽药水、不耗 RNG。
4. 槽满时源 obtainPotion 返回 false，事件忽略此返回：代价、涨价、抽样仍提交，药水丢失；不创造奖励屏、等待队列或免费重试。其他失败包括未知内容不视为槽满，整个当前命令回滚。
5. 无色牌：对当前可变完整35牌池用房间 shuffleRng 的 Java shuffle，取首个 uncommon；不使用稀有度骰子/cardRng、不先过滤20张牌。保留同幕池的实际顺序；跨幕重建；同事件连续请求共用推进后的房间流。
6. 伤害后的奖励不得因HP归零提前取消；先执行永久复活/获得钩子，随后由 Nodes 统一转 defeat。每个命令的生命、复活瓶、代价、RNG、牌池、UID与获得钩子必须一起提交/回滚，先前已成功交易不回滚。

## 实现入口与验收

- `abyss_knowing_skull_event` 为独立核心叶模块；`abyss_act2_events` 分派，`abyss_event_pool.contentId` 映射。通用四按钮和已有过期动作防护复用；UI仅添加原创标题，不改布局。
- `Nodes.chooseEvent` 是唯一公开事务入口；`Run.eventDamage/obtainCard/obtainPotion/gainGold` 保持永久对象和遗物语义。未知内容/损坏 RNG fail closed，不重抽、不吞异常。
- 测试：`node --test tests/knowing-skull-event.test.mjs`，底层 `tests/lua/knowing_skull_event.lua` 经真实 Nodes 和生成控件测试费用、完整槽位、四职业药水池、无色池推进、死亡/复活、晚失败回滚及旧输入。
- 全量CI、官方导入、当前候选ready、手机及真实PC对照是独立验收层；上述源码合同及离线测试不替代它们。

## 本轮离线证据（2026-10-30）

- RED：新增真实 `Nodes.enter` 回归在未实现基线上以 `event_unavailable` 失败。
- GREEN：事件10组通过，包含真实四职业 Run 构建及各自专属药水索引、未裁剪完整事件池的自然抽中/once移除/付费离开；最终事件+药水源码向量+未知事件向量6项 Node 测试通过。
- 相关 Nest 与事件快照组合回归通过；架构检查281模块/1657依赖边、质量4452/4452测量、Luacheck零新增诊断（28项历史警告）及既有4项变异检查通过。
- 未运行完整 `npm test` / `npm run check`；合并切片后应由集成者执行相应门禁。未执行官方导入、实机ready、手机测试或PC动态对照。
