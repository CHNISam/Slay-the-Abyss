package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,A=require('abyss_run'),require('abyss_combat'),require('abyss_actor')
local Data=require('abyss_data')
local n=0
local prototypes={}
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function same(a,b)
 eq(type(a),type(b));if type(a)~='table' then eq(a,b);return end
 for k,v in pairs(a) do same(v,b[k]) end
 for k in pairs(b) do assert(a[k]~=nil,'unexpected '..tostring(k)) end
end
local function test(name,fn) fn();n=n+1;print('ok basic five '..n..' - '..name) end
local function battle(ids,source,encounter)
 source=source or Data
 -- Each case receives its own untouched Run.new result. Cache the initial
 -- snapshot to avoid repeatedly constructing the unrelated encounter queue.
 if not prototypes[source] then prototypes[source]=Run.new(source,42) end
 local run=C.copy(prototypes[source])
 for _,id in ipairs(ids or {}) do assert(Run.obtainPotion(run,id)) end
 if encounter then assert(Run.startCombat(run,encounter)) else assert(Run.startRoomCombat(run,'normal')) end
 return run
end
local function refuse(run,slot,target,why)
 local before=C.copy(run);local combat,potions,deck=run.combat,run.potions,run.deck
 local ok,reason=Run.usePotion(run,slot,target);eq(ok,false);eq(reason,why)
 same(run,before);eq(run.combat,combat);eq(run.potions,potions);eq(run.deck,deck)
end
local function starter(cards)
 local d=C.copy(Data);d.cards.starter_deck.cards=cards;return d
end
local function use(run,slot,target)
 local energy,uid,deck=run.combat.energy,run.nextDeckUid,C.copy(run.deck)
 assert(Run.usePotion(run,slot,target));eq(run.combat.energy,energy);eq(run.nextDeckUid,uid);same(run.deck,deck)
 assert(not run.potions[slot]);refuse(run,slot,target,'empty_potion_slot')
end
test('five production bottles use normal obtain/view/use and preserve surrounding fixed slots',function()
 for _,id in ipairs({'swift_potion','weak_potion','fear_potion','ancient_potion','liquid_bronze'}) do
  local run=battle({'fire_potion',id,'block_potion'},nil,'louse_pair')
  local targeted=id=='weak_potion' or id=='fear_potion'
  local before=C.copy(run);local view=Run.potionView(run)[2]
  eq(view.id,id);eq(view.needTarget,targeted);assert(view.canUse);same(run,before)
  use(run,2,targeted and 2 or nil);eq(run.potions[1],'fire_potion');eq(run.potions[3],'block_potion')
 end
end)
test('Swift draws three actual top instances without spending source RNG when no shuffle is needed',function()
 local run=battle({'swift_potion'});local s=run.combat
 local hand=#s.hand;local expected={s.draw[#s.draw],s.draw[#s.draw-1],s.draw[#s.draw-2]}
 local rng=C.copy(s.shuffleRng);use(run,1);eq(#s.hand,hand+3);same(s.shuffleRng,rng)
 for i=1,3 do eq(s.hand[hand+i].uid,expected[i].uid) end
end)
test('Swift stops at ten, and a full hand still consumes exactly one bottle without drawing',function()
 local run=battle({'swift_potion','swift_potion'});local s=run.combat
 C.draw(s,4);eq(#s.hand,9);local rng=C.copy(s.shuffleRng)
 use(run,1);eq(#s.hand,10);same(s.shuffleRng,rng)
 local piles=C.copy({s.hand,s.draw,s.discard});use(run,2);same({s.hand,s.draw,s.discard},piles);same(s.shuffleRng,rng)
end)
test('Swift at exhausted piles causes no fatigue damage or RNG draw',function()
 local run=battle({'swift_potion'},starter({'defend','defend','defend','defend','defend'}))
 local s=run.combat;eq(#s.draw,0);eq(#s.discard,0);local before=C.copy(s)
 use(run,1);eq(#s.hand,5);eq(s.player.hp,before.player.hp);same(s.shuffleRng,before.shuffleRng)
end)
test('Swift respects No Draw applied by a real Battle Trance card and still consumes the bottle',function()
 local run=battle({'swift_potion'},starter({'battle_trance','defend','defend','defend','defend'}))
 local s=run.combat;local uid
 for _,card in ipairs(s.hand) do if card.cardId=='battle_trance' then uid=card.uid end end
 assert(Run.play(run,uid));assert(s.player.noDraw)
 local before=C.copy({s.hand,s.draw,s.discard,s.shuffleRng});use(run,1);same({s.hand,s.draw,s.discard,s.shuffleRng},before)
end)
test('Swift crosses an empty draw pile using the existing source shuffle and draws only available cards',function()
 local run=battle({'swift_potion'},starter({'defend','defend','defend','defend','defend','defend'}))
 local s=run.combat;local uid=s.hand[1].uid;assert(Run.play(run,uid));eq(#s.draw,1);eq(#s.discard,1)
 local top=s.draw[1].uid;local hand=#s.hand;local counter=s.shuffleRng.counter
 use(run,1);eq(#s.hand,hand+2);eq(s.hand[hand+1].uid,top);eq(s.hand[hand+2].uid,uid)
 -- DrawCardAction splits again after the singleton, scheduling the final empty shuffle.
 eq(#s.draw,0);eq(#s.discard,0);eq(s.shuffleRng.counter,counter+2)
end)
test('Weak and Fear select only the requested enemy, stack duration, and decay on the next round',function()
 for _,spec in ipairs({{'weak_potion','weak'},{'fear_potion','vulnerable'}}) do
  for _,initial in ipairs({0,2}) do
   local run=battle({spec[1]},nil,'louse_pair');local s=run.combat
   if initial>0 then C.addStatus(s.enemies[2],spec[2],initial) end
   use(run,1,2);eq(s.enemies[2].statuses[spec[2]],initial+3);eq(s.enemies[1].statuses[spec[2]] or 0,0)
   assert(not s.enemies[2][spec[2]..'JustApplied'])
   if spec[2]=='weak' then eq(A.attackAmount(s,s.enemies[2],s.player,8),6)
   else eq(A.attackAmount(s,s.player,s.enemies[2],8),12) end
   assert(Run.endTurn(run));eq(s.enemies[2].statuses[spec[2]],initial+2)
  end
 end
end)
test('enemy Artifact blocks Weak or Fear as a successful consumed use, then the next bottle applies three',function()
 for _,spec in ipairs({{'weak_potion','weak'},{'fear_potion','vulnerable'}}) do
  local run=battle({spec[1],spec[1]},nil,'louse_pair');local s=run.combat
  C.addStatus(s.enemies[2],'artifact',1);use(run,1,2)
  eq(s.enemies[2].statuses.artifact,0);eq(s.enemies[2].statuses[spec[2]] or 0,0)
  use(run,2,2);eq(s.enemies[2].statuses[spec[2]],3)
 end
end)
test('Ancient stacks one Artifact per bottle and blocks one debuff per stack without end-turn decay',function()
 local run=battle({'ancient_potion','ancient_potion'},nil,'cultist_solo');local s=run.combat
 use(run,1);use(run,2);eq(s.player.statuses.artifact,2)
 assert(not A.applyPower(s,s.player,'weak',3,s.enemies[1],true));eq(s.player.statuses.artifact,1)
 eq(s.player.statuses.weak or 0,0);assert(Run.endTurn(run));eq(s.player.statuses.artifact,1)
 assert(not A.applyPower(s,s.player,'frail',1,s.enemies[1],true));eq(s.player.statuses.artifact,0)
 assert(A.applyPower(s,s.player,'weak',3,s.enemies[1],true));eq(s.player.statuses.weak,3)
end)
test('Liquid Bronze stacks three persistent Thorns and retaliates on each blocked attack without recursion',function()
 local run=battle({'liquid_bronze','liquid_bronze'},nil,'cultist_solo');local s=run.combat
 use(run,1);eq(s.player.statuses.thorns,3);use(run,2);eq(s.player.statuses.thorns,6)
 C.addStatus(s.enemies[1],'thorns',20);s.player.block=20
 local hp,enemyHp=s.player.hp,s.enemies[1].hp
 C.damage(s,s.enemies[1],s.player,1);eq(s.player.hp,hp);eq(s.enemies[1].hp,enemyHp-6)
 C.damage(s,s.enemies[1],s.player,1);eq(s.player.hp,hp);eq(s.enemies[1].hp,enemyHp-12)
 assert(Run.endTurn(run));eq(s.player.statuses.thorns,6)
end)
test('target, phase, slot and overflow failures leave all Run fields and identities unchanged',function()
 for _,id in ipairs({'swift_potion','weak_potion','fear_potion','ancient_potion','liquid_bronze'}) do
  local run=battle({id},nil,'louse_pair')
  refuse(run,0,1,'invalid_potion_slot');refuse(run,1.5,1,'invalid_potion_slot')
  if id=='weak_potion' or id=='fear_potion' then
   refuse(run,1,nil,'invalid_target');refuse(run,1,3,'invalid_target')
   run.combat.enemies[2].escaped=true;refuse(run,1,2,'invalid_target')
   run.combat.enemies[2].escaped=false;run.combat.enemies[2].hp=0;refuse(run,1,2,'invalid_target')
  end
  run.combat.phase='enemy';refuse(run,1,1,'not_player_turn');run.combat.phase='player'
  run.phase='map';refuse(run,1,1,'not_in_combat')
 end
 for _,spec in ipairs({{'ancient_potion','artifact'},{'liquid_bronze','thorns'},{'weak_potion','weak'},{'fear_potion','vulnerable'}}) do
  local run=battle({spec[1]},nil,'louse_pair')
  local actor=spec[1]=='weak_potion' or spec[1]=='fear_potion'
  actor=actor and run.combat.enemies[2] or run.combat.player
  actor.statuses[spec[2]]=2147483647;refuse(run,1,2,'effect_overflow')
 end
end)
print('LUA_POTION_BASIC_FIVE_PASS '..n)
