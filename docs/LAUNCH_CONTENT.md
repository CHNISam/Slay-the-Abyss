# 第一幕首发内容清单与验收边界

**2026-10-25 范围更新**：用户已选择补齐首发涉及的完整原版内容池，保持原版概率，详见[SCOPE](SCOPE.md)。下表和当前机器清单仍是已实现的生产基线，30牌/13遗物/6可获药水不再是完整M3目标。完整原池目录、顺序、消费和依赖正在分别核对；本页校验通过不证明完整池已齐备，也不能以受限池重抽或占位验收。

TASK-47，2026-10-25。初始盘点基线 `6e8714f`，本次正式运行时接线基线 `d3369bb`。本清单冻结本轮**既有生产接线范围**，逐项自然获取、执行和实机验收仍未完成，TASK-47 保持 In Progress。已完成的 M2 第一幕通关证据保留；它不能扩张为所有内容逐项通过。

Map v3、17个来源队列绑定、动态编组及 `Nodes.enter → Run.startRoomCombat` 已接入正式源码，见[地图接线](reviews/TASK-12.4-map-production.md)与[遭遇接线](reviews/TASK-12.4-encounter-runtime.md)。此前“地图候选未部署”和“medium_slimes仍是正式池阻塞”的说法是历史状态：`medium_slimes`、`large_acid`、`large_spike`现在仅为显式ID开发/回放入口，不能登记自然路线渠道。**源码接线不是逐项自然获取、平台或实机验收**，清单仍不是内容合规放行表；洗牌、奖励经济等规则差异及逐项证据由原任务继续验收。

机器清单：[launch-content.json](../data/release/launch-content.json)。每项的 `profile` 关联生产入口、现有本地覆盖文件、平台/实机状态和负责验收任务；这是证据账本，不是运行时放行开关。

## 范围和校验

| 类别 | 数量与边界 |
| --- | --- |
| 职业牌 | 30 张，每张基本版和升级版；3 张初始牌、27 张非基础牌 |
| 状态与诅咒 | dazed、slimed、regret；不计入 30 张构筑牌 |
| 敌人 | 19 种普通、3 种精英、1 个 Boss，共 23 个定义 |
| 正式遭遇 | 14 个普通来源、3 个精英来源，加 Guardian，共18个绑定；由来源名驱动动态编组 |
| 旧显式ID盘点 | `legacyData.encounters`保留Data的18条定义；与正式18绑定不是同一组ID，不是额外自然池 |
| 事件 | 7 种；当前生产已是 restricted-seven，含已接入的 Golden Shrine |
| 遗物 | 1 件初始、8 件普通宝箱候选、1 件商店专属、3 件 Boss，共 13 件 |
| 药水 | 岩元素/战士可获得 6 种；另 1 种毒药水只保留数据，不进入此职业奖励或商店 |

检查命令：

```powershell
node scripts/verify-launch-content.mjs
node --test tests/launch-content.test.mjs
```

schema2校验直接读取真实 `Queue.rules`、`Bindings.resolve`，穷举 `Formation.assemble` 的有限Boolean/整数决策路径；只统计最终返回成员，不把被丢弃的预构造敌人当作在场成员。它比较来源名、运行时ID、队列资格、成员范围、合法渠道、每条形成路径及池顺序/重复槽位/抽取数。旧Data的楼层、分支和池继续单独逐字段盘点，不能反向决定正式队列。正式入口还用一个明确的节点预览ID污染夹具证明实际房间服从队列；这不是自然通关证据。

同时核对新模块require关系和实际候选打包器的源码模块发现规则。打包器的生成文件存在性预检使用隔离临时元数据占位，仅读模块名，不执行/部署占位内容，也不生成候选。卡牌支持谓词、事件池、Boss遗物资格和平台/live必须pending的防伪门禁全部保留。它不证明原版概率/AI已完全一致，也不提供编译、导入、实机或素材批准证据。

本轮实际运行：旧清单先因三个精英legacy楼层陈旧而失败；新增正式来源红例后9项中4项失败。迁移后清单CLI与13项定向测试通过；覆盖漏绑定、ID漂移、旧入口误入、把两种大型软泥当独立来源、Thugs/Wildlife成员与渠道遗漏、动态池顺序/数量及模块部署关系。此前4/5项历史结果不能认证schema2。首次扩展负例生成大对象断言差异触发Node内存失败，改用同等严格的布尔深比较后完整13项约4秒通过，没有放宽Lua预算。没有启动游戏、调用MCP或制作新存档。

## 每项的状态如何阅读

下面所有条目均为“生产已接线，现有本地覆盖已登记，逐项平台与自然实机待验”。本地文件被列出不等于本轮已重跑该文件；本轮只执行上述清单校验。每项都继承机器清单同名 profile 中的源码入口、测试引用和当前状态。平台和实机 evidence 数组为空，不能以空记录宣称通过。

表现入口为现有正式 UI 及共享主题，卡面、角色、敌人、事件和商店表现的最终批准资产装配与设备检查仍由 TASK-25、TASK-4 及相关 M4 任务承接；离线素材存在不等于正式接入或视觉验收完成。

## 职业牌

定义入口 `data/cards.json#<ID>`；状态/命令入口 `abyss_run`、`abyss_nodes`、`abyss_combat`，显示入口 `abyss_battle_ui`。TASK-16/16.1/47 与 TASK-12.5 验收。现有本地逐牌基本/升级、节点获取和营地升级覆盖在 `tests/lua/card_pool.lua`；其中商店、营地为隔离节点夹具，不能替代同局自然路径。

| ID | 版本 | 合法获取/升级渠道 | Boss选牌 |
| --- | --- | --- | --- |
| strike | 基本 / 升级 | 初始牌组、营地升级、事件升级 | 不进入 |
| defend | 基本 / 升级 | 初始牌组、营地升级、事件升级 | 不进入 |
| bash | 基本 / 升级 | 初始牌组、营地升级、事件升级 | 不进入 |
| cleave | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| clothesline | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| iron_wave | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| anger | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| body_slam | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| flex | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| twin_strike | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| pommel_strike | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| shrug_it_off | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| thunderclap | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| uppercut | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| inflame | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| battle_trance | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| bloodletting | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| barricade | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 可进入稀有池 |
| carnage | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| disarm | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| dropkick | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| entrench | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| ghostly_armor | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| hemokinesis | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| rampage | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| seeing_red | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| shockwave | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 不进入 |
| offering | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 可进入稀有池 |
| impervious | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 可进入稀有池 |
| bludgeon | 基本 / 升级 | 战后选牌、商店职业牌、营地升级、事件升级 | 可进入稀有池 |

### 附带状态与诅咒

| ID | 入口 | 边界 |
| --- | --- | --- |
| dazed | enemy:sentry:intent | 战斗生成状态；不能打出 |
| slimed | enemy:acid_slime_m:intent、enemy:acid_slime_l:intent、enemy:spike_slime_m:intent、enemy:spike_slime_l:intent | 战斗生成，可支付费用消耗；不是可购职业牌 |
| regret | event:golden_shrine:desecrate | 永久诅咒；回合末执行，不作为可打出职业牌 |

## 敌人与遭遇

23种敌人定义来自 `data/enemies.json`。正式路径为 `abyss_map` → `abyss_nodes.enter` → `abyss_run.startRoomCombat` → 来源队列/绑定 → `abyss_combat`/动态形成器；`Run.startCombat(id)`保留为legacy开发入口。意图分派在 `abyss_enemy_ai` 和各专用AI模块。TASK-15/47、TASK-12.5验普通/精英；Boss另由TASK-17.2/17.3负责。现有构造、形成器和126个来源解释向量是本地覆盖，不能外推逐项自然实机通过。

| 敌人 ID | 类别 | 所在遭遇 |
| --- | --- | --- |
| cultist | 普通 | cultist_solo、exordium_thugs |
| jaw_worm | 普通 | jaw_solo、wildlife |
| red_louse | 普通 | louse_pair、louse_trio、exordium_thugs、wildlife |
| green_louse | 普通 | louse_pair、louse_trio、exordium_thugs、wildlife |
| acid_slime_s | 普通 | small_slimes、lots_of_slimes |
| acid_slime_m | 普通 | small_slimes、exordium_thugs、wildlife |
| acid_slime_l | 普通 | large_slime |
| spike_slime_s | 普通 | small_slimes、lots_of_slimes |
| spike_slime_m | 普通 | small_slimes、exordium_thugs、wildlife |
| spike_slime_l | 普通 | large_slime |
| looter | 普通 | looter_solo、exordium_thugs |
| blue_slaver | 普通 | blue_slaver_solo、exordium_thugs |
| red_slaver | 普通 | red_slaver_solo、exordium_thugs |
| fungi_beast | 普通 | fungi_pair、wildlife |
| mad_gremlin | 普通 | gremlin_gang |
| sneaky_gremlin | 普通 | gremlin_gang |
| fat_gremlin | 普通 | gremlin_gang |
| wizard_gremlin | 普通 | gremlin_gang |
| shield_gremlin | 普通 | gremlin_gang |
| gremlin_nob | 精英 | elite_nob |
| lagavulin | 精英 | elite_lagavulin |
| sentry | 精英 | elite_sentries |
| guardian | Boss | boss_guardian |

| 正式来源 → 运行时ID | 敌人组成 | 队列资格 | 渠道 |
| --- | --- | --- | --- |
| Cultist → cultist_solo | cultist | weak | 地图普通战斗、问号战斗 |
| Jaw Worm → jaw_solo | jaw_worm | weak | 地图普通战斗、问号战斗 |
| 2 Louse → louse_pair | 两个槽各自Boolean选择红/绿 | weak | 地图普通战斗、问号战斗 |
| Small Slimes → small_slimes | false：acid_s、spike_m；true：spike_s、acid_m | weak | 地图普通战斗、问号战斗 |
| Blue Slaver → blue_slaver_solo | blue_slaver | strong | 地图普通战斗、问号战斗 |
| Gremlin Gang → gremlin_gang | mad×2、sneaky×2、fat×2、shield×1、wizard×1有序池，不放回抽四次 | strong | 地图普通战斗、问号战斗 |
| Looter → looter_solo | looter | strong | 地图普通战斗、问号战斗 |
| Large Slime → large_slime | 一个Boolean选择acid_l或spike_l | strong | 地图普通战斗、问号战斗 |
| Lots of Slimes → lots_of_slimes | spike_s×3、acid_s×2有序池，不放回抽五次 | strong | 地图普通战斗、问号战斗 |
| Exordium Thugs → exordium_thugs | 弱敌槽：红/绿虱、spike_m、acid_m；人形槽：cultist、蓝/红奴隶、looter | strong | 地图普通战斗、问号战斗 |
| Exordium Wildlife → wildlife | 强敌槽：fungi_beast/jaw_worm；弱敌槽同Thugs；固定两个在场槽 | strong | 地图普通战斗、问号战斗 |
| Red Slaver → red_slaver_solo | red_slaver | strong | 地图普通战斗、问号战斗 |
| 3 Louse → louse_trio | 三个槽各自Boolean选择红/绿 | strong | 地图普通战斗、问号战斗 |
| 2 Fungi Beasts → fungi_pair | fungi_beast×2 | strong | 地图普通战斗、问号战斗 |
| Gremlin Nob → elite_nob | gremlin_nob | elite | 地图精英 |
| Lagavulin → elite_lagavulin | lagavulin | elite | 地图精英 |
| 3 Sentries → elite_sentries | sentry×3 | elite | 地图精英 |
| The Guardian → boss_guardian | guardian | guardian-unseen | 第16层Boss |

weak/strong按普通遭遇消费次数推进（前三个weak，之后strong），不是旧Data的楼层过滤。Thugs/Wildlife会预先构造候选再选择，候选构造的HP/Bite消耗不等于候选都在场。`legacyData.encounters`完整保留旧18条的楼层、Boolean分支与Gremlin池供开发回放校验；`medium_slimes`、`large_acid`、`large_spike`没有正式地图/问号渠道。正式大型软泥只有一个来源 `Large Slime`，不拆成两份独立抽奖权重。

Boss 固定 `guardian` / `boss_guardian`，第16层战斗、第17层独立宝箱。完整转阶段、反伤、易伤和结算须按 TASK-17.2/17.3 的来源与本轮候选证据核对，不能用一个胜利截图替代。

## 事件

均由问号房间自然解析进入；不是直接指定事件的调试入口。生产 `abyss_event_pool` → `abyss_nodes.eventOptions/chooseEvent` → `abyss_node_ui`。TASK-13.1.2/47 负责逐选项，TASK-12.5 负责严格资格、概率及平台。

| ID（原始ID） | 当前可执行命令 | 条件与边界 |
| --- | --- | --- |
| cleric（The Cleric） | heal、purify、leave | 入池金币≥35；治疗35金、删牌50金；删牌需有可选卡，可以移除末张 |
| purifier（Purifier） | pray、leave | 免费删牌；需有可选卡，可以移除末张 |
| goop（World of Goop） | gather、leave | 拾取受11伤害获75金；离开损失入场固定金币 |
| upgrade_shrine（Upgrade Shrine） | upgrade、leave | 有可升级牌才可选择升级 |
| golden_wing（Golden Wing） | sacrifice、purge、take_gold、leave | 献祭7血后移除；取金需单个基础伤害效果≥10；purge为献祭后阶段 |
| shining_light（Shining Light） | accept、leave | 有可升级牌才可接受；扣血、随机升级最多2张 |
| golden_shrine（Golden Shrine） | pray、desecrate、leave | 祈祷100金；亵渎275金并获regret；离开 |

原六事件文档是历史切片；本清单反映已合入的第七事件，不将配对/转化候选顺带纳入。受限池不是完整原版事件分布；耗尽/资格不足和严格概率差异仍由 TASK-13.1.2/12.5 承接，不通过重抽隐藏。末张移除及空牌组开战已补本地回归，见[专项证据](reviews/TASK-13.1.2-empty-permanent-deck.md)；空选牌组的表现降级和平台验收仍明确保留。

## 遗物

定义 `data/relics.json`；获取 `abyss_nodes`/`abyss_shop`，效果 `abyss_inventory`/`abyss_run`/`abyss_shop`。TASK-14.1/13.1/47 与 TASK-12.5 负责。商店交易效果与受限货架规则继续以 `docs/SHOP_PARITY.md` 为准。

| ID | 渠道 | 自然执行边界 |
| --- | --- | --- |
| membership_card | 商店遗物 | 逐项自然获取及效果待实机 |
| courier | 宝箱 | 只从宝箱获得，商店不能刷出；效果在后续商店观察 |
| smiling_mask | 宝箱 | 只从宝箱获得，商店不能刷出；效果在后续商店观察 |
| burning_blood | 初始遗物 | 逐项自然获取及效果待实机 |
| anchor | 宝箱、商店遗物 | 逐项自然获取及效果待实机 |
| vajra | 宝箱、商店遗物 | 逐项自然获取及效果待实机 |
| bag_of_preparation | 宝箱、商店遗物 | 逐项自然获取及效果待实机 |
| lantern | 宝箱、商店遗物 | 逐项自然获取及效果待实机 |
| oddly_smooth_stone | 宝箱、商店遗物 | 逐项自然获取及效果待实机 |
| bronze_scales | 宝箱、商店遗物 | 逐项自然获取及效果待实机 |
| black_blood | 第17层Boss宝箱 | 最后一战后领取；本幕无后续战斗可触发，后续战斗效果仅有本地夹具 |
| slavers_collar | 第17层Boss宝箱 | 最后一战后领取；本幕无后续战斗可触发，后续战斗效果仅有本地夹具 |
| sozu | 第17层Boss宝箱 | 最后一战后领取；本幕无后续战斗可触发，后续战斗效果仅有本地夹具 |

黑血还要求持有 burning_blood 才能出现在 Boss 宝箱。三件 Boss 遗物的“正常获得”与“随后战斗触发”必须分开：首发只含第一幕，不为凑 AC 擅自增加第二幕，也不把调试加战斗算正常首发执行。这是 TASK-47 的明确剩余边界。

## 药水

定义 `data/potions.json`；`abyss_potion_rewards`/`abyss_shop` 选择，`abyss_run.usePotion` 与 `abyss_inventory` 执行，`abyss_battle_ui` 发送命令。TASK-14.1/16.1/47 与 TASK-12.5 负责。

| ID | 稀有度 | 合法渠道 |
| --- | --- | --- |
| fire_potion | common | 战后药水、商店药水 |
| block_potion | common | 战后药水、商店药水 |
| strength_potion | common | 战后药水、商店药水 |
| dexterity_potion | common | 战后药水、商店药水 |
| energy_potion | common | 战后药水、商店药水 |
| regen_potion | uncommon | 战后药水、商店药水 |

三槽满时必须明确领取/替换/跳过；Sozu 阻止新药水，已有可用。稀有药水桶当前为空，不能重抽到低稀有度掩盖缺项；当前商店也缺无色牌/部分稀有度等货架内容。这些受限内容与原版规则差异仍按来源账本逐项承接。毒雾药水 `poison_potion` 是 Silent 专属，只保留数据与隔离效果测试，战士战后奖励及商店均明确排除，不属于可获得首发六种。

## 明确排除

- 未实现职业牌：`clash`、`true_grit`、`warcry`、`metallicize`、`whirlwind`、`demon_form`、`reaper`；不能进入奖励、商店和营地升级。75牌参考全集不等于首发牌池。
- `Match and Keep!`（`tools/candidates/match_game.lua`）和 `Transmorgrifier`（`tools/candidates/transform_card.lua`）仅独立候选，无生产事件路由。完整原版事件目录、一次性事件、Tiny Chest/Juzu 等仅测试/审计接口不能冒充可获得内容。
- 其他职业/元素、第二/三幕、额外Boss、合作及成就为 SCOPE 中独立候选，不加入本轮必过内容。
- 离线素材/模型/音频文件未获准且未正式装配者，不登记为玩家已可用。

## 后续证据及变更

1. 以同一候选 SHA/hash，自然奖励、商店、事件、宝箱和初始套装逐项获取与执行，保留种子、路径、卡组、截图和本轮 clientScriptLog；不调试塞牌/遗物/药水替代。
2. 多种合法构筑要记录正常获得的完整路径及可重复游玩种子；目前没有因建表新增这类实玩记录，TASK-47 AC 全部保留未勾选。
3. 原版来源/预期、本地覆盖、平台导入和实机逐项分开验；最终表现与设备由 M4、同一 RC 由 M5 继续验。
4. 新增/删除或改变合法渠道时同时改机器清单、此文和 history，并重新运行清单门禁；支持谓词/定义变化触发报错后须人工审查，不能重新生成清单掩盖变更。
