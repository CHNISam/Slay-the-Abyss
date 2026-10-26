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
local function room(source)
 for n=1,100 do
  local seed=tostring(n);local q=Q.new(seed,2)
  if Q.peek(q,'normal')==source then
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
 local r=room('3 Byrds');local queue=r.encounters;local gen=r.roomGeneration
 local ok,reason=Run.startRoomCombat(r,'normal');eq(ok,false);eq(reason,'act_content_unavailable')
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
print('LUA_ACT2_ENEMIES_PASS '..count)
