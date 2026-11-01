package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Combat,Silent,Actors=require('abyss_combat'),require('abyss_silent'),require('abyss_actor')
local Cards,Discard,Random=require('abyss_silent_tactics_cards'),require('abyss_discard'),require('abyss_sts_random')
local data=Cards.withCardDefinitions(require('abyss_silent_attack_cards').withCardDefinitions(Silent.withFoundationCards(require('abyss_data'))))
local count,failed=0,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)
 local ok,reason=pcall(fn);count=count+1
 if ok then print('ok Silent tactics '..count..' - '..name)
 else failed=failed+1;print('not ok Silent tactics '..count..' - '..name..': '..tostring(reason))end
end
-- Constructed unit fixtures, not natural Run evidence: control piles and durable
-- targets to isolate card semantics; commands under test remain real Combat.
local function fresh(ids,handSize,two)
 local s=Combat.new(data,{deck=ids,enemies=two and {'jaw_worm','jaw_worm'}or{'jaw_worm'},seed=42,experimental=true})
 local all={};for _,name in ipairs({'hand','draw','discard','exhaust'})do for _,c in ipairs(s[name])do all[#all+1]=c end end
 table.sort(all,function(a,b)return a.uid<b.uid end)
 s.hand,s.draw,s.discard,s.exhaust={},{},{},{}
 for i,c in ipairs(all)do local pile=i<=(handSize or #all)and s.hand or s.draw;pile[#pile+1]=c end
 for _,enemy in ipairs(s.enemies)do enemy.hp,enemy.maxHp=300,300 end
 s.cardRandomRng=Random.fromSeed('123');return s,all
end
local function held(s,id)
 for _,c in ipairs(s.hand)do if c.cardId==id then return c end end
 error('not in hand: '..id)
end
local function play(s,id,target)
 local ok,reason=Combat.play(s,held(s,id).uid,target)
 assert(ok,'real play rejected: '..tostring(reason))
end
local function hits(s)
 local n=0;for _,event in ipairs(s.events)do if event.kind=='damage'and event.detail.source==s.player.id then n=n+1 end end;return n
end
local function card(id,up)return {cardId=id,upgraded=up}end
local function emptyQueue(s)eq(s.actionQueue,nil);eq(s.pendingPlay,nil);eq(s.pendingDiscard,nil)end

test('20 independent definitions have source identity, Chinese name and no duplicate',function()
 local ids={};local n=0
 for _,c in ipairs(data.cards.cards)do assert(not ids[c.id]);ids[c.id]=true;if c.sourceId and c.sts_name==c.sourceId and c.name then n=n+1 end end
 assert(n>=20);assert(not pcall(Cards.withCardDefinitions,data))
 local nextDraw;for _,power in ipairs(data.statuses.statuses)do if power.id=='draw_next_turn'then nextDraw=power end end
 eq(assert(nextDraw).priority,20,'DrawCardNextTurnPower priority')
end)
test('pure plans freeze construction damage but read Finisher history at execution',function()
 local s,all=fresh({'finisher','defend'});s.player.statuses.strength=2
 local prepared=Cards.prepareEffect(s,{op='finisherDamage',value=6},s.enemies[1]);eq(prepared.normalAmount,8)
 s.player.statuses.strength=99;s.cardsPlayedThisTurn={{type='attack'},{type='skill'},{type='attack'}}
 local plan=Cards.planEffect(s,prepared);eq(#plan.top,1);eq(plan.top[1].normalAmount,8)
end)
test('Piercing Wail freezes Artifact at card construction before action consumes it',function()
 local s=fresh({'piercing_wail'},1,true);s.enemies[1].statuses.artifact=1
 local prepared=Cards.prepareEffect(s,{op='piercingWail',value=6});s.enemies[1].statuses.artifact=nil
 local plan=Cards.planEffect(s,prepared);eq(#plan.top,3);eq(plan.top[1].value,-6)
 eq(plan.top[2].targetId,s.enemies[2].id);eq(plan.top[3].status,'shackled')
end)
test('Piercing Wail queues every Strength loss before any restoration Power',function()
 local s=fresh({'piercing_wail'},1,true)
 local plan=Cards.planEffect(s,Cards.prepareEffect(s,{op='piercingWail',value=6}))
 eq(#plan.top,4);eq(plan.top[1].status,'strength');eq(plan.top[2].status,'strength')
 eq(plan.top[3].status,'shackled');eq(plan.top[4].status,'shackled')
 eq(plan.top[1].targetId,plan.top[3].targetId);eq(plan.top[2].targetId,plan.top[4].targetId)
end)
test('random discard single candidate consumes zero calls, two consumes exactly one',function()
 local s,all=fresh({'defend','strike'});s.hand={all[1]}
 eq(Cards.randomDiscardUid(s),all[1].uid);eq(s.cardRandomRng.counter,0)
 s.hand=all;local twin=Random.cloneState(s.cardRandomRng);local i=Random.randomInt(twin,1)+1
 eq(Cards.randomDiscardUid(s),all[i].uid);eq(s.cardRandomRng.counter,1)
 s.hand={};eq(Cards.randomDiscardUid(s),nil);eq(s.cardRandomRng.counter,1)
end)
test('Glass Knife reduction includes in-use card and caps before later upgrade',function()
 local s,all=fresh({'glass_knife'});local c=all[1];s.hand={};s.cardInUse=c
 for _=1,5 do eq(Cards.reduceGlassKnife(s,c.uid,2),1)end
 eq(c.glassKnifeReduction,8);c.upgraded=true
 local def=Combat.copy(s.catalog.cards.glass_knife);def.effects=Combat.copy(def.upgrade.effects)
 eq(Cards.adaptDefinition(s,c,def).effects[1].value,4)
end)
for _,up in ipairs({false,true})do
 local suffix=' upgraded='..tostring(up)
 test('Piercing Wail Artifact blocks loss and no restoration is constructed'..suffix,function()
  local s=fresh({card('piercing_wail',up)},1,true);s.enemies[1].statuses.artifact=1
  play(s,'piercing_wail');eq(s.enemies[1].statuses.artifact or 0,0);eq(s.enemies[1].statuses.strength or 0,0)
  eq(s.enemies[1].statuses.shackled,nil);eq(s.enemies[2].statuses.strength,-(up and 8 or 6))
  eq(s.enemies[2].statuses.shackled,up and 8 or 6);eq(#s.exhaust,1)
  assert(Combat.endTurn(s));eq(s.enemies[2].statuses.strength or 0,0);eq(s.enemies[2].statuses.shackled,nil)
 end)
 test('All-Out Attack area hit then one true random manual discard'..suffix,function()
  local s=fresh({card('all_out_attack',up),'tactician','reflex'},3,true)
  local rng=Random.cloneState(s.cardRandomRng);local selected=Random.randomInt(rng,1)+2
  local id=s.hand[selected].cardId;play(s,'all_out_attack')
  eq(hits(s),2);eq(s.enemies[1].hp,300-(up and 14 or 10));eq(s.enemies[2].hp,s.enemies[1].hp)
  eq(s.discardedThisTurn,1);eq(s.cardRandomRng.counter,1);eq(s.energy,id=='tactician'and 3 or 2);emptyQueue(s)
 end)
 test('Blur keeps surviving Block exactly next turn, then expires'..suffix,function()
  local s=fresh({card('blur',up)});s.player.block=40
  play(s,'blur');local block=40+(up and 8 or 5)
  eq(s.player.block,block);eq(s.player.statuses.blur,1)
  assert(Combat.endTurn(s));assert(s.player.block>0,'Blur must preserve leftover block');eq(s.player.statuses.blur,nil)
  assert(Combat.endTurn(s));eq(s.player.block,0)
 end)
 test('Choke does not trigger itself, bypasses block on next card and expires at enemy start'..suffix,function()
  local s=fresh({card('choke',up),'defend'});play(s,'choke',1);eq(s.enemies[1].hp,288)
  s.enemies[1].block=99;play(s,'defend');eq(s.enemies[1].hp,288-(up and 5 or 3));eq(s.enemies[1].block,99)
  assert(Combat.endTurn(s));eq(s.enemies[1].statuses.choked,nil)
 end)
 test('Concentrate pauses before energy, validates token, resumes after true discard triggers'..suffix,function()
  local s,all=fresh({card('concentrate',up),'tactician','reflex','defend','strike'})
  play(s,'concentrate');assert(s.pendingDiscard);eq(s.energy,3);assert(s.actionQueue.paused)
  local token=s.pendingDiscard.token;local uids={all[2].uid,all[3].uid};if not up then uids[3]=all[4].uid end
  local ok=Combat.chooseDiscard(s,uids,token+1);eq(ok,false);eq(s.energy,3)
  assert(Combat.chooseDiscard(s,uids,token));eq(s.energy,6);eq(s.discardedThisTurn,up and 2 or 3);emptyQueue(s)
 end)
 test('Crippling Poison applies poison then Weak per enemy with independent Artifact charges'..suffix,function()
  local s=fresh({card('crippling_poison',up)},1,true);s.enemies[1].statuses.artifact=1
  play(s,'crippling_poison');eq(s.enemies[1].statuses.poison,nil);eq(s.enemies[1].statuses.weak,2)
  eq(s.enemies[2].statuses.poison,up and 7 or 4);eq(s.enemies[2].statuses.weak,2);eq(#s.exhaust,1)
 end)
 test('Dash gains modified Block before its NORMAL hit'..suffix,function()
  local s=fresh({card('dash',up)});s.player.statuses.dexterity=2;s.enemies[1].statuses.thorns=3
  local hp=s.player.hp;play(s,'dash',1);eq(s.player.block,(up and 13 or 10)+2-3);eq(s.player.hp,hp)
  eq(s.enemies[1].hp,300-(up and 13 or 10))
 end)
 test('Escape Plan actual Skill draw grants construction-modified Block'..suffix,function()
  local s=fresh({card('escape_plan',up),'defend'},1);s.player.statuses.dexterity=2
  play(s,'escape_plan');eq(#s.hand,1);eq(s.hand[1].cardId,'defend');eq(s.player.block,(up and 5 or 3)+2)
 end)
 test('Expertise draws to six or seven after played card leaves hand'..suffix,function()
  local ids={card('expertise',up)};for _=1,9 do ids[#ids+1]='defend'end
  local s=fresh(ids,3);play(s,'expertise');eq(#s.hand,up and 7 or 6);eq(s.energy,2)
 end)
 test('Finisher counts attacks before itself, excluding earlier skills'..suffix,function()
  local s=fresh({'slice','deflect',card('finisher',up)});play(s,'slice',1);play(s,'deflect');play(s,'finisher',1)
  eq(s.enemies[1].hp,300-6-(up and 8 or 6));eq(hits(s),2)
 end)
 test('Flechettes counts Skill cards in remaining hand, including unplayable ones'..suffix,function()
  local s=fresh({card('flechettes',up),'defend','tactician','strike'})
  play(s,'flechettes',1);eq(hits(s),2);eq(s.enemies[1].hp,300-2*(up and 6 or 4))
 end)
 test('Leg Sweep Weak before player modified Block'..suffix,function()
  local s=fresh({card('leg_sweep',up)});play(s,'leg_sweep',1)
  eq(s.enemies[1].statuses.weak,up and 3 or 2);eq(s.player.block,up and 14 or 11)
 end)
 test('Predator gives exactly two extra cards post-draw next turn then removes power'..suffix,function()
  local ids={card('predator',up)};for _=1,12 do ids[#ids+1]='defend'end
  local s=fresh(ids,1);play(s,'predator',1);eq(s.enemies[1].hp,300-(up and 20 or 15));eq(#s.hand,0)
  eq(s.player.statuses.draw_next_turn,2);assert(Combat.endTurn(s));eq(#s.hand,7);eq(s.player.statuses.draw_next_turn,nil)
 end)
 test('Skewer uses X snapshot and three separately modified NORMAL hits'..suffix,function()
  local s=fresh({card('skewer',up)});s.player.statuses.strength=2;play(s,'skewer',1)
  eq(s.energy,0);eq(hits(s),3);eq(s.enemies[1].hp,300-3*((up and 10 or 7)+2));emptyQueue(s)
 end)
 test('Terror payment upgrade, 99 Vulnerable and exhaust'..suffix,function()
  local s=fresh({card('terror',up)});play(s,'terror',1);eq(s.energy,up and 3 or 2)
  eq(s.enemies[1].statuses.vulnerable,99);eq(#s.exhaust,1)
 end)
 test('Die Die Die all enemies and exhaust'..suffix,function()
  local s=fresh({card('die_die_die',up)},1,true);play(s,'die_die_die')
  eq(s.enemies[1].hp,300-(up and 17 or 13));eq(s.enemies[2].hp,s.enemies[1].hp);eq(#s.exhaust,1)
 end)
 test('Glass Knife two hits lose exactly two base damage for its next use'..suffix,function()
  local s=fresh({card('glass_knife',up)});local c=s.hand[1];play(s,'glass_knife',1)
  eq(s.enemies[1].hp,300-2*(up and 12 or 8));eq(c.glassKnifeReduction,2)
  eq(Combat.cardDefinition(s,c).effects[1].value,(up and 12 or 8)-2)
  Combat.draw(s,1);play(s,'glass_knife',1);eq(c.glassKnifeReduction,4)
  eq(s.enemies[1].hp,300-2*(up and 12 or 8)-2*((up and 12 or 8)-2))
 end)
 test('Malaise X independent Strength and Weak applications spend energy'..suffix,function()
  local s=fresh({card('malaise',up)});s.enemies[1].statuses.artifact=1;play(s,'malaise',1)
  eq(s.energy,0);eq(s.enemies[1].statuses.strength or 0,0);eq(s.enemies[1].statuses.weak,up and 4 or 3);eq(#s.exhaust,1)
 end)
 test('Unload retains attacks, discards all other types and triggers manual hooks'..suffix,function()
  local s=fresh({card('unload',up),'tactician','reflex','strike'});s.player.noDraw=true
  play(s,'unload',1);eq(s.enemies[1].hp,300-(up and 18 or 14));eq(#s.hand,1);eq(s.hand[1].cardId,'strike')
  eq(s.discardedThisTurn,2);eq(s.energy,3);emptyQueue(s)
 end)
 test('Storm of Steel discards first then generates one matching-upgrade Shiv per original card'..suffix,function()
  local s=fresh({card('storm_of_steel',up),'tactician','defend','strike'});s.player.statuses.accuracy=4
  play(s,'storm_of_steel');eq(s.discardedThisTurn,3);eq(s.energy,3);eq(#s.hand,3)
  for _,c in ipairs(s.hand)do eq(c.cardId,'shiv');eq(c.upgraded,up);eq(c.shivAccuracyBonus,4)end
  play(s,'shiv',1);eq(s.enemies[1].hp,300-(up and 10 or 8));emptyQueue(s)
 end)
end

test('Concentrate with zero cards still grants two energy without a fake selection',function()
 local s=fresh({'concentrate'});play(s,'concentrate');eq(s.energy,5);eq(s.discardedThisTurn or 0,0);emptyQueue(s)
end)
test('Escape Plan does not grant Block for Attack, NoDraw or an empty draw action',function()
 for _,mode in ipairs({'attack','no_draw','empty'})do
  local s=fresh(mode=='empty'and{'escape_plan'}or{'escape_plan',mode=='attack'and'strike'or'defend'},1)
  if mode=='no_draw'then s.player.noDraw=true end
  play(s,'escape_plan');eq(s.player.block,0)
 end
end)
test('Finisher and Flechettes with no matching history or skills do no fake hit',function()
 for _,id in ipairs({'finisher','flechettes'})do local s=fresh({id});play(s,id,1);eq(hits(s),0);eq(s.enemies[1].hp,300)end
end)
test('zero X Malaise base does nothing, upgrade applies one each',function()
 for _,up in ipairs({false,true})do
  local s=fresh({card('malaise',up)});s.energy=0;play(s,'malaise',1)
  eq(s.enemies[1].statuses.strength or 0,up and -1 or 0);eq(s.enemies[1].statuses.weak or 0,up and 1 or 0)
 end
end)
test('All-Out Attack with one remaining card never draws discard RNG',function()
 local s=fresh({'all_out_attack','tactician'});play(s,'all_out_attack');eq(s.cardRandomRng.counter,0);eq(s.energy,3)
end)
test('Storm with Reflex generates before tail draw, obeys ten hand limit',function()
 local ids={'storm_of_steel','reflex'};for _=1,8 do ids[#ids+1]='defend'end
 local s=fresh(ids);play(s,'storm_of_steel');eq(s.discardedThisTurn,9);eq(#s.hand,10)
 local shivs=0;for _,c in ipairs(s.hand)do if c.cardId=='shiv'then shivs=shivs+1 end end;eq(shivs,9);emptyQueue(s)
end)
test('post-RNG chosen UID failure rolls back stream, original instances, actor resources and queue',function()
 local s,all=fresh({'all_out_attack','defend','strike'});local hand=s.hand;local statuses=s.player.statuses
 assert(require('abyss_effects').supported(Combat.cardDefinition(s,all[1]).effects),'All-Out Attack core dispatch required before rollback can be tested')
 local rng=s.cardRandomRng;local before=Random.snapshot(rng)
 local predicted=Random.cloneState(rng);local selected=Random.randomInt(predicted,1)+2
 all[selected].uid=0 -- fails only when the real random selection validates its chosen UID
 local ok,reason=pcall(Combat.play,s,all[1].uid);eq(ok,false);assert(tostring(reason):find('invalid Silent tactics UID',1,true),'fault must occur at the post-RNG UID guard: '..tostring(reason));
 local after=Random.snapshot(rng);eq(after.counter,before.counter);for i,word in ipairs(before.words)do eq(after.words[i],word)end;eq(s.hand,hand);eq(s.player.statuses,statuses)
 eq(s.hand[1],all[1]);eq(s.hand[2],all[2]);eq(s.cardRandomRng,rng);eq(s.energy,3);eq(s.enemies[1].hp,300);emptyQueue(s)
end)
test('Concentrate with one remaining card auto-discards and still grants full energy',function()
 local s=fresh({'concentrate','tactician'});play(s,'concentrate');eq(s.energy,6);eq(s.discardedThisTurn,1);emptyQueue(s)
end)
test('Choke application is an Artifact-blockable debuff',function()
 local s=fresh({'choke','defend'});s.enemies[1].statuses.artifact=1;play(s,'choke',1)
 eq(s.enemies[1].statuses.choked,nil);eq(s.enemies[1].statuses.artifact or 0,0)
 play(s,'defend');eq(s.enemies[1].hp,288)
end)
test('stacked Blur preserves block for exactly two future starts',function()
 local s=fresh({'blur','blur'});s.player.block=70;play(s,'blur');play(s,'blur');eq(s.player.statuses.blur,2)
 assert(Combat.endTurn(s));assert(s.player.block>0);eq(s.player.statuses.blur,1)
 assert(Combat.endTurn(s));assert(s.player.block>0);eq(s.player.statuses.blur,nil)
 assert(Combat.endTurn(s));eq(s.player.block,0)
end)
test('Storm of Steel zero original cards generates none and does not exhaust',function()
 local s=fresh({'storm_of_steel'});play(s,'storm_of_steel');eq(#s.hand,0);eq(#s.exhaust,0);eq(#s.discard,1);emptyQueue(s)
end)
test('Expertise with NoDraw never changes hand or invents draw callbacks',function()
 local s=fresh({'expertise','defend','strike'},1);s.player.noDraw=true;play(s,'expertise');eq(#s.hand,0);eq(#s.draw,2)
end)
test('X plans preserve freeToPlayOnce and reject unsupported Chemical X rather than guessing',function()
 local s=fresh({'skewer'});local prepared=Cards.prepareEffect(s,{op='skewer',value=7},s.enemies[1])
 local plan=Cards.planEffect(s,prepared,{energyOnUse=2,freeToPlayOnce=true});eq(plan.consumeAllEnergy,false)
 eq(plan.bottom[1].remaining,2);assert(not pcall(Cards.planEffect,s,prepared,{energyOnUse=2,chemicalX=2}))
end)
test('Malaise upgrade at 999 energy caps Strength but preserves raw 1000 Weak',function()
 for _,before in ipairs({0,500})do
  local s=fresh({card('malaise',true)});s.energy=999
  if before~=0 then s.enemies[1].statuses.strength=before end
  play(s,'malaise',1);eq(s.energy,0);eq(s.enemies[1].statuses.strength,math.max(-999,before-1000))
  eq(s.enemies[1].statuses.weak,1000)
 end
end)
print('SILENT_TACTICS_BUILD_RESULT '..(count-failed)..'/'..count)
assert(failed==0,'Silent tactics real integration missing or incorrect: '..failed..' cases')
print('SILENT_TACTICS_BUILD_PASS '..count)
