local C=require('abyss_combat')
local A=require('abyss_actor')
local AI=require('abyss_enemy_ai')
local Run=require('abyss_run')
local Q=require('abyss_encounter_queue')
local Data=require('abyss_data')
local count=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();count=count+1;print('ok act2 '..count..' - '..name)end
local function battle(ids)return C.new(Data,{enemies=ids,deck={},seed=42,hp=500,maxHp=500})end
local function intent(e)return e.intents[e.intentIndex].id end
local function roll(n)return function(_,max)eq(max,100);return n+1 end end
local function room(source,tier)
 tier=tier or 'normal'
 for n=1,100 do
  local seed=tostring(n);local q=Q.new(seed,2)
  if Q.peek(q,tier)==source then
   local r=Run.new(Data,seed,{experimental=true,campaign=true})
   r.act,r.floor,r.encounters=2,18,q
   return r
  end
 end
 error('no independent source seed '..source)
end
test('source room creates Spheric Guardian with A0 powers, no first-act substitute',function()
 local r=room('Spheric Guardian');local before=#r.encounters.normal
 local ok,reason=Run.startRoomCombat(r,'normal');assert(ok,reason)
 local s=r.combat;local e=s.enemies[1]
 eq(e.definitionId,'spheric_guardian');eq(e.hp,20);eq(e.block,40)
 eq(e.statuses.artifact,3);eq(e.statuses.barricade,1);eq(intent(e),'activate')
 eq(#r.encounters.normal,before-1);eq(r.encounterSource,'Spheric Guardian')
 local counter,hp=s.aiRng.counter,s.player.hp
 assert(C.endTurn(s));eq(e.block,65);eq(intent(e),'frail_attack');eq(s.aiRng.counter,counter+1)
 assert(C.endTurn(s));eq(s.player.hp,hp-10);eq(s.player.statuses.frail,5);eq(e.block,65);eq(intent(e),'slam')
 assert(C.endTurn(s));eq(s.player.hp,hp-30);eq(intent(e),'harden')
 assert(C.endTurn(s));eq(s.player.hp,hp-40);eq(e.block,80);eq(intent(e),'slam')
end)
test('Centurion protects a live ally and changes Fury choice after ally dies',function()
 local s=battle({'centurion','mystic'});local e,h=s.enemies[1],s.enemies[2]
 assert(e.hp>=76 and e.hp<=80 and h.hp>=48 and h.hp<=56)
 AI.initialize(s,e,roll(65));eq(intent(e),'protect')
 C.applyEffects(s,e.intents[e.intentIndex].effects,e,s.player);eq(h.block,15);eq(e.block,0)
 AI.advance(s,e,roll(65));eq(intent(e),'protect')
 AI.advance(s,e,roll(65));eq(intent(e),'slash')
 h.hp=0;AI.advance(s,e,roll(99));eq(intent(e),'fury')
 local hp=s.player.hp;C.applyEffects(s,e.intents[e.intentIndex].effects,e,s.player);eq(hp-s.player.hp,18)
end)
test('Mystic heals only live allies and buffs in source actor order',function()
 local s=battle({'centurion','mystic'});local e,h=s.enemies[1],s.enemies[2]
 e.hp=e.maxHp-16;AI.initialize(s,h,roll(99));eq(intent(h),'heal')
 C.applyEffects(s,h.intents[h.intentIndex].effects,h,s.player);eq(e.hp,e.maxHp)
 AI.advance(s,h,roll(0));eq(intent(h),'buff')
 C.applyEffects(s,h.intents[h.intentIndex].effects,h,s.player);eq(e.statuses.strength,2);eq(h.statuses.strength,2)
 e.hp=0;h.hp=h.maxHp-20;AI.advance(s,h,roll(99));eq(intent(h),'heal')
 C.applyEffects(s,h.intents[h.intentIndex].effects,h,s.player);eq(e.hp,0);eq(h.hp,h.maxHp-4)
end)
test('Mystic A0 history forbids three consecutive attacks, buffs, or heals',function()
 local s=battle({'mystic'});local h=s.enemies[1]
 AI.initialize(s,h,roll(40));eq(intent(h),'attack')
 AI.advance(s,h,roll(40));eq(intent(h),'attack')
 AI.advance(s,h,roll(40));eq(intent(h),'buff')
 AI.initialize(s,h,roll(0));AI.advance(s,h,roll(0));eq(intent(h),'buff')
 AI.advance(s,h,roll(0));eq(intent(h),'attack')
 h.hp=h.maxHp-30;AI.initialize(s,h,roll(0));AI.advance(s,h,roll(0));eq(intent(h),'heal')
 AI.advance(s,h,roll(99));eq(intent(h),'attack')
end)
test('unimplemented chapter rooms reject without consuming queue or generation',function()
 local r=room('Spheric Guardian');r.floor=33;r.bossInitialization={profile='source-history',bossList={'Automaton','Automaton'}}
 local queue=r.encounters;local gen=r.roomGeneration
 local ok,reason=Run.startRoomCombat(r,'boss');eq(ok,false);eq(reason,'act_content_unavailable')
 eq(r.encounters,queue);eq(r.roomGeneration,gen);eq(r.phase,'map')
end)
test('Spheric constructor does not spend HP RNG, Taskmaster spends both source range draws',function()
 local streams=Run.roomStreams({runSeed='42'},18)
 local s=C.new(Data,{enemies={'spheric_guardian','taskmaster'},deck={},seed=42,roomSeed=streams.seed,roomStreams=streams})
 eq(s.monsterHpRng.counter,2);eq(s.aiRng.counter,2)
end)
test('Taskmaster keeps queued Wound after lethal retaliation while allies survive',function()
 local s=battle({'taskmaster','cultist'});local e=s.enemies[1]
 e.hp=1;A.applyPower(s,s.player,'thorns',1,s.player)
 assert(C.endTurn(s));eq(e.hp,0)
 local wounds=0;for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,c in ipairs(pile)do if c.cardId=='wound'then wounds=wounds+1 end end end
 eq(wounds,1)
end)
test('Book starts with two stabs, grows only multistabs and gives one Wound for each HP loss',function()
 local s=battle({'book_of_stabbing'});local e=s.enemies[1]
 AI.initialize(s,e,roll(15));eq(intent(e),'multi_stab');eq(e.intents[e.intentIndex].effects[1].times,2)
 AI.advance(s,e,roll(15));eq(e.intents[e.intentIndex].effects[1].times,3)
 AI.advance(s,e,roll(15));eq(intent(e),'big_stab')
 AI.advance(s,e,roll(0));eq(intent(e),'multi_stab');eq(e.intents[e.intentIndex].effects[1].times,4)
 s.player.block=7;local hp=s.player.hp
 assert(C.endTurn(s));eq(hp-s.player.hp,17)
 local wounds=0;for _,pile in ipairs({s.hand,s.draw,s.discard})do for _,c in ipairs(pile)do if c.cardId=='wound'then wounds=wounds+1 end end end
 eq(wounds,3)
end)
test('Snake Plant Malleable queues escalating blocks behind all card hits, resets after its turn',function()
 local s=C.new(Data,{enemies={'snake_plant'},deck={'twin_strike'},seed=42,hp=500,maxHp=500})
 local e=s.enemies[1];local hp=e.hp;assert(C.play(s,s.hand[1].uid,1))
 eq(e.hp,hp-10);eq(e.block,7);eq(e.statuses.malleable,5)
 A.resetBlock(s,e);C.damage(s,s.player,e,1,true);eq(e.block,0);eq(e.statuses.malleable,5)
 assert(C.endTurn(s));eq(e.statuses.malleable,3)
end)
test('Snake Plant A0 attack cutoff and no-three-attacks/no-two-spores constraints',function()
 local s=battle({'snake_plant'});local e=s.enemies[1]
 AI.initialize(s,e,roll(64));eq(intent(e),'chomp')
 AI.advance(s,e,roll(64));eq(intent(e),'chomp')
 AI.advance(s,e,roll(64));eq(intent(e),'spores')
 AI.advance(s,e,roll(99));eq(intent(e),'chomp')
 AI.initialize(s,e,roll(65));eq(intent(e),'spores')
end)
test('Champ uses exact half-HP threshold, clears debuffs, and spaces Execute two moves apart',function()
 local s=battle({'champ'});local e=s.enemies[1]
 e.hp=210;AI.initialize(s,e,roll(99));eq(intent(e),'heavy_slash')
 e.hp=209;AI.advance(s,e,roll(99));eq(intent(e),'anger')
 A.applyPower(s,e,'weak',3,s.player);A.applyPower(s,e,'strength',-3,s.player)
 C.applyEffects(s,e.intents[e.intentIndex].effects,e,s.player)
 eq(e.statuses.weak,nil);eq(e.statuses.strength,6)
 AI.advance(s,e,roll(99));eq(intent(e),'execute')
 AI.advance(s,e,roll(99));eq(intent(e),'heavy_slash')
 AI.advance(s,e,roll(99));eq(intent(e),'face_slap')
 AI.advance(s,e,roll(99));eq(intent(e),'execute')
end)
test('Champ fourth selected move Taunts and defensive stance grants end-turn Metallicize',function()
 local s=battle({'champ'});local e=s.enemies[1]
 AI.initialize(s,e,roll(15));eq(intent(e),'defensive_stance')
 assert(C.endTurn(s));eq(e.block,20);eq(e.statuses.metallicize,5)
 AI.initialize(s,e,roll(99));AI.advance(s,e,roll(99));AI.advance(s,e,roll(99))
 AI.advance(s,e,roll(99));eq(intent(e),'taunt')
end)
test('Chosen A0 opens Poke then Hex, alternates debuffs and attacks at source cutoffs',function()
 local s=battle({'chosen'});local e=s.enemies[1]
 AI.initialize(s,e,roll(99));eq(intent(e),'poke')
 AI.advance(s,e,roll(99));eq(intent(e),'hex')
 AI.advance(s,e,roll(49));eq(intent(e),'debilitate')
 AI.advance(s,e,roll(39));eq(intent(e),'zap')
 AI.advance(s,e,roll(50));eq(intent(e),'drain')
 AI.advance(s,e,roll(40));eq(intent(e),'poke')
end)
test('Hex is Artifact-blockable and inserts Dazed below the top without drawing on an empty pile',function()
 local s=C.new(Data,{enemies={'chosen'},deck={'defend','strike'},seed=42})
 local e=s.enemies[1];AI.advance(s,e,roll(99))
 A.applyPower(s,s.player,'artifact',1,s.player)
 C.applyEffects(s,e.intents[e.intentIndex].effects,e,s.player);eq(s.player.statuses.hex,nil);eq(s.player.statuses.artifact,0)
 C.applyEffects(s,e.intents[e.intentIndex].effects,e,s.player);eq(s.player.statuses.hex,1)
 local before=s.cardRandomRng.counter;local uid
 for _,c in ipairs(s.hand)do if c.cardId=='defend'then uid=c.uid end end
 assert(C.play(s,uid));eq(#s.draw,1);eq(s.draw[1].cardId,'dazed');eq(s.cardRandomRng.counter,before)
 local r=C.new(Data,{enemies={'chosen'},deck={'defend'},seed=42})
 A.applyPower(r,r.player,'hex',1,r.enemies[1])
 r.draw={{cardId='strike',uid=100},{cardId='bash',uid=101}};before=r.cardRandomRng.counter
 assert(C.play(r,r.hand[1].uid));eq(r.draw[#r.draw].cardId,'bash');eq(r.cardRandomRng.counter,before+1)
end)
test('Shelled Parasite starts with 14 armor/block and opening Boolean consumes a second AI draw',function()
 local streams=Run.roomStreams({runSeed='42'},18)
 local s=C.new(Data,{enemies={'shelled_parasite'},deck={},seed=42,roomSeed=streams.seed,roomStreams=streams})
 local e=s.enemies[1];eq(e.statuses.plated_armor,14);eq(e.block,14);eq(s.aiRng.counter,2)
 assert(intent(e)=='double_strike' or intent(e)=='life_suck')
 e.block=0;e.hp=e.maxHp-20
 for i,v in ipairs(e.intents)do if v.id=='life_suck'then e.intentIndex=i end end
 s.player.block=7;local hp=e.hp;assert(C.endTurn(s));eq(e.hp,hp+3);eq(e.block,14)
end)
test('Parasite armor break interrupts to Stunned then uses Fell history for its bounded reroll',function()
 local s=battle({'shelled_parasite'});local e=s.enemies[1];e.block=0
 for _=1,14 do C.damage(s,s.player,e,1) end
 eq(e.statuses.plated_armor,0);eq(intent(e),'stunned')
 local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp)
 for i,v in ipairs(e.intents)do if v.id=='fell'then e.intentIndex=i end end
 local seen={};AI.advance(s,e,function(_,max)seen[#seen+1]=max;return 1 end)
 eq(table.concat(seen,','),'100,80');eq(intent(e),'double_strike')
end)
test('Byrd Flight halves all queued attack hits before grounding; Headbutt sets Airborne without a roll',function()
 local s=C.new(Data,{enemies={'byrd'},deck={},seed=42,hp=500,maxHp=500})
 local e=s.enemies[1];eq(e.statuses.flight,3)
 local hp=e.hp;C.applyEffects(s,{{op='damage',value=6,times=3}},s.player,e)
 eq(e.hp,hp-9);eq(e.statuses.flight,0);eq(intent(e),'stunned')
 assert(C.endTurn(s));eq(intent(e),'headbutt')
 local before=s.seed;assert(C.endTurn(s));eq(intent(e),'airborne');eq(s.seed,before)
 assert(C.endTurn(s));eq(e.statuses.flight,3);assert(intent(e)~='airborne')
end)
test('Flight ignores fully blocked and fixed hits and refreshes only before enemy action',function()
 local s=battle({'byrd'});local e=s.enemies[1];e.block=20
 C.damage(s,s.player,e,6);eq(e.statuses.flight,3)
 e.block=0;C.damage(s,s.player,e,6,true);eq(e.statuses.flight,3)
 C.damage(s,s.player,e,6);eq(e.statuses.flight,2)
 assert(C.endTurn(s));eq(e.statuses.flight,3)
 local r=room('3 Byrds');assert(Run.startRoomCombat(r,'normal'));eq(#r.combat.enemies,3)
 for _,b in ipairs(r.combat.enemies)do eq(b.definitionId,'byrd');eq(b.statuses.flight,3)end
end)
test('Snecko opens Confusion, follows 40 cutoff and no three Bites, and Artifact blocks Confusion',function()
 local s=battle({'snecko'});local e=s.enemies[1];eq(intent(e),'glare')
 A.applyPower(s,s.player,'artifact',1,s.player)
 assert(C.endTurn(s));eq(s.player.statuses.confusion,nil);eq(s.player.statuses.artifact,0)
 AI.initialize(s,e,roll(99));AI.advance(s,e,roll(40));eq(intent(e),'bite')
 AI.advance(s,e,roll(40));eq(intent(e),'bite');AI.advance(s,e,roll(40));eq(intent(e),'tail')
 AI.advance(s,e,roll(39));eq(intent(e),'tail')
end)
test('Confusion randomizes only drawn nonnegative-cost cards and persists through turn reset',function()
 local s=battle({'snecko'});local e=s.enemies[1]
 A.applyPower(s,s.player,'confusion',1,e)
 s.draw={{cardId='dazed',uid=200},{cardId='whirlwind',uid=201},{cardId='defend',uid=202},{cardId='strike',uid=203}}
 local before=s.cardRandomRng.counter
 local drawn=C.draw(s,4);eq(s.cardRandomRng.counter,before+2)
 for i=1,2 do local cost=C.cardDefinition(s,drawn[i]).cost;assert(cost>=0 and cost<=3);eq(drawn[i].combatCost or C.combatBaseCost(s,drawn[i]),cost)end
 eq(C.cardDefinition(s,drawn[3]).costMode,'all_energy');eq(C.cardDefinition(s,drawn[4]).cost,-2)
 local cost=C.cardDefinition(s,drawn[1]).cost;A.endTurn(s,s.player);eq(C.cardDefinition(s,drawn[1]).cost,cost)
end)
test('two Thieves uses distinct Mugger HP/damage/block and exact sound/talk AI entropy',function()
 local r=room('2 Thieves');r.gold=100;assert(Run.startRoomCombat(r,'normal'))
 local s=r.combat;local e=s.enemies[2]
 eq(s.enemies[1].definitionId,'looter');eq(e.definitionId,'mugger');assert(e.hp>=48 and e.hp<=52)
 eq(e.intents[2].effects[1].value,16);eq(e.intents[3].effects[1].value,11)
 local before=s.aiRng.counter;assert(C.endTurn(s));eq(s.aiRng.counter,before+2);eq(s.player.gold,70)
 before=s.aiRng.counter;assert(C.endTurn(s));eq(s.aiRng.counter,before+4);eq(s.player.gold,40)
 eq(e.stolenGold,30);before=s.aiRng.counter
 C.damage(s,s.player,e,999,true);eq(s.aiRng.counter,before+1);eq(s.stolenGoldReward,30)
end)
test('Gremlin Leader source formation draws two minions with replacement from misc',function()
 local r=room('Gremlin Leader','elite');assert(Run.startRoomCombat(r,'elite'))
 local s=r.combat;eq(#s.enemies,3);eq(r.miscRng.counter,2)
 local leader=s.enemies[3];eq(leader.definitionId,'gremlin_leader');assert(leader.hp>=140 and leader.hp<=148)
 for i=1,2 do eq(s.enemies[i].statuses.minion,1);eq(s.enemies[i].minion,true)end
 local b={misc={integer=function(lo,hi)eq(lo,0);eq(hi,7);return 0 end}}
 local t=C.new(Data,{deck={},seed=42,sourceEncounter='Gremlin Leader',encounterBoundary=b})
 eq(t.enemies[1].definitionId,'mad_gremlin');eq(t.enemies[2].definitionId,'mad_gremlin')
end)
test('Leader Encourages allies with Strength3 Block6, itself only Strength, then rallies real empty slots',function()
 local r=room('Gremlin Leader','elite');assert(Run.startRoomCombat(r,'elite'));local s=r.combat;local leader=s.enemies[3]
 AI.initialize(s,leader,roll(0));eq(intent(leader),'encourage')
 C.applyEffects(s,leader.intents[leader.intentIndex].effects,leader,s.player)
 eq(leader.statuses.strength,3);eq(leader.block,0)
 for i=1,2 do eq(s.enemies[i].statuses.strength,3);eq(s.enemies[i].block,6);s.enemies[i].hp=0 end
 AI.advance(s,leader,roll(0));eq(intent(leader),'rally')
 local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp)
 local living=0;for _,e in ipairs(s.enemies)do if e~=leader and A.isActive(e)then living=living+1;eq(e.statuses.minion,1);assert(e.id~=s.enemies[1].id or e.hp>0)end end
 eq(living,2)
 C.damage(s,s.player,leader,999,true);eq(C.outcome(s),'victory')
 for _,e in ipairs(s.enemies)do if e.hp>0 then eq(e.escaped,true)end end
end)
test('Leader one-ally repeat exclusions consume bounded source rerolls',function()
 local r=room('Gremlin Leader','elite');assert(Run.startRoomCombat(r,'elite'))
 local s=r.combat;local leader=s.enemies[3];s.enemies[1].hp=0
 for i,v in ipairs(leader.intents)do if v.id=='rally'then leader.intentIndex=i end end
 local calls={};AI.advance(s,leader,function(_,max)calls[#calls+1]=max;return max==100 and 1 or max end)
 eq(table.concat(calls,','),'100,50');eq(intent(leader),'stab')
 calls={};AI.advance(s,leader,function(_,max)calls[#calls+1]=max;return max==100 and 100 or 51 end)
 eq(table.concat(calls,','),'100,81');eq(intent(leader),'encourage')
end)
print('LUA_ACT2_ENEMIES_PASS '..count)
