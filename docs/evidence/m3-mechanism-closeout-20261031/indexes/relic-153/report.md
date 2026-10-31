# 153遗物逐ID离线证据索引

固定源码 `c3d2654beee31fdd011db0535228e063b657ab8a`，tree `129836d253d4357ee120c43b08ce5fd85afb9a9e`。逐项范围直接取 `data/relics.json` 的153个唯一ID，并与发布清单对应。索引文件是 [matrix.json](matrix.json)。本轮只读，没有运行Lua/完整CI、修改冻结PR或Backlog。

153项均能定位至少一个包含该精确ID/源ID及实际断言的聚焦Lua用例，合计686个共享断言块。**这支持停止把“没有统一旧表”当作153件均无效果证据；不支持153件所有数值/顺序/组合已经通过。** 每条保留fixture、起止行、测试标题、具体assert/eq/equal/same行、Run/Nodes调用、运行入口及实现引用。用例可能使用受控HP/牌组/地图/直接hook；这与自然取得分开。

普通铁甲战士五档源队列的130身份覆盖不是全部153：其余包含初始/特殊/其它职业身份。发布清单各自profile和channels逐项保留，不能把153个定义解释为当前比赛自然可掉落153件。

## AC判断

- AC5：已有大量逐件固定字面效果断言、真实Run取得/战斗、源码锁与独立向量。每ID可按表重用，不需要重复开发。仍未据本索引认证所有对象/持续/数值和触发序列；以下定位到具体薄弱边界。
- AC7：已有重复/回滚/跨战斗/组合专项；matrix的dimensions给出精确断言线索，**不是普适通过列**。例如唯一遗物通常拒绝重复取得，而Circlet允许重复计次；没有通用“每件重复使用”可机械执行。
- AC8/9：三局轨迹只观察8种遗物（含初始燃烧之血）；自然取得不等于逐件效果发生。没有同候选逐件官方平台证据，本轮0项平台认证。
- 本轮未发现可直接认定的新增生产缺实现或已复现缺陷；下面全部是有界测试/来源证明缺口，不能伪写成游戏bug。

## 已复核的具体缺口与应保留现有行为

- **eternal_feather**：uncommon_relics_effects62:9-card camp enter heals3 once; entered phase no second heal; Bloom blocks; direct U hook only. No per-ID public Nodes.enter(camp) effect assertion located; floor(#deck/5) boundary0/4/5/10/large and MagicFlower interaction not individually indexed. This is test-evidence gap, not an implementation defect.
- **letter_opener**：uncommon_relics_effects23:three direct skill callbacks produce fixed5 to both enemies despite Strength100. No per-ID real Run.play third-skill public dispatch located; explicit next-turn reset, dead-enemy/filter and held-order interaction not in this sole focused block. Existing module U.atTurnStart implementation is present.
- **brimstone**：shop_relics_effects68:two direct turnStartActions batches yield playerStrength4/enemy2. No per-ID Run.endTurn multi-turn dispatch assertion located; summoned/multiple/dead enemies and TOP order need independent per-ID evidence if claimed.
- **hand_drill**：shop_relics_effects24:direct onBlockBroken->queued vulnerable2; Artifact consumption and player-not-target negative. No named real attack reducing enemy block to0 then public queue/drain assertion located. Callback isolation is not public dispatch proof.
- **preserved_insect**：common_relic_final25:normal-vs-elite direct battle construction; floor(float32(maxHp*.75)) and maxHP unchanged. Current expected expression shares production float helper; no independent numeric vector/boundary table or real Run elite-entry per-ID assertion located.
- **juzu_bracelet**：common_relic_final88:real Nodes.enter with relic; source randomFloat temporarily forces0; produces event instead of combat. Controlled sampler override does not establish natural encounter probability or stream invariance. Other source unknown-room oracles remain separate evidence.
- **snecko_eye**：boss_relics_missing26:Run.obtainRelic then actual battle;7cards/confusion1 and some costOverride exists. Focused test does not independently assert every randomized cost, exact shared stream/counter, later-turn count or interaction ordering. Existing card RNG/Confusion tests are separate leads, not automatically source-complete Snecko proof.
- **pantograph**：relic_reported_failures37:actual obtain/start normal then controlled floor16 Boss;20->45, Bloom stays20. MagicFlower rounded1.5 multiplier, near-full clamp and repeat re-entry per-ID public assertions not in this sole focused block; generic health tests may cover some dimensions.
- **medical_kit**：shop_relics_effects37:status template cost-2->0/exhaust copy;cost1 retains cost;attack same identity. This isolated transform does not establish whole real status-card play/dispose/exhaust transaction; search other Slime/Dazed/Wound card cases before adding redundant tests.
- **cultist_mask**：special_event_relics:actual obtain/start emits exactly1 cosmetic cue;noStrength;Gremlin weak1 preserved. Cosmetic source effect is intentionally no numerical buff; do not mistake empty effects JSON for missing implementation. Native audio/visual fidelity unverified.
- **circlet**：special_relics:three obtains keep oneinventory identity and counter1->2->3;onEquip no double increment. Repeat acquisition is expected behavior for this special relic, unlike ordinary unique relics. Do not impose universal duplicate-rejection requirement.
- **runic_cube**：boss_relics_missing44:real obtain/start;positive HP loss draws1,fullyblocked draws0,second positive loss draws1. Existing explicit literal test was hidden by searching assert only because it uses local eq() assertion helper. No new missing-test finding.

## 完整153ID清单

表中“主断言”仅选一个聚焦入口方便起步；所有其它断言、独立来源线索、触发/计次/重置/冲突的范围见matrix。`hook`与`Run/Nodes`应读具体调用及本地helper；表内不宣称本轮执行成功。

| # | ID / 原版sourceId | 实现引用文件（非执行证明） | 主断言fixture:行 / 标题 | 断言块数 | 自然观察 |
|---|---|---|---|---:|---|
|1|`bottled_tornado` / Bottled Tornado|abyss_relic_hooks.lua, abyss_relic_loss.lua, abyss_uncommon_relics.lua|tests/lua/addict_event_content.lua:183 Every implemented selectable source relic has same settled ordinary state with onEquip deferred after Shame|5|有库存/初始观察，效果未逐件认证|
|2|`sundial` / Sundial|abyss_uncommon_relics.lua|tests/lua/relic_pool.lua:62 screenless filters consume all forbidden candidates without shifting RNG|6|未观察|
|3|`kunai` / Kunai|abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:16 attack triples give independent Strength Dexterity and fixed block|2|未观察|
|4|`blue_candle` / Blue Candle|abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:49 Blue Candle loses HP and exhausts the exact curse|3|未观察|
|5|`eternal_feather` / Eternal Feather|abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:62 Eternal Feather floors deck groups and Meat has half HP gate|1|有库存/初始观察，效果未逐件认证|
|6|`strike_dummy` / StrikeDummy|abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:68 Strike Dummy Paper Frog Question Card modifiers are ownership gated|2|未观察|
|7|`singing_bowl` / Singing Bowl|abyss_battle_render_hud.lua, abyss_boss_relics.lua, abyss_relic_card_rewards.lua, abyss_relic_choices.lua, abyss_relic_pending.lua|tests/lua/m3_driver_relic_choices.lua:3 top-level fixture (per-ID attribution requires assertion excerpts)|11|未观察|
|8|`matryoshka` / Matryoshka|abyss_treasure.lua, abyss_uncommon_relics.lua|tests/lua/sapphire_current_relics.lua:2 top-level fixture (per-ID attribution requires assertion excerpts)|11|未观察|
|9|`ink_bottle` / InkBottle|abyss_uncommon_relics.lua|tests/lua/darkstone_spawn_gates.lua:30 direct Shop.prepare is readonly and uses current floor48/49 source eligibility|10|未观察|
|10|`ornamental_fan` / Ornamental Fan|abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:16 attack triples give independent Strength Dexterity and fixed block|2|未观察|
|11|`bottled_lightning` / Bottled Lightning|abyss_relic_hooks.lua, abyss_relic_loss.lua, abyss_uncommon_relics.lua|tests/lua/addict_event_content.lua:183 Every implemented selectable source relic has same settled ordinary state with onEquip deferred after Shame|5|未观察|
|12|`gremlin_horn` / Gremlin Horn|abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:39 Gremlin Horn excludes final enemy and escape|2|未观察|
|13|`horn_cleat` / HornCleat|abyss_relic_loss.lua, abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:34 Horn Cleat second turn and Mercury each turn|2|未观察|
|14|`letter_opener` / Letter Opener|abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:23 Letter Opener uses fixed damage to every enemy|1|未观察|
|15|`question_card` / Question Card|abyss_card_pool.lua, abyss_uncommon_relics.lua|tests/lua/library_event_rng.lua:59 full deck ownership and ordinary reward relics do not filter, alter20, cross-color or add upgrade draws|6|未观察|
|16|`bottled_flame` / Bottled Flame|abyss_relic_hooks.lua, abyss_relic_loss.lua, abyss_uncommon_relics.lua|tests/lua/addict_event_content.lua:183 Every implemented selectable source relic has same settled ordinary state with onEquip deferred after Shame|8|未观察|
|17|`shuriken` / Shuriken|abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:16 attack triples give independent Strength Dexterity and fixed block|2|未观察|
|18|`meat_on_the_bone` / Meat on the Bone|abyss_uncommon_relics.lua|tests/lua/relic_reported_failures.lua:47 Magic Flower modifies Meat and Burning Blood once while victory room is still combat|3|未观察|
|19|`mummified_hand` / Mummified Hand|abyss_uncommon_relics.lua|tests/lua/support/card_random_chain.lua:2 top-level fixture (per-ID attribution requires assertion excerpts)|3|未观察|
|20|`mercury_hourglass` / Mercury Hourglass|abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:34 Horn Cleat second turn and Mercury each turn|5|未观察|
|21|`self_forming_clay` / Self Forming Clay|abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:45 Clay queues next turn block for each actual HP loss|4|未观察|
|22|`paper_frog` / Paper Frog|abyss_uncommon_relics.lua|tests/lua/uncommon_relics_effects.lua:68 Strike Dummy Paper Frog Question Card modifiers are ownership gated|3|有库存/初始观察，效果未逐件认证|
|23|`ginger` / Ginger|abyss_rare_relics.lua|tests/lua/rare_relics_run.lua:26 Ginger and Turnip block debuffs before Artifact|3|未观察|
|24|`bird_faced_urn` / Bird Faced Urn|abyss_rare_relics.lua|tests/lua/act2_event_ui_hooks.lua:40 both simple event source relic misses refuse without queue truncation/reroll, gold/protection/RNG/UID mutation|5|未观察|
|25|`unceasing_top` / Unceasing Top|abyss_card_actions.lua, abyss_combat.lua, abyss_rare_relics.lua|tests/lua/relic_reported_failures.lua:59 Unceasing Top draws after the real last-card action queue drains|4|未观察|
|26|`torii` / Torii|abyss_rare_relics.lua|tests/lua/act3_winding_outcomes.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|4|未观察|
|27|`stone_calendar` / StoneCalendar|abyss_rare_relics.lua, abyss_relic_end_turn.lua|tests/lua/act2_calendar_codex_joint.lua:43 Calendar before Codex lethal suppresses the later offer/RNG but retains source queued Plated block|5|未观察|
|28|`shovel` / Shovel|abyss_nodes_rare_camp.lua, abyss_rare_relics.lua, abyss_relic_pool.lua|tests/lua/rare_relics_nodes.lua:24 Shovel consumes one source rarity draw and offers an actual optional relic|6|未观察|
|29|`winged_greaves` / WingedGreaves|abyss_nodes.lua, abyss_rare_relics.lua|tests/lua/rare_relics_nodes.lua:33 Winged Greaves advertises next row and consumes only committed off-path entry|3|未观察|
|30|`thread_and_needle` / Thread and Needle|abyss_inventory.lua, abyss_rare_relics.lua, abyss_relic_hooks.lua|tests/lua/act2_calendar_codex_joint.lua:43 Calendar before Codex lethal suppresses the later offer/RNG but retains source queued Plated block|6|未观察|
|31|`turnip` / Turnip|abyss_rare_relics.lua|tests/lua/rare_relics_run.lua:26 Ginger and Turnip block debuffs before Artifact|3|未观察|
|32|`ice_cream` / Ice Cream|abyss_rare_relics.lua|tests/lua/rare_relics_run.lua:93 Ice Cream preserves actual unused energy at the next recharge|3|未观察|
|33|`calipers` / Calipers|abyss_rare_relics.lua|tests/lua/rare_relics_run.lua:36 Thread applies real plated armor and Calipers preserves excess block|3|未观察|
|34|`prayer_wheel` / Prayer Wheel|abyss_rare_relics.lua, abyss_relic_card_rewards.lua|tests/lua/library_event_rng.lua:59 full deck ownership and ordinary reward relics do not filter, alter20, cross-color or add upgrade draws|11|未观察|
|35|`girya` / Girya|abyss_inventory.lua, abyss_nodes_rare_camp.lua, abyss_rare_relics.lua, abyss_relic_hooks.lua|tests/lua/rare_relics_nodes.lua:12 Girya uses one camp action and grants its accumulated battle strength|7|未观察|
|36|`dead_branch` / Dead Branch|abyss_exhaust.lua, abyss_rare_relics.lua|tests/lua/act2_necronomicurse_exhaust_order.lua:2 top-level fixture (per-ID attribution requires assertion excerpts)|7|未观察|
|37|`du_vu_doll` / Du-Vu Doll|abyss_inventory.lua, abyss_rare_relics.lua, abyss_relic_hooks.lua|tests/lua/uncommon_relics_opening.lua:23 Du Vu Doll counts permanent curses and applies Strength TOP before draw|3|未观察|
|38|`pocketwatch` / Pocketwatch|abyss_rare_relics.lua|tests/lua/uncommon_relics_opening.lua:78 Pocketwatch and Tongs preserve held order before Brutality postdraw power|3|未观察|
|39|`incense_burner` / Incense Burner|abyss_rare_relics.lua|tests/lua/rare_relics_run.lua:80 Wheel Calendar and Incense use actual turn progression|4|未观察|
|40|`gambling_chip` / Gambling Chip|abyss_rare_relics.lua|tests/lua/rare_relics_run.lua:71 Gambling Chip opens a real optional UID choice only at battle opening|3|未观察|
|41|`peace_pipe` / Peace Pipe|abyss_nodes_rare_camp.lua, abyss_rare_relics.lua|tests/lua/black_star.lua:2 top-level fixture (per-ID attribution requires assertion excerpts)|7|未观察|
|42|`captains_wheel` / CaptainsWheel|abyss_rare_relics.lua|tests/lua/rare_relics_run.lua:80 Wheel Calendar and Incense use actual turn progression|4|未观察|
|43|`magic_flower` / Magic Flower|abyss_max_hp_relics.lua, abyss_potion_fairy.lua, abyss_potion_health.lua, abyss_rare_relics.lua, abyss_relic_hooks.lua|tests/lua/act2_event_relic_bloody.lua:36 MagicFlower joint actual combat gainGold heals5 to8 exactly once, not twice-modified12|24|未观察|
|44|`charons_ashes` / Charon's Ashes|abyss_exhaust.lua, abyss_rare_relics.lua|tests/lua/rare_relics_run.lua:60 Ashes damages and Dead Branch generates on actual exhaust movement|5|有库存/初始观察，效果未逐件认证|
|45|`champion_belt` / Champion Belt|abyss_rare_relics.lua|tests/lua/rare_relics_run.lua:54 Champion Belt successful Vulnerable queues actual Weak and respects Artifact|4|未观察|
|46|`velvet_choker` / Velvet Choker|abyss_boss_relics.lua, abyss_inventory.lua|tests/lua/boss_relics_missing.lua:20 seven energy bosses prepare four energy and Ectoplasm prevents actual gold|2|未观察|
|47|`runic_dome` / Runic Dome|abyss_boss_relics.lua, abyss_inventory.lua|tests/lua/boss_relics_dome.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|4|有库存/初始观察，效果未逐件认证|
|48|`snecko_eye` / Snecko Eye|abyss_boss_relics.lua, abyss_inventory.lua|tests/lua/boss_relics_missing.lua:26 Snecko applies confusion before first seven-card draw|2|未观察|
|49|`pandoras_box` / Pandora's Box|abyss_boss_relics.lua, abyss_inventory.lua|tests/lua/boss_relics_missing.lua:65 Pandora replaces every starter, preserving Bash and permanent obtain hooks|3|未观察|
|50|`cursed_key` / Cursed Key|abyss_boss_relics.lua, abyss_inventory.lua, abyss_treasure.lua|tests/lua/boss_relics_missing.lua:20 seven energy bosses prepare four energy and Ectoplasm prevents actual gold|7|未观察|
|51|`busted_crown` / Busted Crown|abyss_boss_relics.lua, abyss_inventory.lua|tests/lua/boss_relics_missing.lua:20 seven energy bosses prepare four energy and Ectoplasm prevents actual gold|8|未观察|
|52|`ectoplasm` / Ectoplasm|abyss_boss_relics.lua, abyss_colorless_cards.lua, abyss_inventory.lua, abyss_moai_event.lua, abyss_relic_hooks.lua|tests/lua/act2_event_relic_bloody.lua:16 controlled Ectoplasm owned-flag interaction prevents combat gold and BloodyIdol heal, not acquisition evidence|22|未观察|
|53|`tiny_house` / Tiny House|abyss_boss_relics.lua, abyss_inventory.lua|tests/lua/black_star.lua:2 top-level fixture (per-ID attribution requires assertion excerpts)|8|未观察|
|54|`philosophers_stone` / Philosopher's Stone|abyss_boss_relics.lua, abyss_inventory.lua, abyss_relic_hooks.lua|tests/lua/boss_relics_missing.lua:20 seven energy bosses prepare four energy and Ectoplasm prevents actual gold|4|未观察|
|55|`astrolabe` / Astrolabe|abyss_boss_relics.lua, abyss_inventory.lua|tests/lua/black_star.lua:2 top-level fixture (per-ID attribution requires assertion excerpts)|6|未观察|
|56|`empty_cage` / Empty Cage|abyss_boss_relics.lua, abyss_inventory.lua|tests/lua/boss_relics_missing.lua:50 Empty Cage selects two distinct live UIDs and rejects duplicate input atomically|5|未观察|
|57|`runic_pyramid` / Runic Pyramid|abyss_boss_relics.lua, abyss_inventory.lua, abyss_silent_final_cards.lua|tests/lua/boss_relics_missing.lua:81 Crown and visibility/retention predicates follow actual acquired owners|2|未观察|
|58|`calling_bell` / Calling Bell|abyss_boss_relics.lua, abyss_inventory.lua|tests/lua/boss_relics_missing.lua:102 Calling Bell obtains its protected curse and individually grants three source relic offers|5|未观察|
|59|`mark_of_pain` / Mark of Pain|abyss_boss_relics.lua, abyss_inventory.lua, abyss_relic_hooks.lua|tests/lua/boss_relics_missing.lua:20 seven energy bosses prepare four energy and Ectoplasm prevents actual gold|4|未观察|
|60|`runic_cube` / Runic Cube|abyss_boss_relics.lua, abyss_inventory.lua|tests/lua/boss_relics_missing.lua:44 Runic Cube draws once for each actual HP loss and none for block|2|未观察|
|61|`sling` / Sling|abyss_shop_relics.lua|tests/lua/shop_relics_effects.lua:13 source aliases and owners are exact|3|未观察|
|62|`hand_drill` / HandDrill|abyss_shop_relics.lua|tests/lua/shop_relics_effects.lua:24 Hand Drill queues actual vulnerable and respects Artifact|2|未观察|
|63|`toolbox` / Toolbox|abyss_card_actions.lua, abyss_combat.lua, abyss_combat_effect_dispatch.lua, abyss_shop_relics.lua|tests/lua/shop_relics_effects.lua:76 Toolbox offers three distinct source cards and preserves real costs|2|未观察|
|64|`chemical_x` / Chemical X|abyss_colorless_cards.lua, abyss_shop_relics.lua, abyss_silent_final_cards.lua, abyss_watcher_final_cards.lua|tests/lua/shop_relics_effects.lua:13 source aliases and owners are exact|4|未观察|
|65|`orrery` / Orrery|abyss_shop_relics.lua|tests/lua/m3_driver_relic_choices.lua:3 top-level fixture (per-ID attribution requires assertion excerpts)|7|未观察|
|66|`dollys_mirror` / DollysMirror|abyss_shop_relics.lua|tests/lua/m3_driver_relic_choices.lua:3 top-level fixture (per-ID attribution requires assertion excerpts)|6|未观察|
|67|`orange_pellets` / OrangePellets|abyss_shop_relics.lua|tests/lua/shop_relics_effects.lua:58 Orange Pellets removes debuffs but retains positive strength|5|未观察|
|68|`prismatic_shard` / PrismaticShard|abyss_card_pool.lua, abyss_shop_relics.lua|tests/lua/library_event_rng.lua:59 full deck ownership and ordinary reward relics do not filter, alter20, cross-color or add upgrade draws|2|未观察|
|69|`clockwork_souvenir` / ClockworkSouvenir|abyss_shop_relics.lua|tests/lua/shop_relics_effects.lua:17 Sling only grants elite strength and Clockwork grants artifact|4|未观察|
|70|`frozen_eye` / Frozen Eye|abyss_shop_relics.lua|tests/lua/deck_pile_view.lua:60 discard view keeps group order and Frozen Eye permits the original reversed draw copy|3|未观察|
|71|`the_abacus` / TheAbacus|abyss_shop_relics.lua|tests/lua/shop_relics_effects.lua:32 Abacus fixed block ignores dexterity and frail|2|未观察|
|72|`medical_kit` / Medical Kit|abyss_combat.lua, abyss_shop_relics.lua|tests/lua/shop_relics_effects.lua:37 Chemical X, Medical Kit and Frozen Eye preserve unrelated cards|2|未观察|
|73|`cauldron` / Cauldron|abyss_shop_relics.lua|tests/lua/m3_driver_relic_choices.lua:3 top-level fixture (per-ID attribution requires assertion excerpts)|4|未观察|
|74|`strange_spoon` / Strange Spoon|abyss_shop_relics.lua|tests/lua/shop_relics_effects.lua:45 Spoon consumes one source boolean at disposal only|3|未观察|
|75|`brimstone` / Brimstone|abyss_shop_relics.lua|tests/lua/shop_relics_effects.lua:68 Brimstone grants both sides strength each turn|2|未观察|
|76|`fossilized_helix` / FossilizedHelix|abyss_inventory.lua, abyss_relic_hooks.lua|tests/lua/relic_reported_failures.lua:16 event box grants its original Helix identity and Regret exactly once|5|未观察|
|77|`pantograph` / Pantograph|abyss_inventory.lua, abyss_relic_hooks.lua|tests/lua/relic_reported_failures.lua:37 Pantograph heals 25 only at a Boss opening and respects Bloom|1|未观察|
|78|`sacred_bark` / SacredBark|abyss_inventory.lua, abyss_potion_fairy.lua|tests/lua/act3_moai_event.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|18|有库存/初始观察，效果未逐件认证|
|79|`white_beast_statue` / White Beast Statue|abyss_potion_rewards.lua|tests/lua/potion_full_pool.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|3|未观察|
|80|`pear` / Pear|abyss_max_hp_relics.lua, abyss_relic_hooks.lua|tests/lua/inventory.lua:221 legacy six-opening fixture keeps resources across two original-enemy battles and the acquired relic persists into the next battle|11|未观察|
|81|`mango` / Mango|abyss_max_hp_relics.lua, abyss_relic_hooks.lua|tests/lua/m3_relic_choice_events.lua:180 Gift exact rarity thresholds retain PR357 reward modifiers and one-shot sacrifice effects|11|未观察|
|82|`old_coin` / Old Coin|abyss_relic_hooks.lua|tests/lua/face_nloth_skull_events.lua:42 Nloth constructor shuffles all relics once and immutable offer identity survives reorder|9|未观察|
|83|`frozen_egg` / Frozen Egg 2|abyss_relic_hooks.lua|tests/lua/library_event.lua:136 unsupported original-V4/prepared mapping stays honest; Frozen Egg previews and obtains only upgraded Powers|5|未观察|
|84|`coffee_dripper` / Coffee Dripper|abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven), abyss_nodes.lua, abyss_relic_hooks.lua, abyss_relic_loss.lua|tests/lua/relic_camp_ui.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|4|未观察|
|85|`fusion_hammer` / Fusion Hammer|abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven), abyss_nodes.lua, abyss_relic_hooks.lua, abyss_relic_loss.lua|tests/lua/relic_camp_ui.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|4|未观察|
|86|`mark_of_bloom` / Mark of the Bloom|abyss_lizard_tail.lua, abyss_max_hp_relics.lua, abyss_mind_bloom_event.lua, abyss_moai_event.lua, abyss_potion_fairy.lua|tests/lua/act2_event_relic_bloody.lua:20 real MarkOfTheBloom preserves gold but blocks BloodyIdol healing|46|未观察|
|87|`membership_card` / Membership Card|abyss_relic_rewards.lua, abyss_run.lua, abyss_shop.lua, abyss_treasure.lua|tests/lua/nodes.lua:298 shops keep configured deletion increments and purchases across independently sampled nodes|2|未观察|
|88|`courier` / The Courier|abyss_relic_rewards.lua, abyss_run.lua, abyss_shop.lua, abyss_shop_price.lua, abyss_treasure.lua|tests/lua/molten_egg_eligibility.lua:25 initial source shop uses destination floor49 while source floor48 still offers Egg|7|未观察|
|89|`smiling_mask` / Smiling Mask|abyss_relic_rewards.lua, abyss_run.lua, abyss_shop.lua, abyss_treasure.lua|tests/lua/nodes.lua:298 shops keep configured deletion increments and purchases across independently sampled nodes|2|未观察|
|90|`burning_blood` / Burning Blood|abyss_inventory.lua / abyss_run.lua(data-driven), abyss_relic_rewards.lua, abyss_run.lua, abyss_treasure.lua, abyss_warrior_cards.lua|tests/lua/act3_moai_event.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|26|有库存/初始观察，效果未逐件认证|
|91|`anchor` / Anchor|abyss_battle_card_view.lua, abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven), abyss_map_topology.lua, abyss_relic_rewards.lua|tests/lua/act1_event_content.lua:92 big fish box uses complete shared queue and commits Regret and actual Anchor once|36|未观察|
|92|`vajra` / Vajra|abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven), abyss_relic_rewards.lua, abyss_run.lua, abyss_treasure.lua|tests/lua/act3_moai_event.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|15|未观察|
|93|`bag_of_preparation` / Bag of Preparation|abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven), abyss_relic_rewards.lua, abyss_run.lua, abyss_treasure.lua|tests/lua/inventory.lua:41 all six opening relics use current data and retain their effects after owner-turn reset|6|未观察|
|94|`lantern` / Lantern|abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven), abyss_merchant.lua, abyss_relic_rewards.lua, abyss_run.lua|tests/lua/act2_event_relic_acquisition.lua:8 Altar actual GoldenIdol slot becomes real BloodyIdol, then positive gold heals5 exactly once|9|未观察|
|95|`oddly_smooth_stone` / Oddly Smooth Stone|abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven), abyss_relic_rewards.lua, abyss_run.lua, abyss_treasure.lua|tests/lua/class_common_relic_effects.lua:61 DataDisk gives one first-turn Focus before draw and never regrants each turn|5|未观察|
|96|`bronze_scales` / Bronze Scales|abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven), abyss_relic_rewards.lua, abyss_run.lua, abyss_treasure.lua|tests/lua/inventory_parity.lua:28 Bronze Scales is a common relic granting exactly three Thorns|5|未观察|
|97|`black_star` / Black Star|abyss_relic_rewards.lua|tests/lua/black_star.lua:2 top-level fixture (per-ID attribution requires assertion excerpts)|5|未观察|
|98|`black_blood` / Black Blood|abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven), abyss_relic_rewards.lua, abyss_run.lua, abyss_treasure.lua|tests/lua/boss_relic_effects.lua:50 Black Blood heals 12 once on victory, caps at max HP and never heals defeat|7|未观察|
|99|`slavers_collar` / SlaversCollar|abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven), abyss_relic_rewards.lua, abyss_run.lua, abyss_treasure.lua|tests/lua/boss_relic_effects.lua:19 Slaver collar applies in elite and Boss fights but not ordinary combat|7|未观察|
|100|`sozu` / Sozu|abyss_card_actions.lua, abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven), abyss_knowing_skull_event.lua, abyss_neow.lua|tests/lua/boss_relic_effects.lua:14 Sozu raises prepared energy on both opening and subsequent turns|17|未观察|
|101|`omamori` / Omamori|abyss_relic_hooks.lua, abyss_writhing_mass.lua|tests/lua/act1_event_content.lua:78 serpent old Omamori blocks curse once without spending a permanent UID|50|未观察|
|102|`ceramic_fish` / CeramicFish|abyss_relic_hooks.lua|tests/lua/act1_event_content.lua:103 big fish card resolve dispatches the newly acquired Ceramic Fish hook|74|未观察|
|103|`potion_belt` / Potion Belt|abyss_relic_hooks.lua|tests/lua/approved_main_potion_shell.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|14|未观察|
|104|`meal_ticket` / MealTicket|abyss_relic_hooks.lua|tests/lua/common_relic_hooks.lua:20 MealTicket only heals entering shop; MawBank awards each entered room then shop spend disables permanently|6|未观察|
|105|`maw_bank` / MawBank|abyss_relic_hooks.lua|tests/lua/addict_event_content.lua:115 Source event payment does not disable Maw Bank|18|未观察|
|106|`blood_vial` / Blood Vial|abyss_inventory.lua, abyss_relic_hooks.lua, abyss_vampires_event.lua|tests/lua/common_relic_hooks.lua:31 BloodVial TOP healing and BagOfMarbles BOTTOM status use actual opening API|10|有库存/初始观察，效果未逐件认证|
|107|`bag_of_marbles` / Bag of Marbles|abyss_inventory.lua, abyss_relic_hooks.lua|tests/lua/common_relic_hooks.lua:31 BloodVial TOP healing and BagOfMarbles BOTTOM status use actual opening API|3|未观察|
|108|`orichalcum` / Orichalcum|abyss_relic_end_turn.lua, abyss_relic_hooks.lua|tests/lua/act2_event_relic_codex.lua:56 legacy Orichalcum-only runs retain their existing path with no new relic dispatch markers|5|未观察|
|109|`strawberry` / Strawberry|abyss_max_hp_relics.lua, abyss_relic_hooks.lua|tests/lua/act2_event_ui_hooks.lua:63 both simple-event equip/card exceptions rollback paid/protection/relic/curse state then fresh gesture recovers|19|未观察|
|110|`regal_pillow` / Regal Pillow|abyss_relic_hooks.lua|tests/lua/common_relic_equipment.lua:9 RegalPillow adds fifteen only to rest recovery; healing still clamps at max|8|未观察|
|111|`toy_ornithopter` / Toy Ornithopter|abyss_relic_hooks.lua|tests/lua/class_potion_ambrosia_queue.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|15|未观察|
|112|`whetstone` / Whetstone|abyss_relic_hooks.lua, abyss_run.lua|tests/lua/addict_event_content.lua:118 Screenless Whetstone exclusion consumes source queue entries and only one tier draw|15|未观察|
|113|`war_paint` / War Paint|abyss_relic_hooks.lua, abyss_run.lua|tests/lua/addict_event_content.lua:118 Screenless Whetstone exclusion consumes source queue entries and only one tier draw|9|未观察|
|114|`happy_flower` / Happy Flower|abyss_relic_hooks.lua|tests/lua/common_relic_turns.lua:12 HappyFlower grants one energy on every third player turn and persists its counter|2|未观察|
|115|`ancient_tea_set` / Ancient Tea Set|abyss_relic_hooks.lua|tests/lua/common_relic_nodes.lua:29 entry rejection retains external map resources and all mutable owners|6|未观察|
|116|`art_of_war` / Art of War|abyss_relic_hooks.lua|tests/lua/common_relic_turns.lua:29 ArtOfWar skips first-turn bonus and tracks attacks even after they leave hand|2|未观察|
|117|`boot` / Boot|abyss_actor.lua, abyss_relic_hooks.lua|tests/lua/act1_event_content.lua:113 big fish missing original relic refuses whole box without reroll, UID, queue or RNG mutation|6|未观察|
|118|`akabeko` / Akabeko|abyss_inventory.lua, abyss_relic_hooks.lua|tests/lua/common_relic_attacks.lua:22 Akabeko vigor applies eight to each hit of first attack, consumed only by attacks|3|未观察|
|119|`pen_nib` / Pen Nib|abyss_actor.lua, abyss_battle_intent_view.lua, abyss_inventory.lua, abyss_relic_hooks.lua|tests/lua/common_relic_attacks.lua:28 PenNib doubles tenth attack and preserves source priority with Vigor Weak and Vulnerable|4|未观察|
|120|`nunchaku` / Nunchaku|abyss_relic_hooks.lua|tests/lua/autoplay_lifecycle.lua:10 Chaos auto attack updates Nunchaku once through both use and after-card hooks|5|未观察|
|121|`preserved_insect` / PreservedInsect|abyss_relic_hooks.lua|tests/lua/common_relic_final.lua:25 PreservedInsect sets only elite current HP to floor 75 percent and preserves max HP|1|未观察|
|122|`red_skull` / Red Skull|abyss_hp_loss.lua, abyss_inventory.lua, abyss_relic_hooks.lua|tests/lua/act3_writhing_parasite.lua:74 Darkstone in-combat health uses source healing modifiers and CeramicFish respects Ectoplasm|8|未观察|
|123|`centennial_puzzle` / Centennial Puzzle|abyss_hp_loss.lua, abyss_relic_hooks.lua|tests/lua/centennial_puzzle_queue.lua:3 top-level fixture (per-ID attribution requires assertion excerpts)|12|未观察|
|124|`tiny_chest` / Tiny Chest|abyss_nodes_entry.lua, abyss_relic_hooks.lua, abyss_relic_loss.lua|tests/lua/common_relic_final.lua:84 TinyChest equipment resets its actual unknown-room counter|4|未观察|
|125|`juzu_bracelet` / Juzu Bracelet|abyss_nodes_entry.lua, abyss_relic_hooks.lua|tests/lua/common_relic_final.lua:88 Juzu and fourth TinyChest use existing formal Nodes unknown-room ownership adapters|1|未观察|
|126|`dream_catcher` / Dream Catcher|abyss_nodes.lua, abyss_relic_hooks.lua|tests/lua/common_relic_final.lua:107 DreamCatcher rest hook requests the ordinary card reward once and refuses missing production adapter|12|未观察|
|127|`warped_tongs` / WarpedTongs|abyss_relic_hooks.lua|tests/lua/act1_event_content.lua:107 blacksmith missing original Tongs rolls back already prepared old Omamori|7|未观察|
|128|`spirit_poop` / Spirit Poop|abyss_act1_events.lua, abyss_relic_hooks.lua|tests/lua/act1_event_content.lua:145 bonfire curse obtains Spirit Poop then repeatable Circlet and permanently removes each offered UID|3|未观察|
|129|`circlet` / Circlet|abyss_cursed_tome_event.lua, abyss_event_combat.lua, abyss_event_combat_routes.lua, abyss_golden_idol_event.lua, abyss_masked_bandits_event.lua|tests/lua/act1_event_content.lua:145 bonfire curse obtains Spirit Poop then repeatable Circlet and permanently removes each offered UID|21|未观察|
|130|`darkstone_periapt` / Darkstone Periapt|abyss_golden_idol_event.lua, abyss_nodes_entry.lua, abyss_relic_hooks.lua, abyss_winding_event.lua|tests/lua/act2_event_relic_acquisition.lua:34 Necronomicon actual curse obtain sees Omamori/Fish/Darkstone, not inert special-card exemption|43|未观察|
|131|`red_mask` / Red Mask|abyss_event_combat_routes.lua, abyss_inventory.lua, abyss_masked_bandits_event.lua, abyss_relic_hooks.lua, abyss_tomb_red_mask_event.lua|tests/lua/event_combat_route_smoke.lua:3 top-level fixture (per-ID attribution requires assertion excerpts)|8|未观察|
|132|`toxic_egg` / Toxic Egg 2|abyss_nodes_entry.lua, abyss_relic_hooks.lua|tests/lua/act3_winding_outcomes.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|29|未观察|
|133|`molten_egg` / Molten Egg 2|abyss_nodes_entry.lua, abyss_relic_hooks.lua|tests/lua/duplicator_event.lua:69 Egg upgrades only newly obtained copy and does not double-upgrade upgraded original|23|未观察|
|134|`tungsten_rod` / TungstenRod|abyss_relic_hooks.lua|tests/lua/act3_winding_outcomes.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|28|未观察|
|135|`golden_idol` / Golden Idol|abyss_act1_events.lua, abyss_event_pool.lua, abyss_forgotten_altar_event.lua, abyss_gold_rewards.lua, abyss_golden_idol_event.lua|tests/lua/act2_event_relic_acquisition.lua:8 Altar actual GoldenIdol slot becomes real BloodyIdol, then positive gold heals5 exactly once|17|未观察|
|136|`neows_lament` / NeowsBlessing|abyss_relic_hooks.lua|tests/lua/neow_lament_opening.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|2|未观察|
|137|`snake_skull` / Snake Skull|abyss_actor.lua, abyss_relic_hooks.lua, abyss_run.lua|tests/lua/class_common_relic_constructor.lua:13 Fumes constructor snapshots Snake ownership before a real Foresight pause|15|未观察|
|138|`data_disk` / DataDisk|abyss_inventory.lua, abyss_relic_hooks.lua, abyss_run.lua|tests/lua/class_common_relic_effects.lua:61 DataDisk gives one first-turn Focus before draw and never regrants each turn|7|未观察|
|139|`damaru` / Damaru|abyss_relic_hooks.lua, abyss_run.lua|tests/lua/class_common_relic_lifecycle.lua:25 Damaru dispatches one queued Mantra each real player turn, before normal draw|10|未观察|
|140|`lizard_tail` / Lizard Tail|abyss_battle_info_content.lua, abyss_lizard_tail.lua, abyss_player_revive.lua, abyss_relic_hooks.lua, abyss_run.lua|tests/lua/act3_winding_outcomes.lua:1 top-level fixture (per-ID attribution requires assertion excerpts)|42|未观察|
|141|`odd_mushroom` / Odd Mushroom|abyss_actor.lua, abyss_event_combat.lua, abyss_mushrooms_event.lua|tests/lua/intent_formula.lua:71 actual odd mushroom and Wrath multipliers use the same core route|3|未观察|
|142|`lees_waffle` / Lee's Waffle|abyss_max_hp_relics.lua, abyss_relic_hooks.lua|tests/lua/max_hp_competition_profiles.lua:2 top-level fixture (per-ID attribution requires assertion excerpts)|7|未观察|
|143|`cultist_mask` / CultistMask|abyss_inventory.lua, abyss_relic_hooks.lua|tests/lua/face_nloth_skull_events.lua:17 FaceTrader uses exact unowned five-face list in source order and singleton shuffle Circlet fallback|4|未观察|
|144|`face_of_cleric` / FaceOfCleric|abyss_run_settlement.lua|tests/lua/face_nloth_skull_events.lua:17 FaceTrader uses exact unowned five-face list in source order and singleton shuffle Circlet fallback|5|未观察|
|145|`gremlin_mask` / GremlinMask|abyss_inventory.lua, abyss_inventory.lua / abyss_run.lua(data-driven)|tests/lua/face_nloth_skull_events.lua:17 FaceTrader uses exact unowned five-face list in source order and singleton shuffle Circlet fallback|4|未观察|
|146|`nloths_mask` / NlothsMask|abyss_relic_hooks.lua, abyss_treasure.lua|tests/lua/face_nloth_skull_events.lua:17 FaceTrader uses exact unowned five-face list in source order and singleton shuffle Circlet fallback|11|未观察|
|147|`ssserpent_head` / SsserpentHead|abyss_relic_hooks.lua|tests/lua/face_nloth_skull_events.lua:17 FaceTrader uses exact unowned five-face list in source order and singleton shuffle Circlet fallback|4|未观察|
|148|`nloths_gift` / Nloth's Gift|abyss_library_event.lua, abyss_relic_rarity.lua|tests/lua/act2_event_relic_acquisition.lua:70 actual Nloth trade consumes real Necronomicon and its curse before giving real Gift|13|未观察|
|149|`bloody_idol` / Bloody Idol|abyss_act2_event_relics.lua, abyss_forgotten_altar_event.lua, abyss_run.lua|tests/lua/act2_event_relic_acquisition.lua:8 Altar actual GoldenIdol slot becomes real BloodyIdol, then positive gold heals5 exactly once|4|未观察|
|150|`mutagenic_strength` / MutagenicStrength|abyss_act2_event_relics.lua, abyss_drug_dealer_event.lua, abyss_inventory.lua, abyss_relic_hooks.lua|tests/lua/act2_event_relic_acquisition.lua:18 Augmenter obtains real MutagenicStrength once; existing source identity gets actual Circlet|5|未观察|
|151|`necronomicon` / Necronomicon|abyss_act2_event_relics.lua, abyss_combat.lua, abyss_cursed_tome_event.lua, abyss_relic_hooks.lua, abyss_relic_loss.lua|tests/lua/act2_event_relic_acquisition.lua:24 all THREE Tome outcomes are real source relic claims; one exact unowned candidate still draws misc once|15|未观察|
|152|`enchiridion` / Enchiridion|abyss_act2_event_relics.lua, abyss_cursed_tome_event.lua, abyss_inventory.lua|tests/lua/act2_event_relic_acquisition.lua:24 all THREE Tome outcomes are real source relic claims; one exact unowned candidate still draws misc once|8|未观察|
|153|`nilrys_codex` / Nilry's Codex|abyss_act2_event_relics.lua, abyss_codex_relic.lua, abyss_cursed_tome_event.lua, abyss_relic_end_turn.lua|tests/lua/act2_calendar_codex_joint.lua:43 Calendar before Codex lethal suppresses the later offer/RNG but retains source queued Plated block|14|未观察|

## 可复查方法与限制

源ID使用definition.sourceId；13项旧定义缺该字段时按 `abyss_relic_rewards.lua` 的精确legacy适配映射。固定原版镜像为 aeubanks/sts@319009d5；专属source-lock/oracle按ID定位，原版PC二进制与实机仍未认证。值相等、正确计数、显式拒绝等保留为原断言；生产sampler/float helper推导的expected不会被标成独立oracle。

扫描全部当前Lua测试/实现，AST解析0错误；只为解析把非ASCII字符等长掩为问号，所有展示行/断言仍读取原文。Lua的eq/equal/same等局部助手也收录，避免漏掉RunicCube等有实际断言的用例。测试标题/文件/ID相同只是索引入口；大top-level多遗物用例的某一断言不能自动归给所有遗物。matrix逐项明确这一限制。

dimensions是静态关键词辅助索引，不能自动判完成或证明缺实现；directRunNodesBlockIds也只枚举直接调用，间接battle/start/obtain本地helper另见源码。需要关闭全量AC前，由审查者按精确例子检查对应必要维度，并把当前CI实际结果关联到这些入口。不要因其中一个未证明的组合而抹去已证明的153件子集，也不要用子集抹平剩余差集。

本轮产物未写回仓库；冻结PR/完整CI/正常合并继续由主控负责。
