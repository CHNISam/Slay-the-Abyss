# 第一幕首发内容清单与验收边界

TASK-47。2026-10-25正式范围改为完整75张，当前分支是尚未完整验收的75卡候选。四层证据见[验收矩阵](reviews/TASK-16-warrior75-matrix.md)。历史生产代码基线 `6e8714f`。本清单冻结本轮**既有生产接线范围**，逐项自然获取、执行和实机验收仍未完成，TASK-47 保持 In Progress。已完成的 M2 第一幕通关证据保留；它不能扩张为所有内容逐项通过。

本次整合已承接 `ee9c40d` 的窃金客完整闭环（AI入口 `abyss_looter_ai`）及 `b757705` 的 PR174 动态小软泥组合；清单同时核对两个Boolean分支和两种中型敌人的新增获取渠道。**这是一份首发清单基线，尚不是内容合规放行表**：`medium_slimes`组合仍缺原版依据，见[遭遇审计](reviews/TASK-15-encounter-composition-audit-20261024.md)。`gremlin_gang`原固定五人组已由[TASK-15.18](reviews/TASK-15.18-gremlin-gang.md)修正为八槽有序池不放回抽四次；这是局部生产代码与本地证据更新，不是逐项自然获取、平台或实机验收。完整地图候选12/12也还未接生产。这些已接入但未修正的项目继续阻止 M3 Done，不能因为清单校验通过就放行。

机器清单：[launch-content.json](../data/release/launch-content.json)。每项的 `profile` 关联生产入口、现有本地覆盖文件、平台/实机状态和负责验收任务；这是证据账本，不是运行时放行开关。

## 范围和校验

| 类别 | 数量与边界 |
| --- | --- |
| 职业牌 | 75 张，每张基本版和升级版；3 张初始牌、72 张非基础牌，完整必做 |
| 状态与诅咒 | dazed、slimed、regret、wound、burn；不计入75张职业牌 |
| 敌人 | 19 种普通、3 种精英、1 个 Boss，共 23 个定义 |
| 遭遇 | 14 种普通组合、3 种精英、1 种 Boss，共 18 种 |
| 事件 | 7 种；当前生产已是 restricted-seven，含已接入的 Golden Shrine |
| 遗物 | 1 件初始、8 件普通宝箱候选、1 件商店专属、3 件 Boss，共 13 件 |
| 药水 | 岩元素/战士可获得 6 种；另 1 种毒药水只保留数据，不进入此职业奖励或商店 |

检查命令：

```powershell
node scripts/verify-launch-content.mjs
node --test tests/launch-content.test.mjs
```

校验会比对实际 JSON 定义、遭遇成员和楼层、动态池顺序/重复槽位/抽样数量、合法渠道、基本/升级版与实际 Lua 支持谓词、当前事件池和 Boss 遗物资格；遗漏、新增支持内容或候选误入会报错。它不证明原版概率/AI已完全一致，也不提供编译、导入、实机或素材批准证据。

本轮实际运行：清单 CLI 通过；Node 清单初版4项、承接动态小软泥后的5项均通过。动态分支遗漏和渠道遗漏有真实失败回归；与小软泥数据专项合跑12项通过、0失败、0跳过。首次沙箱执行因 Node 子进程 spawn EPERM 未运行，按正常审批重跑后通过。没有启动游戏、调用 MCP 或制作新存档。

## 每项的状态如何阅读

下面所有条目均为“生产已接线，现有本地覆盖已登记，逐项平台与自然实机待验”。本地文件被列出不等于本轮已重跑该文件；本轮只执行上述清单校验。每项都继承机器清单同名 profile 中的源码入口、测试引用和当前状态。平台和实机 evidence 数组为空，不能以空记录宣称通过。

表现入口为现有正式 UI 及共享主题，卡面、角色、敌人、事件和商店表现的最终批准资产装配与设备检查仍由 TASK-25、TASK-4 及相关 M4 任务承接；离线素材存在不等于正式接入或视觉验收完成。

## 职业牌

完整75张基本/升级均已接入候选共享效果系统，基础执行和公共获取/营地事务已测；完整集成、原版随机流全链、平台与自然实玩仍须逐项验收。不得将此登记当作通过。

| 原版名称 / ID | 稀有度 | 获取与升级 |
|---|---|---|
| Strike / `strike` | basic | 初始牌组；营地/事件升级 |
| Defend / `defend` | basic | 初始牌组；营地/事件升级 |
| Bash / `bash` | basic | 初始牌组；营地/事件升级 |
| Anger / `anger` | common | 战后奖励、彩色商店；营地/事件升级 |
| Armaments / `armaments` | common | 战后奖励、彩色商店；营地/事件升级 |
| Body Slam / `body_slam` | common | 战后奖励、彩色商店；营地/事件升级 |
| Clash / `clash` | common | 战后奖励、彩色商店；营地/事件升级 |
| Cleave / `cleave` | common | 战后奖励、彩色商店；营地/事件升级 |
| Clothesline / `clothesline` | common | 战后奖励、彩色商店；营地/事件升级 |
| Flex / `flex` | common | 战后奖励、彩色商店；营地/事件升级 |
| Havoc / `havoc` | common | 战后奖励、彩色商店；营地/事件升级 |
| Headbutt / `headbutt` | common | 战后奖励、彩色商店；营地/事件升级 |
| Heavy Blade / `heavy_blade` | common | 战后奖励、彩色商店；营地/事件升级 |
| Iron Wave / `iron_wave` | common | 战后奖励、彩色商店；营地/事件升级 |
| Perfected Strike / `perfected_strike` | common | 战后奖励、彩色商店；营地/事件升级 |
| Pommel Strike / `pommel_strike` | common | 战后奖励、彩色商店；营地/事件升级 |
| Shrug It Off / `shrug_it_off` | common | 战后奖励、彩色商店；营地/事件升级 |
| Sword Boomerang / `sword_boomerang` | common | 战后奖励、彩色商店；营地/事件升级 |
| Thunderclap / `thunderclap` | common | 战后奖励、彩色商店；营地/事件升级 |
| True Grit / `true_grit` | common | 战后奖励、彩色商店；营地/事件升级 |
| Twin Strike / `twin_strike` | common | 战后奖励、彩色商店；营地/事件升级 |
| Warcry / `warcry` | common | 战后奖励、彩色商店；营地/事件升级 |
| Wild Strike / `wild_strike` | common | 战后奖励、彩色商店；营地/事件升级 |
| Battle Trance / `battle_trance` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Blood for Blood / `blood_for_blood` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Bloodletting / `bloodletting` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Burning Pact / `burning_pact` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Carnage / `carnage` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Combust / `combust` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Dark Embrace / `dark_embrace` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Disarm / `disarm` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Dropkick / `dropkick` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Dual Wield / `dual_wield` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Entrench / `entrench` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Evolve / `evolve` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Feel No Pain / `feel_no_pain` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Fire Breathing / `fire_breathing` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Flame Barrier / `flame_barrier` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Ghostly Armor / `ghostly_armor` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Hemokinesis / `hemokinesis` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Infernal Blade / `infernal_blade` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Inflame / `inflame` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Intimidate / `intimidate` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Metallicize / `metallicize` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Power Through / `power_through` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Pummel / `pummel` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Rage / `rage` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Rampage / `rampage` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Reckless Charge / `reckless_charge` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Rupture / `rupture` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Searing Blow / `searing_blow` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Second Wind / `second_wind` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Seeing Red / `seeing_red` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Sentinel / `sentinel` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Sever Soul / `sever_soul` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Shockwave / `shockwave` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Spot Weakness / `spot_weakness` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Uppercut / `uppercut` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Whirlwind / `whirlwind` | uncommon | 战后奖励、彩色商店；营地/事件升级 |
| Barricade / `barricade` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Berserk / `berserk` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Bludgeon / `bludgeon` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Brutality / `brutality` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Corruption / `corruption` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Demon Form / `demon_form` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Double Tap / `double_tap` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Exhume / `exhume` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Feed / `feed` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Fiend Fire / `fiend_fire` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Immolate / `immolate` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Impervious / `impervious` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Juggernaut / `juggernaut` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Limit Break / `limit_break` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Offering / `offering` | rare | 战后奖励、彩色商店；营地/事件升级 |
| Reaper / `reaper` | rare | 战后奖励、彩色商店；营地/事件升级 |

### 附带状态与诅咒

Dazed/Slimed沿用敌人生成；Wound由Wild Strike/Power Through生成；Burn由Immolate生成；Regret沿用事件渠道。状态与诅咒不进职业奖励/商店池，不计入75。

## 敌人与遭遇

定义均来自 `data/enemies.json`。地图选择 `abyss_map` → `abyss_nodes.enter` → `abyss_run.startCombat` → `abyss_combat`；意图分派在 `abyss_enemy_ai` 和各专用 AI 模块。TASK-15/47、TASK-12.5 验普通/精英；Boss 另由 TASK-17.2/17.3。现有 `encounter_coverage.lua` 只证明构造及有限本地行为，不能外推每个自然遭遇和 AI 分支都通过。

| 敌人 ID | 类别 | 所在遭遇 |
| --- | --- | --- |
| cultist | 普通 | cultist_solo |
| jaw_worm | 普通 | jaw_solo、wildlife |
| red_louse | 普通 | louse_pair、louse_trio |
| green_louse | 普通 | louse_pair、louse_trio、wildlife |
| acid_slime_s | 普通 | small_slimes |
| acid_slime_m | 普通 | small_slimes的true分支、medium_slimes |
| acid_slime_l | 普通 | large_acid |
| spike_slime_s | 普通 | small_slimes |
| spike_slime_m | 普通 | small_slimes的false分支、medium_slimes |
| spike_slime_l | 普通 | large_spike |
| looter | 普通 | looter_solo |
| blue_slaver | 普通 | blue_slaver_solo |
| red_slaver | 普通 | red_slaver_solo |
| fungi_beast | 普通 | fungi_pair |
| mad_gremlin | 普通 | gremlin_gang |
| sneaky_gremlin | 普通 | gremlin_gang |
| fat_gremlin | 普通 | gremlin_gang |
| wizard_gremlin | 普通 | gremlin_gang |
| shield_gremlin | 普通 | gremlin_gang |
| gremlin_nob | 精英 | elite_nob |
| lagavulin | 精英 | elite_lagavulin |
| sentry | 精英 | elite_sentries |
| guardian | Boss | boss_guardian |

| 遭遇 ID | 敌人组成 | 合法层数 | 渠道 |
| --- | --- | --- | --- |
| cultist_solo | cultist | 1–14 | 地图普通战斗、问号战斗 |
| jaw_solo | jaw_worm | 1–14 | 地图普通战斗、问号战斗 |
| louse_pair | red_louse、green_louse | 1–14 | 地图普通战斗、问号战斗 |
| small_slimes | false：acid_slime_s→spike_slime_m；true：spike_slime_s→acid_slime_m | 1–14 | 地图普通战斗、问号战斗；misc Boolean一次 |
| louse_trio | red_louse、green_louse、red_louse | 4–14 | 地图普通战斗、问号战斗 |
| medium_slimes | acid_slime_m、spike_slime_m | 4–14 | 地图普通战斗、问号战斗 |
| large_acid | acid_slime_l | 4–14 | 地图普通战斗、问号战斗 |
| large_spike | spike_slime_l | 4–14 | 地图普通战斗、问号战斗 |
| looter_solo | looter | 4–14 | 地图普通战斗、问号战斗 |
| blue_slaver_solo | blue_slaver | 4–14 | 地图普通战斗、问号战斗 |
| red_slaver_solo | red_slaver | 4–14 | 地图普通战斗、问号战斗 |
| fungi_pair | fungi_beast、fungi_beast | 4–14 | 地图普通战斗、问号战斗 |
| gremlin_gang | 有序八槽池：mad×2、sneaky×2、fat×2、shield×1、wizard×1；逐次移除抽中槽位，共四只 | 5–14 | 地图普通战斗、问号战斗；staged misc四次抽样，完整成功后提交 |
| wildlife | jaw_worm、green_louse | 5–14 | 地图普通战斗、问号战斗 |
| elite_nob | gremlin_nob | 6–13 | 地图精英 |
| elite_lagavulin | lagavulin | 6–13 | 地图精英 |
| elite_sentries | sentry、sentry、sentry | 6–13 | 地图精英 |
| boss_guardian | guardian | 16–16 | 第16层Boss |

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

- 75张职业牌不再排除任何一张；最终必须全部验收。其他色/无色牌效仍按各自任务承接，不能用占位效果冒充实现。
- `Match and Keep!`（`tools/candidates/match_game.lua`）和 `Transmorgrifier`（`tools/candidates/transform_card.lua`）仅独立候选，无生产事件路由。完整原版事件目录、一次性事件、Tiny Chest/Juzu 等仅测试/审计接口不能冒充可获得内容。
- 其他职业/元素、第二/三幕、额外Boss、合作及成就为 SCOPE 中独立候选，不加入本轮必过内容。
- 离线素材/模型/音频文件未获准且未正式装配者，不登记为玩家已可用。

## 后续证据及变更

1. 以同一候选 SHA/hash，自然奖励、商店、事件、宝箱和初始套装逐项获取与执行，保留种子、路径、卡组、截图和本轮 clientScriptLog；不调试塞牌/遗物/药水替代。
2. 多种合法构筑要记录正常获得的完整路径及可重复游玩种子；目前没有因建表新增这类实玩记录，TASK-47 AC 全部保留未勾选。
3. 原版来源/预期、本地覆盖、平台导入和实机逐项分开验；最终表现与设备由 M4、同一 RC 由 M5 继续验。
4. 新增/删除或改变合法渠道时同时改机器清单、此文和 history，并重新运行清单门禁；支持谓词/定义变化触发报错后须人工审查，不能重新生成清单掩盖变更。
