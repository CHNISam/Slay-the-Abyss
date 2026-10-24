# M3 遗物和药水复核

2026-10-24，基线 `6e8714f`。当前数据为 **13 件遗物、7 件药水定义**，不是早期账本的 7+7。首发战士自然获取池只有六种药水，`poison_potion` 保留效果定义但排除商店/战后奖励。TASK-47 清单负责最终冻结；本表不扩大池。

本轮只读固定社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，PoisonPotion 交叉读取 `purewhitelove/ButterflyGame@fc379c875c11e008e9c10548ac8e394c301c532f`。前者版本字段的既有核查为 2.3.4，但均未经正版 PC 可执行文件认证；日期是查阅日，**没有本轮原作观察、录像或构建 hash**。逐文件 URL 和 Git blob 身份保存在 [来源身份](TASK-14.1-m3-source-identity.json)。未复制、执行镜像程序。

## 逐件效果、时点和入口

源码章节使用来源身份文件中的同名路径。以下均是源码/本地证据，不代表本轮千星实机通过。

| ID | 来源方法及固定预期 | 当前入口和本地证据 | 剩余限制 |
|---|---|---|---|
| burning_blood | BurningBlood.onVictory：存活胜利回 6，最大生命封顶 | 起始持有；Run.finishCombat；inventory_parity / run | 无本轮原作观察 |
| anchor | Anchor.atBattleStart：队尾获得固定 10 格挡 | 普通宝箱/商店；Inventory.opening；opening_relic_order | 未覆盖原作全开战钩子 |
| vajra | Vajra.atBattleStart：队首力量 1 | 普通宝箱/商店；opening_relic_order | 同上 |
| bag_of_preparation | BagOfPreparation.atBattleStart：队尾抽 2 | 普通宝箱/商店；opening_relic_order，首手 7 | 未纳 Innate 等交互 |
| lantern | Lantern.atTurnStart：每战首回合队首能量 1 | 普通宝箱/商店；opening_relic_order，4→3 能量 | 同上 |
| oddly_smooth_stone | OddlySmoothStone.atBattleStart：队首敏捷 1 | 普通宝箱/商店；opening_relic_order | 同上 |
| bronze_scales | BronzeScales.atBattleStart：队首荆棘 3 | 普通宝箱/商店；inventory_parity，0 伤害普通攻击也反刺 | 完整原作伤害队列未认证 |
| membership_card | MembershipCard.MULTIPLIER=0.5；交易计算见 SHOP_PARITY | 商店专属槽；shop / shop_price oracle | 全原版池与随机消费仍缺 |
| courier | Courier.MULTIPLIER=0.8；canSpawn 排除商店；补货见 SHOP_PARITY | 普通宝箱；shop 价格和补货专项 | 商品空桶仍是受限池 |
| smiling_mask | SmilingMask.COST=50；canSpawn 排除商店 | 普通宝箱；shop 删牌交互专项 | 与其他价格修正的顺序见商店账本 |
| black_blood | BlackBlood.canSpawn/onVictory：要求余烬之心，替换后存活胜利回 12 | 17 层 Boss 宝箱；boss_treasure / boss_relic_effects | 首发领完即终局，无自然下一战触发 |
| slavers_collar | SlaversCollar.beforeEnergyPrep/onVictory：精英或 Boss 能量上限 +1，胜利撤回 | 17 层 Boss 宝箱；boss_relic_effects 用夹具核普通/精英/Boss和下一战 | 同上，夹具不当自然可执行证据 |
| sozu | Sozu.onEquip/onUnequip：能量上限 +1；获取拒绝另见 BOSS_TREASURE 方法链 | 17 层 Boss 宝箱；boss_relic_effects，已有瓶可用、新瓶拒绝 | 同上，首发没有领完后的自然获取链 |
| fire_potion | FirePotion.use/getPotency：指定敌人，THORNS 类伤害 20，经过格挡 | 商店/战后；inventory，reward_effects；7盾扣13，不吃攻强/虚弱/易伤、不反刺 | 未纳 Intangible 等敌方最终伤害修正 |
| block_potion | BlockPotion.use/getPotency：固定格挡 12，不吃卡牌敏捷/脆弱 | 商店/战后；inventory / reward_effects，最终格挡封顶999 | 不把固定格挡当成缺陷再改 |
| strength_potion | StrengthPotion.use/getPotency：本战力量 2；StrengthPower constructor/stackPower 封顶 ±999 | 商店/战后；artifact_runtime / reward_effects，封顶仍耗瓶且不耗Artifact | 旧账本“999→1001”已被当前共享actor修复 |
| dexterity_potion | DexterityPotion.use/getPotency：本战敏捷 2；DexterityPower 封顶 ±999 | 商店/战后；同上 | 同上 |
| energy_potion | EnergyPotion.use/getPotency：本回合能量 +2 | 商店/战后；inventory / reward_effects，3→5，次回合重置 | 无本轮原作观察 |
| regen_potion | RegenPotion.use/getPotency：再生5；RegenPower.atEndOfTurn → RegenAction，存活先回再减1 | 商店/战后；inventory_parity / statuses / reward_effects | RegenPower.stackPower 调用 AbstractPower，未发现999封顶；不得套用力量上限 |
| poison_potion | PoisonPotion.use/getPotency：指定敌人施毒6；Artifact拦截仍耗瓶 | 无战士自然获取入口；inventory_parity / artifact_runtime 是明确授予夹具 | 不计首发战士可获得药水；不为凑入口改职业池 |

详细原开战顺序、固定槽、反刺和修正证据分别见 [六件开战](TASK-14.1-opening-relic-order.md)、[固定槽](TASK-14.1-potion-slots.md)、[旧基础量账本](TASK-14.1-inventory-parity.md)。商店三遗物的算法/完整交易来源见 [SHOP_PARITY](../SHOP_PARITY.md)，Boss 三件见 [BOSS_TREASURE](../rules/BOSS_TREASURE.md)，药水掉落概率另见 [POTION_REWARDS](../POTION_REWARDS.md)。本轮没有更改数值或随机池。

## 本轮证实的差异：主动丢弃缺失

[AbstractPotion.canDiscard](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/potions/AbstractPotion.java) 只对 WeMeetAgain 特例拒绝丢弃；它独立于 canUse 的战斗/回合限制。[PotionPopUp.updateInput](https://github.com/aeubanks/sts/blob/319009d5df0a82d9fb0f23cc22322286c6a87ec0/ui/panels/PotionPopUp.java) 的丢弃选项销毁指定槽，无药水 use 或 onUsePotion 调用。WeMeetAgain 不在本项目事件池。

原实现只有消耗和获取，没有主动丢弃命令。满带时虽然能放弃新战利品，却不能丢掉旧瓶腾槽。新增 `Run.discardPotion(run, slot)`：只清空指定槽，保留其他瓶号；不执行效果、不消费能量或随机数。无效、空槽、未知定义拒绝且所有状态保持。命令和已接通的生成控件回调均有本地验证，原生平台仍待测。

`tests/lua/potion_discard.lua` 四组先在原代码全部证红（缺少 discardPotion），新增最小命令后四绿：中槽/重复丢弃/最左空槽补货；地图/节点/奖励和战斗敌方阶段不误用瓶；非法输入原子性；满带奖励先丢中瓶再领取到原中槽一次。奖励边界使用完成战斗夹具，未当正常通关。

## 自然发瓶与实际效果连接

`tests/lua/potion_reward_effects.lua` 六组使用原始起手牌组和未改 Cultist 数据，实际出牌取胜后，从真实奖励领取六类瓶，跨 map 相位保留，再从真实下一战 usePotion 生效并拒绝重复使用。种子/ID为 2/energy、4/fire、13/block、23/dexterity、28/regen、59/strength；这些固定 ID 是本项目受限池回归，**不是原版随机流一致性证明**。不冒称通过地图正常选路或17层全局通关。

本轮没有重做稳定槽、六遗物开战或已修的力量/敏捷上限。完整原作 actionManager / onUsePotion 时序仍未实现，当前十三遗物没有 onUsePotion 效果，不能把没有组合差异写成完整队列一致。主动丢弃之外未发现需要改值的新差异。

## 丢弃入口与输入隔离

共用顶栏原药水计数位置现在可点开一个三槽丢弃弹层：选择现有瓶，查看名称/效果，再按「确认丢弃」，随后可关闭并领取原战利品或购买商店瓶。保留战斗药水槽的原短按用药。空槽/未选不可确认；槽位不交换，已有瓶和新瓶之间没有自动替换。按钮四态、字体、颜色、间距、槽位和弹层尺寸全部复用 `ui_theme.json` 既有 token。地图/节点标题沿既有顶栏 token 收窄至 380，避免挡住计数入口。没有新增通用背包、移动瓶或新物品系统。

`abyss_potion_discard_ui` 只读道具定义并发送 Run 命令；宿主打开弹层时停用底层地图/节点/战斗控制，关闭恢复。旧确认按 run、phase、battle、turn、背包表身份和弹层 generation 拒绝；选择后换瓶、换局、关闭重开、缩放或进入胜败页均不能复活旧操作。核心丢弃按来源不限制玩家回合；UI只在活动局的 map/node/reward/combat 可打开，终局立即关闭并拒绝旧回调，不把核心辅助命令的 phase 独立误当成终局 UI 可操作。

新增 `game_ui_potion_discard.lua` 首轮六组在没有 UI 接线时全部证红，接线后通过；额外 phase 切换例曾证红并补齐 selection 身份，最终九组全部通过。真实 `discardPotion` 后立刻补同 ID 曾使旧直接用药指针消费新瓶，该例单独证红；丢弃现与 usePotion 一样替换背包表身份后再清槽，保留稳定槽值，修后九绿。旧确认 Down 后同 ID 丢弃补回、已选瓶无重绘同 ID 补回也都原子拒绝。满槽奖励与商店例执行生成控件真实回调，核对原槽、真实扣款及售罄；测试不伪称正常地图选路。

验证：核心丢弃4组、自然奖励效果6组、生成树丢弃UI9组；已有 inventory_parity10 / potion_slots6 / artifact_runtime13 / boss_relic_effects6、药水手势9 / 兼容11 / ownership9、牌库宿主6 / game_ui15 均通过。定向 JS host/layout 13 项通过（其中新布局2项检查四态、安全区和核心顶栏不重叠）。UI生成、JS定向语法、git diff检查通过。另一子代理只读复审并独立重跑UI9+布局2未发现剩余有证据的问题；完整组合 check 由主线程在最终整合源执行。

没有开原神、MCP编译、写入候选、官方导入、实机录屏或UI门禁。本任务四项全量AC继续保持未勾选；本地结果不替代这些必要证据。新弹层的原生层级、字体容量和物理触控仍未知，必须在统一候选独立验收。
