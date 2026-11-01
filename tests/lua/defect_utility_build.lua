package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local O=require('abyss_orbs')
local U=require('abyss_defect_utility_cards')
local base=require('abyss_data')
local originalBurn,originalBurnFields
for _,c in ipairs(base.cards.cards)do if c.id=='burn' then
 originalBurn=c;originalBurnFields={};for k,v in pairs(c)do originalBurnFields[k]=v end
end end
local data=U.withCards(require('abyss_defect_cards').withFoundationCards(base))
local n=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,f)f();n=n+1;print('ok '..n..' '..name)end
local function uid(s,id)for _,c in ipairs(s.hand)do if c.cardId==id then return c.uid end end;error('not in hand: '..id)end
local function setup(id,up,count)
 local deck={};for i=1,(count or 1)do deck[i]={cardId=id,upgraded=up or false}end
 return C.new(data,{seed=42,orbSlots=3,orbRandomSeed='17',deck=deck,enemies={'jaw_worm','jaw_worm'}})
end
local function play(s,id,target)assert(C.play(s,uid(s,id),target))end
local function count(s,pile,id)local n=0;for _,c in ipairs(s[pile])do if c.cardId==id then n=n+1 end end;return n end
local function ch(s,kind)assert(O.channel(s,kind,C))end
test('helper independently prepares fourteen class and two status cards',function()
 local sourceBurn
 for _,c in ipairs(base.cards.cards)do if c.id=='burn' then sourceBurn=c end end
 eq(#data.cards.cards-#base.cards.cards,31-(sourceBurn and 1 or 0))
 local seen={};for _,c in ipairs(data.cards.cards)do assert(not seen[c.id],c.id);seen[c.id]=true end
 if sourceBurn then
  assert(sourceBurn==originalBurn)
  for k,v in pairs(originalBurnFields)do assert(sourceBurn[k]==v,'production Burn changed')end
  for k,v in pairs(sourceBurn)do assert(originalBurnFields[k]==v,'production Burn changed')end
  local preparedBurn=data.cards.cards[#data.cards.cards]
  assert(preparedBurn~=sourceBurn);eq(preparedBurn.burnDamage,2);eq(preparedBurn.upgrade.burnDamage,4)
 end
 local s=setup('rainbow',true);local c=C.cardDefinition(s,s.hand[1]);eq(c.exhaust,false)
 eq(data.cards.cards[#data.cards.cards].id,'burn');eq(data.cards.cards[#data.cards.cards-1].ethereal,true)
 eq(#base.cards.cards,#require('abyss_data').cards.cards)
 assert(not pcall(U.withCards,data),'duplicate registration must fail')
end)
test('all fourteen definitions have source ids Chinese text costs rarities and upgrades',function()
 local expected={barrage={1,'common'},compile_driver={1,'common'},go_for_the_eyes={0,'common'},boot_sequence={0,'uncommon'},charge_battery={1,'common'},glacier={2,'uncommon'},overclock={0,'uncommon'},turbo={0,'common'},core_surge={1,'rare'},rainbow={2,'rare'},hyperbeam={2,'rare'},reinforced_body={-1,'uncommon'},double_energy={1,'uncommon'},ftl={0,'uncommon'}}
 for id,v in pairs(expected)do local s=setup(id);local c=C.cardDefinition(s,s.hand[1]);eq(c.cost,v[1]);eq(c.rarity,v[2]);assert(c.sourceId and c.text and c.upgradeText and c.upgrade)end
end)
test('pure preparation freezes NORMAL modifiers while action count stays dynamic',function()
 local s=setup('barrage');s.player.statuses.strength=2
 local prepared=U.prepareEffect(s,{op='barrageDamage',value=4},s.enemies[1]);eq(prepared.normalAmount,6)
 s.player.statuses.strength=20;ch(s,'frost');ch(s,'plasma')
 local events,energy=#s.events,s.energy;local plan=U.planEffect(s,prepared,{target=s.enemies[1]})
 eq(#plan.top,2);eq(plan.top[1].op,'damage');eq(plan.top[1].normalAmount,6);eq(plan.top[1].value,4);eq(#s.events,events);eq(s.energy,energy)
 eq(U.planEffect(s,{op='compileDriverDraw',value=1},{}).top[1].value,2)
end)
test('pure FTL plan distinguishes TOP draw from BOTTOM ordinary damage',function()
 local s=setup('ftl');local effect=U.prepareEffect(s,{op='ftlDamage',value=5,threshold=3},s.enemies[1])
 local p=U.planEffect(s,effect,{cardsPlayedBefore=2});eq(p.top[1].op,'draw');eq(p.bottom[1].op,'damage');eq(p.bottom[1].normalAmount,5)
 eq(#U.planEffect(s,effect,{cardsPlayedBefore=3}).top,0)
 assert(not pcall(U.planEffect,s,effect,{}));eq(U.planEffect(s,{op='unknown'},{}),nil)
end)
test('pure X plan is lazy freezes per-hit block and never spends energy itself',function()
 local s=setup('reinforced_body');s.player.statuses.dexterity=2;s.player.statuses.frail=1
 local effect=U.prepareEffect(s,{op='xBlock',value=7});eq(effect.blockAmount,6)
 local p=U.planEffect(s,effect,{energyOnUse=2147483647});eq(#p.top,0);eq(#p.bottom,1);eq(p.bottom[1].op,'xBlockRounds');eq(p.bottom[1].remaining,2147483647);eq(p.bottom[1].value,6);eq(p.bottom[1].fixed,true);eq(p.consumeAllEnergy,true);eq(s.energy,3)
 eq(#U.planEffect(s,effect,{energyOnUse=0}).bottom,0);eq(U.planEffect(s,effect,{energyOnUse=3,freeToPlayOnce=true}).consumeAllEnergy,false)
 assert(not pcall(U.planEffect,s,effect,{energyOnUse=3,chemicalX=2}))
 eq(U.planEffect(s,{op='doubleEnergy',value=1},{}).top[1].value,3)
end)
for _,up in ipairs({false,true})do
 local tag=up and '+' or ''
 test('Barrage'..tag..' only filled slots create normal attack hits',function()
  local s=setup('barrage',up);ch(s,'frost');ch(s,'frost');s.player.statuses.strength=2
  local h=s.enemies[1].hp;play(s,'barrage',1);eq(s.energy,2);eq(s.enemies[1].hp,h-2*(up and 8 or 6));eq(s.player.block,0)
 end)
 test('Compile Driver'..tag..' damage then draw distinct orb types',function()
  local s=setup('compile_driver',up,12);ch(s,'frost');ch(s,'frost');ch(s,'plasma')
  local h,hand=s.enemies[1].hp,#s.hand;play(s,'compile_driver',1);eq(s.enemies[1].hp,h-(up and 10 or 7));eq(#s.hand,hand+1);eq(s.energy,2)
 end)
 test('Go for the Eyes'..tag..' attacking enemy gets Weak after damage',function()
  local s=setup('go_for_the_eyes',up);s.enemies[1].intents={{id='attack',effects={{op='damage',value=0}}}};s.enemies[1].intentIndex=1
  local h=s.enemies[1].hp;play(s,'go_for_the_eyes',1);eq(s.energy,3);eq(s.enemies[1].hp,h-(up and 4 or 3));eq(s.enemies[1].statuses.weak,up and 2 or 1)
 end)
 test('Boot Sequence'..tag..' innate zero-cost block and exhaust',function()
  local s=setup('boot_sequence',up);eq(C.cardDefinition(s,s.hand[1]).innate,true);play(s,'boot_sequence');eq(s.energy,3);eq(s.player.block,up and 13 or 10);eq(count(s,'exhaust','boot_sequence'),1)
 end)
 test('Charge Battery'..tag..' next recharge once with real endTurn',function()
  local s=setup('charge_battery',up);play(s,'charge_battery');eq(s.energy,2);eq(s.player.block,up and 10 or 7);eq(s.player.statuses.energized_blue,1)
  assert(C.endTurn(s));eq(s.energy,4);eq(s.player.statuses.energized_blue or 0,0)
  assert(C.endTurn(s));eq(s.energy,3)
 end)
 test('Glacier'..tag..' block before two Frost channels',function()
  local s=setup('glacier',up);play(s,'glacier');eq(s.energy,1);eq(s.player.block,up and 10 or 7);eq(#s.orbs.balls,2);eq(s.orbs.balls[1].kind,'frost');eq(s.orbs.balls[2].kind,'frost')
 end)
 test('Overclock'..tag..' draws before new Burn enters discard',function()
  local s=setup('overclock',up,12);local hand=#s.hand;play(s,'overclock');eq(s.energy,3);eq(#s.hand,hand-1+(up and 3 or 2));eq(count(s,'discard','burn'),1);eq(count(s,'hand','burn'),0)
 end)
 test('Turbo'..tag..' immediate energy then Void in discard',function()
  local s=setup('turbo',up);play(s,'turbo');eq(s.energy,up and 6 or 5);eq(count(s,'discard','void'),1)
 end)
 test('Core Surge'..tag..' ordinary damage then Artifact and exhaust',function()
  local s=setup('core_surge',up);local hp=s.enemies[1].hp;play(s,'core_surge',1);eq(s.energy,2);eq(s.enemies[1].hp,hp-(up and 15 or 11));eq(s.player.statuses.artifact,1);eq(count(s,'exhaust','core_surge'),1)
 end)
 test('Rainbow'..tag..' exact three-orb order and upgrade removes exhaust',function()
  local s=setup('rainbow',up);play(s,'rainbow');eq(s.energy,1);eq(#s.orbs.balls,3)
  for i,k in ipairs({'lightning','frost','dark'})do eq(s.orbs.balls[i].kind,k)end
  eq(count(s,'exhaust','rainbow'),up and 0 or 1);eq(count(s,'discard','rainbow'),up and 1 or 0)
 end)
 test('Hyperbeam'..tag..' area attack then signed focus loss',function()
  local s=setup('hyperbeam',up);local h1,h2=s.enemies[1].hp,s.enemies[2].hp;O.setFocus(s,2);play(s,'hyperbeam')
  eq(s.energy,1);eq(s.enemies[1].hp,h1-(up and 34 or 26));eq(s.enemies[2].hp,h2-(up and 34 or 26));eq(s.player.statuses.focus,-1)
 end)
 test('Reinforced Body'..tag..' X separate card-modified blocks consumes all energy',function()
  local s=setup('reinforced_body',up);s.player.statuses.dexterity=2;s.player.statuses.frail=1;play(s,'reinforced_body');eq(s.energy,0);eq(s.player.block,3*(up and 8 or 6))
 end)
 test('Double Energy'..tag..' doubles energy remaining after card payment',function()
  local s=setup('double_energy',up);play(s,'double_energy');eq(s.energy,up and 6 or 4);eq(count(s,'exhaust','double_energy'),1)
 end)
 test('FTL'..tag..' zero cost and conditional draw before damage',function()
  local s=setup('ftl',up,12);s.enemies[1].hp=1;s.enemies[2].hp=0;local hand=#s.hand;play(s,'ftl',1)
  eq(s.phase,'victory');eq(s.energy,3);eq(#s.hand,hand);eq(count(s,'discard','ftl'),1)
 end)
end
test('Barrage empty slots perform no hits but still pay and clean up',function()
 local s=setup('barrage');local h=s.enemies[1].hp;play(s,'barrage',1);eq(s.enemies[1].hp,h);eq(s.energy,2);eq(count(s,'discard','barrage'),1)
end)
test('Boot Sequence is guaranteed in opening hand beyond ordinary draw size',function()
 local deck={};for i=1,8 do deck[i]='strike' end;deck[9]='boot_sequence'
 local s=C.new(data,{seed=42,orbSlots=3,orbRandomSeed='17',deck=deck,enemies={'jaw_worm'}})
 assert(uid(s,'boot_sequence'));eq(#s.hand,5)
end)
test('Barrage stops later hits after Thorns kills player',function()
 local s=setup('barrage');for i=1,3 do ch(s,'frost')end;s.player.hp=1;s.enemies[1].statuses.thorns=2
 local h=s.enemies[1].hp;play(s,'barrage',1);eq(s.phase,'defeat');eq(s.enemies[1].hp,h-4)
end)
test('Compile Driver final kill clears conditional draw',function()
 local s=setup('compile_driver',false,12);ch(s,'frost');ch(s,'plasma');s.enemies[1].hp=1;s.enemies[2].hp=0;local hand=#s.hand
 play(s,'compile_driver',1);eq(s.phase,'victory');eq(#s.hand,hand-1)
end)
test('Go for the Eyes nonattack intent is unchanged and Artifact blocks attack debuff',function()
 local s=setup('go_for_the_eyes',true,2);s.enemies[1].intents={{id='buff',effects={{op='block',value=3}}}};s.enemies[1].intentIndex=1
 play(s,'go_for_the_eyes',1);eq(s.enemies[1].statuses.weak or 0,0)
 s.enemies[1].intents={{id='attack',effects={{op='damage',value=1}}}};s.enemies[1].statuses.artifact=1
 play(s,'go_for_the_eyes',1);eq(s.enemies[1].statuses.weak or 0,0);eq(s.enemies[1].statuses.artifact,0)
end)
test('Glacier full Frost slots evokes once per channel after card block',function()
 local s=setup('glacier');for i=1,3 do ch(s,'frost')end;play(s,'glacier');eq(s.player.block,17);eq(#s.orbs.balls,3)
end)
test('Hyperbeam Artifact prevents negative Focus and is consumed',function()
 local s=setup('hyperbeam');s.player.statuses.artifact=1;play(s,'hyperbeam');eq(s.player.statuses.focus,nil);eq(s.player.statuses.artifact,0)
end)
test('Hyperbeam final kill cancels Focus loss',function()
 local s=setup('hyperbeam');for _,e in ipairs(s.enemies)do e.hp=1 end;O.setFocus(s,2);play(s,'hyperbeam');eq(s.phase,'victory');eq(s.player.statuses.focus,2)
end)
test('Core Surge final kill cancels queued Artifact',function()
 local s=setup('core_surge');s.enemies[1].hp=1;s.enemies[2].hp=0;play(s,'core_surge',1);eq(s.phase,'victory');eq(s.player.statuses.artifact or 0,0)
end)
test('Reinforced Body with zero energy grants zero block',function()
 local s=setup('reinforced_body',true);s.energy=0;play(s,'reinforced_body');eq(s.player.block,0);eq(s.energy,0)
end)
test('Reinforced Body pays X then disposes before its three separate block actions',function()
 local s=setup('reinforced_body');local start=#s.events;play(s,'reinforced_body');local hits=0
 for i=start+1,#s.events do local event=s.events[i]
  if event.kind=='block' then
   hits=hits+1;eq(event.detail.amount,7);eq(event.frame.energy,0)
   local disposed=0;for _,c in ipairs(event.frame.discard)do if c.cardId=='reinforced_body' then disposed=disposed+1 end end
   eq(disposed,1)
  end
 end
 eq(hits,3);eq(s.player.block,21)
end)
test('Corrupted X block exhausts before its blocks then resolves the later FNP hook',function()
 local extra=require('abyss_warrior_exhaust_cards').withCards(data)
 local s=C.new(extra,{seed=42,orbSlots=3,orbRandomSeed='17',deck={'reinforced_body'},enemies={'jaw_worm'}})
 require('abyss_corruption').apply(s,1)
 require('abyss_actor').applyPower(s,s.player,'feel_no_pain',3,s.player)
 require('abyss_exhaust').rememberPower(s,'feel_no_pain')
 local start=#s.events;play(s,'reinforced_body');local exhausted,hits=false,0
 for i=start+1,#s.events do local event=s.events[i]
  if event.kind=='exhaust' and event.detail.cardId=='reinforced_body' then exhausted=true;eq(event.frame.energy,0)end
  if event.kind=='block' then assert(exhausted,'X block overtook UseCard exhaust');hits=hits+1;eq(event.detail.amount,hits<=3 and 7 or 3);eq(event.frame.energy,0)end
 end
 eq(hits,4);eq(s.player.block,24);eq(count(s,'exhaust','reinforced_body'),1)
end)
test('FTL threshold counts previous cards and resets each turn',function()
 local s=setup('ftl',false,15);local h=s.enemies[1].hp;s.enemies[1].hp=200
 for i=1,4 do local hand=#s.hand;play(s,'ftl',1);eq(#s.hand,hand-(i==4 and 1 or 0))end
 eq(s.enemies[1].hp,180);assert(C.endTurn(s));local hand=#s.hand;play(s,'ftl',1);eq(#s.hand,hand)
end)
test('upgraded FTL draws for four prior-card positions but not the fifth',function()
 local s=setup('ftl',true,15);s.enemies[1].hp=200
 for i=1,5 do local hand=#s.hand;play(s,'ftl',1);eq(#s.hand,hand-(i==5 and 1 or 0))end
 eq(s.enemies[1].hp,170)
end)
test('FTL history includes earlier skills and excludes a rejected attempt',function()
 local deck={'boot_sequence'};for i=1,12 do deck[#deck+1]='ftl'end
 local s=C.new(data,{seed=42,orbSlots=3,orbRandomSeed='17',deck=deck,enemies={'jaw_worm','jaw_worm'}})
 s.enemies[1].hp=200;play(s,'boot_sequence');eq(#s.cardsPlayedThisTurn,1)
 eq(C.play(s,uid(s,'ftl'),99),false);eq(#s.cardsPlayedThisTurn,1)
 for i=1,3 do local hand=#s.hand;play(s,'ftl',1);eq(#s.hand,hand-(i==3 and 1 or 0))end
 eq(#s.cardsPlayedThisTurn,4);eq(s.cardsPlayedThisTurn[1].type,'skill')
end)
test('Void is unplayable ethereal and draw costs energy without self-exhaust',function()
 local s=setup('void',false,8);eq(s.energy,0);eq(#s.hand,5);eq(#s.exhaust,0);eq(C.play(s,s.hand[1].uid),false)
 assert(C.endTurn(s));assert(#s.exhaust>=5);eq(s.energy,0)
end)
for _,up in ipairs({false,true})do test('Burn'..(up and '+' or '')..' endTurn damage consumes block and ignores Weak',function()
 local s=setup('burn',up);s.player.block=1;s.player.statuses.strength=40;s.player.statuses.weak=2;s.player.statuses.vulnerable=2
 -- Unit fixture: the ordinary cyclic fallback has a single harmless intent;
 -- disable source Jaw Worm AI before replacing its registered intent list.
 for _,e in ipairs(s.enemies)do e.ai=nil;e.intents={{id='buff',effects={{op='block',value=0}}}};e.intentIndex=1 end
 local hp=s.player.hp;eq(C.play(s,s.hand[1].uid),false);assert(C.endTurn(s));eq(s.player.hp,hp-(up and 3 or 1));eq(#s.exhaust,0)
end)end
test('late utility error restores energy piles orb state RNG and original references',function()
 local s=setup('rainbow');ch(s,'lightning');ch(s,'frost');ch(s,'dark')
 local c=s.catalog.cards.rainbow;c.effects[#c.effects+1]={op='gainFocus',value=2147483648}
 local hand,draw,discard,orbs,rng=s.hand,s.draw,s.discard,s.orbs,s.cardRandomRng;local counter=rng.counter
 local turnHistory,combatHistory=s.cardsPlayedThisTurn,s.cardsPlayedThisCombat
 local turnCount,combatCount=turnHistory and #turnHistory or 0,combatHistory and #combatHistory or 0
 assert(not pcall(C.play,s,uid(s,'rainbow')));eq(s.energy,3);eq(s.hand,hand);eq(s.draw,draw);eq(s.discard,discard);eq(s.orbs,orbs);eq(s.cardRandomRng,rng);eq(rng.counter,counter);eq(orbs.balls[1].kind,'lightning')
 eq(s.cardsPlayedThisTurn,turnHistory);eq(s.cardsPlayedThisCombat,combatHistory)
 eq(turnHistory and #turnHistory or 0,turnCount);eq(combatHistory and #combatHistory or 0,combatCount)
end)
print('DEFECT_UTILITY_BUILD_PASS '..n)
