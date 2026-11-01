local sliceFirst,sliceLast=...
sliceFirst,sliceLast=sliceFirst or 1,sliceLast or 5
local H=dofile('tests/lua/support/gremlin_gang_fixture.lua')
H.selectCases(sliceFirst,sliceLast)
local Run,Map,Nodes,C,R,I,Data=H.Run,H.Map,H.Nodes,H.C,H.R,H.I,H.Data
local eq,same,freeze,test,ids,oracle,vectors,force,direct,nodeSetup,normal,unknown,enter,streamAfter=H.eq,H.same,H.freeze,H.test,H.ids,H.oracle,H.vectors,H.force,H.direct,H.nodeSetup,H.normal,H.unknown,H.enter,H.streamAfter
for i,v in ipairs(vectors) do test('literal source vector '..i..' constructs four ordered independent instances',function()
 local run=direct(42,11);local wanted=streamAfter(run)
 local oldMisc,oldEvent,oldData,oldDeck=run.miscRng,run.eventRng,run.data,run.deck
 local stable=freeze(oldMisc,oldEvent,oldData,oldDeck)
 force(v[1],function(calls)
  assert(Run.startCombat(run,'gremlin_gang'));eq(calls(),4);same(ids(run.combat),v[2]);same(oracle(v[1]),v[2])
  same(run.miscRng,wanted);eq(run.miscRng.counter,15);eq(run.eventRng,oldEvent);eq(run.data,oldData);eq(run.deck,oldDeck);stable()
  local seen={}
  for slot,e in ipairs(run.combat.enemies) do
   assert(not seen[e.id],'duplicate instance ID');seen[e.id]=true
   for previous=1,slot-1 do local other=run.combat.enemies[previous]
    assert(e~=other and e.statuses~=other.statuses and e.intents~=other.intents,'shared instance state')
   end
  end
  local pristine=freeze(run);eq(Run.startCombat(run,'gremlin_gang'),false);eq(calls(),4);pristine()
 end)
 -- Independent Combat constructor proves slot-to-HP/AI correspondence under
 -- CURRENT separate misc vs shared Combat stream. Not Java cross-stream order.
 local reference=C.new(run.data,{seed=run.seed,cardRandomSeed=string.format('%.0f',tonumber(run.eventSeed)+run.floor),shuffleSeed=string.format('%.0f',tonumber(run.eventSeed)+run.floor),hp=run.hp,maxHp=run.maxHp,gold=run.gold,deck=run.deck,enemies=v[2],masterDeck=run.deck,miscRng=run.miscRng,cardRng=run.cardRng,
  beforeFirstTurn=function(state)state.potionRng=run.shopRng and R.cloneState(run.shopRng.potion)or R.fromSeed(run.runSeed);state.potionCharacter=require('abyss_potion_random').character(run);state.potionInventory=C.copy(run.potions);state.potionCapacity=Run.potionCapacity(run);return true end})
 assert(reference.potionInventory~=run.potions,'independent constructor owns its potion snapshot')
 same(Data.rules.player.startingRelics,{'burning_blood'})
 reference.relics={'burning_blood'};reference.relicCounters={};reference.relicCombat={attackPlayed=false}
 H.sameRunCombat(run,reference)
end) end

local seeded={
 {0,0,{'fat_gremlin','wizard_gremlin','mad_gremlin','sneaky_gremlin'}},
 {1,0,{'wizard_gremlin','fat_gremlin','fat_gremlin','sneaky_gremlin'}},
 {42,0,{'mad_gremlin','shield_gremlin','fat_gremlin','fat_gremlin'}},
 {65535,0,{'wizard_gremlin','mad_gremlin','mad_gremlin','sneaky_gremlin'}},
 {42,11,{'fat_gremlin','wizard_gremlin','shield_gremlin','sneaky_gremlin'}},
}
for _,v in ipairs(seeded) do test('current stream seed '..v[1]..' at counter '..v[2]..' is deterministic without reseeding',function()
 local run,again=direct(v[1],v[2]),direct(v[1],v[2]);local wanted=streamAfter(run)
 assert(Run.startCombat(run,'gremlin_gang'));assert(Run.startCombat(again,'gremlin_gang'))
 same(ids(run.combat),v[3]);same(run.miscRng,wanted);same(run,again)
end) end

test('each battle owns a fresh candidate pool and repeated species remain separate actors',function()
 local run=direct();local pool
 for _,e in ipairs(run.data.enemies.encounters) do if e.id=='gremlin_gang' then pool=e.gremlinPool end end
 assert(pool,'source candidate pool missing');local stable=freeze(pool)
 for _=1,2 do
  force(vectors[1][1],function(calls) assert(Run.startCombat(run,'gremlin_gang'));eq(calls(),4);same(ids(run.combat),vectors[1][2]) end)
  local a,b=run.combat.enemies[1],run.combat.enemies[2];local hp=b.hp
  C.addStatus(a,'weak',1);a.hp=a.hp-1;eq(b.hp,hp);eq(b.statuses.weak,nil);eq(b.statuses.angry,1)
  stable();run.phase='map' -- explicit repeated-host fixture, not a played victory
 end
 eq(run.miscRng.counter,8)
end)
H.failureCases('direct')
test('invalid direct requests and illegal node destinations do not draw or mutate',function()
 for _,mode in ipairs({'id','floor','relic','phase'}) do
  local run=direct();local id='gremlin_gang'
  if mode=='id' then id='missing' elseif mode=='floor' then run.floor=4 elseif mode=='relic' then run.relics={'missing'} else run.phase='reward' end
  local stable=freeze(run);force({},function(calls) eq(Run.startCombat(run,id),false);eq(calls(),0);stable() end)
 end
 local run,map,id=normal();local stable=freeze(run,map)
 eq(Nodes.enter(run,map,'missing'),false);eq(Nodes.enter(run,map,'f1_l1'),false);stable()
 assert(Nodes.enter(run,map,id));run.phase='map';run.nodeFlow.complete=true;run.nodeFlow.mapSeed=-1
 stable=freeze(run,map);local ok,reason=Nodes.enter(run,map,'f11_l2');eq(ok,false);eq(reason,'map_mismatch');stable()
end)

test('low-level explicit five-actor arrays retain capacity and never trigger group selection',function()
 local roster={'mad_gremlin','sneaky_gremlin','fat_gremlin','wizard_gremlin','shield_gremlin'}
 force({},function(calls) local battle=C.new(Data,{seed=42,enemies=roster});same(ids(battle),roster);eq(calls(),0) end)
end)

local unchanged={
 cultist_solo={'cultist'},jaw_solo={'jaw_worm'},louse_pair={'red_louse','red_louse'},
 louse_trio={'red_louse','red_louse','green_louse'},medium_slimes={'acid_slime_m','spike_slime_m'},
 large_acid={'acid_slime_l'},large_spike={'spike_slime_l'},looter_solo={'looter'},
 blue_slaver_solo={'blue_slaver'},red_slaver_solo={'red_slaver'},fungi_pair={'fungi_beast','fungi_beast'},
 wildlife={'jaw_worm','green_louse'},elite_nob={'gremlin_nob'},elite_lagavulin={'lagavulin'},
 elite_sentries={'sentry','sentry','sentry'},boss_guardian={'guardian'},small_slimes={'spike_slime_s','acid_slime_m'}
}
test('all other 17 encounters keep construction and their declared misc consumption',function()
 local n=0
 for _,e in ipairs(Data.enemies.encounters) do if e.id~='gremlin_gang' then
  n=n+1;local run=Run.new(Data,42);run.floor=e.minFloor
  local oldMisc=run.miscRng;local stable=freeze(oldMisc)
  assert(Run.startCombat(run,e.id));same(ids(run.combat),assert(unchanged[e.id]));stable()
  if e.id=='small_slimes' then local wanted=R.cloneState(oldMisc);R.randomBoolean(wanted);same(run.miscRng,wanted)
  elseif e.louseCount then local wanted=R.cloneState(oldMisc);for _=1,e.louseCount do R.randomBoolean(wanted) end;same(run.miscRng,wanted)
  else eq(run.miscRng,oldMisc) end
  local reference=C.new(run.data,{seed=42,cardRandomSeed=string.format('%.0f',tonumber(run.eventSeed)+run.floor),shuffleSeed=string.format('%.0f',tonumber(run.eventSeed)+run.floor),enemies=unchanged[e.id],deck=run.deck,hp=run.hp,maxHp=run.maxHp,gold=run.gold,masterDeck=run.deck,miscRng=run.miscRng,cardRng=run.cardRng,
   beforeFirstTurn=function(state)state.potionRng=run.shopRng and R.cloneState(run.shopRng.potion)or R.fromSeed(run.runSeed);state.potionCharacter=require('abyss_potion_random').character(run);state.potionInventory=C.copy(run.potions);state.potionCapacity=Run.potionCapacity(run);return true end})
  assert(reference.potionInventory~=run.potions,'independent constructor owns its potion snapshot')
  same(Data.rules.player.startingRelics,{'burning_blood'})
  reference.relics={'burning_blood'};reference.relicCounters={};reference.relicCombat={attackPlayed=false}
  H.sameRunCombat(run,reference)
 end end
 eq(n,17)
end)
test('source-room Protect spends only the AI stream, including a singleton target',function()
 -- GainBlockRandomMonsterAction.update uses aiRng.random(size-1). Independent
 -- fixed-source Python integer interpretation (the existing wrapper fixture's
 -- generator) gives room seed42: after 3 opening rolls, next roll88; after a
 -- Protect draw, the following roll61. A singleton still consumes that draw.
 for _,eligible in ipairs({2,1,0}) do
  local run=Run.new(Data,41);local room=Run.roomStreams(run,1)
  eq(room.seed,'42')
  local s=C.new(Data,{seed=101,deck={},enemies={'shield_gremlin','mad_gremlin','sneaky_gremlin'},
   roomSeed=room.seed,roomStreams=room})
  eq(s.aiRng.counter,3)
  if eligible<2 then s.enemies[3].hp=0 end
  if eligible==0 then s.enemies[2].hp=0 end
  local beforeSeed=s.seed
  local hp,shuffle,cards=R.snapshot(s.monsterHpRng),R.snapshot(s.shuffleRng),R.snapshot(s.cardRandomRng)
  C.applyEffects(s,s.enemies[1].intents[1].effects,s.enemies[1],s.player)
  eq(s.aiRng.counter,eligible>0 and 4 or 3,'Protect AI draw count')
  eq(s.seed,beforeSeed,'source Protect must not consume the legacy seed')
  eq(s.enemies[eligible>0 and 2 or 1].block,7,'source-ordered recipient')
  eq(s.enemies[3].block,0)
  same(R.snapshot(s.monsterHpRng),hp);same(R.snapshot(s.shuffleRng),shuffle);same(R.snapshot(s.cardRandomRng),cards)
  eq(R.randomInt(s.aiRng,99),eligible>0 and 61 or 88,'independent following AI roll')
 end
end)
H.finish(19,'GREMLIN_GANG_PASS')
