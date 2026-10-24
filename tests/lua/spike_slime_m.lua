-- Independent A0 expectations: SpikeSlime_M / Slimed at the fixed source ledger.
package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local C,Run,Data=require('abyss_combat'),require('abyss_run'),require('abyss_data')
local Effects,Nodes,Map=require('abyss_effects'),require('abyss_nodes'),require('abyss_map')
local passed,failed=0,0
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function same(a,b) if type(a)~='table' then return eq(a,b) end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function test(name,fn) local ok,why=pcall(fn);if ok then passed=passed+1 else failed=failed+1 end;print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(why))) end
local function battle(ids,deck,seed) return C.new(Data,{enemies=ids or {'spike_slime_m'},deck=deck or {'defend'},seed=seed or 42}) end
local function observe(roll,fn)
 local old,calls=C.random,{};C.random=function(s,n) calls[#calls+1]=n;local v=old(s,n);return n==100 and roll+1 or v end
 local ok,why=pcall(fn,calls);C.random=old;assert(ok,why)
end
local function count(s,id) local n=0;for _,pile in ipairs({s.hand,s.draw,s.discard,s.exhaust})do for _,c in ipairs(pile)do if c.cardId==id then n=n+1 end end end;return n end
local function generate(s) C.applyEffects(s,{{op='makeTempCardInDiscard',card='slimed',value=1}},s.enemies[1],s.player) end

test('HP28-32 is sampled before opening main roll and shuffle',function()
 observe(0,function(calls) local s=battle(nil,{'strike','defend','bash','anger'});eq(#calls,5);for i,v in ipairs({5,100,4,3,2})do eq(calls[i],v)end;eq(C.intent(s,1).id,'spike_slime_m_1') end)
 local seen={};for seed=1,64 do local e=battle(nil,nil,seed).enemies[1];assert(e.hp>=28 and e.hp<=32);eq(e.hp,e.maxHp);seen[e.hp]=true end
 for hp=28,32 do assert(seen[hp],'missing HP '..hp) end
end)
for _,r in ipairs({0,29,30,99})do test('opening decision boundary '..r,function()
 observe(r,function() local s=battle();eq(C.intent(s,1).id,r<30 and 'spike_slime_m_1' or 'spike_slime_m_2')end)
end)end
test('all 900 controlled rolls and histories follow 30/70 with no third identical move',function()
 local AI=require('abyss_spike_slime_m_ai');local ai={tackleIntent='t',frailIntent='f',tackleCutoff=30}
 local cases={{nil,nil},{'t',nil},{'f',nil},{'t','t'},{'f','f'},{'t','f'},{'f','t'},{nil,'t'},{nil,'f'}}
 for _,h in ipairs(cases)do for r=0,99 do
  local want=r<30 and 't' or 'f';if h[1]=='t' and h[2]=='t' then want='f' elseif h[1]=='f' and h[2]=='f' then want='t' end
  eq(AI.choose(ai,h[1],h[2],r),want,'history/roll')
 end end
end)
test('two attacks force Frail then attack; each real action rolls exactly once',function()
 observe(0,function(calls) local s=battle();local initial=#calls
  for turn,want in ipairs({'spike_slime_m_1','spike_slime_m_2','spike_slime_m_1'})do
   local before=#calls;assert(C.endTurn(s));eq(C.intent(s,1).id,want)
   local rolls=0;for i=before+1,#calls do if calls[i]==100 then rolls=rolls+1 end end;eq(rolls,1)
  end
  eq(s.player.hp,64);eq(count(s,'slimed'),2);eq(s.player.statuses.frail,1);assert(#calls>initial)
 end)
end)
test('two Frail actions force attack and existing duration does not refresh justApplied',function()
 observe(99,function() local s=battle();assert(C.endTurn(s));eq(C.intent(s,1).id,'spike_slime_m_2');eq(s.player.statuses.frail,1)
 assert(C.endTurn(s));eq(C.intent(s,1).id,'spike_slime_m_1');eq(s.player.statuses.frail,1);eq(s.player.hp,80)
 assert(C.endTurn(s));eq(s.player.hp,72);eq(s.player.statuses.frail,0);eq(count(s,'slimed'),1) end)
end)
test('Tackle damages before generating one temporary card and before the next enemy',function()
 observe(0,function() local s=battle({'spike_slime_m','sneaky_gremlin'});local start=#s.events+1;assert(C.endTurn(s));local attack,created,nextAttack
 for i=start,#s.events do local e=s.events[i];if e.kind=='damage' and e.detail.source==s.enemies[1].id then attack=i elseif e.kind=='cards_created' then created=i;eq(e.detail.cardId,'slimed');eq(e.detail.amount,1);eq(e.frame.player.hp,72) elseif e.kind=='damage' and e.detail.source==s.enemies[2].id then nextAttack=i end end
 assert(attack and created and nextAttack and attack<created and created<nextAttack);eq(count(s,'slimed'),1);eq(s.player.hp,63)
 end)
end)
test('fully blocked Tackle still creates one Slimed',function()
 observe(0,function() local s=battle();C.block(s,s.player,8,true);assert(C.endTurn(s));eq(s.player.hp,80);eq(count(s,'slimed'),1)end)
end)
test('queued creation survives dead attacker with a teammate but final kill cancels it and roll',function()
 for _,solo in ipairs({false,true})do observe(0,function(calls)
  local s=battle(solo and {'spike_slime_m'} or {'spike_slime_m','shield_gremlin'});s.enemies[1].hp=1;C.addStatus(s.player,'thorns',1);local before=#calls
  assert(C.endTurn(s));eq(s.enemies[1].hp,0);eq(count(s,'slimed'),solo and 0 or 1);eq(s.phase,solo and 'victory' or 'player')
  local rolls=0;for i=before+1,#calls do if calls[i]==100 then rolls=rolls+1 end end;eq(rolls,solo and 0 or 1)
 end)end
end)
test('pre-turn poison death never attacks generates or rolls',function()
 observe(0,function(calls) local s=battle({'spike_slime_m','shield_gremlin'});C.addStatus(s.enemies[1],'poison',99);local before=#calls;assert(C.endTurn(s));eq(s.player.hp,80);eq(count(s,'slimed'),0);eq(#calls,before)end)
end)
test('public dead source remains unable to generate a card',function()
 local s=battle({'spike_slime_m','shield_gremlin'});s.enemies[1].hp=0;local before=C.copy(s);generate(s);same(s,before)
end)
test('a genuinely drawn Slimed costs one and exhausts without an enemy target',function()
 local s=battle({'gremlin_nob'},{'defend'});generate(s);assert(C.endTurn(s));local slimed
 for _,c in ipairs(s.hand)do if c.cardId=='slimed' then slimed=c end end;assert(slimed,'must draw generated Slimed')
 local hp,block,seed=s.player.hp,s.player.block,s.seed;local strength=s.enemies[1].statuses.strength or 0
 assert(C.canPlay(s,slimed.uid));assert(C.play(s,slimed.uid));eq(s.energy,2);eq(s.exhaust[1],slimed);eq(s.player.hp,hp);eq(s.player.block,block);eq(s.seed,seed);eq(s.enemies[1].statuses.strength or 0,strength)
end)
test('zero energy rejects Slimed atomically and Dazed is still unplayable',function()
 local s=battle({'cultist'},{'slimed','dazed'});s.energy=0;local before=C.copy(s)
 for _,c in ipairs(s.hand)do local ok,why=C.play(s,c.uid);eq(ok,false);eq(why,c.cardId=='slimed' and 'insufficient_energy' or 'unplayable_card')end;same(s,before)
end)
test('unplayed Slimed discards and reshuffles instead of ethereal exhaust',function()
 local s=battle({'cultist'},{'slimed'});local card=s.hand[1];assert(C.endTurn(s));eq(#s.exhaust,0);eq(#s.hand,1);eq(s.hand[1],card)
end)
test('no arbitrary empty effects become legal through the Slimed exception',function()
 eq(Effects.supported({}),false)
 for _,change in ipairs({{id='other'},{type='skill'},{cost=0},{cost=2},{exhaust=false},{ethereal=true},{upgrade={cost=0}},{effects={junk=true}},{effects={{op='block',value=1}}},{effects={{op='not_real'}}}})do
  local s=battle({'cultist'},{'slimed'});for k,v in pairs(change)do s.catalog.cards.slimed[k]=v end
  local before=C.copy(s);eq(C.play(s,s.hand[1].uid),false);same(s,before)
 end
 local s=battle();s.catalog.cards.defend.effects={};eq(C.play(s,s.hand[1].uid),false)
end)
test('status type remains excluded from rewards and shop even with a supported payload',function()
 local data=C.copy(Data)
 local found=false;for _,c in ipairs(data.cards.cards)do if c.id=='slimed' then found=true end end;assert(found)
 for _,c in ipairs(data.cards.cards)do if c.id=='slimed' then c.effects={{op='block',value=1}} else c.rarity='basic' end end
 local r=Run.new(data,42);assert(Run.startCombat(r,'cultist_solo'));C.applyEffects(r.combat,{{op='damage',value=999}},r.combat.player,r.combat.enemies[1]);assert(Run.finishCombat(r));eq(#Run.rewardOptions(r),0);assert(Run.claimCardReward(r,0))
 local map=Map.generate(data,42);for _=1,17 do local available=Map.available(map);for _,node in ipairs(available)do if node.type=='shop' then assert(Nodes.enter(r,map,node.id));eq(#r.nodeFlow.cards,0);return end end;assert(Map.choose(map,available[1].id))end;error('expected shop fixture')
end)
test('camp and upgrade shrine reject Slimed without spending their choice',function()
 assert(battle().catalog.cards.slimed)
 local r=Run.new(Data,42);r.deck={{uid=1,cardId='slimed',upgraded=false},{uid=2,cardId='strike',upgraded=false}}
 local map=Map.generate(Data,42)
 r.phase='node';r.nodeFlow={type='camp',complete=false,upgradesLeft=1};local choices=Nodes.view(r,map).node.upgradeCards;eq(#choices,1);eq(choices[1].cardId,'strike')
 local before=C.copy(r);local ok,why=Nodes.upgrade(r,1);eq(ok,false);eq(why,'card_not_upgradeable');same(r,before)
 r.nodeFlow={type='event',complete=false,event={id='upgrade_shrine'}};choices=Nodes.view(r,map).node.upgradeCards;eq(#choices,1);eq(choices[1].cardId,'strike')
 before=C.copy(r);ok,why=Nodes.upgradeEvent(r,1);eq(ok,false);eq(why,'card_not_upgradeable');same(r,before)
end)
test('new enemy instances do not inherit history from another Spike M',function()
 observe(0,function()local s=battle({'spike_slime_m','spike_slime_m'});local AI=require('abyss_enemy_ai');AI.advance(s,s.enemies[1],C.random);AI.advance(s,s.enemies[1],C.random);eq(C.intent(s,1).id,'spike_slime_m_2');eq(C.intent(s,2).id,'spike_slime_m_1');eq(s.enemies[2].spikeLast,nil)end)
end)
test('temporary Slimed never reaches permanent deck or the next combat',function()
 local r=Run.new(Data,42);r.floor=5;assert(Run.startCombat(r,'medium_slimes'));local deck=C.copy(r.deck);generate(r.combat);eq(count(r.combat,'slimed'),1);same(r.deck,deck)
 C.applyEffects(r.combat,{{op='damageAll',value=999}},r.combat.player);assert(Run.finishCombat(r));for _,id in ipairs(Run.rewardOptions(r))do assert(id~='slimed')end;assert(Run.claimCardReward(r,0));assert(Run.startCombat(r,'medium_slimes'));eq(count(r.combat,'slimed'),0);same(r.deck,deck)
end)
test('failing player effect rolls back Spike decision history and RNG',function()
 local s=battle();s.catalog.cards.defend.effects={{op='draw',value=1},{op='gainStatus',status='missing',value=1}};local before=C.copy(s);assert(not pcall(C.play,s,s.hand[1].uid,1));same(s,before)
end)
print('SPIKE_SLIME_M '..passed..' passed; '..failed..' failed');assert(failed==0)
