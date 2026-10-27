# 宝箱规则切片

基线 `develop@c91f0d22`；独立实现依据只读 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`。它是社区反编译镜像，未认证正版 PC 二进制；没有搬运 Java 方法体、图片或音频。19 份实读文件摘要见 `tests/fixtures/sts1-treasure-source-lock.json`。

| 原版方法及调用链 | 当前差异与实现 |
|---|---|
| `TreasureRoom.onPlayerEntry → AbstractDungeon.getRandomChest → Small/Medium/LargeChest → AbstractChest.randomizeReward` | 旧 Nodes 从已实现遗物排序后随机挑一件。`abyss_treasure.create` 改为 treasureRng 的箱型掷点（50/33/17）及一次共同奖励掷点；第四幕箱型固定 Medium 仍消费箱型掷点。普通箱进房不消费遗物队列、金币浮点或开箱钩子。 |
| `AbstractChest.open → onChestOpen → gold → addRelicToRewards → addSapphireKey → onChestOpenAfter` | `open` 用 Small 75/25/0、Medium 35/50/15、Large 0/75/25 稀有度，且同一掷点决定 50/35/50 金币资格。若有金币才消费一次 treasureRng 浮点，25/50/75 × binary32 0.9–1.1 后 Java 正数 round；金币独立领取。 |
| `AbstractRoom.addRelicToRewards → AbstractDungeon.returnRandomRelicKey/returnEndRandomRelicKey` | 从同一 Run.relicPool 消费源身份队列，复用已有 canSpawn/降级/Circlet。缺效果定义保留真实 sourceId 与 available=false；不缩池、重抽或冒充取得。 |
| `Matryoshka.onChestOpen`、`CursedKey.onChestOpen`、`NlothsMask.onChestOpenAfter` | 持有顺序执行；套娃先消费 relicRng 的 75% 判断并从共同队列加一件，剩余 2→1→-2；诅咒钥匙从固定 CardLibrary.getCurse 十项顺序消费 cardRng 并返回永久取得请求；面具在全部奖励及蓝钥匙链接后删除第一件遗物及其相邻链接（若有），计数 1→-2。 |
| `BossChest` 构造与 `open` | 构造时从 Boss 队首连续取三件；无宝箱类型/奖励/金币掷点。打开排除套娃且不调用 after 钩子；普通箱规则不进入 Boss 箱。 |
| `RewardItem.claimReward`、`AbstractRoom.removeOneRelicFromRewards` | 奖励项有稳定 slot；`take` 私下移除所领项及链接项。蓝钥匙只放弃基础遗物，额外遗物和金币仍可领取；缺定义遗物不能领取，但其关联蓝钥匙、金币和离开仍有独立入口。 |
| `RewardItem.applyGoldBonus` | 明确排除 TreasureRoom，宝箱金币不应用 Golden Idol 的战后金币加成。 |

正式接线合同：进房调用 `create`，整体提交返回的四个状态 owner，保存 chest/reward；显式“打开宝箱”调用 `open`，先用永久卡牌 API 处理 `curseSourceIds`（包括 Omamori/Darkstone/CeramicFish 钩子），然后在同一 Run 事务提交 chest/reward 与 treasureRng/relicPool/cardRng/relicCounters。任一取得失败不发布任何状态。关闭状态允许直接离开，不得提前触发诅咒。单项领取用 `take` 的新 reward，获得/金币/钥匙操作在同一 Run 事务内；Boss 选一件后过幕，其余过期。该模块不改 Nodes/Run/UI 共享文件，接线由主 session 负责。

验证：`node --test tests/sts1-treasure-runtime.test.mjs` 两项通过，包含 9 组基础 Lua 回归及 23 个种子 × 三种幕环境的 69 次连续普通战后金币→宝箱轨迹，独立 Python RNG/binary32 数值向量和独立 JS/Java 队列预期逐身份、每个 RNG word/counter 比较；包含 int64 边界。覆盖完整 100 掷点箱型/资格/稀有度边界、Boss 三选一源队列、前后钩子顺序、未打开离开、缺定义不重抽、多奖励/蓝钥匙互斥、重复领取和失败不改变 owner。固定 Luacheck 1.2.0 对新模块无诊断；没有跑整套 check 或放宽原门禁。

状态：宝箱独立模块已实现，主 session 正在接正式入口；完整遗物效果/四职业来源队列、商店和战后奖励共同消费需集成层继续核对，不能把模块完成当全池已接。平台没有本轮桌面窗口、官方导入、日志、截图或自然游玩验收；不声明完整游戏体验通过。

## 商店与精英共同队列接线

`abyss_relic_rewards` 补充同一队列的来源适配；`ShopScreen.initRelics` 初始前两槽按 merchantRng 48/34/18 掷稀有度，第三槽固定 Shop，各自取队尾而非再消费一次 merchantRng 随机选定义。`StoreRelic.purchaseRelic` 的 Courier 补货每拒绝 Old Coin/Smiling Mask/MawBank/The Courier 都消费候选并重新掷稀有度；不提前过滤。价格按最终实际返回遗物的层级（含队列耗尽后的 Special Circlet）确定基础价。正常领取/onEquip 应在补货资格核对前执行，外层已有 Run.transaction 保证失败仍整体回滚。

`MonsterRoomElite.dropReward` 在金币之后、药水之前从共同 relicRng 消费 50/33/17 稀有度并取队首；Black Star 再独立掷一次并走 `returnRandomNonCampfireRelic`，排除的 Peace Pipe/Shovel/Girya 真实消费队列，不另消费随机数。普通和 Boss 战不使用该默认精英掉落。新增 `Pool.noncamp` 复用既有队列选择器。

共享三文件接线由主 session 审查；子 session 仅在临时 overlay 应用 patch 并跑 `relic_channel_queues.lua`，六组实际通过：尾部身份/商人掷点、Courier 改层级重试、精英及 Black Star 双掷点、Noncamp 消费、完整来源商店删定义后的身份/价格/状态不漂移、真实 Run.startRoomCombat/finishCombat 产生精英遗物并保持普通战不掉落。最后一组显式终态夹具不称自然战斗取胜；领取 UI 及完整 CI 待主 session 接齐。`abyss_relic_rewards` 和 Pool 新方法固定 Luacheck 无诊断。
