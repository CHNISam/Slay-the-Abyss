package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,Map,Nodes,H,Fairy=require('abyss_run'),require('abyss_combat'),require('abyss_map'),require('abyss_nodes'),require('abyss_relic_hooks'),require('abyss_potion_fairy')
local Data=require('abyss_data')
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function same(a,b,seen)
 eq(type(a),type(b));if type(a)~='table'then eq(a,b);return end
 seen=seen or {};if seen[a]==b then return end;seen[a]=b
 for k,v in pairs(a)do same(v,b[k],seen)end;for k in pairs(b)do assert(a[k]~=nil)end
end
do
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'TungstenRod'));r.phase='node';r.hp=1
 for _,id in ipairs({'energy_potion','fairy_in_a_bottle','fairy_in_a_bottle'})do assert(Run.obtainPotion(r,id))end
 assert(Run.eventDamage(r,1));eq(r.hp,1);eq(r.potions[2],'fairy_in_a_bottle')
 assert(Run.eventNormalDamage(r,2));eq(r.hp,24);eq(r.potions[1],'energy_potion');eq(r.potions[2],nil);eq(r.potions[3],'fairy_in_a_bottle')
 print('PASS Rod prevents the first fatal boundary, actual later fatal loss consumes only leftmost Fairy')
end
do
 local F=dofile('tests/lua/support/golden_idol_fixture.lua');local r,m,n=F.fixture(1)
 assert(Run.obtainRelic(r,'TungstenRod'));assert(Run.obtainPotion(r,'fairy_in_a_bottle'))
 assert(Nodes.enter(r,m,n));assert(Nodes.chooseEvent(r,'take'))
 local before,bm=C.copy(r),C.copy(m);local inventory,event,deck,misc=r.potions,r.nodeFlow.event,r.deck,r.miscRng
 local outside=Fairy.outside;local observed=false
 Fairy.outside=function(staged)local result=outside(staged);eq(staged.hp,24);eq(staged.potions[1],nil);observed=true;error('INJECTED_AFTER_ROD_FAIRY')end
 local ok,why=Nodes.chooseEvent(r,'damage');Fairy.outside=outside
 eq(ok,false);eq(why,'transaction_failed');assert(observed);same(r,before);same(m,bm)
 eq(r.potions,inventory);eq(r.nodeFlow.event,event);eq(r.deck,deck);eq(r.miscRng,misc)
 assert(Nodes.chooseEvent(r,'damage'));eq(r.hp,24);eq(r.potions[1],nil)
 print('PASS actual Nodes trap/Fairy late failure restores complete original event, inventory, deck and RNG owners')
end
do
 local r=Run.new(Data,42);assert(Run.obtainRelic(r,'TungstenRod'));assert(Run.startCombat(r,'cultist_solo'));assert(Run.endTurn(r))
 local before=C.copy(r);local battle,player,enemy,hand,rng=r.combat,r.combat.player,r.combat.enemies[1],r.combat.hand,r.miscRng
 local changed=H.hpChanged;local observed=false
 H.hpChanged=function(state,actor,hp)
  changed(state,actor,hp)
  if actor==state.player and hp>actor.hp then observed=true;assert(hp-actor.hp>0);error('INJECTED_AFTER_ROD_HP_NOTIFICATION')end
 end
 local called,why=pcall(Run.endTurn,r);H.hpChanged=changed
 assert(not called and observed and tostring(why):find('INJECTED_AFTER_ROD_HP_NOTIFICATION',1,true))
 same(r,before);eq(r.combat,battle);eq(r.combat.player,player);eq(r.combat.enemies[1],enemy);eq(r.combat.hand,hand);eq(r.miscRng,rng)
 assert(Run.endTurn(r));assert(r.combat.player.hp<before.combat.player.hp)
 print('PASS real public enemy-turn damage late failure preserves full Run and original battle graph, then retries')
end
do
 local r,m=Run.new(Data,42),Map.generate(Data,42);assert(Run.obtainRelic(r,'TungstenRod'));assert(Run.obtainPotion(r,'fire_potion'))
 r.hp=30;assert(Run.startCombat(r,'cultist_solo'));local old=r.combat;old.enemies[1].hp=1
 eq(C.damage(old,old.enemies[1],old.player,1,false),0);assert(Run.usePotion(r,1,1));eq(r.phase,'reward');assert(Run.leaveCombatRewards(r))
 local first=Map.available(m)[1];for _,n in ipairs(m.nodes)do if n.id==first.id then n.type='event';n.eventId='shining_light'end end
 local hp=r.hp;assert(Nodes.enter(r,m,first.id));local damage=r.nodeFlow.event.damage
 assert(Nodes.chooseEvent(r,'accept'));eq(r.hp,hp-(damage-1));eq(r.phase,'map')
 assert(Run.startCombat(r,'cultist_solo'));assert(r.combat~=old);hp=r.combat.player.hp
 eq(C.damage(r.combat,r.combat.enemies[1],r.combat.player,1,false),0);eq(r.combat.player.hp,hp)
 print('PASS same Rod survives actual victory/reward, real damage event and fresh second battle')
end
print('TUNGSTEN_ROD_TRANSACTIONS_PASS 4')
