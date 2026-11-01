local C=require('abyss_combat')
local Run=require('abyss_run')
local Q=require('abyss_encounter_queue')
local Bosses=require('abyss_act3_bosses')
local A=require('abyss_actor')
local D=require('abyss_data')
local count=0
local function eq(a,b,label)assert(a==b,(label or 'value')..': '..tostring(a)..' ~= '..tostring(b))end
local function test(name,fn)fn();count=count+1;print('ok Donu/Deca '..count..' - '..name)end
local function battle(ids)return C.new(D,{enemies=ids or {'deca','donu'},deck={},seed=42,hp=500,maxHp=500})end
local function intent(e)return e.intents[e.intentIndex].id end
local function room()
 local run=Run.new(D,'42',{experimental=true,campaign=true})
 run.act,run.floor,run.encounters=3,50,Q.new('42',3)
 run.bossInitialization,run.encounters=Q.initializeBoss(run.encounters,{CROW=true})
 eq(run.bossInitialization.bossList[1],'Donu and Deca')
 assert(Run.startRoomCombat(run,'boss'))
 return run,run.combat
end
local function created(s,id)
 local n=0
 for _,event in ipairs(s.events)do
  if event.kind=='cards_created' and event.detail.cardId==id then n=n+event.detail.amount end
 end
 return n
end
test('source encounter keeps Deca before Donu and refuses other tiers',function()
 local encounter=assert(Bosses.resolve('Donu and Deca','boss'))
 eq(encounter.enemies[1],'deca');eq(encounter.enemies[2],'donu')
 eq(Bosses.resolve('Donu and Deca','normal'),nil);eq(Bosses.resolve('Unknown Act3 Boss','boss'),nil)
end)
test('normal third-act room creates both at 250 HP with two Artifact and two opening rolls',function()
 local run,s=room();eq(run.encounterSource,'Donu and Deca')
 for _,e in ipairs(s.enemies)do eq(e.hp,250);eq(e.maxHp,250);eq(e.statuses.artifact,2)end
 eq(s.enemies[1].definitionId,'deca');eq(s.enemies[2].definitionId,'donu')
 eq(s.monsterHpRng.counter,2);eq(s.aiRng.counter,2)
 eq(intent(s.enemies[1]),'beam');eq(intent(s.enemies[2]),'circle')
end)
test('first turn resolves Deca two hits and two Dazed before Donu buffs both by three',function()
 local s=battle();local deca,donu=s.enemies[1],s.enemies[2];local first=#s.events+1
 assert(C.endTurn(s));eq(s.player.hp,480);eq(created(s,'dazed'),2)
 eq(deca.statuses.strength,3);eq(donu.statuses.strength,3)
 local hits,creation,buff={},nil,nil
 for i=first,#s.events do
  local event=s.events[i]
  if event.kind=='damage' and event.detail.source==deca.id then hits[#hits+1]=i end
  if event.kind=='cards_created' and event.detail.cardId=='dazed'then creation=i end
  if event.kind=='status' and event.detail.status=='strength'then buff=buff or i end
 end
 eq(#hits,2);assert(hits[2]<creation and creation<buff)
 eq(intent(deca),'square');eq(intent(donu),'beam')
end)
test('second turn gives both fixed 16 Block before Donu attacks twice for 13',function()
 local s=battle();assert(C.endTurn(s));local deca,donu=s.enemies[1],s.enemies[2]
 deca.statuses.dexterity=99;deca.statuses.frail=1
 donu.statuses.dexterity=99;donu.statuses.frail=1
 local hp=s.player.hp;assert(C.endTurn(s));eq(s.player.hp,hp-26)
 eq(deca.block,16);eq(donu.block,16);eq(created(s,'dazed'),2)
 eq(intent(deca),'beam');eq(intent(donu),'circle')
end)
test('four-turn source alternation retains base damage, scaling, and live group roll count',function()
 local _,s=room();s.player.hp=500;s.player.maxHp=500
 local hp={480,454,428,396}
 for turn=1,4 do
  assert(C.endTurn(s));eq(s.player.hp,hp[turn]);eq(s.aiRng.counter,2+turn*2)
 end
 eq(created(s,'dazed'),4);eq(s.enemies[1].statuses.strength,6);eq(s.enemies[2].statuses.strength,6)
end)
test('A0 Artifact blocks exactly two debuffs without affecting the other Boss',function()
 local s=battle();local deca,donu=s.enemies[1],s.enemies[2]
 for n=1,2 do
  eq(A.applyPower(s,deca,'weak',2,s.player),false);eq(deca.statuses.artifact or 0,2-n)
  eq(deca.statuses.weak or 0,0);eq(donu.statuses.artifact,2)
 end
 eq(A.applyPower(s,deca,'weak',2,s.player),true);eq(deca.statuses.weak,2)
end)
test('Donu buffs only living group members and continues after Deca is killed',function()
 local s=battle();local deca,donu=s.enemies[1],s.enemies[2]
 C.damage(s,s.player,deca,250,true);assert(C.endTurn(s))
 eq(deca.statuses.strength or 0,0);eq(donu.statuses.strength,3);eq(s.player.hp,500)
 assert(C.endTurn(s));eq(s.player.hp,474);eq(C.outcome(s),nil)
end)
test('Deca protects only living members and keeps alternating without Donu',function()
 local s=battle();local deca,donu=s.enemies[1],s.enemies[2]
 C.damage(s,s.player,donu,250,true);assert(C.endTurn(s));eq(s.player.hp,480)
 assert(C.endTurn(s));eq(deca.block,16);eq(donu.block,0)
 assert(C.endTurn(s));eq(s.player.hp,460);eq(created(s,'dazed'),4)
end)
test('Deca retaliation death keeps queued Dazed and its roll while Donu still lives',function()
 local _,s=room();s.player.hp=500;s.player.maxHp=500
 local deca,donu=s.enemies[1],s.enemies[2];deca.hp=1;s.player.statuses.thorns=3
 local ai=s.aiRng.counter
 assert(C.endTurn(s));eq(deca.hp,0);eq(s.player.hp,490);eq(created(s,'dazed'),2)
 eq(s.aiRng.counter,ai+2);eq(intent(deca),'square');eq(donu.statuses.strength,3)
end)
test('final Deca retaliation death clears Dazed and roll, with only first damage resolved',function()
 local _,s=room();s.player.hp=500;s.player.maxHp=500
 local deca,donu=s.enemies[1],s.enemies[2];C.damage(s,s.player,donu,250,true)
 deca.hp=1;s.player.statuses.thorns=3;local ai=s.aiRng.counter
 assert(C.endTurn(s));eq(s.phase,'victory');eq(s.player.hp,490);eq(created(s,'dazed'),0)
 eq(s.aiRng.counter,ai)
end)
test('lethal player damage cancels Deca Dazed, its roll, and the later Donu action',function()
 local _,s=room();s.player.hp=1;local ai=s.aiRng.counter
 assert(C.endTurn(s));eq(s.phase,'defeat');eq(created(s,'dazed'),0);eq(s.aiRng.counter,ai)
 eq(s.enemies[2].statuses.strength or 0,0)
end)
test('Run awards a dual Boss battle once, only after both are dead',function()
 local run,s=room();local deca,donu=s.enemies[1],s.enemies[2]
 C.damage(s,s.player,deca,250,true);assert(Run.endTurn(run));eq(run.phase,'combat');eq(run.victories,0)
 C.damage(s,s.player,donu,250,true);assert(Run.endTurn(run));eq(run.phase,'reward');eq(run.victories,1)
 local gold=run.gold;eq(Run.endTurn(run),false);eq(run.gold,gold);eq(run.victories,1)
end)
test('group actions retain exact source order and spend neither HP nor misc streams',function()
 local run,s=room();s.player.block=1000
 local hp,source=s.monsterHpRng.counter,run.miscRng.counter
 assert(C.endTurn(s));s.player.block=1000;local first=#s.events+1;assert(C.endTurn(s))
 local blocks={}
 for i=first,#s.events do local event=s.events[i];if event.kind=='block'then blocks[#blocks+1]=event.detail.target end end
 eq(#blocks,2);eq(blocks[1],s.enemies[1].id);eq(blocks[2],s.enemies[2].id)
 eq(s.monsterHpRng.counter,hp);eq(run.miscRng.counter,source)
 eq(run.encounterSource,'Donu and Deca')
end)
test('each Boss battle owns detached definitions, effects, statuses and power order',function()
 local a,b=battle(),battle()
 a.enemies[1].intents[1].effects[1].value=99
 a.enemies[1].statuses.artifact=0;a.enemies[1].powerOrder[1]='weak'
 eq(b.enemies[1].intents[1].effects[1].value,10);eq(b.enemies[1].statuses.artifact,2)
 eq(b.enemies[1].powerOrder[1],'artifact')
end)
print('LUA_DONU_DECA_PASS '..count)
