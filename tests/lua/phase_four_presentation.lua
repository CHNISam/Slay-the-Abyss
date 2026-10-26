package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local P=require('abyss_character_presentation')
local C=require('abyss_combat')
local Data=require('abyss_data')
local Existing=require('abyss_presentation')
local Display=require('abyss_card_display')
local Theme=require('abyss_theme')
local F=dofile('tests/lua/support/game_ui_fixture.lua')
local BattleUI=require('abyss_battle_ui')
local Frozen=dofile('tests/lua/support/frozen_display_877c4af.lua')
local cases=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();cases=cases+1;print('ok phase_four_presentation '..cases..' - '..name)end
local prepared=dofile('tests/lua/support/phase_four_presentation_data.lua')
local platform={imageSource='static',color=function(r,g,b,a)return {r=r,g=g,b=b,a=a}end}
test('all sixty-nine new regular cards and required derivative are present exactly once',function()
 local ids={
  ironclad='wild_strike reckless_charge intimidate immolate limit_break sever_soul second_wind fiend_fire flame_barrier evolve fire_breathing blood_for_blood',
  silent='piercing_wail all_out_attack blur choke concentrate crippling_poison dash escape_plan expertise finisher flechettes leg_sweep predator skewer terror die_die_die glass_knife malaise unload storm_of_steel',
  defect='claw stack steam_barrier streamline aggregate auto_shields blizzard chaos chill doom_and_gloom lock_on melter rip_and_tear skim sunder tempest meteor_strike multi_cast thunder_strike',
  watcher='battle_hymn collect fasting fear_no_evil indignation like_water pray reach_heaven study talk_to_the_hand tantrum simmering_fury wallop wheel_kick wreath_of_flame pressure_points flurry_of_blows weave',
 }
 local total=0
 for class,manifest in pairs(ids)do
  local d=prepared(class);local counts={};for _,c in ipairs(d.cards.cards)do counts[c.id]=(counts[c.id]or 0)+1 end
  for id in manifest:gmatch('%S+')do eq(counts[id],1);total=total+1 end
  if class=='watcher'then eq(counts.through_violence,1)end
 end
 eq(total,69)
end)
local function show(class,id,statuses,setup,up)
 local data=prepared(class);local texts=P.prepare(Existing,data)
 local opts={seed=42,cardRandomSeed='17',deck={{cardId=id,upgraded=up}},enableStances=class=='watcher'}
 if class=='defect'then opts.orbSlots=3;opts.orbRandomSeed='17'end
 local s=C.new(data,opts)
 for k,v in pairs(statuses or {})do s.player.statuses[k]=v end
 if setup then setup(s)end
 local card=s.hand[1];local definition=C.cardDefinition(s,card)
 local label=texts[id];local template=(up and label.upgradeCombatText or label.combatText)or(up and label.upgradeText or label.text)
 return Display.format(template,definition,C.cardPreview(s,card,1),Theme.color),label,s
end
test('source-driven conditions and generated cards do not trust arbitrary text',function()
 local s=P.prepare(Existing,prepared('silent'))
 assert(s.bane.text:find('中毒',1,true)and s.grand_finale.text:find('抽牌堆为空',1,true))
 assert(s.heel_hook.text:find('虚弱',1,true)and s.dodge_and_roll.text:find('下回合',1,true))
 local w=P.prepare(Existing,prepared('watcher'))
 assert(w.signature_move.text:find('其他攻击',1,true)and w.follow_up.text:find('上一张',1,true))
 assert(w.evaluate.text:find('洞见',1,true)and w.carve_reality.text:find('惩罚',1,true)and w.deceive_reality.text:find('安全',1,true))
 local data=prepared('watcher');for _,c in ipairs(data.cards.cards)do c.text='虚构的999999点伤害';c.upgradeText=c.text end
 local p=P.prepare(Existing,data);assert(not p.halt.text:find('999999',1,true))
end)
test('phase-three damage and next-turn block use actual modified previews',function()
 for _,spec in ipairs({{'watcher','bowling_bash',9},{'defect','barrage',6},{'defect','ftl',7},{'silent','heel_hook',7}})do
  local rendered=show(spec[1],spec[2],{strength=2})
  assert(rendered:find(tostring(spec[3]),1,true)and rendered:find('↑',1,true),rendered)
 end
 local rendered=show('silent','dodge_and_roll',{dexterity=3,frail=1})
 local _,n=rendered:gsub('5↑','');eq(n,2) -- Both current and next-turn Block must use floor((4+3)*.75).
 rendered=show('defect','reinforced_body',{dexterity=2,frail=1})
 assert(rendered:find('6↓',1,true),rendered)
end)
test('Halt displays actual total and Brilliance captures Mantra once',function()
 local r=show('watcher','halt',{dexterity=2,frail=1},function(s)s.player.stance='Wrath'end)
 assert(r:find('11',1,true),r)
 r=show('watcher','brilliance',{strength=2},function(s)s.mantraGained=5;s.player.stance='Divinity'end)
 assert(r:find('57',1,true),r)
 local heavy=show('ironclad','heavy_blade',{strength=2});assert(heavy:find('20',1,true),heavy)
end)
test('Bane nested conditional damage has its own exact dynamic token',function()
 local r,label=show('silent','bane',{strength=2})
 assert(label.combatText:find('{effects.1.then.0.value}',1,true))
 local _,n=r:gsub('9↑','');eq(n,2);assert(not r:find('{effects',1,true))
end)
test('six card-trigger powers describe conditions and retain innate upgrades',function()
 local s=P.prepare(Existing,prepared('silent'));local d=P.prepare(Existing,prepared('defect'));local w=P.prepare(Existing,prepared('ironclad'))
 assert(s.after_image.text:find('每打出一张牌',1,true)and s.after_image.upgradeText:find('先天',1,true))
 assert(s.thousand_cuts.text:find('固定伤害',1,true)and s.envenom.text:find('未被格挡',1,true))
 assert(d.heat_sinks.text:find('能力牌',1,true)and d.storm.text:find('闪电球',1,true))
 assert(d.storm.upgradeText:find('先天',1,true)and w.rage.text:find('本回合',1,true))
end)
test('877c4af forty-card historical input keeps its prepared wording unchanged',function()
 local historical=C.copy(Data);historical.cards=C.copy(Frozen.cards);eq(#historical.cards.cards,40)
 local base=P.prepare(Frozen.existing,require('abyss_warrior_cards').withFoundationCards(historical))
 local expanded=P.prepare(Frozen.existing,prepared('ironclad',historical))
 for _,c in ipairs(historical.cards.cards)do
  if expanded[c.id]then eq(expanded[c.id].name,base[c.id].name);eq(expanded[c.id].text,base[c.id].text);eq(expanded[c.id].upgradeText,base[c.id].upgradeText)end
 end
 local original=Existing.strike.text;expanded.strike.text='mutated';eq(Existing.strike.text,original)
end)
test('unknown operations statuses conditions and nested branches still reject',function()
 for _,e in ipairs({{op='gainStrengthPower',status='invented',value=1},{op='gainCardTriggerPower',status='invented',value=1},
  {op='makeTempCard',cardId='invented',pile='hand',value=1},{op='previousCardType',cardType='invented',effect={op='energy',value=1}},
  {op='conditional',['if']='target_poison',['then']={{op='invented',value=1}}},
  {op='conditional',['if']='target_poison',['then']={{op='conditional',['if']='target_poison',['then']={{op='damage',value=1}}}}}})do
  local d=prepared('watcher');d.cards.cards[1].effects={e};assert(not pcall(P.prepare,Existing,d))
 end
 for _,field in ipairs({'condition','costMode'})do local d=prepared('watcher');d.cards.cards[1][field]='invented';assert(not pcall(P.prepare,Existing,d))end
end)
test('phase-four per-hit damage uses real modifiers for every new attack op',function()
 for _,spec in ipairs({{'ironclad','fiend_fire',9},{'watcher','fear_no_evil',10},{'watcher','wallop',11},
  {'watcher','flurry_of_blows',6},{'watcher','weave',6},{'watcher','tantrum',5},{'defect','sunder',26},
  {'defect','rip_and_tear',9},{'defect','thunder_strike',9},{'silent','finisher',8},{'silent','flechettes',6},
  {'silent','skewer',9},{'silent','glass_knife',10}})do
  local r=show(spec[1],spec[2],{strength=2})
  assert(r:find(tostring(spec[3])..'↑',1,true),spec[2]..': '..r)
 end
end)
test('phase-four conditional and repeated Block use actual Dexterity and Frail',function()
 for _,spec in ipairs({{'ironclad','second_wind',7},{'defect','auto_shields',13},{'silent','escape_plan',5}})do
  local r=show(spec[1],spec[2],{dexterity=2})
  assert(r:find(tostring(spec[3])..'↑',1,true),spec[2]..': '..r)
 end
 local r=show('defect','stack',{dexterity=2},nil,true)
 assert(r:find('5↑',1,true),r)
end)
test('orb history and permanent instance changes feed the shared dynamic preview',function()
 local r=show('defect','blizzard',{strength=2},function(s)s.orbChannelCounts={lightning=0,frost=4,dark=0,plasma=0}end)
 assert(r:find('10↑',1,true),r)
 r=show('defect','claw',{strength=2},function(s)s.hand[1].engineClawBonus=4 end)
 assert(r:find('9↑',1,true),r)
 r=show('defect','steam_barrier',{dexterity=2},function(s)s.hand[1].engineBlockLoss=2 end)
 assert(r:find('6↑',1,true),r)
 r=show('silent','glass_knife',{strength=2},function(s)s.hand[1].glassKnifeReduction=2 end)
 assert(r:find('8↑',1,true),r)
end)
test('random attack text does not pretend the selected enemy is every random target',function()
 for _,id in ipairs({'rip_and_tear','thunder_strike'})do
  local r=show('defect',id,{strength=2},function(s)s.enemies[1].statuses.vulnerable=1 end)
  assert(r:find('9↑',1,true),id..': '..r)
 end
end)
test('new targeted operations request a live enemy while random and self actions do not',function()
 for _,spec in ipairs({{'ironclad','fiend_fire'},{'watcher','fear_no_evil'},{'watcher','wallop'},{'watcher','tantrum'},
  {'watcher','flurry_of_blows'},{'watcher','pressure_points'},{'defect','lock_on'},{'defect','melter'},{'defect','sunder'},
  {'silent','finisher'},{'silent','flechettes'},{'silent','skewer'},{'silent','glass_knife'},{'silent','malaise'}})do
  local _,_,s=show(spec[1],spec[2]);s.energy=99
  local ok,why=C.canPlay(s,s.hand[1].uid,nil);eq(ok,false);eq(why,'invalid_target')
  assert(C.canPlay(s,s.hand[1].uid,1),spec[2])
 end
 for _,spec in ipairs({{'defect','rip_and_tear'},{'defect','thunder_strike'},{'defect','blizzard'},
  {'watcher','indignation'},{'watcher','collect'},{'silent','escape_plan'}})do
  local _,_,s=show(spec[1],spec[2]);s.energy=99;assert(C.canPlay(s,s.hand[1].uid,nil),spec[2])
 end
end)
test('actual HP-loss and card reuse update displayed cost and Glass Knife damage',function()
 local data=prepared('ironclad');local text=P.prepare(Existing,data)
 local s=C.new(data,{seed=42,cardRandomSeed='17',deck={'blood_for_blood','hemokinesis'},enemies={'cultist'}})
 local blood,hemo
 for _,c in ipairs(s.hand)do if c.cardId=='blood_for_blood'then blood=c else hemo=c end end
 assert(C.play(s,hemo.uid,1));eq(C.cardDefinition(s,blood).cost,3)
 local root=F.Viewport.apply(F.control({children=F.Layout}),1280,720)
 local ui=BattleUI.new(root:GetChild('battlePanel'),data,text,'click',platform,{embedded=true})
 ui.run={phase='combat',combat=s,data=data,relics={},potions={},gold=99};ui:render()
 eq(root:GetChild('battlePanel'):GetChild('card1'):GetChild('cost').text,'3')
 data=prepared('silent');text=P.prepare(Existing,data)
 s=C.new(data,{seed=42,cardRandomSeed='17',deck={'glass_knife'},enemies={'cultist'}})
 local knife=s.hand[1];assert(C.play(s,knife.uid,1));assert(C.endTurn(s));eq(s.hand[1],knife)
 s.player.statuses.strength=2
 local r=Display.format(text.glass_knife.combatText,C.cardDefinition(s,knife),C.cardPreview(s,knife,1),Theme.color)
 assert(r:find('8↑',1,true),r)
end)
test('new X cards and upgrade flags communicate count rather than fake flat zero',function()
 local all={};for _,id in ipairs({'ironclad','silent','defect','watcher'})do
  local p=P.prepare(Existing,prepared(id));for k,v in pairs(p)do all[k]=v end
 end
 for _,id in ipairs({'collect','tempest','multi_cast','skewer','malaise'})do eq(all[id].cost,'X');eq(all[id].upgradeCost,'X')end
 assert(all.collect.text:find('X',1,true)and all.collect.upgradeText:find('X+1',1,true))
 assert(all.tempest.upgradeText:find('X+1',1,true)and all.multi_cast.upgradeText:find('X+1',1,true))
 assert(all.malaise.upgradeText:find('X+1',1,true))
 assert(all.battle_hymn.upgradeText:find('先天',1,true)and all.chill.upgradeText:find('先天',1,true))
 assert(all.tantrum.text:find('原牌',1,true)and all.storm_of_steel.upgradeText:find('升级飞刃',1,true))
 assert(all.through_violence.text:find('保留',1,true)and all.through_violence.text:find('消耗',1,true))
end)
test('all phase-four effects are validated even if arbitrary card text is supplied',function()
 for _,id in ipairs({'ironclad','silent','defect','watcher'})do
  local d=prepared(id)
  for _,c in ipairs(d.cards.cards)do c.text='未知的999999规则';c.upgradeText=c.text end
  local p=P.prepare(Existing,d)
  for _,c in ipairs(d.cards.cards)do assert(not p[c.id].text:find('999999',1,true))end
 end
 for _,e in ipairs({{op='gainStatusPower',status='invented',value=1},{op='gainWatcherFlowPower',status='invented',value=1},
  {op='applyWatcherFlowPower',status='invented',value=1},{op='applyStatus',status='invented',value=1},
  {op='makeTempCard',card='invented',pile='draw',randomSpot=true,value=1},{op='malaise',value=2},
  {op='tempestOrbs',value=2},{op='stormOfSteel',value=0,upgraded='invented'}})do
  local d=prepared('watcher');d.cards.cards[1].effects={e};assert(not pcall(P.prepare,Existing,d))
 end
end)
test('877c4af frozen inputs replay the unchanged 165-card and eleven-auxiliary display hash',function()
 local manifest='accuracy acrobatics adrenaline after_image anger backflip backstab ball_lightning bane barrage barricade bash battle_trance beam_cell berserk biased_cognition blade_dance bloodletting bludgeon body_slam boot_sequence bouncing_flask bowling_bash brilliance brutality burn burning_pact calculated_gamble caltrops capacitor carnage carve_reality catalyst charge_battery clash cleave cloak_and_dagger clothesline cold_snap combust compile_driver consecrate consume coolheaded core_surge corruption crescendo crush_joints cut_through_fate dagger_spray dagger_throw dark_embrace darkness dazed deadly_poison deceive_reality defend defend_blue defend_green defend_purple deflect defragment demon_form devotion disarm dodge_and_roll double_energy dropkick dualcast electrodynamics empty_body empty_fist empty_mind entrench envenom eruption evaluate eviscerate feel_no_pain flex flying_knee flying_sleeves follow_up footwork ftl fusion ghostly_armor glacier go_for_the_eyes grand_finale halt heat_sinks heavy_blade heel_hook hemokinesis hyperbeam impervious infinite_blades inflame inner_peace insight iron_wave just_lucky leap loop mental_fortress metallicize miracle neutralize nirvana noxious_fumes offering outmaneuver overclock perfected_strike perseverance poisoned_stab pommel_strike power_through prepared prostrate protect pummel quick_slash rage rainbow rampage reaper reflex regret reinforced_body reprogram riddle_with_holes rupture rushdown safety sanctity sands_of_time sash_whip scrawl seeing_red sentinel shiv shockwave shrug_it_off signature_move slice slimed smite sneaky_strike spot_weakness storm strike strike_blue strike_green strike_purple sucker_punch survivor sweeping_beam tactician third_eye thousand_cuts thunderclap tranquility true_grit turbo twin_strike uppercut vigilance void warcry whirlwind windmill_strike worship wound zap'
 local historical=C.copy(Data);historical.cards=C.copy(Frozen.cards);eq(#historical.cards.cards,40)
 local all={};for _,id in ipairs({'ironclad','silent','defect','watcher'})do
  local data=prepared(id,historical);local p=P.prepare(Frozen.existing,data);for _,c in ipairs(data.cards.cards)do all[c.id]=p[c.id]end
 end
 local hash,n=0.0,0
 for id in manifest:gmatch('%S+')do
  local c=assert(all[id]);n=n+1
  local text=table.concat({id,c.name,c.text,c.upgradeText,c.combatText or '',c.upgradeCombatText or '',c.cost,c.upgradeCost,c.type},'\0')..'\1'
  for i=1,#text do hash=(hash*131.0+text:byte(i))%2147483647 end
 end
 eq(n,176);eq(hash,780875649) -- captured from the independent frozen sts-triggers adapter/data.
end)
eq(cases,17)
print('phase_four_presentation: '..cases..' passed')
