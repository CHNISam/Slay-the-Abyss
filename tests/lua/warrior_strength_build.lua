package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C=require('abyss_combat')
local Q=require('abyss_action_queue')
local S=require('abyss_warrior_strength_cards')
local W=require('abyss_warrior_cards')
local E=require('abyss_warrior_exhaust_cards')
local Data=require('abyss_data')
local base=E.withCards(W.withFoundationCards(Data))
local function freezeSource(root)
 local saved={}
 local function visit(t)
  if saved[t] then return end
  local values={};saved[t]=values
  for k,v in pairs(t) do values[k]=v;if type(v)=='table' then visit(v) end end
 end
 visit(root)
 return function()
  for t,values in pairs(saved) do
   for k,v in pairs(values) do assert(t[k]==v,'source data mutated') end
   for k,v in pairs(t) do assert(values[k]==v,'source data mutated') end
  end
 end
end
local unchanged=freezeSource(base)
local data=S.withCards(base)
local n=0
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();n=n+1;print('ok warrior strength '..n..' - '..name) end
local function inst(id,up) return {cardId=id,upgraded=up} end
local function held(s,id) for _,c in ipairs(s.hand) do if c.cardId==id then return c end end;error('missing '..id) end
local function play(s,id,target) local ok,why=C.play(s,held(s,id).uid,target);assert(ok,why) end
local function battle(deck)
 local s=C.new(data,{seed=42,deck=deck or {},enemies={'cultist'},cardRandomSeed='42'})
 s.enemies[1].hp=200;s.enemies[1].maxHp=200;return s
end
local function arrange(s,ids)
 local all={};for _,p in ipairs({s.hand,s.draw,s.discard,s.exhaust}) do for _,c in ipairs(p) do all[#all+1]=c end end
 s.hand={};s.draw={};s.discard={};s.exhaust={}
 for _,id in ipairs(ids) do
  local found;for i,c in ipairs(all) do if c.cardId==id then found=table.remove(all,i);break end end
  s.hand[#s.hand+1]=assert(found)
 end
 for _,c in ipairs(all) do s.draw[#s.draw+1]=c end
end
local function rawDefinition(s,card)
 local d=C.copy(s.catalog.cards[card.cardId]);if card.upgraded then for k,v in pairs(d.upgrade or {}) do d[k]=C.copy(v) end end
 return d
end
local function findDef(d,id) for _,c in ipairs(d.cards.cards) do if c.id==id then return c end end end
test('helper prepares nine build cards and Wound while preserving six existing cards',function()
 local missingCards,missingPowers=0,0
 for _,id in ipairs({'heavy_blade','perfected_strike','combust','rupture','brutality','berserk','spot_weakness','pummel','power_through','wound'}) do
  if not findDef(base,id) then missingCards=missingCards+1 end
 end
 local basePowers={};for _,d in ipairs(base.statuses.statuses) do basePowers[d.id]=true end
 for _,id in ipairs({'rupture','combust','brutality','berserk'}) do if not basePowers[id] then missingPowers=missingPowers+1 end end
 eq(#data.cards.cards,#base.cards.cards+missingCards);eq(#data.statuses.statuses,#base.statuses.statuses+missingPowers)
 local seen={};for _,d in ipairs(data.cards.cards) do assert(not seen[d.id],d.id);seen[d.id]=true end
 seen={};for _,d in ipairs(data.statuses.statuses) do assert(not seen[d.id],d.id);seen[d.id]=true end
 unchanged()
 for _,id in ipairs({'bloodletting','hemokinesis','uppercut','seeing_red','disarm','bludgeon'}) do
  local count=0;for _,c in ipairs(data.cards.cards) do if c.id==id then count=count+1 end end
  eq(count,1);eq(findDef(data,id).cost,findDef(base,id).cost)
 end
 eq(base.experimentalWarriorStrength,nil);eq(findDef(data,'heavy_blade').experimental,true)
 eq(pcall(S.withCards,data),false);eq(findDef(data,'wound').cost,-2)
end)
test('Heavy Blade component multiplies signed Strength before normal modifiers',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('heavy_blade',up)});local c=held(s,'heavy_blade')
  s.player.statuses.strength=3
  local d=S.adaptDefinition(s,c,rawDefinition(s,c));eq(C.attackAmount(s,s.player,s.enemies[1],d.effects[1].value),up and 29 or 23)
  s.player.statuses.weak=1;s.enemies[1].statuses.vulnerable=1
  eq(C.attackAmount(s,s.player,s.enemies[1],d.effects[1].value),up and 32 or 25)
  s.player.statuses.strength=-4;s.player.statuses.weak=0;s.enemies[1].statuses.vulnerable=0
  d=S.adaptDefinition(s,c,rawDefinition(s,c));eq(C.attackAmount(s,s.player,s.enemies[1],d.effects[1].value),up and 0 or 2)
 end
end)
test('Perfected Strike component counts tags in exactly three piles including the pre-use self',function()
 local s=battle({'perfected_strike','strike','strike','twin_strike','pommel_strike','bludgeon'})
 arrange(s,{'perfected_strike','strike','twin_strike','pommel_strike','bludgeon'})
 local p=held(s,'perfected_strike');local d=S.adaptDefinition(s,p,rawDefinition(s,p));eq(d.effects[1].value,16)
 local exhausted=table.remove(s.draw);s.exhaust[1]=exhausted
 d=S.adaptDefinition(s,p,rawDefinition(s,p));eq(d.effects[1].value,14)
 for i,c in ipairs(s.hand) do if c==p then table.remove(s.hand,i);break end end;s.cardInUse=p
 d=S.adaptDefinition(s,p,rawDefinition(s,p));eq(d.effects[1].value,12)
 eq(s.catalog.cards.perfected_strike.effects[1].value,6)
end)
test('Combust component stores damage intensity separately from number of HP-loss applications',function()
 local s=battle();assert(S.applyPower(s,'combust',5));assert(S.applyPower(s,'combust',7))
 eq(s.player.statuses.combust,12);eq(s.player.combustHpLoss,2)
 local p=S.planHook(s,'combust','turn_end');eq(#p.bottom,2)
 eq(p.bottom[1].effect.op,'loseHp');eq(p.bottom[1].effect.value,2)
 eq(p.bottom[2].effect.op,'combustDamage');eq(p.bottom[2].effect.value,12)
 s.enemies[1].hp=0;eq(#S.planHook(s,'combust','turn_end').bottom,0)
end)
test('Rupture component checks positive self-owner HP loss and returns TOP Strength',function()
 local s=battle();assert(S.applyPower(s,'rupture',2))
 local p=S.planHpLost(s,s.player,3);eq(#p.top,1);eq(p.top[1].effect.value,2);eq(p.top[1].effect.status,'strength')
 eq(#p.bottom,0);eq(#S.planHpLost(s,s.player,0).top,0)
 eq(#S.planHpLost(s,nil,3).top,0);eq(#S.planHpLost(s,s.enemies[1],3).top,0)
end)
test('Brutality and Berserk component hooks preserve source phases and pure Queue data',function()
 local s=battle();assert(S.applyPower(s,'brutality',2));assert(S.applyPower(s,'berserk',1))
 eq(#S.planHook(s,'brutality','turn_start').bottom,0)
 local b=S.planHook(s,'brutality','turn_start_post_draw');eq(b.bottom[1].effect.op,'draw');eq(b.bottom[2].effect.op,'loseHp')
 eq(b.bottom[1].effect.value,2);eq(b.bottom[2].effect.value,2)
 local energy=S.planHook(s,'berserk','turn_start');eq(energy.bottom[1].effect.op,'energy')
 Q.start(s,b.bottom);local seen={}
 assert(Q.run(s,{effect=function(state,a) seen[#seen+1]=a.effect.op;C.applyEffects(state,{a.effect},state.player,state.player) end}))
 eq(table.concat(seen,','),'draw,loseHp');eq(s.player.hp,s.player.maxHp-2)
end)
print('WARRIOR_STRENGTH_COMPONENT_PASS'..n)
for _,id in ipairs({'bloodletting','hemokinesis','uppercut','seeing_red','disarm','bludgeon'}) do
 test('existing '..id..' retains source base and upgrade behavior through real play',function()
  for _,up in ipairs({false,true}) do
   local s=battle({inst(id,up)});local hp=s.player.hp;play(s,id,1)
   if id=='bloodletting' then eq(s.player.hp,hp-3);eq(s.energy,up and 6 or 5)
   elseif id=='hemokinesis' then eq(s.player.hp,hp-2);eq(s.enemies[1].hp,up and 180 or 185)
   elseif id=='uppercut' then eq(s.enemies[1].hp,187);eq(s.enemies[1].statuses.weak,up and 2 or 1);eq(s.enemies[1].statuses.vulnerable,up and 2 or 1)
   elseif id=='seeing_red' then eq(s.energy,up and 5 or 4);eq(#s.exhaust,1)
   elseif id=='disarm' then eq(s.enemies[1].statuses.strength,up and -3 or -2);eq(#s.exhaust,1)
   else eq(s.enemies[1].hp,up and 158 or 168);eq(s.energy,0) end
  end
 end)
end
test('real Heavy Blade preview and damage apply triple or quintuple Strength',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('heavy_blade',up)});s.player.statuses.strength=3
  local c=held(s,'heavy_blade');eq(C.cardPreview(s,c,1)[1].high,up and 29 or 23)
  play(s,'heavy_blade',1);eq(s.enemies[1].hp,up and 171 or 177);eq(s.player.statuses.strength,3)
 end
end)
test('real Perfected Strike snapshots tagged pre-use deck including itself',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('perfected_strike',up),'strike','twin_strike','pommel_strike','bludgeon'})
  play(s,'perfected_strike',1);eq(s.enemies[1].hp,up and 182 or 186)
 end
end)
test('real Pummel delivers four or five NORMAL hits and exhausts',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('pummel',up)});s.enemies[1].statuses.thorns=1;local hp=s.player.hp
  play(s,'pummel',1);eq(s.enemies[1].hp,up and 190 or 192);eq(s.player.hp,hp-(up and 5 or 4));eq(#s.exhaust,1)
 end
end)
test('real Power Through creates Wounds in hand before granting Block',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('power_through',up)});play(s,'power_through')
  eq(#s.hand,2);eq(s.hand[1].cardId,'wound');eq(s.hand[2].cardId,'wound');eq(s.player.block,up and 20 or 15)
  eq(C.canPlay(s,s.hand[1].uid),false)
  local block;for _,e in ipairs(s.events) do if e.kind=='block' then block=e end end
  assert(block);eq(#block.frame.hand,2)
 end
end)
test('real Power Through fills the last hand slot and sends only overflow Wound to discard',function()
 local deck={'power_through'};for _=1,9 do deck[#deck+1]='strike' end
 local s=battle(deck);arrange(s,deck);play(s,'power_through')
 eq(#s.hand,10);local handWounds=0;for _,c in ipairs(s.hand) do if c.cardId=='wound' then handWounds=handWounds+1 end end
 eq(handWounds,1);local discardWounds=0;for _,c in ipairs(s.discard) do if c.cardId=='wound' then discardWounds=discardWounds+1 end end
 eq(discardWounds,1);eq(s.player.block,15)
end)
test('real Spot Weakness follows nonnegative attack intent and its source upgrade amount',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('spot_weakness',up)});play(s,'spot_weakness',1)
  eq(s.player.statuses.strength or 0,0);assert(C.endTurn(s));play(s,'spot_weakness',1)
  eq(s.player.statuses.strength,up and 4 or 3)
 end
end)
test('real Rupture gains Strength from Bloodletting and preserves the energy tail',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('rupture',up),'bloodletting'});play(s,'rupture');local hp=s.player.hp
  play(s,'bloodletting');eq(s.player.hp,hp-3);eq(s.player.statuses.strength,up and 2 or 1);eq(s.energy,4)
 end
end)
test('real Rupture from Hemokinesis does not modify its already captured damage',function()
 local s=battle({'rupture','hemokinesis'});play(s,'rupture');play(s,'hemokinesis',1)
 eq(s.player.statuses.strength,1);eq(s.enemies[1].hp,185)
end)
test('real Combust stacks HP-loss count and pure damage and triggers Rupture',function()
 local s=battle({'rupture','combust',inst('combust',true)});play(s,'rupture');play(s,'combust');play(s,'combust')
 local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-2);eq(s.player.statuses.strength,1)
 eq(s.enemies[1].hp,188);eq(s.player.combustHpLoss,2)
end)
test('real Brutality draws after normal opening draw and only then loses HP',function()
 local deck={'brutality'};for _=1,6 do deck[#deck+1]='strike' end
 local s=battle(deck);arrange(s,{'brutality'});play(s,'brutality');local hp=s.player.hp
 assert(C.endTurn(s));eq(#s.hand,6);eq(s.player.hp,hp-1)
 local loss;for _,e in ipairs(s.events) do if e.kind=='hp_loss' then loss=e end end
 assert(loss);eq(#loss.frame.hand,6)
end)
test('real Berserk applies Vulnerable immediately and energy starting next turn',function()
 for _,up in ipairs({false,true}) do
  local s=battle({inst('berserk',up)});play(s,'berserk');eq(s.energy,3);eq(s.player.statuses.vulnerable,up and 1 or 2)
  assert(C.endTurn(s));eq(s.energy,4)
 end
 local s=battle({'berserk'});s.player.statuses.artifact=1;play(s,'berserk')
 eq(s.player.statuses.vulnerable or 0,0);eq(s.player.statuses.berserk,1);eq(s.player.statuses.artifact,0)
end)
test('lethal Bloodletting stops queued Rupture Strength and energy without disposing the card',function()
 local s=battle({'rupture','bloodletting'});play(s,'rupture');s.player.hp=3
 local c=held(s,'bloodletting');local energy=s.energy;play(s,'bloodletting')
 eq(s.phase,'defeat');eq(s.player.statuses.strength or 0,0);eq(s.energy,energy);eq(s.cardInUse,c);eq(#s.discard,0)
end)
test('lethal Combust HP loss stops its enemy damage and Rupture application',function()
 local s=battle({'rupture','combust'});play(s,'rupture');play(s,'combust');s.player.hp=1
 assert(C.endTurn(s));eq(s.phase,'defeat');eq(s.enemies[1].hp,200);eq(s.player.statuses.strength or 0,0)
end)
for _,firstPower in ipairs({'brutality','demon_form'}) do
 test('post-draw lethal Brutality respects acquisition order when '..firstPower..' was acquired first',function()
  local deck={'brutality','demon_form'};for _=1,6 do deck[#deck+1]='strike' end
  local s=battle(deck);arrange(s,{'brutality','demon_form'});s.energy=10
  local second=firstPower=='brutality' and 'demon_form' or 'brutality'
  play(s,firstPower);play(s,second);s.player.hp=1
  assert(C.endTurn(s));eq(s.player.hp,0);eq(s.phase,'defeat')
  eq(#s.hand,6) -- The source extra draw still completes before lethal HP loss.
  eq(s.player.statuses.strength or 0,firstPower=='demon_form' and 2 or 0)
 end)
end
for _,firstPower in ipairs({'metallicize','combust'}) do
 test('Metallicize pre-card block precedes Combust end-turn HP loss even with '..firstPower..' first',function()
  local s=battle({'metallicize','combust'})
  local second=firstPower=='metallicize' and 'combust' or 'metallicize'
  play(s,firstPower);play(s,second);local first=#s.events+1;local hp=s.player.hp
  assert(C.endTurn(s));local bi,li,loss
  for i=first,#s.events do
   local e=s.events[i]
   if e.kind=='block' and e.detail.source==s.player.id and not bi then bi=i end
   if e.kind=='hp_loss' and not li then li=i;loss=e end
  end
  assert(bi and li and bi<li);eq(loss.frame.player.block,3)
  eq(s.player.hp,hp-1);eq(s.enemies[1].hp,195)
 end)
end
test('Berserk energy is available before post-draw Brutality regardless of acquiring it later',function()
 local s=battle({'brutality','berserk'});play(s,'brutality');play(s,'berserk')
 local first=#s.events+1;assert(C.endTurn(s));local loss
 for i=first,#s.events do if s.events[i].kind=='hp_loss' then loss=s.events[i];break end end
 assert(loss);eq(loss.frame.energy,4);eq(s.energy,4)
end)
print('WARRIOR_STRENGTH_BUILD_PASS'..n)
