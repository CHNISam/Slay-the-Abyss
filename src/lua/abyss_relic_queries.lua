-- Relic identity and reward queries only. No runtime dependencies or state writes.
-- These fixed namespaces preserve the five original alias scopes and method slots.
local hooks,uncommon,rare,boss,shop={},{},{},{},{}
local hookAliases={['Bloody Idol']='bloody_idol',MutagenicStrength='mutagenic_strength',Necronomicon='necronomicon',Enchiridion='enchiridion',["Nilry's Codex"]='nilrys_codex',["Nloth's Gift"]="nloths_gift",NlothsGift="nloths_gift",CultistMask='cultist_mask',FaceOfCleric='face_of_cleric',GremlinMask='gremlin_mask',NlothsMask='nloths_mask',SsserpentHead='ssserpent_head',FossilizedHelix='fossilized_helix',Pantograph='pantograph',SacredBark='sacred_bark',['White Beast Statue']='white_beast_statue',['Old Coin']='old_coin',
 ['Frozen Egg 2']='frozen_egg',['Coffee Dripper']='coffee_dripper',['Fusion Hammer']='fusion_hammer',
 NeowsBlessing='neows_lament',['Darkstone Periapt']='darkstone_periapt',Omamori='omamori',CeramicFish='ceramic_fish',['Potion Belt']='potion_belt',
 MealTicket='meal_ticket',MawBank='maw_bank',['Blood Vial']='blood_vial',
 ['Bag of Marbles']='bag_of_marbles',Orichalcum='orichalcum',Ectoplasm='ectoplasm',
 Strawberry='strawberry',Pear='pear',Mango='mango',["Lee's Waffle"]='lees_waffle',['Regal Pillow']='regal_pillow',['Toy Ornithopter']='toy_ornithopter',
 Whetstone='whetstone',['War Paint']='war_paint',['Happy Flower']='happy_flower',
 ['Ancient Tea Set']='ancient_tea_set',['Art of War']='art_of_war',
 Boot='boot',Akabeko='akabeko',['Pen Nib']='pen_nib',Nunchaku='nunchaku',
 PreservedInsect='preserved_insect',['Red Skull']='red_skull',['Centennial Puzzle']='centennial_puzzle',
 ['Tiny Chest']='tiny_chest',['Juzu Bracelet']='juzu_bracelet',['Dream Catcher']='dream_catcher',
 WarpedTongs='warped_tongs',['Spirit Poop']='spirit_poop',Circlet='circlet',TungstenRod='tungsten_rod',
 ['Red Mask']='red_mask',['Toxic Egg 2']='toxic_egg',['Molten Egg 2']='molten_egg',['Snake Skull']='snake_skull',DataDisk='data_disk',Damaru='damaru',['Mark of the Bloom']='mark_of_bloom',['Lizard Tail']='lizard_tail'}
local uncommonAliases={['Bottled Tornado']='bottled_tornado',Sundial='sundial',Kunai='kunai',
 ['Blue Candle']='blue_candle',['Eternal Feather']='eternal_feather',StrikeDummy='strike_dummy',
 ['Singing Bowl']='singing_bowl',Matryoshka='matryoshka',InkBottle='ink_bottle',
 ['Ornamental Fan']='ornamental_fan',['Bottled Lightning']='bottled_lightning',
 ['Gremlin Horn']='gremlin_horn',HornCleat='horn_cleat',['Letter Opener']='letter_opener',
 ['Question Card']='question_card',['Bottled Flame']='bottled_flame',Shuriken='shuriken',
 ['Meat on the Bone']='meat_on_the_bone',['Mummified Hand']='mummified_hand',
 ['Mercury Hourglass']='mercury_hourglass',['Self Forming Clay']='self_forming_clay',['Paper Frog']='paper_frog'}
local rareAliases={Ginger='ginger',['Bird Faced Urn']='bird_faced_urn',['Unceasing Top']='unceasing_top',Torii='torii',
 StoneCalendar='stone_calendar',Shovel='shovel',WingedGreaves='winged_greaves',['Thread and Needle']='thread_and_needle',
 Turnip='turnip',['Ice Cream']='ice_cream',Calipers='calipers',['Prayer Wheel']='prayer_wheel',Girya='girya',
 ['Dead Branch']='dead_branch',['Du-Vu Doll']='du_vu_doll',Pocketwatch='pocketwatch',['Incense Burner']='incense_burner',
 ['Gambling Chip']='gambling_chip',['Peace Pipe']='peace_pipe',CaptainsWheel='captains_wheel',['Magic Flower']='magic_flower',
 ["Charon's Ashes"]='charons_ashes',['Champion Belt']='champion_belt'}
local bossAliases={['Velvet Choker']='velvet_choker',['Runic Dome']='runic_dome',['Snecko Eye']='snecko_eye',
 ["Pandora's Box"]='pandoras_box',['Cursed Key']='cursed_key',['Busted Crown']='busted_crown',
 Ectoplasm='ectoplasm',['Tiny House']='tiny_house',["Philosopher's Stone"]='philosophers_stone',
 Astrolabe='astrolabe',['Empty Cage']='empty_cage',['Runic Pyramid']='runic_pyramid',
 ['Calling Bell']='calling_bell',['Mark of Pain']='mark_of_pain',['Runic Cube']='runic_cube'}
shop.aliases={Sling='sling',HandDrill='hand_drill',Toolbox='toolbox',['Chemical X']='chemical_x',
 Orrery='orrery',DollysMirror='dollys_mirror',OrangePellets='orange_pellets',PrismaticShard='prismatic_shard',
 ClockworkSouvenir='clockwork_souvenir',['Frozen Eye']='frozen_eye',TheAbacus='the_abacus',
 ['Medical Kit']='medical_kit',Cauldron='cauldron',['Strange Spoon']='strange_spoon',Brimstone='brimstone'}

function uncommon.localId(id)return uncommonAliases[id]or id end
function uncommon.owns(owner,id)
 for _,held in ipairs(owner.relics or {})do if uncommon.localId(held)==id then return true end end
 return false
end
function rare.localId(id)return rareAliases[id]or id end
local function rareOwns(owner,id)
 for _,held in ipairs(owner.relics or {})do if rare.localId(held)==id then return true end end
 return false
end
rare.owns=rareOwns
function boss.localId(id)return bossAliases[id]or id end
local function bossOwns(owner,id)
 for _,held in ipairs(owner and owner.relics or {})do if boss.localId(held)==id then return true end end
 return false
end
-- Facades capture the original private predicates, independently of public writes.
rare.privateOwns=rareOwns
boss.privateOwns=bossOwns
function boss.cardRewardCount(owner,n)return n-(bossOwns(owner,'busted_crown')and 2 or 0)end
function shop.localId(id)return shop.aliases[id]or id end
function shop.owns(owner,id)
 for _,held in ipairs(owner.relics or {})do if (shop.aliases[held]or held)==id then return true end end
 return false
end
function hooks.localId(id)
 return hookAliases[id]or shop.localId(boss.localId(rare.localId(uncommon.localId(id))))
end
function hooks.owns(owner,id)
 for _,held in ipairs(owner.relics or {})do if hooks.localId(held)==id then return true end end
 return false
end
return {hooks=hooks,uncommon=uncommon,rare=rare,boss=boss,shop=shop}
